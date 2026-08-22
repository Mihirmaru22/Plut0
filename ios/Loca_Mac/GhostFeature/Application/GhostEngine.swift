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
        doctrine: GhostDoctrine = .hard
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

    public func fetchRules(for season: GhostSeason?) -> [GhostProtocolRule] {
        let kind = season?.protocolKind ?? .the120
        return GhostProtocolRule.defaultRules(for: kind)
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
        let rules = fetchRules(for: season)

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
        let daysMap = Dictionary(uniqueKeysWithValues: allDays.map { ($0.dateString, $0) })

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
        let daysMap = Dictionary(uniqueKeysWithValues: allDays.map { ($0.dateString, $0) })

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
        let daysMap = Dictionary(uniqueKeysWithValues: allDays.map { ($0.dateString, $0) })

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
    }

    public struct GhostEvolutionReport: Sendable {
        public let weeklyGhostRate: Double
        public let bodyAdherence: Double
        public let mindAdherence: Double
        public let silenceAdherence: Double
        public let ruleAdherences: [RuleAdherence]
        public let suggestion: String
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

        let rules = fetchRules(for: season)
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
        let daysMap = Dictionary(uniqueKeysWithValues: allDays.map { ($0.id, $0) })

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
}
