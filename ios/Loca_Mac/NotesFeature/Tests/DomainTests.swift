#if canImport(Testing)
import Foundation
import Testing

@Suite("Notes Feature - Domain Layer Tests")
struct DomainTests {
    
    @Test func testPlainTextExtraction() {
        let blocks: [NoteBlock] = [
            .heading(HeadingBlock(text: "Project Pluto", level: 1)),
            .paragraph(ParagraphBlock(text: "This is a local-first notes engine.")),
            .checklistItem(ChecklistItemBlock(text: "Verify SQLite storage", isChecked: true)),
            .checklistItem(ChecklistItemBlock(text: "Verify AsyncStream", isChecked: false)),
            .bullet(BulletBlock(text: "Bullet point alpha")),
            .divider(DividerBlock())
        ]
        let content = NoteContent(version: 1, blocks: blocks)
        let plainText = NoteTextExtractor.plainText(from: content)
        
        let expected = """
Project Pluto
This is a local-first notes engine.
Verify SQLite storage
Verify AsyncStream
Bullet point alpha
"""
        #expect(plainText == expected)
    }
    
    @Test func testPreviewGeneration() {
        let shortText = "Meeting notes from morning standup."
        let shortPreview = NotePreviewGenerator.preview(from: shortText, limit: 180)
        #expect(shortPreview == "Meeting notes from morning standup.")
        
        let longText = String(repeating: "Swift Concurrency and Local SQLite ", count: 20)
        let longPreview = NotePreviewGenerator.preview(from: longText, limit: 50)
        #expect(longPreview.count <= 52)
        #expect(longPreview.hasSuffix("…"))
        
        let multiLineText = "Line 1\nLine 2\n\tLine 3"
        let collapsed = NotePreviewGenerator.preview(from: multiLineText)
        #expect(collapsed == "Line 1 Line 2  Line 3")
    }
    
    @Test func testNoteContentJSONSerialization() throws {
        let blockID = UUID()
        let blocks: [NoteBlock] = [
            .heading(HeadingBlock(id: blockID, text: "Architecture", level: 2)),
            .checklistItem(ChecklistItemBlock(id: UUID(), text: "Engine protocol", isChecked: true))
        ]
        let content = NoteContent(version: 1, blocks: blocks)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(content)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(NoteContent.self, from: data)
        
        #expect(decoded.version == 1)
        #expect(decoded.blocks.count == 2)
        #expect(decoded.blocks.first?.id == blockID)
    }
    
    @Test func testNoteSummaryProjection() {
        let noteID = NoteID()
        let now = Date()
        let summary = NoteSummary(
            id: noteID,
            title: "Quick Thought",
            preview: "Remember to review...",
            folderID: nil,
            isPinned: true,
            isLocked: false,
            isDeleted: false,
            updatedAt: now
        )
        
        #expect(summary.id == noteID)
        #expect(summary.isPinned == true)
        #expect(summary.title == "Quick Thought")
    }
    
    @Test func testSearchTermSanitization() {
        let raw = "100%_complete\\test"
        let sanitized = LocalNotesStore.sanitizeForLike(raw)
        #expect(sanitized == "100\\%\\_complete\\\\test")
    }
    
    @Test func testDerivedTitleAndPreview() {
        let content1 = NoteContent(version: 1, blocks: [
            .paragraph(ParagraphBlock(text: "Grocery List")),
            .checklistItem(ChecklistItemBlock(text: "Almond milk")),
            .checklistItem(ChecklistItemBlock(text: "Avocados"))
        ])
        #expect(NotePreviewGenerator.deriveTitle(from: content1) == "Grocery List")
        #expect(NotePreviewGenerator.derivePreview(from: content1) == "Almond milk")
        
        let emptyContent = NoteContent.empty
        #expect(NotePreviewGenerator.deriveTitle(from: emptyContent) == "New Note")
        #expect(NotePreviewGenerator.derivePreview(from: emptyContent) == "")
    }
}
#endif
