import Foundation

/// Pure functional generator producing derived titles and concise previews for list rows.
public enum NotePreviewGenerator {
    
    /// Derives the title from the first line / block-0 of content.
    public static func deriveTitle(from content: NoteContent) -> String {
        guard let firstBlock = content.blocks.first else { return "New Note" }
        let text = firstBlock.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return "New Note"
        }
        let firstLine = text.components(separatedBy: .newlines).first ?? text
        let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "New Note" : trimmed
    }
    
    /// Derives the preview from the second line of content.
    public static func derivePreview(from content: NoteContent, limit: Int = 180) -> String {
        let activeBlocks = content.blocks
        guard !activeBlocks.isEmpty else { return "" }
        
        // Check if first block has multiple lines:
        let firstBlockLines = activeBlocks[0].text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if firstBlockLines.count > 1 {
            return preview(from: firstBlockLines[1], limit: limit)
        }
        
        // Otherwise look for the next non-empty block:
        for block in activeBlocks.dropFirst() {
            let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                let firstLine = text.components(separatedBy: .newlines).first ?? text
                let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return preview(from: trimmed, limit: limit)
                }
            }
        }
        
        return ""
    }
    
    public static func preview(from plainText: String, limit: Int = 180) -> String {
        let cleaned = plainText
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard cleaned.count > limit else {
            return cleaned
        }
        
        let prefix = cleaned.prefix(limit)
        return String(prefix) + "…"
    }
}
