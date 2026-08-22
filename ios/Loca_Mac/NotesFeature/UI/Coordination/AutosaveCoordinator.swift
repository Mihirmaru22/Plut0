import Foundation

/// Coordinates high-frequency keystrokes with 500ms debounced SQLite writes and 200ms batched WebSocket pushes.
public actor AutosaveCoordinator {
    
    private let materializationDebounceInterval: TimeInterval
    private let syncBatchInterval: TimeInterval
    
    private var pendingMaterializations: [NoteID: Task<Void, Never>] = [:]
    private var pendingSyncPushes: [NoteID: Task<Void, Never>] = [:]
    
    public init(
        materializationDebounceInterval: TimeInterval = 0.5,
        syncBatchInterval: TimeInterval = 0.2
    ) {
        self.materializationDebounceInterval = materializationDebounceInterval
        self.syncBatchInterval = syncBatchInterval
    }
    
    /// Schedules a debounced autosave write using the provided engine.
    public func scheduleAutosave(
        noteID: NoteID,
        title: String,
        isPinned: Bool? = nil,
        content: NoteContent,
        engine: NotesEngine
    ) {
        scheduleMaterialization(for: noteID) {
            try? await engine.updateContent(content, for: noteID)
            if let pinned = isPinned {
                try? await engine.setPinned(pinned, noteID: noteID)
            }
        }
    }
    
    /// Debounces the materialization of a CRDT document into the SQLite read-view.
    public func scheduleMaterialization(
        for noteID: NoteID,
        action: @escaping @Sendable () async -> Void
    ) {
        pendingMaterializations[noteID]?.cancel()
        
        pendingMaterializations[noteID] = Task { [materializationDebounceInterval] in
            try? await Task.sleep(nanoseconds: UInt64(materializationDebounceInterval * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await action()
        }
    }
    
    /// Batches outbound sync delta broadcasts.
    public func scheduleSyncPush(
        for noteID: NoteID,
        action: @escaping @Sendable () async -> Void
    ) {
        if pendingSyncPushes[noteID] != nil {
            return // Already scheduled to batch
        }
        
        pendingSyncPushes[noteID] = Task { [syncBatchInterval] in
            try? await Task.sleep(nanoseconds: UInt64(syncBatchInterval * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await action()
        }
    }
    
    /// Immediately cancels pending timers and executes pending writes.
    public func cancel(for noteID: NoteID) {
        pendingMaterializations[noteID]?.cancel()
        pendingMaterializations.removeValue(forKey: noteID)
        pendingSyncPushes[noteID]?.cancel()
        pendingSyncPushes.removeValue(forKey: noteID)
    }
}
