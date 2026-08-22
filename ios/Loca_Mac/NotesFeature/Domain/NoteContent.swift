import Foundation

/// Structured, versioned block-based note content container.
public struct NoteContent: Hashable, Codable, Sendable {
    public var version: Int
    public var blocks: [NoteBlock]
    
    public init(version: Int = 1, blocks: [NoteBlock] = [.paragraph(ParagraphBlock())]) {
        self.version = version
        self.blocks = blocks
    }
    
    public static var empty: NoteContent {
        NoteContent(version: 1, blocks: [.paragraph(ParagraphBlock(id: UUID(), text: ""))])
    }
}
