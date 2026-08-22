import Foundation

/// Primary abstraction boundary isolating the UI & application layers from underlying SQLite storage.
public protocol NotesRepository: DocumentCoreRepository {
    
    // MARK: - Fetch
    func fetchNotes(matching query: NoteQuery) async throws -> [NoteSummary]
    func fetchNote(id: NoteID) async throws -> Note?
    
    // MARK: - Observation (Live Reactive Streams)
    func observeNotes(matching query: NoteQuery) -> AsyncStream<[NoteSummary]>
    func observeNote(id: NoteID) -> AsyncStream<Note?>
    
    // MARK: - Mutations
    func apply(_ mutation: NoteMutation) async throws
    func apply(mutations: [NoteMutation]) async throws
    
    // MARK: - Folders
    func fetchFolders() async throws -> [Folder]
    func createFolder(name: String, parentID: FolderID?) async throws -> FolderID
    func deleteFolder(id: FolderID) async throws
    
    // MARK: - Tags
    func fetchTags() async throws -> [Tag]
    func createTag(name: String) async throws -> TagID
    func addTag(_ tagID: TagID, to noteID: NoteID) async throws
    func removeTag(_ tagID: TagID, from noteID: NoteID) async throws
    func fetchTags(for noteID: NoteID) async throws -> [Tag]
    
    // MARK: - Search
    func searchNotes(term: String) async throws -> [NoteSummary]
}

extension NotesRepository {
    public func fetchDocument(id: NoteID) async throws -> Note? {
        try await fetchNote(id: id)
    }
    
    public func observeDocument(id: NoteID) -> AsyncStream<Note?> {
        observeNote(id: id)
    }
    
    public func searchDocuments(term: String) async throws -> [NoteSummary] {
        try await searchNotes(term: term)
    }
}
