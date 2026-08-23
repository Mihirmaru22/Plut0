import Foundation
import Combine

/// Central coordinator for Ghost Mode / Winter Arc execution.
/// Thread-safe actor managing contract life cycles, receipts, ring closures, streak math,
/// chain grids, dark hours, and ridge projections.
public actor GhostEngine {
    public static let shared = GhostEngine()

    private let store: GhostStore
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    public init(store: GhostStore = GhostStore.shared) {
        self.store = store
    }

    public static func dateString(from date: Date) -> String {
        dateFormatter.string(from: date)
    }

    // MARK: - Season Management

    public func fetchActiveSeason() async throws -> GhostSeason? {
        try await store.fetchActiveSeason()
    }

    public func signContract(
        name: String,
        protocolKind: GhostProtocolKind = .the120,
        startDate: Date = Date(),
        endDate: Date? = nil,
        doctrine: GhostDoctrine = .hard,
        customRules: [GhostProtocolRule]? = nil
    ) async throws -> GhostSeason {
        let calculatedEnd = endDate ?? Calendar.current.date(byAdding: .day, value: protocolKind.durationDays, to: startDate) ?? startDate
        let season = GhostSeason(
            name: name,
            protocolKind: protocolKind,
            startDate: startDate,
            endDate: calculatedEnd,
            doctrine: doctrine,
            signedAt: Date()
        )
        try await store.saveSeason(season)

        if let rules = customRules {
            try? await store.deleteAllCustomRules(seasonID: season.id)
            for rule in rules {
                try await store.saveCustomRule(rule, seasonID: season.id)
            }
        }
        return season
    }

    // MARK: - Day Operations

    public func getOrCreateDayRecord(for date: Date = Date()) async throws -> GhostDay? {
        guard let season = try await store.fetchActiveSeason() else { return nil }
        let dateStr = Self.dateString(from: date)
        if let existing = try await store.fetchDay(seasonID: season.id, dateString: dateStr) {
            return existing
        }

        let newDay = GhostDay(
            seasonID: season.id,
            dateString: dateStr
        )
        try await store.saveDay(newDay)
        return newDay
    }

    public func fetchRules(for season: GhostSeason?) async -> [GhostProtocolRule] {
        guard let season = season else {
            let presets = GhostProtocolRule.defaultRules(for: .the120)
            return presets.filter { $0.isEnabled }
        }
        let customRules = (try? await store.fetchCustomRules(seasonID: season.id)) ?? []
        if !customRules.isEmpty {
            var seen = Set<String>()
            var deduped: [GhostProtocolRule] = []
            for rule in customRules {
                let key = "\(rule.ring.rawValue)_\(rule.title.lowercased())"
                if !seen.contains(key) {
                    seen.insert(key)
                    deduped.append(rule)
                }
            }
            return deduped
                .filter { $0.isEnabled }
                .sorted { ($0.sortOrder, $0.ring.rawValue) < ($1.sortOrder, $1.ring.rawValue) }
        }
        let kind = season.protocolKind
        var presets = GhostProtocolRule.defaultRules(for: kind)
        for i in presets.indices { presets[i].sortOrder = i }
        return presets.filter { $0.isEnabled }
    }

    public func allRulesIncludingDisabled(for season: GhostSeason) async -> [GhostProtocolRule] {
        let customRules = (try? await store.fetchCustomRules(seasonID: season.id)) ?? []
        if !customRules.isEmpty {
            var seen = Set<String>()
            var deduped: [GhostProtocolRule] = []
            for rule in customRules {
                let key = "\(rule.ring.rawValue)_\(rule.title.lowercased())"
                if !seen.contains(key) {
                    seen.insert(key)
                    deduped.append(rule)
                }
            }
            return deduped.sorted { ($0.sortOrder, $0.ring.rawValue) < ($1.sortOrder, $1.ring.rawValue) }
        }
        let kind = season.protocolKind
        var presets = GhostProtocolRule.defaultRules(for: kind)
        for i in presets.indices { presets[i].sortOrder = i }
        return presets
    }

    // MARK: - Receipts & Live Ring Re-Evaluation (Migration v5)

    public func logReceipt(
        ruleID: String,
        proofKind: GhostProofKind,
        value: Double,
        photoPath: String? = nil,
        date: Date = Date()
    ) async throws -> (day: GhostDay, receipts: [GhostReceipt])? {
        guard var day = try await getOrCreateDayRecord(for: date) else { return nil }
        guard let season = try await store.fetchActiveSeason() else { return nil }

        let receipt = GhostReceipt(
            dayID: day.id,
            ruleID: ruleID,
            kind: proofKind,
            valueReal: value,
            photoPath: photoPath,
            loggedAt: Date()
        )
        try await store.saveReceipt(receipt)

        let allReceipts = try await store.fetchReceipts(dayID: day.id)
        let rules = await fetchRules(for: season)

        // Evaluate Ring Closures from Receipts
        let bodyRules = rules.filter { $0.ring == .body }
        let mindRules = rules.filter { $0.ring == .mind }
        let silenceRules = rules.filter { $0.ring == .silence }

        let bodySatisfied = bodyRules.isEmpty ? day.bodyClosed : bodyRules.allSatisfy { r in
            let matching = allReceipts.filter { $0.ruleID == r.id }
            let total = matching.reduce(0.0) { $0 + $1.valueReal }
            return total >= r.targetValue
        }

        let mindSatisfied = mindRules.isEmpty ? day.mindClosed : mindRules.allSatisfy { r in
            let matching = allReceipts.filter { $0.ruleID == r.id }
            let total = matching.reduce(0.0) { $0 + $1.valueReal }
            return total >= r.targetValue
        }

        let silenceSatisfied = silenceRules.isEmpty ? day.silenceClosed : silenceRules.allSatisfy { r in
            let matching = allReceipts.filter { $0.ruleID == r.id }
            let total = matching.reduce(0.0) { $0 + $1.valueReal }
            return total >= r.targetValue || (day.silenceMinutesVerified + day.silenceMinutesAttested) >= Int(r.targetValue)
        }

        day.bodyClosed = bodySatisfied
        day.mindClosed = mindSatisfied
        day.silenceClosed = silenceSatisfied

        let (isGhost, score) = GhostDay.computeScore(
            body: day.bodyClosed,
            mind: day.mindClosed,
            silence: day.silenceClosed,
            verifiedMinutes: day.silenceMinutesVerified,
            attestedMinutes: day.silenceMinutesAttested
        )

        day.ghostDay = isGhost
        day.score = score

        try await store.saveDay(day)
        return (day, allReceipts)
    }

    public func fetchReceipts(for date: Date = Date()) async throws -> [GhostReceipt] {
        guard let day = try await getOrCreateDayRecord(for: date) else { return [] }
        return try await store.fetchReceipts(dayID: day.id)
    }

    public func nextPendingRule(
        for ring: GhostRing,
        receipts: [GhostReceipt],
        rules: [GhostProtocolRule]
    ) -> String? {
        let ringRules = rules.filter { $0.ring == ring }
        for r in ringRules {
            let matching = receipts.filter { $0.ruleID == r.id }
            let total = matching.reduce(0.0) { $0 + $1.valueReal }
            if total < r.targetValue {
                return r.title
            }
        }
        return nil
    }

    public func toggleRing(ring: GhostRing, isClosed: Bool, date: Date = Date()) async throws -> GhostDay? {
        guard var day = try await getOrCreateDayRecord(for: date) else { return nil }

        switch ring {
        case .body:    day.bodyClosed = isClosed
        case .mind:    day.mindClosed = isClosed
        case .silence: day.silenceClosed = isClosed
        }

        let (isGhost, score) = GhostDay.computeScore(
            body: day.bodyClosed,
            mind: day.mindClosed,
            silence: day.silenceClosed,
            verifiedMinutes: day.silenceMinutesVerified,
            attestedMinutes: day.silenceMinutesAttested
        )

        day.ghostDay = isGhost
        day.score = score

        try await store.saveDay(day)
        return day
    }

    public func recordVerifiedSilenceMinutes(_ minutes: Int, date: Date = Date()) async throws -> GhostDay? {
        guard var day = try await getOrCreateDayRecord(for: date) else { return nil }
        day.silenceMinutesVerified += minutes
        if day.silenceMinutesVerified >= 45 {
            day.silenceClosed = true
        }

        let (isGhost, score) = GhostDay.computeScore(
            body: day.bodyClosed,
            mind: day.mindClosed,
            silence: day.silenceClosed,
            verifiedMinutes: day.silenceMinutesVerified,
            attestedMinutes: day.silenceMinutesAttested
        )

        day.ghostDay = isGhost
        day.score = score

        try await store.saveDay(day)
        return day
    }

    public func recordAttestedSilenceMinutes(_ minutes: Int, date: Date = Date()) async throws -> GhostDay? {
        guard var day = try await getOrCreateDayRecord(for: date) else { return nil }
        day.silenceMinutesAttested = minutes
        if (day.silenceMinutesVerified + minutes) >= 45 {
            day.silenceClosed = true
        }

        let (isGhost, score) = GhostDay.computeScore(
            body: day.bodyClosed,
            mind: day.mindClosed,
            silence: day.silenceClosed,
            verifiedMinutes: day.silenceMinutesVerified,
            attestedMinutes: day.silenceMinutesAttested
        )

        day.ghostDay = isGhost
        day.score = score

        try await store.saveDay(day)
        return day
    }

    public func recordOfflineInterval(start: Date, end: Date? = nil, date: Date = Date()) async throws -> GhostDay? {
        guard var day = try await getOrCreateDayRecord(for: date) else { return nil }
        let interval = GhostOfflineInterval(start: start, end: end)
        day.offlineIntervals.append(interval)
        try await store.saveDay(day)
        return day
    }

    public func setReflectionNoteID(_ noteID: String, date: Date = Date()) async throws -> GhostDay? {
        guard var day = try await getOrCreateDayRecord(for: date) else { return nil }
        day.reflectionNoteID = noteID
        day.mindClosed = true

        let (isGhost, score) = GhostDay.computeScore(
            body: day.bodyClosed,
            mind: day.mindClosed,
            silence: day.silenceClosed,
            verifiedMinutes: day.silenceMinutesVerified,
            attestedMinutes: day.silenceMinutesAttested
        )

        day.ghostDay = isGhost
        day.score = score

        try await store.saveDay(day)
        return day
    }

    // MARK: - Streak & Authentic Restart Doctrine Math

    public struct StreakStatus: Equatable, Sendable {
        public let currentStreak: Int
        public let bestStreak: Int
        public let effectiveDayNumber: Int
        public let isRestarted: Bool
        public let rank: GhostRank
        public let isDented: Bool
        public let totalGhostDays: Int

        public init(
            currentStreak: Int = 0,
            bestStreak: Int = 0,
            effectiveDayNumber: Int = 1,
            isRestarted: Bool = false,
            rank: GhostRank = .uninitiated,
            isDented: Bool = false,
            totalGhostDays: Int = 0
        ) {
            self.currentStreak = currentStreak
            self.bestStreak = bestStreak
            self.effectiveDayNumber = effectiveDayNumber
            self.isRestarted = isRestarted
            self.rank = rank
            self.isDented = isDented
            self.totalGhostDays = totalGhostDays
        }
    }

    public func computeStreakStatus() async throws -> StreakStatus {
        guard let season = try await store.fetchActiveSeason() else {
            return StreakStatus()
        }

        let allDays = try await store.fetchAllDays(seasonID: season.id)
        let daysMap = Dictionary(allDays.map { ($0.dateString, $0) }, uniquingKeysWith: { first, _ in first })

        let calendar = Calendar.current
        let today = Date()
        let calStart = season.startDate
        let totalElapsed = max(1, (calendar.dateComponents([.day], from: calStart, to: today).day ?? 0) + 1)

        var streak = 0
        var bestStreak = 0
        var isDented = false
        var ghostCount = 0
        var effectiveDay = 1
        var isRestarted = false

        for i in 0..<totalElapsed {
            guard let targetDate = calendar.date(byAdding: .day, value: i, to: calStart) else { continue }
            let dateStr = Self.dateString(from: targetDate)
            let isCurrentDay = calendar.isDateInToday(targetDate)

            let isGhost = daysMap[dateStr]?.ghostDay ?? false
            if isGhost {
                ghostCount += 1
                streak += 1
                effectiveDay += 1
                bestStreak = max(bestStreak, streak)
            } else if !isCurrentDay {
                if season.doctrine == .hard {
                    streak = 0
                    effectiveDay = 1 // Authentic Hard Doctrine: Day resets to 1
                    isRestarted = true
                } else {
                    streak = max(0, streak - 1)
                    isDented = true
                }
            }
        }

        let rank = GhostRank.rank(forStreak: streak)
        return StreakStatus(
            currentStreak: streak,
            bestStreak: bestStreak,
            effectiveDayNumber: min(season.totalDays, max(1, effectiveDay)),
            isRestarted: isRestarted,
            rank: rank,
            isDented: isDented,
            totalGhostDays: ghostCount
        )
    }

    // MARK: - Season Ridge Projection (With Restart Cliff)

    public func fetchRidgeSeries() async throws -> [GhostRidgePoint] {
        guard let season = try await store.fetchActiveSeason() else { return [] }

        let allDays = try await store.fetchAllDays(seasonID: season.id)
        let daysMap = Dictionary(allDays.map { ($0.dateString, $0) }, uniquingKeysWith: { first, _ in first })

        let calendar = Calendar.current
        let totalDays = season.totalDays
        var points: [GhostRidgePoint] = []

        var currentAltitudeOffset = 0.0

        for i in 0..<totalDays {
            guard let date = calendar.date(byAdding: .day, value: i, to: season.startDate) else { continue }
            let dateStr = Self.dateString(from: date)
            let isToday = calendar.isDateInToday(date)
            let isSummit = (i == totalDays - 1)

            let record = daysMap[dateStr]
            let score = record?.score ?? 0
            let isGhost = record?.ghostDay ?? false

            // Under Hard doctrine, a missed day creates an elevation cliff
            if !isGhost && record != nil && !isToday && season.doctrine == .hard {
                currentAltitudeOffset = max(0.0, currentAltitudeOffset - 300.0)
            } else if isGhost {
                currentAltitudeOffset += 25.0
            }

            var pt = GhostRidgePoint(
                dayIndex: i + 1,
                dateString: dateStr,
                score: score,
                isGhostDay: isGhost,
                isToday: isToday,
                isSummitMarker: isSummit
            )
            pt.elevationMeters += currentAltitudeOffset
            points.append(pt)
        }

        return points
    }

    // MARK: - Chain Grid Builder

    public struct GhostChainCell: Identifiable, Sendable {
        public var id: String { dateString }
        public let dayIndex: Int
        public let dateString: String
        public let bodyClosed: Bool
        public let mindClosed: Bool
        public let silenceClosed: Bool
        public let ghostDay: Bool
        public let isToday: Bool
        public let isFuture: Bool
        public let score: Int
    }

    public func fetchChainGrid() async throws -> [GhostChainCell] {
        guard let season = try await store.fetchActiveSeason() else { return [] }

        let allDays = try await store.fetchAllDays(seasonID: season.id)
        let daysMap = Dictionary(allDays.map { ($0.dateString, $0) }, uniquingKeysWith: { first, _ in first })

        let calendar = Calendar.current
        let today = Date()
        let totalDays = season.totalDays
        var cells: [GhostChainCell] = []

        for i in 0..<totalDays {
            guard let date = calendar.date(byAdding: .day, value: i, to: season.startDate) else { continue }
            let dateStr = Self.dateString(from: date)
            let isToday = calendar.isDateInToday(date)
            let isFuture = date > today && !isToday

            let record = daysMap[dateStr]
            cells.append(GhostChainCell(
                dayIndex: i + 1,
                dateString: dateStr,
                bodyClosed: record?.bodyClosed ?? false,
                mindClosed: record?.mindClosed ?? false,
                silenceClosed: record?.silenceClosed ?? false,
                ghostDay: record?.ghostDay ?? false,
                isToday: isToday,
                isFuture: isFuture,
                score: record?.score ?? 0
            ))
        }

        return cells
    }

    // MARK: - Dark Hours Summary

    public struct DarkHoursSummary: Sendable {
        public let todayMinutes: Int
        public let weekMinutes: Int
        public let longestStretchMinutes: Int
        public let recentIntervals: [GhostOfflineInterval]

        public init(
            todayMinutes: Int = 0,
            weekMinutes: Int = 0,
            longestStretchMinutes: Int = 0,
            recentIntervals: [GhostOfflineInterval] = []
        ) {
            self.todayMinutes = todayMinutes
            self.weekMinutes = weekMinutes
            self.longestStretchMinutes = longestStretchMinutes
            self.recentIntervals = recentIntervals
        }
    }

    public func fetchDarkHoursSummary() async throws -> DarkHoursSummary {
        guard let season = try await store.fetchActiveSeason() else {
            return DarkHoursSummary(todayMinutes: 0, weekMinutes: 0, longestStretchMinutes: 0, recentIntervals: [])
        }

        let allDays = try await store.fetchAllDays(seasonID: season.id)
        let calendar = Calendar.current
        let todayStr = Self.dateString(from: Date())

        let todayRecord = allDays.first(where: { $0.dateString == todayStr })
        let todayMin = (todayRecord?.silenceMinutesVerified ?? 0) + (todayRecord?.silenceMinutesAttested ?? 0)

        let past7Days = allDays.suffix(7)
        let weekMin = past7Days.reduce(0) { $0 + $1.silenceMinutesVerified + $1.silenceMinutesAttested }

        var maxStretch = 0
        for day in allDays {
            let total = day.silenceMinutesVerified + day.silenceMinutesAttested
            maxStretch = max(maxStretch, total)
        }

        let intervals = todayRecord?.offlineIntervals ?? []

        return DarkHoursSummary(
            todayMinutes: todayMin,
            weekMinutes: weekMin,
            longestStretchMinutes: maxStretch,
            recentIntervals: intervals
        )
    }

    // MARK: - Weekly Evolution Report

    public struct RuleAdherence: Identifiable, Sendable {
        public var id: String { ruleID }
        public let ruleID: String
        public let title: String
        public let ring: GhostRing
        public let completedDays: Int
        public let totalDays: Int
        public var ratePercent: Double {
            totalDays > 0 ? (Double(completedDays) / Double(totalDays)) * 100.0 : 0.0
        }

        public init(
            ruleID: String,
            title: String,
            ring: GhostRing,
            completedDays: Int,
            totalDays: Int
        ) {
            self.ruleID = ruleID
            self.title = title
            self.ring = ring
            self.completedDays = completedDays
            self.totalDays = totalDays
        }
    }

    public struct GhostEvolutionReport: Sendable {
        public let weeklyGhostRate: Double
        public let bodyAdherence: Double
        public let mindAdherence: Double
        public let silenceAdherence: Double
        public let ruleAdherences: [RuleAdherence]
        public let suggestion: String

        public init(
            weeklyGhostRate: Double = 0,
            bodyAdherence: Double = 0,
            mindAdherence: Double = 0,
            silenceAdherence: Double = 0,
            ruleAdherences: [RuleAdherence] = [],
            suggestion: String = ""
        ) {
            self.weeklyGhostRate = weeklyGhostRate
            self.bodyAdherence = bodyAdherence
            self.mindAdherence = mindAdherence
            self.silenceAdherence = silenceAdherence
            self.ruleAdherences = ruleAdherences
            self.suggestion = suggestion
        }
    }

    public func fetchEvolutionReport() async throws -> GhostEvolutionReport {
        guard let season = try await store.fetchActiveSeason() else {
            return GhostEvolutionReport(
                weeklyGhostRate: 0, bodyAdherence: 0, mindAdherence: 0, silenceAdherence: 0,
                ruleAdherences: [], suggestion: "Sign your season covenant to begin evolution tracking."
            )
        }

        let allDays = try await store.fetchAllDays(seasonID: season.id)
        let past7 = Array(allDays.suffix(7))
        let count = max(1, past7.count)

        let ghostDaysCount = past7.filter(\.ghostDay).count
        let bodyCount = past7.filter(\.bodyClosed).count
        let mindCount = past7.filter(\.mindClosed).count
        let silenceCount = past7.filter(\.silenceClosed).count

        let rules = await fetchRules(for: season)
        var ruleStats: [RuleAdherence] = []

        let allReceipts = try await store.fetchAllReceipts(seasonID: season.id)
        let receiptsByDay = Dictionary(grouping: allReceipts, by: \.dayID)

        for rule in rules {
            var completedCount = 0
            for day in past7 {
                let dayReceipts = receiptsByDay[day.id] ?? []
                let ruleReceipts = dayReceipts.filter { $0.ruleID == rule.id }
                let totalVal = ruleReceipts.reduce(0.0) { $0 + $1.valueReal }
                if totalVal >= rule.targetValue {
                    completedCount += 1
                }
            }
            ruleStats.append(RuleAdherence(
                ruleID: rule.id,
                title: rule.title,
                ring: rule.ring,
                completedDays: completedCount,
                totalDays: count
            ))
        }

        let bodyRate = Double(bodyCount) / Double(count)
        let mindRate = Double(mindCount) / Double(count)
        let silenceRate = Double(silenceCount) / Double(count)
        let ghostRate = Double(ghostDaysCount) / Double(count)

        var suggestion = "Sovereign momentum steady. Maintain deep silence focus."
        if silenceRate < 0.6 {
            suggestion = "Silence Ring was lowest this week. Prioritize a 45m Focus Room session earlier in the day."
        } else if bodyRate < 0.6 {
            suggestion = "Body Ring was missed on multiple days. Schedule morning forge as non-negotiable."
        } else if mindRate < 0.6 {
            suggestion = "Mind Ring reflection lagged. Seal your 10 pages before evening sleep."
        }

        return GhostEvolutionReport(
            weeklyGhostRate: ghostRate * 100.0,
            bodyAdherence: bodyRate * 100.0,
            mindAdherence: mindRate * 100.0,
            silenceAdherence: silenceRate * 100.0,
            ruleAdherences: ruleStats,
            suggestion: suggestion
        )
    }

    // MARK: - Photo Wall Artifacts

    public struct GhostPhotoArtifact: Identifiable, Sendable {
        public let id: String
        public let dayIndex: Int
        public let dateString: String
        public let photoPath: String
        public let loggedAt: Date
    }

    public func fetchAllPhotoArtifacts() async throws -> [GhostPhotoArtifact] {
        guard let season = try await store.fetchActiveSeason() else { return [] }

        let allDays = try await store.fetchAllDays(seasonID: season.id)
        let daysMap = Dictionary(allDays.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let receipts = try await store.fetchAllReceipts(seasonID: season.id)
        let photoReceipts = receipts.filter { $0.kind == .artifact && $0.photoPath != nil }

        let calendar = Calendar.current
        var artifacts: [GhostPhotoArtifact] = []

        for r in photoReceipts {
            guard let path = r.photoPath, let day = daysMap[r.dayID] else { continue }
            let dayIndex = (calendar.dateComponents([.day], from: season.startDate, to: day.createdAt).day ?? 0) + 1
            artifacts.append(GhostPhotoArtifact(
                id: r.id,
                dayIndex: max(1, dayIndex),
                dateString: day.dateString,
                photoPath: path,
                loggedAt: r.loggedAt
            ))
        }

        return artifacts.sorted(by: { $0.loggedAt < $1.loggedAt })
    }

    // MARK: - Custom Rules Management

    public func saveCustomRule(_ rule: GhostProtocolRule) async throws {
        guard let season = try await store.fetchActiveSeason() else { return }
        try await store.saveCustomRule(rule, seasonID: season.id)
    }

    public func deleteCustomRule(id: String) async throws {
        try await store.deleteCustomRule(id: id)
    }

    // MARK: - Season Lifecycle

    /// Fetch all seasons including completed ones (for campaign history).
    public func fetchAllSeasons() async throws -> [GhostSeason] {
        try await store.fetchAllSeasons()
    }

    /// Freeze the current active season with final stats.
    public func completeSeason(passportPDFPath: String? = nil) async throws {
        guard var season = try await store.fetchActiveSeason() else { return }
        let allDays  = try await store.fetchAllDays(seasonID: season.id)
        let streak   = try await computeStreakStatus()
        let elapsed  = max(1, allDays.count)
        let ghostDays = allDays.filter(\.ghostDay).count
        let bodyRate  = Double(allDays.filter(\.bodyClosed).count)    / Double(elapsed)
        let mindRate  = Double(allDays.filter(\.mindClosed).count)    / Double(elapsed)
        let silRate   = Double(allDays.filter(\.silenceClosed).count) / Double(elapsed)
        let avgScore  = Double(allDays.map(\.score).reduce(0, +))     / Double(elapsed)

        let stats = SeasonFinalStats(
            totalGhostDays:   ghostDays,
            totalElapsedDays: elapsed,
            bestStreak:       streak.bestStreak,
            finalStreak:      streak.currentStreak,
            completionRate:   Double(ghostDays) / Double(elapsed) * 100.0,
            bodyRate:         bodyRate * 100.0,
            mindRate:         mindRate * 100.0,
            silenceRate:      silRate  * 100.0,
            averageScore:     avgScore,
            finalRank:        streak.rank.rawValue
        )
        season.completedAt     = Date()
        season.finalStats      = stats
        season.passportPDFPath = passportPDFPath
        try await store.completeSeason(season)
    }

    /// Complete the current season then immediately begin a new one.
    public func startNewSeason(
        name: String,
        protocolKind: GhostProtocolKind = .the120,
        startDate: Date = Date(),
        endDate: Date? = nil,
        doctrine: GhostDoctrine = .hard
    ) async throws -> GhostSeason {
        try await completeSeason()
        return try await signContract(
            name: name,
            protocolKind: protocolKind,
            startDate: startDate,
            endDate: endDate,
            doctrine: doctrine
        )
    }

    // MARK: - Analytics Engine

    /// Full on-device analytics report. windowDays controls trend window size.
    public func fetchAnalyticsReport(windowDays: Int = 30) async throws -> GhostAnalyticsReport {
        guard let season = try await store.fetchActiveSeason() else {
            return GhostAnalyticsReport()
        }

        let allDays     = try await store.fetchAllDays(seasonID: season.id)
        let allReceipts = try await store.fetchAllReceipts(seasonID: season.id)
        let rules       = await fetchRules(for: season)
        let streak      = try await computeStreakStatus()
        let calendar    = Calendar.current
        let window      = min(windowDays, max(1, allDays.count))
        let recentDays  = Array(allDays.suffix(window))

        // --- Ring Trend Windows (7-day buckets) ---
        var trendWindows: [GhostRing: [RingTrendWindow]] = [:]
        for ring in GhostRing.allCases {
            var windows: [RingTrendWindow] = []
            let chunkSize = 7
            var offset = 0
            var weekIndex = 1
            while offset < recentDays.count {
                let chunk = Array(recentDays[offset..<min(offset + chunkSize, recentDays.count)])
                let completed: Int
                switch ring {
                case .body:    completed = chunk.filter(\.bodyClosed).count
                case .mind:    completed = chunk.filter(\.mindClosed).count
                case .silence: completed = chunk.filter(\.silenceClosed).count
                }
                let rate = Double(completed) / Double(chunk.count)
                windows.append(RingTrendWindow(ring: ring, label: "Wk \(weekIndex)", completionRate: rate, dayCount: chunk.count))
                offset += chunkSize
                weekIndex += 1
            }
            trendWindows[ring] = windows
        }

        // --- Rule Correlations (point-biserial coefficient: rule completion vs ghost day) ---
        let receiptsByDay = Dictionary(grouping: allReceipts, by: \.dayID)
        var ruleCorrelations: [RuleCorrelation] = []
        let fmt = ISO8601DateFormatter()

        for rule in rules {
            var ruleCompleted = [Bool]()
            var ghostFlags    = [Bool]()
            var wdCompletedCount = [Int: Int]()
            var wdTotalCount     = [Int: Int]()

            for day in recentDays {
                let dayReceipts  = receiptsByDay[day.id] ?? []
                let ruleReceipts = dayReceipts.filter { $0.ruleID == rule.id }
                let totalVal     = ruleReceipts.reduce(0.0) { $0 + $1.valueReal }
                let done         = totalVal >= rule.targetValue
                ruleCompleted.append(done)
                ghostFlags.append(day.ghostDay)

                let date = fmt.date(from: day.dateString + "T00:00:00Z") ?? Date()
                let wd   = calendar.component(.weekday, from: date)
                wdTotalCount[wd, default: 0] += 1
                if done { wdCompletedCount[wd, default: 0] += 1 }
            }

            let n        = Double(ruleCompleted.count)
            let x        = ruleCompleted.map { $0 ? 1.0 : 0.0 }
            let y        = ghostFlags.map    { $0 ? 1.0 : 0.0 }
            let meanX    = n > 0 ? x.reduce(0, +) / n : 0
            let meanY    = n > 0 ? y.reduce(0, +) / n : 0
            let num      = zip(x, y).reduce(0.0) { $0 + ($1.0 - meanX) * ($1.1 - meanY) }
            let denX     = x.reduce(0.0) { $0 + pow($1 - meanX, 2) }
            let denY     = y.reduce(0.0) { $0 + pow($1 - meanY, 2) }
            let coeff    = (denX * denY == 0) ? 0.0 : num / sqrt(denX * denY)

            let completionRate = ruleCompleted.isEmpty ? 0.0 :
                Double(ruleCompleted.filter { $0 }.count) / Double(ruleCompleted.count)

            let half       = max(1, ruleCompleted.count / 2)
            let firstRate  = ruleCompleted.isEmpty ? 0.0 :
                Double(ruleCompleted.prefix(half).filter { $0 }.count) / Double(half)
            let secondRate = ruleCompleted.isEmpty ? 0.0 :
                Double(ruleCompleted.suffix(half).filter { $0 }.count) / Double(half)
            let trend: RuleCorrelation.TrendDirection =
                secondRate - firstRate > 0.1 ? .improving :
                firstRate - secondRate > 0.1 ? .declining : .flat

            let wdRates   = wdTotalCount.compactMapValues { total -> Double in
                let wd = wdTotalCount.first(where: { $0.value == total })?.key ?? 1
                return Double(wdCompletedCount[wd] ?? 0) / Double(total)
            }
            let weakestWD = wdRates.min(by: { $0.value < $1.value })?.key

            ruleCorrelations.append(RuleCorrelation(
                ruleID:                 rule.id,
                title:                  rule.title,
                ring:                   rule.ring,
                correlationCoefficient: max(0, min(1, coeff)),
                completionRate:         completionRate,
                trendDirection:         trend,
                weakestWeekday:         weakestWD
            ))
        }
        ruleCorrelations.sort { $0.correlationCoefficient > $1.correlationCoefficient }

        // --- Time-of-Day Pattern ---
        var hourlyCounts = [Int: Int]()
        for receipt in allReceipts {
            let hr = calendar.component(.hour, from: receipt.loggedAt)
            hourlyCounts[hr, default: 0] += 1
        }
        let timePattern = TimeOfDayPattern(hourlyCounts: hourlyCounts)

        // --- Weekday Pattern ---
        var ghostByWeekday = [Int: Int]()
        var totalByWeekday = [Int: Int]()
        for day in allDays {
            let date = fmt.date(from: day.dateString + "T00:00:00Z") ?? Date()
            let wd   = calendar.component(.weekday, from: date)
            totalByWeekday[wd, default: 0] += 1
            if day.ghostDay { ghostByWeekday[wd, default: 0] += 1 }
        }
        var ghostRateByWeekday = [Int: Double]()
        for (wd, total) in totalByWeekday {
            ghostRateByWeekday[wd] = Double(ghostByWeekday[wd] ?? 0) / Double(total)
        }
        let weekdayPattern = WeekdayPattern(ghostRateByWeekday: ghostRateByWeekday)

        // --- Burnout Risk ---
        let recent7   = Array(allDays.suffix(7))
        let recent14  = Array(allDays.suffix(14))
        let rate7     = recent7.isEmpty ? 0.0 : Double(recent7.filter(\.ghostDay).count) / Double(recent7.count)
        let prevRate  = allDays.count > 14 ?
            Double(Array(allDays.dropLast(7)).suffix(7).filter(\.ghostDay).count) / 7.0 : rate7
        let rateDrop  = max(0.0, prevRate - rate7)
        var cluster   = 0
        for day in recent14.reversed() { if !day.ghostDay { cluster += 1 } else { break } }
        let riskScore   = Int(min(100, rateDrop * 60 + Double(cluster) * 10))
        let burnoutRisk = BurnoutRisk(score: riskScore, recentGhostRate: rate7, missedDayCluster: cluster)

        // --- Summary stats ---
        let totalGhost  = allDays.filter(\.ghostDay).count
        let overallRate = Double(totalGhost) / Double(max(1, allDays.count)) * 100.0
        let avgScore    = Double(allDays.map(\.score).reduce(0, +)) / Double(max(1, allDays.count))

        return GhostAnalyticsReport(
            trendWindows:          trendWindows,
            ruleCorrelations:      ruleCorrelations,
            timePattern:           timePattern,
            weekdayPattern:        weekdayPattern,
            burnoutRisk:           burnoutRisk,
            overallCompletionRate: overallRate,
            averageScore:          avgScore,
            currentStreak:         streak.currentStreak,
            bestStreak:            streak.bestStreak
        )
    }

    // MARK: - Season Comparison & Rule History Deep-Dive

    public func compareSeasons(seasonA: GhostSeason, seasonB: GhostSeason) async throws -> SeasonComparison {
        let sideA = try await buildSide(for: seasonA)
        let sideB = try await buildSide(for: seasonB)
        return SeasonComparison(seasonA: sideA, seasonB: sideB)
    }

    private func buildSide(for season: GhostSeason) async throws -> SeasonComparison.Side {
        if let stats = season.finalStats {
            return SeasonComparison.Side(
                id: season.id,
                name: season.name,
                protocolKind: season.protocolKind.title,
                totalDays: season.totalDays,
                ghostDays: stats.totalGhostDays,
                completionRate: stats.completionRate,
                bestStreak: stats.bestStreak,
                bodyRate: stats.bodyRate,
                mindRate: stats.mindRate,
                silenceRate: stats.silenceRate,
                averageScore: stats.averageScore,
                rank: stats.finalRank
            )
        }

        let allDays = try await store.fetchAllDays(seasonID: season.id)
        let streak = try await computeStreakStatus()
        let elapsed = max(1, allDays.count)
        let ghostDays = allDays.filter(\.ghostDay).count
        let bodyRate = Double(allDays.filter(\.bodyClosed).count) / Double(elapsed) * 100.0
        let mindRate = Double(allDays.filter(\.mindClosed).count) / Double(elapsed) * 100.0
        let silRate = Double(allDays.filter(\.silenceClosed).count) / Double(elapsed) * 100.0
        let avgScore = Double(allDays.map(\.score).reduce(0, +)) / Double(elapsed)
        let completionRate = Double(ghostDays) / Double(elapsed) * 100.0

        return SeasonComparison.Side(
            id: season.id,
            name: season.name,
            protocolKind: season.protocolKind.title,
            totalDays: season.totalDays,
            ghostDays: ghostDays,
            completionRate: completionRate,
            bestStreak: streak.bestStreak,
            bodyRate: bodyRate,
            mindRate: mindRate,
            silenceRate: silRate,
            averageScore: avgScore,
            rank: streak.rank.rawValue
        )
    }

    public struct RuleHistoryReport: Sendable {
        public let ruleID: String
        public let title: String
        public let ring: GhostRing
        public let targetValue: Double
        public let unitLabel: String
        public let completionRate: Double
        public let timeline: [DayStatus]
        public let weekdayRates: [Int: Double]
        public let totalLoggedValue: Double

        public struct DayStatus: Identifiable, Sendable {
            public var id: String { dateString }
            public let dateString: String
            public let isCompleted: Bool
            public let loggedValue: Double
        }
    }

    public func fetchRuleHistory(ruleID: String, windowDays: Int = 30) async throws -> RuleHistoryReport? {
        guard let season = try await store.fetchActiveSeason() else { return nil }
        let rules = await fetchRules(for: season)
        guard let rule = rules.first(where: { $0.id == ruleID }) else { return nil }

        let allDays = try await store.fetchAllDays(seasonID: season.id)
        let allReceipts = try await store.fetchAllReceipts(seasonID: season.id)
        let receiptsByDay = Dictionary(grouping: allReceipts, by: \.dayID)
        let calendar = Calendar.current
        let fmt = ISO8601DateFormatter()

        let recentDays = Array(allDays.suffix(windowDays))
        var timeline: [RuleHistoryReport.DayStatus] = []
        var weekdaySuccess = [Int: Int]()
        var weekdayTotal = [Int: Int]()
        var totalLogged: Double = 0

        for day in recentDays {
            let dayReceipts = receiptsByDay[day.id] ?? []
            let matching = dayReceipts.filter { $0.ruleID == ruleID }
            let val = matching.reduce(0.0) { $0 + $1.valueReal }
            let done = val >= rule.targetValue
            totalLogged += val

            timeline.append(RuleHistoryReport.DayStatus(
                dateString: day.dateString,
                isCompleted: done,
                loggedValue: val
            ))

            let date = fmt.date(from: day.dateString + "T00:00:00Z") ?? Date()
            let wd = calendar.component(.weekday, from: date)
            weekdayTotal[wd, default: 0] += 1
            if done { weekdaySuccess[wd, default: 0] += 1 }
        }

        var wdRates: [Int: Double] = [:]
        for (wd, total) in weekdayTotal {
            wdRates[wd] = Double(weekdaySuccess[wd] ?? 0) / Double(max(1, total))
        }

        let completedCount = timeline.filter(\.isCompleted).count
        let rate = timeline.isEmpty ? 0.0 : Double(completedCount) / Double(timeline.count)

        return RuleHistoryReport(
            ruleID: rule.id,
            title: rule.title,
            ring: rule.ring,
            targetValue: rule.targetValue,
            unitLabel: rule.unitLabel,
            completionRate: rate,
            timeline: timeline,
            weekdayRates: wdRates,
            totalLoggedValue: totalLogged
        )
    }

    // MARK: - Factory Reset Ghost Mode

    public func resetAllGhostData() async throws {
        try await store.resetGhostData()
    }
}



