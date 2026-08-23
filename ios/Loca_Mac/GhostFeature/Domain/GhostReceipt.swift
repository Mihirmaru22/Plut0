import Foundation

// MARK: - GhostProofKind

public enum GhostProofKind: String, Codable, CaseIterable, Sendable {
    case binary   = "binary"
    case quantity = "quantity"
    case duration = "duration"
    case artifact = "artifact"
}

// MARK: - GhostProtocolPhase

public enum GhostProtocolPhase: String, Codable, CaseIterable, Identifiable, Sendable {
    case morning = "morning"
    case day     = "day"
    case night   = "night"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .morning: return "Morning Forge"
        case .day:     return "Day Grind"
        case .night:   return "Night Seal"
        }
    }

    public var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .day:     return "sun.max.fill"
        case .night:   return "moon.stars.fill"
        }
    }
}

// MARK: - GhostProtocolRule

public struct GhostProtocolRule: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let ring: GhostRing
    public let phase: GhostProtocolPhase
    public let proofKind: GhostProofKind
    public let targetValue: Double
    public let unitLabel: String
    public let icon: String
    public let isOutdoorRequired: Bool
    /// Whether this rule was created by the user (false = preset template)
    public var isCustom: Bool
    /// User can disable a rule without deleting it
    public var isEnabled: Bool
    /// Display order within the protocol checklist
    public var sortOrder: Int

    public init(
        id: String,
        title: String,
        subtitle: String,
        ring: GhostRing,
        phase: GhostProtocolPhase,
        proofKind: GhostProofKind,
        targetValue: Double = 1.0,
        unitLabel: String = "",
        icon: String,
        isOutdoorRequired: Bool = false,
        isCustom: Bool = false,
        isEnabled: Bool = true,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.ring = ring
        self.phase = phase
        self.proofKind = proofKind
        self.targetValue = targetValue
        self.unitLabel = unitLabel
        self.icon = icon
        self.isOutdoorRequired = isOutdoorRequired
        self.isCustom = isCustom
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
    }

    // MARK: - Standard Protocol Defaults

    public static let seventyFiveHardRules: [GhostProtocolRule] = [
        GhostProtocolRule(
            id: "75h_diet",
            title: "Strict Diet & Nutrition",
            subtitle: "Zero cheat meals, zero alcohol. Total discipline.",
            ring: .body,
            phase: .morning,
            proofKind: .binary,
            targetValue: 1.0,
            unitLabel: "adherence",
            icon: "fork.knife"
        ),
        GhostProtocolRule(
            id: "75h_workout_outdoor",
            title: "Outdoor Workout 45'",
            subtitle: "45 minutes minimum strictly in open elements.",
            ring: .body,
            phase: .morning,
            proofKind: .duration,
            targetValue: 45.0,
            unitLabel: "mins",
            icon: "figure.run",
            isOutdoorRequired: true
        ),
        GhostProtocolRule(
            id: "75h_workout_indoor",
            title: "Second Workout 45'",
            subtitle: "45-minute strength, cardio, or mobility session.",
            ring: .body,
            phase: .day,
            proofKind: .duration,
            targetValue: 45.0,
            unitLabel: "mins",
            icon: "dumbbell.fill"
        ),
        GhostProtocolRule(
            id: "75h_water",
            title: "1 Gallon Water",
            subtitle: "Hydration target: 8 full glasses (128 oz).",
            ring: .body,
            phase: .day,
            proofKind: .quantity,
            targetValue: 8.0,
            unitLabel: "glasses",
            icon: "drop.fill"
        ),
        GhostProtocolRule(
            id: "75h_reading",
            title: "Read 10 Pages Non-Fiction",
            subtitle: "Physical book or dedicated reader. No audiobooks.",
            ring: .mind,
            phase: .night,
            proofKind: .quantity,
            targetValue: 10.0,
            unitLabel: "pages",
            icon: "book.fill"
        ),
        GhostProtocolRule(
            id: "75h_photo",
            title: "Daily Progress Photo",
            subtitle: "Visual proof artifact sealed to local vault.",
            ring: .body,
            phase: .night,
            proofKind: .artifact,
            targetValue: 1.0,
            unitLabel: "photo",
            icon: "camera.fill"
        )
    ]

    public static let the120Rules: [GhostProtocolRule] = [
        GhostProtocolRule(
            id: "120_body_forge",
            title: "Physical Forge (45'+)",
            subtitle: "Daily intense training, cold exposure, or 10k baseline.",
            ring: .body,
            phase: .morning,
            proofKind: .duration,
            targetValue: 45.0,
            unitLabel: "mins",
            icon: "figure.run"
        ),
        GhostProtocolRule(
            id: "120_silence_focus",
            title: "Deep Focus Silence (45'+)",
            subtitle: "Uninterrupted deep work sprint in Focus Room.",
            ring: .silence,
            phase: .day,
            proofKind: .duration,
            targetValue: 45.0,
            unitLabel: "mins",
            icon: "speaker.slash.fill"
        ),
        GhostProtocolRule(
            id: "120_mind_synthesis",
            title: "Read 10 Pages & Synthesize",
            subtitle: "High-density reading and mental models.",
            ring: .mind,
            phase: .day,
            proofKind: .quantity,
            targetValue: 10.0,
            unitLabel: "pages",
            icon: "book.fill"
        ),
        GhostProtocolRule(
            id: "120_social_fast",
            title: "Social Media Feed Fast",
            subtitle: "Zero algorithmic infinite-scroll consumption.",
            ring: .silence,
            phase: .night,
            proofKind: .binary,
            targetValue: 1.0,
            unitLabel: "adherence",
            icon: "moon.stars.fill"
        ),
        GhostProtocolRule(
            id: "120_evening_reflection",
            title: "Evening Synthesis Note",
            subtitle: "High-leverage realization sealed to Mind ring.",
            ring: .mind,
            phase: .night,
            proofKind: .artifact,
            targetValue: 1.0,
            unitLabel: "entry",
            icon: "pencil.line"
        )
    ]

    public static func defaultRules(for kind: GhostProtocolKind) -> [GhostProtocolRule] {
        switch kind {
        case .seventyFiveHard: return seventyFiveHardRules
        case .the120, .custom: return the120Rules
        }
    }
}

// MARK: - GhostReceipt Entity

public struct GhostReceipt: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let dayID: String
    public let ruleID: String
    public var kind: GhostProofKind
    public var valueReal: Double
    public var photoPath: String?
    public var loggedAt: Date

    public init(
        id: String = UUID().uuidString,
        dayID: String,
        ruleID: String,
        kind: GhostProofKind,
        valueReal: Double = 0.0,
        photoPath: String? = nil,
        loggedAt: Date = Date()
    ) {
        self.id = id
        self.dayID = dayID
        self.ruleID = ruleID
        self.kind = kind
        self.valueReal = valueReal
        self.photoPath = photoPath
        self.loggedAt = loggedAt
    }
}
