import Foundation

// MARK: - GhostProtocolKind

public enum GhostProtocolKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case the120            = "the120"
    case seventyFiveHard   = "seventyFiveHard"
    case custom            = "custom"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .the120:          return "The 120 (Winter Arc)"
        case .seventyFiveHard: return "75 Hard"
        case .custom:          return "Custom Sovereign Arc"
        }
    }

    public var durationDays: Int {
        switch self {
        case .the120:          return 120
        case .seventyFiveHard: return 75
        case .custom:          return 90
        }
    }

    public var subtitle: String {
        switch self {
        case .the120:          return "120 days of complete silence, physical forging, and mental mastery through winter."
        case .seventyFiveHard: return "75 consecutive days of uncompromising daily discipline."
        case .custom:          return "Tailored high-intensity season designed for sovereign transformation."
        }
    }
}

// MARK: - GhostDoctrine

public enum GhostDoctrine: String, Codable, CaseIterable, Identifiable, Sendable {
    case hard = "hard"
    case arc  = "arc"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .hard: return "Hard Doctrine (Zero Compromise)"
        case .arc:  return "Arc Doctrine (Resilient Momentum)"
        }
    }

    public var ruleDescription: String {
        switch self {
        case .hard: return "A missed day quietly resets streak to 0. Season continues with no shame and zero persistent noise."
        case .arc:  return "A missed day creates an elevation dent without resetting your entire cumulative streak."
        }
    }
}

// MARK: - GhostRing

public enum GhostRing: String, Codable, CaseIterable, Identifiable, Sendable {
    case body    = "body"
    case mind    = "mind"
    case silence = "silence"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .body:    return "Body"
        case .mind:    return "Mind"
        case .silence: return "Silence"
        }
    }

    public var icon: String {
        switch self {
        case .body:    return "figure.run"
        case .mind:    return "brain.head.profile"
        case .silence: return "speaker.slash.fill"
        }
    }

    public var accentHex: String {
        switch self {
        case .body:    return "#E54D2E" // Crimson Forge
        case .mind:    return "#3E63DD" // Deep Indigo
        case .silence: return "#0091FF" // Ghost Cyan
        }
    }
}

// MARK: - GhostRank

public enum GhostRank: String, Codable, CaseIterable, Sendable {
    case uninitiated = "Uninitiated"
    case apparition  = "Apparition"
    case shadow      = "Shadow"
    case phantom     = "Phantom"
    case wraith      = "Wraith"
    case specter     = "Specter"
    case sovereign   = "Ghost Sovereign"

    public var glyph: String {
        switch self {
        case .uninitiated: return "circle.dotted"
        case .apparition:  return "sparkle"
        case .shadow:      return "person.fill"
        case .phantom:     return "cloud.fog.fill"
        case .wraith:      return "shield.lefthalf.filled"
        case .specter:     return "eye.fill"
        case .sovereign:   return "crown.fill"
        }
    }

    public var opacity: Double {
        switch self {
        case .uninitiated: return 0.15
        case .apparition:  return 0.30
        case .shadow:      return 0.45
        case .phantom:     return 0.60
        case .wraith:      return 0.75
        case .specter:     return 0.90
        case .sovereign:   return 1.00
        }
    }

    public static func rank(forStreak streak: Int) -> GhostRank {
        switch streak {
        case 0:         return .uninitiated
        case 1...6:     return .apparition
        case 7...20:    return .shadow
        case 21...44:   return .phantom
        case 45...74:   return .wraith
        case 75...119:  return .specter
        default:        return .sovereign
        }
    }
}

// MARK: - GhostSeason Entity

public struct GhostSeason: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var protocolKind: GhostProtocolKind
    public var startDate: Date
    public var endDate: Date
    public var doctrine: GhostDoctrine
    public var signedAt: Date
    public var deviceID: String

    public init(
        id: String = UUID().uuidString,
        name: String,
        protocolKind: GhostProtocolKind = .the120,
        startDate: Date = Date(),
        endDate: Date = Calendar.current.date(byAdding: .day, value: 120, to: Date()) ?? Date(),
        doctrine: GhostDoctrine = .hard,
        signedAt: Date = Date(),
        deviceID: String = Host.current().localizedName ?? "Mac"
    ) {
        self.id = id
        self.name = name
        self.protocolKind = protocolKind
        self.startDate = startDate
        self.endDate = endDate
        self.doctrine = doctrine
        self.signedAt = signedAt
        self.deviceID = deviceID
    }

    public var isWinterArcSeason: Bool {
        protocolKind == .the120
    }

    public var totalDays: Int {
        max(1, Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? protocolKind.durationDays)
    }

    public var elapsedDays: Int {
        let today = Date()
        guard today >= startDate else { return 0 }
        let comps = Calendar.current.dateComponents([.day], from: startDate, to: today).day ?? 0
        return min(totalDays, max(0, comps + 1))
    }
}
