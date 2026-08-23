import Foundation

// MARK: - GhostAnalytics Domain Types

/// A single data point in a ring completion trend line.
public struct RingTrendPoint: Identifiable, Sendable, Codable {
    public var id: String { "\(ring.rawValue)-\(dateString)" }
    public let dateString: String      // "YYYY-MM-DD"
    public let ring: GhostRing
    public let isCompleted: Bool
    public let score: Int
    public let weekIndex: Int

    public init(dateString: String, ring: GhostRing, isCompleted: Bool, score: Int, weekIndex: Int = 0) {
        self.dateString = dateString
        self.ring = ring
        self.isCompleted = isCompleted
        self.score = score
        self.weekIndex = weekIndex
    }
}

/// Aggregated ring completion rate for a given window.
public struct RingTrendWindow: Identifiable, Sendable {
    public var id: String { "\(ring.rawValue)-\(label)" }
    public let ring: GhostRing
    public let label: String
    public let completionRate: Double  // 0.0 – 1.0
    public let dayCount: Int

    public init(ring: GhostRing, label: String, completionRate: Double, dayCount: Int) {
        self.ring = ring
        self.label = label
        self.completionRate = completionRate
        self.dayCount = dayCount
    }
}

// MARK: - Rule Correlation

/// How strongly a single rule predicts a full Ghost Day.
public struct RuleCorrelation: Identifiable, Sendable {
    public var id: String { ruleID }
    public let ruleID: String
    public let title: String
    public let ring: GhostRing
    public let correlationCoefficient: Double
    public let completionRate: Double
    public let trendDirection: TrendDirection
    public let weakestWeekday: Int?

    public enum TrendDirection: String, Sendable {
        case improving  = "improving"
        case flat       = "flat"
        case declining  = "declining"

        public var icon: String {
            switch self {
            case .improving: return "arrow.up.right"
            case .flat:      return "arrow.right"
            case .declining: return "arrow.down.right"
            }
        }

        public var label: String {
            switch self {
            case .improving: return "↑ Improving"
            case .flat:      return "→ Flat"
            case .declining: return "↓ Declining"
            }
        }
    }

    public init(
        ruleID: String,
        title: String,
        ring: GhostRing,
        correlationCoefficient: Double,
        completionRate: Double,
        trendDirection: TrendDirection,
        weakestWeekday: Int? = nil
    ) {
        self.ruleID = ruleID
        self.title = title
        self.ring = ring
        self.correlationCoefficient = correlationCoefficient
        self.completionRate = completionRate
        self.trendDirection = trendDirection
        self.weakestWeekday = weakestWeekday
    }
}

// MARK: - Time-of-Day Patterns

public struct TimeOfDayPattern: Sendable {
    public let hourlyCounts: [Int: Int]
    public let peakHour: Int
    public let morningShare: Double
    public let afternoonShare: Double
    public let eveningShare: Double

    public init(hourlyCounts: [Int: Int]) {
        self.hourlyCounts = hourlyCounts
        let total = max(1, hourlyCounts.values.reduce(0, +))
        self.peakHour = hourlyCounts.max(by: { $0.value < $1.value })?.key ?? 9
        let morning   = (5...11).compactMap  { hourlyCounts[$0] }.reduce(0, +)
        let afternoon = (12...17).compactMap { hourlyCounts[$0] }.reduce(0, +)
        let eve1      = (18...23).compactMap { hourlyCounts[$0] }.reduce(0, +)
        let eve2      = (0...4).compactMap   { hourlyCounts[$0] }.reduce(0, +)
        let evening   = eve1 + eve2
        self.morningShare   = Double(morning)   / Double(total)
        self.afternoonShare = Double(afternoon) / Double(total)
        self.eveningShare   = Double(evening)   / Double(total)
    }
}

// MARK: - Weekday Patterns

public struct WeekdayPattern: Sendable {
    /// Key: 1=Sunday … 7=Saturday (Calendar.current weekday)
    public let ghostRateByWeekday: [Int: Double]
    public let bestWeekday: Int
    public let worstWeekday: Int

    public static let weekdayShortNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    public init(ghostRateByWeekday: [Int: Double]) {
        self.ghostRateByWeekday = ghostRateByWeekday
        self.bestWeekday  = ghostRateByWeekday.max(by: { $0.value < $1.value })?.key ?? 2
        self.worstWeekday = ghostRateByWeekday.min(by: { $0.value < $1.value })?.key ?? 1
    }
}

// MARK: - Burnout Risk

public struct BurnoutRisk: Sendable {
    public let score: Int                // 0–100
    public let label: String
    public let recentGhostRate: Double
    public let missedDayCluster: Int
    public let advisory: String

    public enum Level: String, Sendable {
        case low      = "Thriving"
        case moderate = "Stable Arc"
        case elevated = "Fatigue Signal"
        case high     = "Recovery Needed"
    }

    public var riskLevel: Level {
        switch score {
        case 0..<30:  return .low
        case 30..<60: return .moderate
        case 60..<80: return .elevated
        default:      return .high
        }
    }

    public init(score: Int, recentGhostRate: Double, missedDayCluster: Int) {
        self.score = max(0, min(100, score))
        self.recentGhostRate = recentGhostRate
        self.missedDayCluster = missedDayCluster
        self.label = BurnoutRisk.makeLabel(score: score)
        self.advisory = BurnoutRisk.makeAdvisory(score: score, cluster: missedDayCluster, rate: recentGhostRate)
    }

    private static func makeLabel(score: Int) -> String {
        switch score {
        case 0..<30:  return "Sovereign Momentum"
        case 30..<60: return "Stable Arc"
        case 60..<80: return "Fatigue Signal"
        default:      return "Recovery Needed"
        }
    }

    private static func makeAdvisory(score: Int, cluster: Int, rate: Double) -> String {
        if score >= 80 {
            return "\(cluster) missed days in a row. Prioritize sleep, reduce intensity, and close at least the Silence Ring today."
        } else if score >= 60 {
            return "Fatigue building. Scale one task target down 20% and add a recovery walk."
        } else if score >= 30 {
            return "Consistent but thinning. Block non-negotiable rest before the weekend."
        }
        return "Momentum is solid. Focus on the one ring lagging behind your average."
    }
}

// MARK: - Season Comparison

public struct SeasonComparison: Sendable {
    public let seasonA: Side
    public let seasonB: Side

    public struct Side: Sendable {
        public let id: String
        public let name: String
        public let protocolKind: String
        public let totalDays: Int
        public let ghostDays: Int
        public let completionRate: Double
        public let bestStreak: Int
        public let bodyRate: Double
        public let mindRate: Double
        public let silenceRate: Double
        public let averageScore: Double
        public let rank: String
    }

    public var completionDelta: Double { seasonB.completionRate - seasonA.completionRate }
    public var bestStreakDelta: Int    { seasonB.bestStreak - seasonA.bestStreak }
    public var ghostDaysDelta: Int    { seasonB.ghostDays - seasonA.ghostDays }
    public var scoreDelta: Double     { seasonB.averageScore - seasonA.averageScore }

    public init(seasonA: Side, seasonB: Side) {
        self.seasonA = seasonA
        self.seasonB = seasonB
    }
}

// MARK: - Full Analytics Report

public struct GhostAnalyticsReport: Sendable {
    public let trendWindows: [GhostRing: [RingTrendWindow]]
    public let ruleCorrelations: [RuleCorrelation]
    public let timePattern: TimeOfDayPattern
    public let weekdayPattern: WeekdayPattern
    public let burnoutRisk: BurnoutRisk
    public let overallCompletionRate: Double
    public let averageScore: Double
    public let currentStreak: Int
    public let bestStreak: Int

    public init(
        trendWindows: [GhostRing: [RingTrendWindow]] = [:],
        ruleCorrelations: [RuleCorrelation] = [],
        timePattern: TimeOfDayPattern = TimeOfDayPattern(hourlyCounts: [:]),
        weekdayPattern: WeekdayPattern = WeekdayPattern(ghostRateByWeekday: [:]),
        burnoutRisk: BurnoutRisk = BurnoutRisk(score: 0, recentGhostRate: 1.0, missedDayCluster: 0),
        overallCompletionRate: Double = 0,
        averageScore: Double = 0,
        currentStreak: Int = 0,
        bestStreak: Int = 0
    ) {
        self.trendWindows = trendWindows
        self.ruleCorrelations = ruleCorrelations
        self.timePattern = timePattern
        self.weekdayPattern = weekdayPattern
        self.burnoutRisk = burnoutRisk
        self.overallCompletionRate = overallCompletionRate
        self.averageScore = averageScore
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
    }
}
