import Foundation

// MARK: - ParagraphBlock

public struct ParagraphBlock: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    public var text: String
    
    public init(id: UUID = UUID(), text: String = "") {
        self.id = id
        self.text = text
    }
}

// MARK: - HeadingBlock

public struct HeadingBlock: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    public var text: String
    public var level: Int
    
    public init(id: UUID = UUID(), text: String = "", level: Int = 1) {
        self.id = id
        self.text = text
        self.level = max(1, min(6, level))
    }
}

// MARK: - ChecklistItemBlock

public struct ChecklistItemBlock: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    public var text: String
    public var isChecked: Bool
    
    public init(id: UUID = UUID(), text: String = "", isChecked: Bool = false) {
        self.id = id
        self.text = text
        self.isChecked = isChecked
    }
}

// MARK: - BulletBlock

public struct BulletBlock: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    public var text: String
    
    public init(id: UUID = UUID(), text: String = "") {
        self.id = id
        self.text = text
    }
}

// MARK: - DividerBlock

public struct DividerBlock: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    
    public init(id: UUID = UUID()) {
        self.id = id
    }
}

// MARK: - NoteBlock

public enum NoteBlock: Hashable, Codable, Sendable, Identifiable {
    case paragraph(ParagraphBlock)
    case heading(HeadingBlock)
    case checklistItem(ChecklistItemBlock)
    case bullet(BulletBlock)
    case divider(DividerBlock)
    
    public var id: UUID {
        switch self {
        case .paragraph(let block):
            return block.id
        case .heading(let block):
            return block.id
        case .checklistItem(let block):
            return block.id
        case .bullet(let block):
            return block.id
        case .divider(let block):
            return block.id
        }
    }
    
    public var text: String {
        switch self {
        case .paragraph(let block):
            return block.text
        case .heading(let block):
            return block.text
        case .checklistItem(let block):
            return block.text
        case .bullet(let block):
            return block.text
        case .divider:
            return ""
        }
    }
}
