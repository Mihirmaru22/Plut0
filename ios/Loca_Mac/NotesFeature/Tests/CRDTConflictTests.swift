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
}
#endif
