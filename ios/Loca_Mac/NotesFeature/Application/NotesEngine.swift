import Foundation
import Combine
import SwiftUI

/// Main sovereign entry point and UI-facing facade for the Notes engine on macOS.
@MainActor
public final class NotesEngine: ObservableObject {
    
    public let repository: NotesRepository
    
    // Use Cases
    public let createNoteUseCase: CreateNoteUseCase
    public let updateNoteUseCase: UpdateNoteUseCase
    public let deleteNoteUseCase: DeleteNoteUseCase
    public let restoreNoteUseCase: RestoreNoteUseCase
    public let moveNoteUseCase: MoveNoteUseCase
    public let pinNoteUseCase: PinNoteUseCase
    public let searchNotesUseCase: SearchNotesUseCase
    
    public init(repository: NotesRepository) {
        self.repository = repository
        self.createNoteUseCase = CreateNoteUseCase(repository: repository)
        self.updateNoteUseCase = UpdateNoteUseCase(repository: repository)
        self.deleteNoteUseCase = DeleteNoteUseCase(repository: repository)
        self.restoreNoteUseCase = RestoreNoteUseCase(repository: repository)
        self.moveNoteUseCase = MoveNoteUseCase(repository: repository)
        self.pinNoteUseCase = PinNoteUseCase(repository: repository)
        self.searchNotesUseCase = SearchNotesUseCase(repository: repository)
    }
    
    // MARK: - Query & Observation
    
    public func fetchNotes(matching query: NoteQuery = .all) async throws -> [NoteSummary] {
        try await repository.fetchNotes(matching: query)
    }
    
    public func fetchNote(id: NoteID) async throws -> Note? {
        try await repository.fetchNote(id: id)
    }
    
    public func observeNotes(matching query: NoteQuery = .all) -> AsyncStream<[NoteSummary]> {
        repository.observeNotes(matching: query)
    }
    
    public func observeNote(id: NoteID) -> AsyncStream<Note?> {
        repository.observeNote(id: id)
    }
    
    // MARK: - Write Actions
    
    public func apply(_ mutation: NoteMutation) async throws {
        try await repository.apply(mutation)
    }
    
    public func apply(mutations: [NoteMutation]) async throws {
        try await repository.apply(mutations: mutations)
    }
    
    @discardableResult
    public func createNote(in folderID: FolderID? = nil) async throws -> NoteID {
        try await createNoteUseCase.execute(in: folderID)
    }
    
    public func createNote(title: String = "", folderID: FolderID? = nil) async throws -> Note {
        let noteID = try await createNoteUseCase.execute(in: folderID)
        if let note = try await repository.fetchNote(id: noteID) {
            return note
        }
        return Note(id: noteID, folderID: folderID, title: title)
    }
    
    public func updateNote(id: NoteID, title: String? = nil, isPinned: Bool? = nil, content: NoteContent? = nil) async throws {
        if let title = title {
            try await setTitle(title, for: id)
        }
        if let isPinned = isPinned {
            try await setPinned(isPinned, noteID: id)
        }
        if let content = content {
            try await updateContent(content, for: id)
        }
    }
    
    public func fetchNotes(folderID: FolderID? = nil, includeDeleted: Bool = false) async throws -> [NoteSummary] {
        let query = NoteQuery(folderID: folderID, includeDeleted: includeDeleted)
        return try await fetchNotes(matching: query)
    }
    
    public func observeNotes(folderID: FolderID? = nil, includeDeleted: Bool = false) -> AsyncStream<[NoteSummary]> {
        let query = NoteQuery(folderID: folderID, includeDeleted: includeDeleted)
        return observeNotes(matching: query)
    }
    
    public func setTitle(_ title: String, for noteID: NoteID) async throws {
        try await updateNoteUseCase.setTitle(title, for: noteID)
    }
    
    public func updateContent(_ content: NoteContent, for noteID: NoteID) async throws {
        try await updateNoteUseCase.updateContent(content, for: noteID)
    }
    
    public func toggleChecklistItem(noteID: NoteID, blockID: UUID) async throws {
        try await updateNoteUseCase.toggleChecklistItem(noteID: noteID, blockID: blockID)
    }
    
    public func move(noteID: NoteID, to folderID: FolderID?) async throws {
        try await moveNoteUseCase.execute(noteID: noteID, to: folderID)
    }
    
    public func setPinned(_ isPinned: Bool, noteID: NoteID) async throws {
        try await pinNoteUseCase.execute(noteID: noteID, isPinned: isPinned)
    }
    
    public func setPinned(_ isPinned: Bool, for noteID: NoteID) async throws {
        try await pinNoteUseCase.execute(noteID: noteID, isPinned: isPinned)
    }
    
    public func delete(noteID: NoteID) async throws {
        try await deleteNoteUseCase.softDelete(noteID: noteID)
    }
    
    public func deleteNote(id: NoteID) async throws {
        try await deleteNoteUseCase.softDelete(noteID: id)
    }
    
    public func delete(id: NoteID) async throws {
        try await deleteNoteUseCase.softDelete(noteID: id)
    }
    
    public func restore(noteID: NoteID) async throws {
        try await restoreNoteUseCase.execute(noteID: noteID)
    }
    
    public func permanentlyDelete(noteID: NoteID) async throws {
        try await deleteNoteUseCase.permanentlyDelete(noteID: noteID)
    }
    
    public func search(term: String) async throws -> [NoteSummary] {
        try await searchNotesUseCase.execute(term: term)
    }
    
    // MARK: - Folders & Tags
    
    public func fetchFolders() async throws -> [Folder] {
        try await repository.fetchFolders()
    }
    
    public func createFolder(name: String, parentID: FolderID? = nil) async throws -> FolderID {
        try await repository.createFolder(name: name, parentID: parentID)
    }
    
    public func deleteFolder(id: FolderID) async throws {
        try await repository.deleteFolder(id: id)
    }
    
    public func fetchTags() async throws -> [Tag] {
        try await repository.fetchTags()
    }
    
    public func createTag(name: String) async throws -> TagID {
        try await repository.createTag(name: name)
    }
    
    public func addTag(_ tagID: TagID, to noteID: NoteID) async throws {
        try await repository.addTag(tagID, to: noteID)
    }
    
    public func removeTag(_ tagID: TagID, from noteID: NoteID) async throws {
        try await repository.removeTag(tagID, from: noteID)
    }
    
    public func fetchTags(for noteID: NoteID) async throws -> [Tag] {
        try await repository.fetchTags(for: noteID)
    }
    
    // MARK: - Factory Constructors
    
    public static func localDefault() throws -> NotesEngine {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let plutoDir = appSupport.appendingPathComponent("Pluto", isDirectory: true)
        try? FileManager.default.createDirectory(at: plutoDir, withIntermediateDirectories: true)
        let dbURL = plutoDir.appendingPathComponent("notes_v1.sqlite")
        
        let db = try NotesDatabase(fileURL: dbURL)
        let store = LocalNotesStore(database: db)
        let eventBus = NotesEventBus()
        let repo = LocalNotesRepository(store: store, eventBus: eventBus)
        return NotesEngine(repository: repo)
    }
    
    public static func inMemory() -> NotesEngine {
        let repo = InMemoryNotesRepository()
        return NotesEngine(repository: repo)
    }
    
    public static let shared: NotesEngine = {
        do {
            return try localDefault()
        } catch {
            return inMemory()
        }
    }()
}
