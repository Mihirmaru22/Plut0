import Foundation

/// Concrete repository implementation combining SQLite LocalStore with reactive NotesEventBus.
public final class LocalNotesRepository: NotesRepository, @unchecked Sendable {
    
    private let store: LocalNotesStore
    private let eventBus: NotesEventBus
    
    public init(store: LocalNotesStore, eventBus: NotesEventBus) {
        self.store = store
        self.eventBus = eventBus
    }
    
    // MARK: - Fetch
    
    public func fetchNotes(matching query: NoteQuery) async throws -> [NoteSummary] {
        try await store.fetchNoteSummaries(matching: query)
    }
    
    public func fetchNote(id: NoteID) async throws -> Note? {
        guard let row = try await store.fetchNoteRow(id: id.raw.uuidString) else {
            return nil
        }
        return NotesMappers.note(from: row)
    }
    
    // MARK: - Observation (Live Reactive AsyncStreams)
    
    public func observeNotes(matching query: NoteQuery) -> AsyncStream<[NoteSummary]> {
        AsyncStream { continuation in
            let task = Task {
                // 1. Emit current initial state
                if let initial = try? await self.fetchNotes(matching: query) {
                    continuation.yield(initial)
                }
                
                // 2. Listen to mutation events and re-emit updated results
                for await _ in self.eventBus.events() {
                    guard !Task.isCancelled else { break }
                    if let updated = try? await self.fetchNotes(matching: query) {
                        continuation.yield(updated)
                    }
                }
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    public func observeNote(id: NoteID) -> AsyncStream<Note?> {
        AsyncStream { continuation in
            let task = Task {
                // 1. Emit current initial state
                if let initial = try? await self.fetchNote(id: id) {
                    continuation.yield(initial)
                }
                
                // 2. Listen to mutation events and re-emit updated note
                for await event in self.eventBus.events() {
                    guard !Task.isCancelled else { break }
                    
                    switch event {
                    case .noteUpdated(let targetID),
                         .notePinned(let targetID),
                         .noteMoved(let targetID),
                         .noteRestored(let targetID),
                         .tagsChanged(let targetID):
                        if targetID == id {
                            let note = try? await self.fetchNote(id: id)
                            continuation.yield(note)
                        }
                    case .noteDeleted(let targetID):
                        if targetID == id {
                            let note = try? await self.fetchNote(id: id)
                            continuation.yield(note)
                        }
                    case .notePermanentlyDeleted(let targetID):
                        if targetID == id {
                            continuation.yield(nil)
                        }
                    case .databaseReset:
                        let note = try? await self.fetchNote(id: id)
                        continuation.yield(note)
                    default:
                        break
                    }
                }
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    // MARK: - Mutations
    
    public func apply(_ mutation: NoteMutation) async throws {
        try await apply(mutations: [mutation])
    }
    
    public func apply(mutations: [NoteMutation]) async throws {
        guard !mutations.isEmpty else { return }
        let events = try await store.applyBatchMutations(mutations)
        for event in events {
            eventBus.publish(event)
        }
    }
    
    // MARK: - Folders
    
    public func fetchFolders() async throws -> [Folder] {
        let rows = try await store.fetchFolderRows()
        return rows.map { NotesMappers.folder(from: $0) }
    }
    
    public func createFolder(name: String, parentID: FolderID?) async throws -> FolderID {
        let id = FolderID()
        let folder = Folder(id: id, name: name, parentID: parentID)
        let row = NotesMappers.folderRow(from: folder)
        try await store.insertFolderRow(row)
        eventBus.publish(.folderCreated(id))
        return id
    }
    
    public func deleteFolder(id: FolderID) async throws {
        try await store.deleteFolderRow(id: id.raw.uuidString)
        eventBus.publish(.folderDeleted(id))
    }
    
    // MARK: - Tags
    
    public func fetchTags() async throws -> [Tag] {
        let rows = try await store.fetchTagRows()
        return rows.map { NotesMappers.tag(from: $0) }
    }
    
    public func createTag(name: String) async throws -> TagID {
        let id = TagID()
        let tag = Tag(id: id, name: name)
        let row = NotesMappers.tagRow(from: tag)
        try await store.insertTagRow(row)
        eventBus.publish(.tagCreated(id))
        return id
    }
    
    public func addTag(_ tagID: TagID, to noteID: NoteID) async throws {
        try await store.addTagToNote(tagID: tagID.raw.uuidString, noteID: noteID.raw.uuidString)
        eventBus.publish(.tagsChanged(noteID))
    }
    
    public func removeTag(_ tagID: TagID, from noteID: NoteID) async throws {
        try await store.removeTagFromNote(tagID: tagID.raw.uuidString, noteID: noteID.raw.uuidString)
        eventBus.publish(.tagsChanged(noteID))
    }
    
    public func fetchTags(for noteID: NoteID) async throws -> [Tag] {
        let rows = try await store.fetchTagsForNote(noteID: noteID.raw.uuidString)
        return rows.map { NotesMappers.tag(from: $0) }
    }
    
    // MARK: - Search
    
    public func searchNotes(term: String) async throws -> [NoteSummary] {
        let query = NoteQuery(
            folderID: nil,
            includeDeleted: false,
            searchText: term,
            tagIDs: [],
            sortOrder: .updatedAtDescending,
            limit: nil
        )
        return try await fetchNotes(matching: query)
    }
}
