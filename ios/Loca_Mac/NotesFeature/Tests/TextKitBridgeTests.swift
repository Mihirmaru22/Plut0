#if canImport(Testing)
import Foundation
import Testing

@Suite("Notes Feature - TextKit 2 CRDT Bridge Tests")
struct TextKitBridgeTests {
    
    @Test func testTypingGeneratesCRDTCheracterOperations() {
        let noteID = NoteID()
        let blockID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        let initialBlock = CRDTBlock(id: blockID, type: "paragraph", text: CRDTText(string: "Hello", deviceID: "test-device"))
        doc.addBlock(initialBlock)
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        
        // Type " World" at index 5
        bridge.insertText(" World", at: 5)
        
        let rendered = bridge.renderAttributedString().string
        #expect(rendered == "Hello World")
        
        // Assert CRDT block text is updated
        let activeBlocks = bridge.doc.blocks.filter { !$0.isDeleted }
        #expect(activeBlocks.count == 1)
        #expect(activeBlocks.first?.text.string == "Hello World")
    }
    
    @Test func testBlockSplittingOnReturn() {
        let noteID = NoteID()
        let blockID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        let initialBlock = CRDTBlock(id: blockID, type: "paragraph", text: CRDTText(string: "FirstLineSecondLine", deviceID: "test-device"))
        doc.addBlock(initialBlock)
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        
        // Split at index 9 ("FirstLine" | "SecondLine")
        let split = bridge.splitBlock(at: 9)
        #expect(split?.newBlockID != nil)
        
        let activeBlocks = bridge.doc.blocks.filter { !$0.isDeleted }
        #expect(activeBlocks.count == 2)
        #expect(activeBlocks[0].text.string == "FirstLine")
        #expect(activeBlocks[1].text.string == "SecondLine")
        #expect(activeBlocks[0].sortKey < activeBlocks[1].sortKey)
    }
    
    @Test func testBlockMergeOnBackspace() {
        let noteID = NoteID()
        let b1ID = UUID()
        let b2ID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        let b1 = CRDTBlock(id: b1ID, type: "paragraph", text: CRDTText(string: "Alpha", deviceID: "test-device"))
        let b2 = CRDTBlock(id: b2ID, type: "paragraph", text: CRDTText(string: "Beta", deviceID: "test-device"))
        doc.addBlock(b1)
        doc.addBlock(b2)
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        
        // Global length of "Alpha\n" is 6. Deleting at index 6 (start of "Beta") merges with "Alpha"
        bridge.deleteText(at: 6, length: 1)
        
        let activeBlocks = bridge.doc.blocks.filter { !$0.isDeleted }
        #expect(activeBlocks.count == 1)
        #expect(activeBlocks.first?.text.string == "AlphaBeta")
    }
    
    @Test func testBlockTypeConversion() {
        let noteID = NoteID()
        let blockID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        let b = CRDTBlock(id: blockID, type: "paragraph", text: CRDTText(string: "Architecture", deviceID: "test-device"))
        doc.addBlock(b)
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        
        // Convert to Heading 1
        bridge.setBlockType("heading", at: 5, attributes: ["level": "1"])
        #expect(bridge.doc.blocks.first?.type == "heading")
        #expect(bridge.doc.blocks.first?.attributes["level"] == "1")
        
        // Convert to Checklist
        bridge.setBlockType("checklistItem", at: 5, attributes: ["isChecked": "false"])
        #expect(bridge.doc.blocks.first?.type == "checklistItem")
        
        // Toggle checklist
        bridge.toggleChecklist(at: 5)
        #expect(bridge.doc.blocks.first?.attributes["isChecked"] == "true")
    }
    
    // MARK: - Fix 1 Tests: Gutter Click Interactive Toggling
    
    @Test func testGutterClickTogglesChecklist() {
        let noteID = NoteID()
        let blockID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        let item = CRDTBlock(id: blockID, type: "checklistItem", text: CRDTText(string: "Review Architecture", deviceID: "test-device"), attributes: ["isChecked": "false"])
        doc.addBlock(item)
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        
        // Target block resolved at location 0
        let target = bridge.resolveLocation(0)
        #expect(target?.block.type == "checklistItem")
        
        // Gutter click toggles checklist state
        bridge.toggleChecklist(blockID: blockID)
        #expect(bridge.block(for: blockID)?.attributes["isChecked"] == "true")
        
        // Click again toggles off
        bridge.toggleChecklist(blockID: blockID)
        #expect(bridge.block(for: blockID)?.attributes["isChecked"] == "false")
    }
    
    @Test func testGutterClickIgnoresParagraphs() {
        let noteID = NoteID()
        let blockID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        let paragraph = CRDTBlock(id: blockID, type: "paragraph", text: CRDTText(string: "Regular text", deviceID: "test-device"))
        doc.addBlock(paragraph)
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        let target = bridge.resolveLocation(0)
        
        // Assert block is not checklistItem
        #expect(target?.block.type == "paragraph")
        #expect(target?.block.attributes["isChecked"] == nil)
    }
    
    // MARK: - Fix 2 Tests: Inline Formatting Spans
    
    @Test func testInlineBoldMarkGeneration() {
        let noteID = NoteID()
        let blockID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        let paragraph = CRDTBlock(id: blockID, type: "paragraph", text: CRDTText(string: "I ate an apple today", deviceID: "test-device"))
        doc.addBlock(paragraph)
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        
        // Select "apple" (range location: 9, length: 5)
        bridge.applyInlineMark(type: "bold", in: NSRange(location: 9, length: 5))
        
        let targetBlock = bridge.block(for: blockID)
        #expect(targetBlock?.marks.count == 1)
        #expect(targetBlock?.marks.first?.type == "bold")
        #expect(targetBlock?.marks.first?.startIndex == 9)
        #expect(targetBlock?.marks.first?.endIndex == 14)
    }
    
    @Test func testInlineMarkRendering() {
        let noteID = NoteID()
        let blockID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        var paragraph = CRDTBlock(id: blockID, type: "paragraph", text: CRDTText(string: "ItalicText NormalText", deviceID: "test-device"))
        paragraph.applyMark(type: "italic", startIndex: 0, endIndex: 10)
        doc.addBlock(paragraph)
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        let attributed = bridge.renderAttributedString()
        
        #expect(attributed.string == "ItalicText NormalText")
        #expect(bridge.block(for: blockID)?.marks.first?.type == "italic")
    }
    
    @Test func testTypingInsideMarkInheritsFormat() {
        let noteID = NoteID()
        let blockID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        var paragraph = CRDTBlock(id: blockID, type: "paragraph", text: CRDTText(string: "Swift Concurrency", deviceID: "test-device"))
        // Mark "Swift" as bold (0...5)
        paragraph.applyMark(type: "bold", startIndex: 0, endIndex: 5)
        doc.addBlock(paragraph)
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        
        // Type "UI" at index 5 (inside bold mark)
        bridge.insertText("UI", at: 5)
        
        let targetBlock = bridge.block(for: blockID)
        #expect(targetBlock?.text.string == "SwiftUI Concurrency")
        // Bold mark expands from 0...5 to 0...7
        #expect(targetBlock?.marks.first?.startIndex == 0)
        #expect(targetBlock?.marks.first?.endIndex == 7)
    }
    
    // MARK: - Typing Pipeline Regression Tests (Option A Contract)
    
    @Test func testLocalTypingRendersAndReachesCRDT() {
        let noteID = NoteID()
        let blockID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        doc.addBlock(CRDTBlock(id: blockID, type: "paragraph", text: CRDTText(string: "", deviceID: "test-device")))
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        let state = EditorBridgeState(bridge: bridge)
        
        // Simulate typing "H", "e", "y"
        bridge.insertText("H", at: 0)
        bridge.insertText("e", at: 1)
        bridge.insertText("y", at: 2)
        
        // Assert CRDT model has "Hey"
        #expect(bridge.doc.blocks.first?.text.string == "Hey")
        
        // Assert rendered attributed string matches
        let rendered = bridge.renderAttributedString().string
        #expect(rendered == "Hey")
    }
    
    @Test func testLocalEditDoesNotTriggerRemoteRenderLoop() {
        let noteID = NoteID()
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        doc.addBlock(CRDTBlock(id: UUID(), type: "paragraph", text: CRDTText(string: "Initial", deviceID: "test-device")))
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        let state = EditorBridgeState(bridge: bridge)
        
        // Local edit does not flag needsRemoteRefresh
        bridge.insertText(" Text", at: 7)
        #expect(state.needsRemoteRefresh == false)
        
        // Remote update explicitly sets needsRemoteRefresh
        var remoteDoc = bridge.doc
        remoteDoc.insertText(" Remote", at: 12, in: remoteDoc.blocks.first!.id)
        state.updateDocFromRemote(remoteDoc)
        #expect(state.needsRemoteRefresh == true)
    }
    
    // MARK: - Stateful Formatting Toolbar Tests
    
    @Test func testToolbarReflectsCursorInsideBoldSpan() {
        let noteID = NoteID()
        let blockID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        var paragraph = CRDTBlock(id: blockID, type: "paragraph", text: CRDTText(string: "Hello Bold World", deviceID: "test-device"))
        paragraph.applyMark(type: "bold", startIndex: 6, endIndex: 10) // "Bold" is at 6..<10
        doc.addBlock(paragraph)
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        
        // Cursor at index 7 (inside "Bold")
        let insideState = bridge.currentFormattingState(at: NSRange(location: 7, length: 0))
        #expect(insideState.isBold == true)
        #expect(insideState.isItalic == false)
        #expect(insideState.blockType == .paragraph)
        
        // Cursor at index 2 (inside "Hello")
        let outsideState = bridge.currentFormattingState(at: NSRange(location: 2, length: 0))
        #expect(outsideState.isBold == false)
    }
    
    @Test func testBoldAndItalicOnSimultaneously() {
        let noteID = NoteID()
        let blockID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        var paragraph = CRDTBlock(id: blockID, type: "paragraph", text: CRDTText(string: "Formatted Text", deviceID: "test-device"))
        paragraph.applyMark(type: "bold", startIndex: 0, endIndex: 9)
        paragraph.applyMark(type: "italic", startIndex: 0, endIndex: 9)
        doc.addBlock(paragraph)
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        
        // Selection over "Formatted" (0...9)
        let state = bridge.currentFormattingState(at: NSRange(location: 0, length: 9))
        #expect(state.isBold == true)
        #expect(state.isItalic == true)
        #expect(state.blockType == .paragraph)
    }
    
    @Test func testBlockTypeExclusive() {
        let noteID = NoteID()
        let blockID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        let paragraph = CRDTBlock(id: blockID, type: "paragraph", text: CRDTText(string: "Exclusive Headings", deviceID: "test-device"))
        doc.addBlock(paragraph)
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        
        // Activate H1
        bridge.toggleBlockType(.h1, at: 5)
        let h1State = bridge.currentFormattingState(at: NSRange(location: 5, length: 0))
        #expect(h1State.blockType == .h1)
        
        // Activate H2 while H1 is active -> switches to H2
        bridge.toggleBlockType(.h2, at: 5)
        let h2State = bridge.currentFormattingState(at: NSRange(location: 5, length: 0))
        #expect(h2State.blockType == .h2)
    }
    
    @Test func testActiveBlockClickRevertsToParagraph() {
        let noteID = NoteID()
        let blockID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        let h1Block = CRDTBlock(id: blockID, type: "heading", text: CRDTText(string: "Title Text", deviceID: "test-device"), attributes: ["level": "1"])
        doc.addBlock(h1Block)
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        let initial = bridge.currentFormattingState(at: NSRange(location: 2, length: 0))
        #expect(initial.blockType == .h1)
        
        // Clicking H1 again reverts to paragraph
        bridge.toggleBlockType(.h1, at: 2)
        let reverted = bridge.currentFormattingState(at: NSRange(location: 2, length: 0))
        #expect(reverted.blockType == .paragraph)
    }
    
    @Test func testToggleBoldOffRemovesMark() {
        let noteID = NoteID()
        let blockID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        var paragraph = CRDTBlock(id: blockID, type: "paragraph", text: CRDTText(string: "Selected Word Here", deviceID: "test-device"))
        paragraph.applyMark(type: "bold", startIndex: 9, endIndex: 13) // "Word" is at 9..<13
        doc.addBlock(paragraph)
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        
        // Select "Word" (range: 9, length: 4) and toggle bold off
        bridge.toggleInlineMark(type: "bold", in: NSRange(location: 9, length: 4))
        
        let targetBlock = bridge.block(for: blockID)
        #expect(targetBlock?.marks.isEmpty == true)
        
        let state = bridge.currentFormattingState(at: NSRange(location: 9, length: 4))
        #expect(state.isBold == false)
    }
    
    @Test func testStickyBoldTypingWithEmptySelection() {
        let noteID = NoteID()
        let blockID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        doc.addBlock(CRDTBlock(id: blockID, type: "paragraph", text: CRDTText(string: "Prefix ", deviceID: "test-device")))
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        let state = EditorBridgeState(bridge: bridge)
        
        // Empty selection at index 7 (after "Prefix ")
        state.updateSelection(NSRange(location: 7, length: 0))
        #expect(state.formattingState.isBold == false)
        
        // Toggle bold with empty selection -> sets stickyBold in bridge
        state.toggleBold()
        #expect(bridge.getStickyMarks().contains("bold"))
        #expect(state.formattingState.isBold == true)
        
        // Typing automatically applies sticky marks
        let insertLoc = 7
        let typedText = "Bolded"
        bridge.insertText(typedText, at: insertLoc)
        
        let targetBlock = bridge.block(for: blockID)
        #expect(targetBlock?.text.string == "Prefix Bolded")
        #expect(targetBlock?.marks.count == 1)
        #expect(targetBlock?.marks.first?.type == "bold")
        #expect(targetBlock?.marks.first?.startIndex == 7)
        #expect(targetBlock?.marks.first?.endIndex == 13)
    }
    
    @Test func testConsecutiveTypingPreservesStickyMarksUntilCursorMoves() {
        let noteID = NoteID()
        let blockID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        doc.addBlock(CRDTBlock(id: blockID, type: "paragraph", text: CRDTText(string: "", deviceID: "test-device")))
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        let state = EditorBridgeState(bridge: bridge)
        
        // Empty selection at index 0, toggle bold
        state.updateSelection(NSRange(location: 0, length: 0))
        state.toggleBold()
        #expect(bridge.getStickyMarks().contains("bold"))
        
        // Type character 1 at 0
        bridge.insertText("A", at: 0)
        state.updateSelection(NSRange(location: 1, length: 0))
        #expect(bridge.getStickyMarks().contains("bold"))
        
        // Type character 2 at 1
        bridge.insertText("B", at: 1)
        state.updateSelection(NSRange(location: 2, length: 0))
        #expect(bridge.getStickyMarks().contains("bold"))
        
        // Type character 3 at 2
        bridge.insertText("C", at: 2)
        state.updateSelection(NSRange(location: 3, length: 0))
        #expect(bridge.getStickyMarks().contains("bold"))
        
        // Move cursor to 0 (non-consecutive)
        state.updateSelection(NSRange(location: 0, length: 0))
        #expect(bridge.getStickyMarks().isEmpty)
    }
    
    @Test func testEmptyChecklistItemEnterExitsToParagraph() {
        let noteID = NoteID()
        let blockID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        let item = CRDTBlock(id: blockID, type: "checklistItem", text: CRDTText(string: "", deviceID: "test-device"), attributes: ["isChecked": "false"])
        doc.addBlock(item)
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        
        // Enter on empty checklist item -> exits to paragraph
        let split = bridge.splitBlock(at: 0)
        #expect(split?.newBlockType == "paragraph")
        #expect(split?.newBlockID == nil)
        #expect(bridge.doc.blocks.first?.type == "paragraph")
    }
    
    @Test func testNonEmptyChecklistItemEnterCreatesNewChecklistItem() {
        let noteID = NoteID()
        let blockID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        let item = CRDTBlock(id: blockID, type: "checklistItem", text: CRDTText(string: "Task 1", deviceID: "test-device"), attributes: ["isChecked": "false"])
        doc.addBlock(item)
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        
        // Enter at end of "Task 1" -> creates new checklistItem
        let split = bridge.splitBlock(at: 6)
        #expect(split?.newBlockType == "checklistItem")
        #expect(split?.newBlockID != nil)
        
        let activeBlocks = bridge.doc.blocks.filter { !$0.isDeleted }
        #expect(activeBlocks.count == 2)
        #expect(activeBlocks[0].type == "checklistItem")
        #expect(activeBlocks[1].type == "checklistItem")
    }
    
    @Test func testHeadingEnterCreatesParagraph() {
        let noteID = NoteID()
        let blockID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        let heading = CRDTBlock(id: blockID, type: "heading", text: CRDTText(string: "Title", deviceID: "test-device"), attributes: ["level": "1"])
        doc.addBlock(heading)
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        
        // Enter at end of "Title" -> new block is paragraph
        let split = bridge.splitBlock(at: 5)
        #expect(split?.newBlockType == "paragraph")
        
        let activeBlocks = bridge.doc.blocks.filter { !$0.isDeleted }
        #expect(activeBlocks.count == 2)
        #expect(activeBlocks[0].type == "heading")
        #expect(activeBlocks[1].type == "paragraph")
    }
    
    @Test func testStickyMarksDoNotLeakAcrossEnter() {
        let noteID = NoteID()
        let blockID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        doc.addBlock(CRDTBlock(id: blockID, type: "paragraph", text: CRDTText(string: "Bold", deviceID: "test-device")))
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        let state = EditorBridgeState(bridge: bridge)
        
        // Toggle bold with empty selection at index 4
        state.updateSelection(NSRange(location: 4, length: 0))
        state.toggleBold()
        #expect(bridge.getStickyMarks().contains("bold"))
        
        // Enter split at 4
        let split = bridge.splitBlock(at: 4)
        #expect(split != nil)
        
        // Sticky marks must be cleared
        #expect(bridge.getStickyMarks().isEmpty)
    }
    
    @Test func testStickyArmingSurvivesFocusReturnSelectionEvent() {
        let noteID = NoteID()
        let blockID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        doc.addBlock(CRDTBlock(id: blockID, type: "paragraph", text: CRDTText(string: "Hello", deviceID: "test-device")))
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        let state = EditorBridgeState(bridge: bridge)
        
        // Cursor at index 5
        state.updateSelection(NSRange(location: 5, length: 0))
        
        // Click Italic button -> arms sticky italic
        state.toggleItalic()
        #expect(bridge.getStickyMarks().contains("italic"))
        
        // Immediate focus-return selection event (within 0.25s)
        bridge.selectionDidChange(to: NSRange(location: 5, length: 0))
        #expect(bridge.getStickyMarks().contains("italic"))
        
        // Type " World"
        bridge.insertText(" World", at: 5)
        
        let targetBlock = bridge.block(for: blockID)
        #expect(targetBlock?.text.string == "Hello World")
        #expect(targetBlock?.marks.first?.type == "italic")
        #expect(targetBlock?.marks.first?.startIndex == 5)
        #expect(targetBlock?.marks.first?.endIndex == 11)
    }
    
    @Test func testEmptyBulletEnterExitsToParagraph() {
        let noteID = NoteID()
        let blockID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        let item = CRDTBlock(id: blockID, type: "bullet", text: CRDTText(string: "", deviceID: "test-device"))
        doc.addBlock(item)
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        
        // Enter on empty bullet item -> exits to paragraph
        let split = bridge.splitBlock(at: 0)
        #expect(split?.newBlockType == "paragraph")
        #expect(split?.newBlockID == nil)
        #expect(bridge.doc.blocks.first?.type == "paragraph")
    }
    
    @Test func testToolbarUsesLiveCursorLocation() {
        let noteID = NoteID()
        let b1ID = UUID()
        let b2ID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        let b1 = CRDTBlock(id: b1ID, type: "paragraph", text: CRDTText(string: "First paragraph.", deviceID: "test-device"))
        let b2 = CRDTBlock(id: b2ID, type: "paragraph", text: CRDTText(string: "Second block.", deviceID: "test-device"))
        doc.addBlock(b1)
        doc.addBlock(b2)
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        let state = EditorBridgeState(bridge: bridge)
        
        // User moves cursor into second block (loc 20)
        state.updateSelection(NSRange(location: 20, length: 0))
        #expect(bridge.lastKnownSelection.location == 20)
        
        // Click H2 button
        state.toggleBlockType(.h2)
        
        // Assert second block converted to H2, first block remains paragraph
        #expect(bridge.block(for: b1ID)?.type == "paragraph")
        #expect(bridge.block(for: b2ID)?.type == "heading")
        #expect(bridge.block(for: b2ID)?.attributes["level"] == "2")
        #expect(state.formattingState.blockType == .h2)
    }
    
    @Test func testMarginGlyphsDoNotShiftIndices() {
        let noteID = NoteID()
        let b1ID = UUID()
        let b2ID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        let b1 = CRDTBlock(id: b1ID, type: "checklistItem", text: CRDTText(string: "Task item", deviceID: "test-device"), attributes: ["isChecked": "false"])
        let b2 = CRDTBlock(id: b2ID, type: "bullet", text: CRDTText(string: "Bullet item", deviceID: "test-device"))
        doc.addBlock(b1)
        doc.addBlock(b2)
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        let rendered = bridge.renderAttributedString()
        
        // Assert storage.string has NO glyph prefixes or attachments (exact 1:1 character parity)
        #expect(rendered.string == "Task item\nBullet item")
        #expect(!rendered.string.contains("•"))
        #expect(!rendered.string.contains("[ ]"))
        #expect(!rendered.string.contains("[x]"))
        #expect(rendered.string.count == 21)
    }
    
    @Test func testSplitThenFastTypeKeepsIndent() {
        let noteID = NoteID()
        let b1ID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        let b1 = CRDTBlock(id: b1ID, type: "checklistItem", text: CRDTText(string: "First item", deviceID: "test-device"), attributes: ["isChecked": "false"])
        doc.addBlock(b1)
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        let split = bridge.splitBlock(at: 10)
        #expect(split != nil)
        #expect(split?.newBlockType == "checklistItem")
        
        // Fast type "Hello" into new block
        bridge.insertText("Hello", at: split!.newCursor)
        
        let rendered = bridge.renderAttributedString()
        let newBlockRange = bridge.blockRanges[split!.newBlockID!]
        #expect(newBlockRange != nil)
        
        // Read paragraph style of the new block
        let attrs = rendered.attributes(at: newBlockRange!.location, effectiveRange: nil)
        let style = attrs[.paragraphStyle] as? NSParagraphStyle
        #expect(style?.headIndent == 24)
        #expect(style?.firstLineHeadIndent == 24)
    }
    
    @Test func testSelectAllDeletePersistsOneEmptyParagraph() {
        let noteID = NoteID()
        let b1ID = UUID()
        let b2ID = UUID()
        let b3ID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        doc.addBlock(CRDTBlock(id: b1ID, type: "heading", text: CRDTText(string: "Title", deviceID: "test-device"), attributes: ["level": "1"]))
        doc.addBlock(CRDTBlock(id: b2ID, type: "paragraph", text: CRDTText(string: "Middle content", deviceID: "test-device")))
        doc.addBlock(CRDTBlock(id: b3ID, type: "checklistItem", text: CRDTText(string: "Last item", deviceID: "test-device")))
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        let totalLen = bridge.renderAttributedString().length
        
        // Select All (0..<totalLen) and Delete
        bridge.deleteRange(at: 0, length: totalLen)
        
        let activeBlocks = bridge.doc.blocks.filter { !$0.isDeleted }
        #expect(activeBlocks.count == 1)
        #expect(activeBlocks.first?.type == "paragraph")
        #expect(activeBlocks.first?.text.string == "")
        #expect(bridge.renderAttributedString().string == "")
    }
    
    @Test func testMultiLinePasteIntoChecklistCreatesItems() {
        let noteID = NoteID()
        let b1ID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        doc.addBlock(CRDTBlock(id: b1ID, type: "checklistItem", text: CRDTText(string: "Item 1", deviceID: "test-device"), attributes: ["isChecked": "false"]))
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        
        // Paste 2 lines at end of "Item 1" (loc 6)
        let pasteString = "\nItem 2\nItem 3"
        let newCursor = bridge.insertStructuredText(pasteString, at: 6)
        
        let activeBlocks = bridge.doc.blocks.filter { !$0.isDeleted }
        #expect(activeBlocks.count == 3)
        #expect(activeBlocks[0].type == "checklistItem")
        #expect(activeBlocks[0].text.string == "Item 1")
        #expect(activeBlocks[1].type == "checklistItem")
        #expect(activeBlocks[1].text.string == "Item 2")
        #expect(activeBlocks[2].type == "checklistItem")
        #expect(activeBlocks[2].text.string == "Item 3")
        
        let rendered = bridge.renderAttributedString().string
        #expect(rendered == "Item 1\nItem 2\nItem 3")
        #expect(newCursor == 20)
    }
    
    @Test func testUndoRedoTypingSplitAndToggle() {
        let noteID = NoteID()
        let b1ID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        doc.addBlock(CRDTBlock(id: b1ID, type: "paragraph", text: CRDTText(string: "", deviceID: "test-device")))
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        
        // 1. Type "hello"
        bridge.insertText("hello", at: 0)
        #expect(bridge.doc.blocks.first?.text.string == "hello")
        
        // 2. Split (Enter)
        let split = bridge.splitBlock(at: 5)
        #expect(split != nil)
        #expect(bridge.doc.blocks.filter { !$0.isDeleted }.count == 2)
        
        // 3. Type "world"
        bridge.insertText("world", at: split!.newCursor)
        #expect(bridge.renderAttributedString().string == "hello\nworld")
        
        // 4. Undo typing "world"
        let undo1 = bridge.undo(currentSelection: NSRange(location: 11, length: 0))
        #expect(undo1 != nil)
        #expect(bridge.renderAttributedString().string == "hello\n")
        
        // 5. Undo split
        let undo2 = bridge.undo(currentSelection: undo1!)
        #expect(undo2 != nil)
        #expect(bridge.renderAttributedString().string == "hello")
        #expect(bridge.doc.blocks.filter { !$0.isDeleted }.count == 1)
        
        // 6. Redo split
        let redo1 = bridge.redo(currentSelection: undo2!)
        #expect(redo1 != nil)
        #expect(bridge.doc.blocks.filter { !$0.isDeleted }.count == 2)
        
        // 7. Redo typing
        let redo2 = bridge.redo(currentSelection: redo1!)
        #expect(redo2 != nil)
        #expect(bridge.renderAttributedString().string == "hello\nworld")
    }
    
    @Test func testCutPasteRoundTrip() {
        let noteID = NoteID()
        let b1ID = UUID()
        
        var doc = CRDTDoc(id: noteID, deviceID: "test-device")
        doc.addBlock(CRDTBlock(id: b1ID, type: "paragraph", text: CRDTText(string: "CutThisKeepThis", deviceID: "test-device")))
        
        let bridge = TextKitCRDTBridge(doc: doc, deviceID: "test-device")
        
        // Cut "CutThis" (0..<7)
        let cutText = "CutThis"
        bridge.deleteRange(at: 0, length: 7)
        #expect(bridge.renderAttributedString().string == "KeepThis")
        
        // Paste "CutThis" at end (index 8)
        _ = bridge.insertStructuredText(cutText, at: 8)
        #expect(bridge.renderAttributedString().string == "KeepThisCutThis")
    }
}
#endif
