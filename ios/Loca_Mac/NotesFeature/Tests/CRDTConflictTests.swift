#if canImport(Testing)
import Foundation
import Testing

@Suite("Notes Feature - CRDT Conflict Resolution Tests")
struct CRDTConflictTests {
    
    // MARK: - Scenario 1: The Airplane Mode Clash
    @Test func testAirplaneModeChecklistClash() {
        let noteID = NoteID()
        
        // Initial state on both devices before offline
        var docA = CRDTDoc(id: noteID, deviceID: "device-A")
        docA.title = "Groceries"
        
        let block1 = CRDTBlock(id: UUID(), type: "checklistItem", text: CRDTText(string: "Milk", deviceID: "device-A"), sortKey: "00000000000001")
        docA.addBlock(block1)
        
        var docB = docA
        docB.deviceID = "device-B"
        
        // Device A goes offline and adds "Eggs"
        let blockEggs = CRDTBlock(id: UUID(), type: "checklistItem", text: CRDTText(string: "Eggs", deviceID: "device-A"), sortKey: "00000000000002")
        docA.addBlock(blockEggs)
        
        // Device B goes offline and adds "Bread"
        let blockBread = CRDTBlock(id: UUID(), type: "checklistItem", text: CRDTText(string: "Bread", deviceID: "device-B"), sortKey: "00000000000003")
        docB.addBlock(blockBread)
        
        // Merge A into B and B into A
        docA.merge(with: docB)
        docB.merge(with: docA)
        
        // Assert convergence: Both documents have all 3 items
        let contentA = CRDTTranslator.materializeContent(from: docA)
        let contentB = CRDTTranslator.materializeContent(from: docB)
        
        #expect(contentA.blocks.count == 3)
        #expect(contentB.blocks.count == 3)
        
        let textsA = Set(contentA.blocks.map { $0.text })
        #expect(textsA.contains("Milk"))
        #expect(textsA.contains("Eggs"))
        #expect(textsA.contains("Bread"))
    }
    
    // MARK: - Scenario 2: The Mid-Text Split
    @Test func testMidTextConcurrentEditing() {
        let noteID = NoteID()
        let blockID = UUID()
        
        var docA = CRDTDoc(id: noteID, deviceID: "device-A")
        let initialBlock = CRDTBlock(id: blockID, type: "paragraph", text: CRDTText(string: "Hello ", deviceID: "device-A"))
        docA.addBlock(initialBlock)
        
        var docB = docA
        docB.deviceID = "device-B"
        
        // Device A appends "Mac" at index 6
        docA.insertText("Mac", at: 6, in: blockID)
        
        // Device B appends "Web" at index 6
        docB.insertText("Web", at: 6, in: blockID)
        
        // Merge both
        docA.merge(with: docB)
        docB.merge(with: docA)
        
        let textA = docA.blocks.first?.text.string ?? ""
        let textB = docB.blocks.first?.text.string ?? ""
        
        // Assert deterministic convergence and no data loss
        #expect(textA == textB)
        #expect(textA.contains("Hello"))
        #expect(textA.contains("Mac"))
        #expect(textA.contains("Web"))
    }
    
    // MARK: - Scenario 3: The Delete vs Edit Race (Tombstone Wins)
    @Test func testDeleteVsEditRaceCondition() {
        let noteID = NoteID()
        let blockID = UUID()
        
        var docA = CRDTDoc(id: noteID, deviceID: "device-A")
        let initialBlock = CRDTBlock(id: blockID, type: "paragraph", text: CRDTText(string: "Delete Me", deviceID: "device-A"))
        docA.addBlock(initialBlock)
        
        var docB = docA
        docB.deviceID = "device-B"
        
        // Device A deletes the block
        docA.removeBlock(blockID: blockID)
        
        // Device B edits text inside the block
        docB.insertText(" Later", at: 9, in: blockID)
        
        // Merge
        docA.merge(with: docB)
        docB.merge(with: docA)
        
        // Assert that tombstone deletion takes precedence
        let contentA = CRDTTranslator.materializeContent(from: docA)
        let contentB = CRDTTranslator.materializeContent(from: docB)
        
        #expect(docA.blocks.first?.isDeleted == true)
        #expect(docB.blocks.first?.isDeleted == true)
        
        // Materialized content ignores deleted tombstones
        #expect(!contentA.blocks.contains(where: { $0.id == blockID }))
        #expect(!contentB.blocks.contains(where: { $0.id == blockID }))
    }
    
    // MARK: - Scenario 4: Character-Level Diff Atom Preservation (B-19)
    @Test func testCharacterLevelDiffPreservesOrigins() throws {
        let deviceA = "device-a"
        let deviceB = "device-b"
        let noteID = NoteID()
        let blockID = UUID()
        
        // Initial setup: Document has "Hello" created by device A
        var docA = CRDTDoc(id: noteID, deviceID: deviceA)
        let initialBlock = CRDTBlock(id: blockID, type: "paragraph", text: CRDTText(string: "Hello", deviceID: deviceA))
        docA.addBlock(initialBlock)
        
        var docB = docA
        docB.deviceID = deviceB
        
        // Peer A edits "Hello" -> "Hello World" via NoteMutation.updateContent
        let noteContentA = NoteContent(blocks: [
            .paragraph(BlockData(id: blockID, text: "Hello World"))
        ])
        CRDTTranslator.apply(mutation: .updateContent(noteID: noteID, content: noteContentA), to: &docA, deviceID: deviceA)
        
        // Peer B edits "Hello" -> "Hello!" via NoteMutation.updateContent
        let noteContentB = NoteContent(blocks: [
            .paragraph(BlockData(id: blockID, text: "Hello!"))
        ])
        CRDTTranslator.apply(mutation: .updateContent(noteID: noteID, content: noteContentB), to: &docB, deviceID: deviceB)
        
        // Merge both directions
        docA.merge(with: docB)
        docB.merge(with: docA)
        
        let resultA = docA.blocks.first?.text.string ?? ""
        let resultB = docB.blocks.first?.text.string ?? ""
        
        // Assert convergence without duplication of "Hello"
        #expect(resultA == resultB)
        #expect(resultA.contains("Hello"))
        #expect(resultA.contains("World"))
        #expect(resultA.contains("!"))
        
        // Ensure "Hello" is not duplicated
        let helloCount = resultA.components(separatedBy: "Hello").count - 1
        #expect(helloCount == 1)
        
        // Verify atom origins: original 5 atoms ("Hello") still have deviceA's origin
        let activeAtomsA = docA.blocks.first?.text.atoms.filter { !$0.isDeleted } ?? []
        let helloAtoms = activeAtomsA.prefix(5)
        #expect(helloAtoms.count == 5)
        #expect(helloAtoms.allSatisfy { $0.id.deviceID == deviceA })
    }
    
    @Test func testDiffAlgorithmCorrectness() {
        let diff1 = Diff.compute(from: "Hello", to: "Hello World")
        #expect(diff1.deletes.isEmpty)
        #expect(diff1.inserts.count == 6)
        
        let diff2 = Diff.compute(from: "Hello World", to: "Hello")
        #expect(diff2.deletes.count == 6)
        #expect(diff2.inserts.isEmpty)
        
        let diff3 = Diff.compute(from: "cat", to: "car")
        #expect(diff3.deletes.count == 1)
        #expect(diff3.inserts.count == 1)
        #expect(diff3.inserts.first?.character == "r")
    }

    // MARK: - Scenario 5: RGA Child-Subtree Skip (B-01)
    @Test func testRGAChildSubtreeSkip() throws {
        let deviceA = "device-a"
        let deviceB = "device-b"
        let noteID = NoteID()
        let blockID = UUID()
        
        // Peer A starts with empty block
        var docA = CRDTDoc(id: noteID, deviceID: deviceA)
        let initialBlock = CRDTBlock(id: blockID, type: "paragraph", text: CRDTText())
        docA.addBlock(initialBlock)
        
        // Peer A types "B" at index 0, then "C" after "B" (C's origin is B)
        docA.insertText("B", at: 0, in: blockID)
        docA.insertText("C", at: 1, in: blockID)
        
        // Peer B starts from initial state and types "A" at index 0
        var docB = CRDTDoc(id: noteID, deviceID: deviceB)
        docB.addBlock(initialBlock)
        docB.insertText("A", at: 0, in: blockID)
        
        // Merge both ways
        docA.merge(with: docB)
        docB.merge(with: docA)
        
        let resultA = docA.blocks.first?.text.string ?? ""
        let resultB = docB.blocks.first?.text.string ?? ""
        
        #expect(resultA == resultB)
        #expect(resultA.contains("A"))
        #expect(resultA.contains("B"))
        #expect(resultA.contains("C"))
        
        // Verify deterministic atom ordering: "B" and "C" remain grouped together without splitting
        let atomsA = docA.blocks.first?.text.atoms.filter { !$0.isDeleted }.map { $0.value } ?? []
        let bIdx = atomsA.firstIndex(of: "B")
        let cIdx = atomsA.firstIndex(of: "C")
        #expect(bIdx != nil && cIdx != nil)
        if let b = bIdx, let c = cIdx {
            #expect(c == b + 1, "C must remain immediately following its origin B")
        }
    }
}
#endif
