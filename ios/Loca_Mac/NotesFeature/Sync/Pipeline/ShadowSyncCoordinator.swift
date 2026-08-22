import Foundation

/// Central coordinator managing the distributed CRDT lifecycle, E2EE encryption, WebSocket sync, ACK gating, and materialization.
public actor ShadowSyncCoordinator {
    
    public let deviceID: String
    private let vault: NoteVault
    private let repository: any NotesRepository
    private let crdtStore: CRDTStore
    private let queueStore: OutboundQueueStore
    private let client: WebSocketClientProtocol
    private let materializer: MaterializationPipeline
    private let networkMonitor: NetworkMonitor
    
    private var docCache: [NoteID: CRDTDoc] = [:]
    private var listeningTask: Task<Void, Never>?
    private var networkTask: Task<Void, Never>?
    
    public init(
        deviceID: String = "local-device",
        vault: NoteVault,
        repository: any NotesRepository,
        crdtStore: CRDTStore,
        queueStore: OutboundQueueStore,
        client: WebSocketClientProtocol,
        materializer: MaterializationPipeline,
        networkMonitor: NetworkMonitor = .shared
    ) {
        self.deviceID = deviceID
        self.vault = vault
        self.repository = repository
        self.crdtStore = crdtStore
        self.queueStore = queueStore
        self.client = client
        self.materializer = materializer
        self.networkMonitor = networkMonitor
    }
    
    public func start() {
        startListeningToRemoteMessages()
        startMonitoringNetwork()
    }
    
    public func stop() {
        listeningTask?.cancel()
        networkTask?.cancel()
    }
    
    // MARK: - Local Mutation Interception & Materialization
    
    @discardableResult
    public func applyLocalMutation(_ mutation: NoteMutation) async throws -> Note {
        let noteID = targetNoteID(from: mutation)
        var doc = try await loadOrCreateDoc(for: noteID)
        
        // 1. Apply mutation to CRDT
        CRDTTranslator.apply(mutation: mutation, to: &doc, deviceID: deviceID)
        docCache[noteID] = doc
        
        // 2. Encrypt CRDT state with AES-256-GCM via Vault
        let snapshotData = try JSONEncoder().encode(doc)
        let encryptedPayload = try vault.encrypt(data: snapshotData, for: noteID)
        
        // 3. Persist raw encrypted CRDT state to SQLite
        try await crdtStore.saveEncryptedDoc(payload: encryptedPayload, vectorClock: doc.vectorClock, for: noteID)
        
        // 4. Materialize to Phase 1 SQLite read-view via NotesRepository
        let materializedNote = try await materializer.materialize(doc: doc)
        
        // 5. Build Push Delta with unique Message ID
        let messageID = UUID()
        let syncMessage = SyncMessage.pushDelta(
            messageID: messageID,
            noteID: noteID,
            encryptedPayload: encryptedPayload,
            vectorClock: doc.vectorClock,
            deviceID: deviceID
        )
        
        // 6. Enqueue into SQLite Outbound Queue (retained until server ACK)
        try await queueStore.enqueue(messageID: messageID, message: syncMessage, for: noteID)
        
        // 7. If connected, send via WebSocket
        if await client.isConnected {
            try? await client.send(message: syncMessage)
        }
        
        return materializedNote
    }
    
    // MARK: - Remote Message Ingestion (CRDT Merge & Decryption)
    
    public func applyRemoteDelta(
        messageID: UUID,
        noteID: NoteID,
        encryptedPayload: EncryptedPayload,
        vectorClock: CRDTVectorClock,
        remoteDeviceID: String
    ) async throws {
        guard remoteDeviceID != deviceID else { return } // Skip self-broadcasts
        
        // 1. Decrypt remote payload using NoteVault
        let decryptedData = try vault.decrypt(payload: encryptedPayload, for: noteID)
        let remoteDoc = try JSONDecoder().decode(CRDTDoc.self, from: decryptedData)
        
        // 2. Load local CRDT doc and merge deterministically
        var localDoc = try await loadOrCreateDoc(for: noteID)
        localDoc.merge(with: remoteDoc)
        docCache[noteID] = localDoc
        
        // 3. Re-encrypt merged document and save to CRDT store
        let mergedData = try JSONEncoder().encode(localDoc)
        let mergedEncrypted = try vault.encrypt(data: mergedData, for: noteID)
        try await crdtStore.saveEncryptedDoc(payload: mergedEncrypted, vectorClock: localDoc.vectorClock, for: noteID)
        
        // 4. Materialize to SQLite read-view via NotesRepository (does NOT enqueue local delta)
        _ = try await materializer.materialize(doc: localDoc)
    }
    
    // MARK: - Offline Outbound Queue Flush (ACK-Gated)
    
    public func flushOutboundQueue() async {
        guard await client.isConnected else { return }
        
        guard let pending = try? await queueStore.fetchPending(limit: 50), !pending.isEmpty else {
            return
        }
        
        for item in pending {
            do {
                try await client.send(message: item.message)
                // Note: Item is NOT deleted here. It is deleted only when server responds with .ack
            } catch {
                break
            }
        }
    }
    
    public func handleServerAck(messageID: UUID) async {
        try? await queueStore.remove(messageID: messageID)
    }
    
    // MARK: - Private Helpers
    
    private func loadOrCreateDoc(for noteID: NoteID) async throws -> CRDTDoc {
        if let cached = docCache[noteID] {
            return cached
        }
        
        // Try to load encrypted state from CRDT store
        if let (encryptedPayload, _) = try await crdtStore.loadEncryptedDoc(for: noteID) {
            let decryptedData = try vault.decrypt(payload: encryptedPayload, for: noteID)
            let doc = try JSONDecoder().decode(CRDTDoc.self, from: decryptedData)
            docCache[noteID] = doc
            return doc
        }
        
        // Fallback: If note exists in SQLite read-view, synthesize CRDTDoc
        if let note = try await repository.fetchNote(id: noteID) {
            let doc = CRDTTranslator.crdtDoc(from: note, deviceID: deviceID)
            docCache[noteID] = doc
            return doc
        }
        
        // Create fresh CRDTDoc
        let newDoc = CRDTDoc(id: noteID, deviceID: deviceID)
        docCache[noteID] = newDoc
        return newDoc
    }
    
    private func targetNoteID(from mutation: NoteMutation) -> NoteID {
        switch mutation {
        case .createNote(let id, _): return id
        case .setTitle(let id, _): return id
        case .updateContent(let id, _): return id
        case .move(let id, _): return id
        case .setPinned(let id, _): return id
        case .setLocked(let id, _): return id
        case .markDeleted(let id): return id
        case .restore(let id): return id
        case .permanentlyDelete(let id): return id
        case .toggleChecklistItem(let id, _): return id
        case .materializeFromSync(let id, _, _, _, _): return id
        }
    }
    
    private func startListeningToRemoteMessages() {
        listeningTask = Task { [weak self] in
            guard let self = self else { return }
            let stream = await self.client.incomingMessages()
            for await msg in stream {
                guard !Task.isCancelled else { break }
                switch msg {
                case .ack(let messageID, _):
                    await self.handleServerAck(messageID: messageID)
                    
                case .broadcastDelta(let messageID, let noteID, let payload, let clock, let devID),
                     .pushDelta(let messageID, let noteID, let payload, let clock, let devID):
                    try? await self.applyRemoteDelta(
                        messageID: messageID,
                        noteID: noteID,
                        encryptedPayload: payload,
                        vectorClock: clock,
                        remoteDeviceID: devID
                    )
                default:
                    break
                }
            }
        }
    }
    
    private func startMonitoringNetwork() {
        networkTask = Task { [weak self] in
            guard let self = self else { return }
            for await isConnected in self.networkMonitor.observeStatus() {
                guard !Task.isCancelled else { break }
                if isConnected {
                    await self.client.connect()
                    await self.flushOutboundQueue()
                }
            }
        }
    }
}
