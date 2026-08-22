#if canImport(Testing)
import Foundation
import Testing

@Suite("Notes Feature - Materialization & Shadow Sync Pipeline Tests")
struct MaterializationTests {
    
    private func makeTestEnvironment() throws -> (ShadowSyncCoordinator, LocalNotesStore, NoteVault, URL) {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let dbURL = tempDir.appendingPathComponent("shadow_sync_test.sqlite")
        
        let db = try NotesDatabase(fileURL: dbURL)
        _ = try db.write { pointer in
            try CRDTSQLiteMigrations.runMigrationV2(on: pointer)
        }
        
        let store = LocalNotesStore(database: db)
        let eventBus = NotesEventBus()
        let repo = LocalNotesRepository(store: store, eventBus: eventBus)
        let crdtStore = CRDTStore(database: db)
        let queueStore = OutboundQueueStore(database: db)
        let materializer = MaterializationPipeline(repository: repo)
        
        let relay = MockRelayServer()
        let mockSocket = MockWebSocketClient(deviceID: "device-1", relay: relay)
        let vault = NoteVault()
        
        let coordinator = ShadowSyncCoordinator(
            deviceID: "device-1",
            vault: vault,
            repository: repo,
            crdtStore: crdtStore,
            queueStore: queueStore,
            client: mockSocket,
            materializer: materializer
        )
        
        return (coordinator, store, vault, tempDir)
    }
    
    @Test func testMaterializationPipelineConsistency() async throws {
        let (coordinator, store, _, tempDir) = try makeTestEnvironment()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let noteID = NoteID()
        
        // 1. Create note
        let note = try await coordinator.applyLocalMutation(.createNote(noteID: noteID, folderID: nil))
        #expect(note.id == noteID)
        
        // 2. Set title
        try await coordinator.applyLocalMutation(.setTitle(noteID: noteID, title: "CRDT Sync Protocol"))
        
        // 3. Update blocks
        let blocks: [NoteBlock] = [
            .heading(HeadingBlock(text: "Executive Summary", level: 1)),
            .paragraph(ParagraphBlock(text: "Local-first E2EE syncing.")),
            .checklistItem(ChecklistItemBlock(text: "Implement AES-GCM", isChecked: true))
        ]
        let content = NoteContent(version: 1, blocks: blocks)
        try await coordinator.applyLocalMutation(.updateContent(noteID: noteID, content: content))
        
        // 4. Assert SQLite row matches materialized CRDT state
        let fetchedRow = try await store.fetchNoteRow(id: noteID.raw.uuidString)
        #expect(fetchedRow != nil)
        #expect(fetchedRow?.title == "CRDT Sync Protocol")
        #expect(fetchedRow?.plainTextCache.contains("Local-first E2EE syncing.") == true)
        #expect(fetchedRow?.preview.contains("Executive Summary") == true)
    }
    
    @Test func testRandomizedCRDTStressOperations() {
        let noteID = NoteID()
        var doc = CRDTDoc(id: noteID, deviceID: "stress-device")
        let blockID = UUID()
        doc.addBlock(CRDTBlock(id: blockID, type: "paragraph", text: CRDTText()))
        
        // Perform 1,000 randomized operations
        for i in 0..<1_000 {
            let op = i % 4
            switch op {
            case 0:
                doc.insertText("a", at: 0, in: blockID)
            case 1:
                doc.insertText("b", at: doc.blocks.first?.text.string.count ?? 0, in: blockID)
            case 2:
                if (doc.blocks.first?.text.string.count ?? 0) > 2 {
                    doc.deleteText(at: 0, length: 1, in: blockID)
                }
            case 3:
                doc.title = "Iteration \(i)"
            default:
                break
            }
        }
        
        let materialized = CRDTTranslator.materializeContent(from: doc)
        let plainText = NoteTextExtractor.plainText(from: materialized)
        let crdtString = doc.blocks.first?.text.string ?? ""
        
        #expect(plainText == crdtString)
        #expect(doc.title == "Iteration 999")
    }
}
#endif
