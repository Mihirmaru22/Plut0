import Foundation

/// Pure functional extractor converting structured NoteContent blocks into searchable plain text.
public enum NoteTextExtractor {
    
    public static func plainText(from content: NoteContent) -> String {
        content.blocks.compactMap { block in
            switch block {
            case .paragraph(let value):
                return value.text
            case .heading(let value):
                return value.text
            case .checklistItem(let value):
                return value.text
            case .bullet(let value):
                return value.text
            case .divider:
                return nil
            }
        }
        .joined(separator: "\n")
    }
}
