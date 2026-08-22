import Foundation

// MARK: - GhostOfflineInterval

public struct GhostOfflineInterval: Codable, Equatable, Sendable {
    public let start: Date
    public let end: Date?

    public init(start: Date, end: Date? = nil) {
        self.start = start
        self.end = end
    }

    public var durationMinutes: Int {
        let finish = end ?? Date()
        return max(0, Int(finish.timeIntervalSince(start) / 60.0))
    }
}

// MARK: - GhostDay Entity

public struct GhostDay: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var seasonID: String
    public var dateString: String // "YYYY-MM-DD"
    public var bodyClosed: Bool
    public var mindClosed: Bool
    public var silenceClosed: Bool
    public var ghostDay: Bool
    public var score: Int // 0 to 100
    public var silenceMinutesVerified: Int
    public var silenceMinutesAttested: Int
    public var offlineIntervals: [GhostOfflineInterval]
    public var reflectionNoteID: String?
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        seasonID: String,
        dateString: String,
        bodyClosed: Bool = false,
        mindClosed: Bool = false,
        silenceClosed: Bool = false,
        ghostDay: Bool = false,
        score: Int = 0,
        silenceMinutesVerified: Int = 0,
        silenceMinutesAttested: Int = 0,
        offlineIntervals: [GhostOfflineInterval] = [],
        reflectionNoteID: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.seasonID = seasonID
        self.dateString = dateString
        self.bodyClosed = bodyClosed
        self.mindClosed = mindClosed
        self.silenceClosed = silenceClosed
        self.ghostDay = ghostDay
        self.score = score
        self.silenceMinutesVerified = silenceMinutesVerified
        self.silenceMinutesAttested = silenceMinutesAttested
        self.offlineIntervals = offlineIntervals
        self.reflectionNoteID = reflectionNoteID
        self.createdAt = createdAt
    }

    public var totalSilenceMinutes: Int {
        silenceMinutesVerified + silenceMinutesAttested
    }

    public var closedRingsCount: Int {
        (bodyClosed ? 1 : 0) + (mindClosed ? 1 : 0) + (silenceClosed ? 1 : 0)
    }

    /// Computes deterministic 0-100 day score based on ring closures and focus silence minutes.
    public static func computeScore(
        body: Bool,
        mind: Bool,
        silence: Bool,
        verifiedMinutes: Int,
        attestedMinutes: Int
    ) -> (ghostDay: Bool, score: Int) {
        let isGhost = body && mind && silence
        var baseScore = 0
        if body { baseScore += 25 }
        if mind { baseScore += 25 }
        if silence { baseScore += 25 }

        let totalSilence = verifiedMinutes + (attestedMinutes / 2)
        let silenceBonus = min(25, Int((Double(totalSilence) / 90.0) * 25.0))
        let finalScore = min(100, max(0, baseScore + silenceBonus))

        return (ghostDay: isGhost, score: finalScore)
    }
}

// MARK: - GhostRidgePoint

public struct GhostRidgePoint: Identifiable, Equatable, Sendable {
    public var id: String { dateString }
    public let dayIndex: Int
    public let dateString: String
    public let score: Int
    public let isGhostDay: Bool
    public let isToday: Bool
    public let isSummitMarker: Bool
    public let elevationMeters: Double

    public init(
        dayIndex: Int,
        dateString: String,
        score: Int,
        isGhostDay: Bool,
        isToday: Bool = false,
        isSummitMarker: Bool = false
    ) {
        self.dayIndex = dayIndex
        self.dateString = dateString
        self.score = score
        self.isGhostDay = isGhostDay
        self.isToday = isToday
        self.isSummitMarker = isSummitMarker
        // Elevates from base 1000m to 4800m summit curve
        let baseAlt = 1200.0 + (Double(dayIndex) * 28.0)
        let scoreLift = Double(score) * 6.5
        self.elevationMeters = isGhostDay ? (baseAlt + scoreLift) : max(800.0, baseAlt - 400.0 + (Double(score) * 2.0))
    }
}
