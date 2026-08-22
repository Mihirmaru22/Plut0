#if canImport(Testing)
import Foundation
import Testing

@Suite("Notes Feature - Phase 2 Hardening Tests (ACK Gating, Repository Materialization & Fractional Indexing)")
struct SyncEngineHardeningTests {
    
    private func makeTestEnvironment(autoAck: Bool = true) throws -> (ShadowSyncCoordinator, LocalNotesRepository, OutboundQueueStore, MockWebSocketClient, MockRelayServer, URL) {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let dbURL = tempDir.appendingPathComponent("sync_hardening_test.sqlite")
        
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
        
        let relay = MockRelayServer(autoAck: autoAck)
        let mockSocket = MockWebSocketClient(deviceID: "device-test-1", relay: relay)
        let vault = NoteVault()
        
        let coordinator = ShadowSyncCoordinator(
            deviceID: "device-test-1",
            vault: vault,
            repository: repo,
            crdtStore: crdtStore,
            queueStore: queueStore,
            client: mockSocket,
            materializer: materializer
        )
        
        return (coordinator, repo, queueStore, mockSocket, relay, tempDir)
    }
    
    // MARK: - Fix 1 Tests: Server ACK Outbound Queue Gating
    
    @Test func testOutboundQueueRetainsUntilACK() async throws {
        // Auto-ack DISABLED: server ingests socket packets but never sends .ack
        let (coordinator, _, queueStore, _, _, tempDir) = try makeTestEnvironment(autoAck: false)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let noteID = NoteID()
        try await coordinator.applyLocalMutation(.createNote(noteID: noteID, folderID: nil))
        
        // Item must remain in SQLite queue because ACK was not received
        let queueCount = try await queueStore.count()
        #expect(queueCount == 1)
    }
    
    @Test func testOutboundQueueRemovesOnACK() async throws {
        // Auto-ack ENABLED: server immediately sends .ack(messageID)
        let (coordinator, _, queueStore, _, _, tempDir) = try makeTestEnvironment(autoAck: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        await coordinator.start()
        
        let noteID = NoteID()
        try await coordinator.applyLocalMutation(.createNote(noteID: noteID, folderID: nil))
        
        // Small async delay to allow message cycle and ACK processing
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        let queueCount = try await queueStore.count()
        #expect(queueCount == 0)
        
        await coordinator.stop()
    }
    
    @Test func testQueueFlushOnReconnect() async throws {
        let (coordinator, _, queueStore, socket, _, tempDir) = try makeTestEnvironment(autoAck: false)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // 1. Device is offline: disconnect socket
        await socket.disconnect()
        
        // 2. Perform 5 local edits while offline
        let noteID = NoteID()
        try await coordinator.applyLocalMutation(.createNote(noteID: noteID, folderID: nil))
        for i in 1...4 {
            try await coordinator.applyLocalMutation(.setTitle(noteID: noteID, title: "Revision \(i)"))
        }
        
        let offlineCount = try await queueStore.count()
        #expect(offlineCount == 5)
        
        // 3. Fetch pending items, manually ACK first 3 items
        let pending = try await queueStore.fetchPending(limit: 10)
        #expect(pending.count == 5)
        
        await coordinator.handleServerAck(messageID: pending[0].messageID)
        await coordinator.handleServerAck(messageID: pending[1].messageID)
        await coordinator.handleServerAck(messageID: pending[2].messageID)
        
        // Exactly 2 items remain
        let remainingCount = try await queueStore.count()
        #expect(remainingCount == 2)
    }
    
    // MARK: - Fix 2 Tests: Repository-Mediated Materialization & Loop Prevention
    
    @Test func testMaterializationRoutesThroughRepository() async throws {
        let (coordinator, repo, _, _, _, tempDir) = try makeTestEnvironment(autoAck: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let noteID = NoteID()
        let vault = NoteVault()
        
        // Remote device creates a note
        var remoteDoc = CRDTDoc(id: noteID, deviceID: "remote-mac")
        remoteDoc.title = "Collaborative Strategy"
        remoteDoc.addBlock(CRDTBlock(id: UUID(), type: "paragraph", text: CRDTText(string: "Secret Plan", deviceID: "remote-mac")))
        
        let rawData = try JSONEncoder().encode(remoteDoc)
        let encrypted = try vault.encrypt(data: rawData, for: noteID)
        
        // Ingest remote delta
        try await coordinator.applyRemoteDelta(
            messageID: UUID(),
            noteID: noteID,
            encryptedPayload: encrypted,
            vectorClock: remoteDoc.vectorClock,
            remoteDeviceID: "remote-mac"
        )
        
        // Assert note exists in Phase 1 SQLite repository
        let fetched = try await repo.fetchNote(id: noteID)
        #expect(fetched != nil)
        #expect(fetched?.title == "Collaborative Strategy")
        #expect(fetched?.plainTextCache.contains("Secret Plan") == true)
    }
    
    @Test func testNoInfiniteSyncLoop() async throws {
        let (coordinator, _, queueStore, _, _, tempDir) = try makeTestEnvironment(autoAck: false)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let noteID = NoteID()
        let vault = NoteVault()
        
        var remoteDoc = CRDTDoc(id: noteID, deviceID: "remote-mac-2")
        remoteDoc.title = "Incoming Update"
        let rawData = try JSONEncoder().encode(remoteDoc)
        let encrypted = try vault.encrypt(data: rawData, for: noteID)
        
        // Ingest remote delta
        try await coordinator.applyRemoteDelta(
            messageID: UUID(),
            noteID: noteID,
            encryptedPayload: encrypted,
            vectorClock: remoteDoc.vectorClock,
            remoteDeviceID: "remote-mac-2"
        )
        
        // Assert zero outbound queue entries generated (no infinite loop)
        let queueCount = try await queueStore.count()
        #expect(queueCount == 0)
    }
    
    // MARK: - Fix 3 Tests: Fractional Indexing (Logoot/Fugue)
    
    @Test func testFractionalIndexGeneration() {
        // Initial
        let a0 = FractionalIndex.initial
        #expect(a0 == "a0")
        
        // Append after a0
        let a1 = FractionalIndex.between(a0, nil)
        #expect(a0 < a1)
        
        // Prepend before a0
        let zz = FractionalIndex.between(nil, a0)
        #expect(zz < a0)
        
        // Insert between a0 and a1
        let mid1 = FractionalIndex.between(a0, a1)
        #expect(a0 < mid1)
        #expect(mid1 < a1)
        
        // Insert between a0 and mid1
        let mid2 = FractionalIndex.between(a0, mid1)
        #expect(a0 < mid2)
        #expect(mid2 < mid1)
    }
    
    @Test func testConcurrentBlockInsertionOrder() {
        let noteID = NoteID()
        let block1ID = UUID()
        
        var docA = CRDTDoc(id: noteID, deviceID: "device-A")
        let b1 = CRDTBlock(id: block1ID, type: "paragraph", text: CRDTText(string: "Block 1", deviceID: "device-A"))
        docA.addBlock(b1)
        
        var docB = docA
        docB.deviceID = "device-B"
        
        // Device A inserts Block X after Block 1
        let blockX = CRDTBlock(id: UUID(), type: "paragraph", text: CRDTText(string: "Block X", deviceID: "device-A"))
        docA.insertBlock(blockX, afterBlockID: block1ID)
        
        // Device B inserts Block Y after Block 1
        let blockY = CRDTBlock(id: UUID(), type: "paragraph", text: CRDTText(string: "Block Y", deviceID: "device-B"))
        docB.insertBlock(blockY, afterBlockID: block1ID)
        
        // Merge A and B
        docA.merge(with: docB)
        docB.merge(with: docA)
        
        // Assert both documents converge to identical ordered lists
        let titlesA = docA.blocks.map { $0.text.string }
        let titlesB = docB.blocks.map { $0.text.string }
        
        #expect(titlesA == titlesB)
        #expect(titlesA.count == 3)
        #expect(titlesA.first == "Block 1")
    }
}
#endif
