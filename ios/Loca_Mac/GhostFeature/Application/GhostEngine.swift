import Foundation
import Combine

/// Central coordinator for Ghost Mode / Winter Arc execution.
/// Thread-safe actor managing contract life cycles, ring closures, streak math, and ridge projections.
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

    // MARK: - Streak & Rank Math

    public struct StreakStatus: Equatable, Sendable {
        public let currentStreak: Int
        public let bestStreak: Int
        public let rank: GhostRank
        public let isDented: Bool
        public let totalGhostDays: Int
    }

    public func computeStreakStatus() async throws -> StreakStatus {
        guard let season = try await store.fetchActiveSeason() else {
            return StreakStatus(currentStreak: 0, bestStreak: 0, rank: .uninitiated, isDented: false, totalGhostDays: 0)
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

        // Traverse sequentially from day 0 to today
        for i in 0..<totalElapsed {
            guard let targetDate = calendar.date(byAdding: .day, value: i, to: calStart) else { continue }
            let dateStr = Self.dateString(from: targetDate)
            let isCurrentDay = calendar.isDateInToday(targetDate)

            let isGhost = daysMap[dateStr]?.ghostDay ?? false
            if isGhost {
                ghostCount += 1
                streak += 1
                bestStreak = max(bestStreak, streak)
            } else if !isCurrentDay {
                // Past missed day
                if season.doctrine == .hard {
                    streak = 0
                } else {
                    // Arc Doctrine: Dent only
                    streak = max(0, streak - 1)
                    isDented = true
                }
            }
        }

        let rank = GhostRank.rank(forStreak: streak)
        return StreakStatus(
            currentStreak: streak,
            bestStreak: bestStreak,
            rank: rank,
            isDented: isDented,
            totalGhostDays: ghostCount
        )
    }

    // MARK: - Season Ridge Projection

    public func fetchRidgeSeries() async throws -> [GhostRidgePoint] {
        guard let season = try await store.fetchActiveSeason() else { return [] }

        let allDays = try await store.fetchAllDays(seasonID: season.id)
        let daysMap = Dictionary(uniqueKeysWithValues: allDays.map { ($0.dateString, $0) })

        let calendar = Calendar.current
        let totalDays = season.totalDays
        var points: [GhostRidgePoint] = []

        for i in 0..<totalDays {
            guard let date = calendar.date(byAdding: .day, value: i, to: season.startDate) else { continue }
            let dateStr = Self.dateString(from: date)
            let isToday = calendar.isDateInToday(date)
            let isSummit = (i == totalDays - 1)

            let record = daysMap[dateStr]
            let score = record?.score ?? 0
            let isGhost = record?.ghostDay ?? false

            let pt = GhostRidgePoint(
                dayIndex: i + 1,
                dateString: dateStr,
                score: score,
                isGhostDay: isGhost,
                isToday: isToday,
                isSummitMarker: isSummit
            )
            points.append(pt)
        }

        return points
    }
}
