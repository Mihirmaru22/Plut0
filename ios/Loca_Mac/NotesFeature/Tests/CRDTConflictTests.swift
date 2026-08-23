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

    // MARK: - Scenario 6: Operation-Based Undo/Redo (B-15)
    @Test func testUndoPreservesRemoteEdits() throws {
        let deviceA = "device-a"
        let deviceB = "device-b"
        let noteID = NoteID()
        
        let docA = CRDTDoc(id: noteID, deviceID: deviceA)
        let bridgeA = TextKitCRDTBridge(doc: docA, deviceID: deviceA)
        let blockID = bridgeA.createBlock(text: "")
        
        // Peer A types "Hello "
        bridgeA.insertText("Hello ", atBlockID: blockID, position: 0)
        
        // Peer B starts from state with block and types "World" at index 0
        let docB = CRDTDoc(id: noteID, deviceID: deviceB)
        let bridgeB = TextKitCRDTBridge(doc: docB, deviceID: deviceB)
        _ = bridgeB.createBlock(id: blockID, text: "")
        bridgeB.insertText("World", atBlockID: blockID, position: 0)
        
        // Merge B into A
        bridgeA.merge(from: bridgeB.doc)
        
        let mergedText = bridgeA.getBlock(id: blockID)?.text.string ?? ""
        #expect(mergedText.contains("Hello"))
        #expect(mergedText.contains("World"))
        
        // Peer A undoes local typing
        let undoResult = bridgeA.undo(currentSelection: NSRange(location: 0, length: 0))
        #expect(undoResult != nil)
        
        // Result: Peer B's "World" is preserved, Peer A's "Hello " is deleted via tombstones
        let textAfterUndo = bridgeA.getBlock(id: blockID)?.text.string ?? ""
        #expect(textAfterUndo.contains("World"), "Undo must preserve concurrent remote edits")
        #expect(!textAfterUndo.contains("Hello"), "Local edits must be undone")
        
        // Peer A redoes typing
        let redoResult = bridgeA.redo(currentSelection: NSRange(location: 0, length: 0))
        #expect(redoResult != nil)
        let textAfterRedo = bridgeA.getBlock(id: blockID)?.text.string ?? ""
        #expect(textAfterRedo.contains("Hello"))
        #expect(textAfterRedo.contains("World"))
    }

    // MARK: - Scenario 7: Remote Doc Merge Preserves Undo History (B-20)
    @Test func testRemoteMergePreservesLocalUndoHistory() throws {
        let deviceA = "device-a"
        let deviceB = "device-b"
        let noteID = NoteID()
        
        // Peer A types "Hello" (builds local undo history)
        let docA = CRDTDoc(id: noteID, deviceID: deviceA)
        let bridgeA = TextKitCRDTBridge(doc: docA, deviceID: deviceA)
        let blockID1 = bridgeA.createBlock(text: "")
        bridgeA.insertText("Hello", atBlockID: blockID1, position: 0)
        
        // Peer B creates a different block with "World"
        let docB = CRDTDoc(id: noteID, deviceID: deviceB)
        let bridgeB = TextKitCRDTBridge(doc: docB, deviceID: deviceB)
        let blockID2 = bridgeB.createBlock(text: "")
        bridgeB.insertText("World", atBlockID: blockID2, position: 0)
        
        // Remote delta from B arrives at A
        let oldDoc = bridgeA.doc
        bridgeA.merge(from: bridgeB.doc)
        bridgeA.adjustUndoStackAfterRemoteMerge(oldDoc: oldDoc, newDoc: bridgeB.doc)
        
        // Peer A undoes "Hello" insertion
        let undoResult = bridgeA.undo(currentSelection: NSRange(location: 0, length: 0))
        #expect(undoResult != nil)
        
        // Result: Block 1 has "Hello" undone (empty), Block 2 retains "World" completely intact
        let b1 = bridgeA.getBlock(id: blockID1)
        let b2 = bridgeA.getBlock(id: blockID2)
        
        #expect(b1 != nil && b1?.text.string == "", "Local undo must work after remote merge")
        #expect(b2 != nil && b2?.text.string == "World", "Remote edit must be preserved")
    }

    // MARK: - Scenario 8: Multi-Peer Convergence Suite (B-22)
    
    @Test func testThreePeerConvergence() throws {
        let harness = MultiPeerTestHarness(peerCount: 3)
        let blockID = harness.peers[0].bridge.createBlock(text: "")
        
        // Share initial block to peers 1 and 2
        for i in 1..<3 {
            _ = harness.peers[i].bridge.createBlock(id: blockID, text: "")
        }
        
        // Peer 0 types "A"
        harness.type(on: 0, text: "A", atBlockID: blockID, position: 0)
        
        // Peer 1 types "B"
        harness.type(on: 1, text: "B", atBlockID: blockID, position: 0)
        
        // Peer 2 types "C"
        harness.type(on: 2, text: "C", atBlockID: blockID, position: 0)
        
        // Merge all peers
        harness.mergeAll()
        
        // Verify convergence
        #expect(harness.converge(), "All 3 peers should converge to the exact same state")
        
        let results = harness.getDocumentStrings()
        #expect(results[0] == results[1], "Peer 0 and Peer 1 should match")
        #expect(results[1] == results[2], "Peer 1 and Peer 2 should match")
        
        let finalDoc = results[0]
        #expect(
            ["ABC", "ACB", "BAC", "BCA", "CAB", "CBA"].contains(finalDoc),
            "Final state should be a valid deterministic permutation"
        )
    }

    @Test func testOutOfOrderDeliveryThreePeers() throws {
        let harness = MultiPeerTestHarness(peerCount: 3)
        let blockID = harness.peers[0].bridge.createBlock(text: "")
        for i in 1..<3 {
            _ = harness.peers[i].bridge.createBlock(id: blockID, text: "")
        }
        
        // Peer 0 sends Op1, then Op2
        harness.type(on: 0, text: "Op1", atBlockID: blockID, position: 0)
        let docAfterOp1 = harness.peers[0].bridge.doc
        
        harness.type(on: 0, text: "Op2", atBlockID: blockID, position: 3)
        let docAfterOp2 = harness.peers[0].bridge.doc
        
        // Peer 1 receives Op2 first (out of order)
        harness.peers[1].bridge.merge(from: docAfterOp2)
        // Peer 1 receives Op1 second
        harness.peers[1].bridge.merge(from: docAfterOp1)
        
        // Peer 2 receives in regular order
        harness.peers[2].bridge.merge(from: docAfterOp1)
        harness.peers[2].bridge.merge(from: docAfterOp2)
        
        harness.mergeAll()
        #expect(harness.converge(), "Out-of-order delivery should still converge")
    }

    @Test func testConcurrentSplitAndMerge() throws {
        let harness = MultiPeerTestHarness(peerCount: 3)
        let blockID = harness.peers[0].bridge.createBlock(text: "Hello World")
        for i in 1..<3 {
            _ = harness.peers[i].bridge.createBlock(id: blockID, text: "Hello World")
        }
        
        // Peer 0 splits at position 5 (after "Hello")
        harness.peers[0].bridge.splitBlock(atBlockID: blockID, position: 5)
        
        // Peer 1 types "!" at end of original block
        harness.type(on: 1, text: "!", atBlockID: blockID, position: 11)
        
        // Peer 2 deletes "World"
        harness.peers[2].bridge.deleteText(atBlockID: blockID, position: 6, length: 5)
        
        harness.mergeAll()
        #expect(harness.converge(), "Concurrent split/merge should converge")
    }

    @Test func testRandomizedMultiPeerConvergence() throws {
        // Run 50 randomized multi-peer fuzzing scenarios
        for _ in 0..<50 {
            let peerCount = Int.random(in: 3...5)
            let harness = MultiPeerTestHarness(peerCount: peerCount)
            let blockID = harness.peers[0].bridge.createBlock(text: "")
            for i in 1..<peerCount {
                _ = harness.peers[i].bridge.createBlock(id: blockID, text: "")
            }
            
            // Random operations across peers
            for _ in 0..<10 {
                let peerIndex = Int.random(in: 0..<peerCount)
                let char = String(UnicodeScalar(Int.random(in: 65...90))!) // A-Z
                let pos = Int.random(in: 0...5)
                harness.type(on: peerIndex, text: char, atBlockID: blockID, position: pos)
            }
            
            harness.mergeAll()
            #expect(harness.converge(), "Randomized multi-peer operations must converge deterministically")
        }
    }
}
#endif
