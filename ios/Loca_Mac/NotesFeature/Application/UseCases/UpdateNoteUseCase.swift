import Foundation

/// Use case applying content and title updates to a note.
public struct UpdateNoteUseCase: Sendable {
    private let repository: NotesRepository
    
    public init(repository: NotesRepository) {
        self.repository = repository
    }
    
    public func setTitle(_ title: String, for noteID: NoteID) async throws {
        try await repository.apply(.setTitle(noteID: noteID, title: title))
    }
    
    public func updateContent(_ content: NoteContent, for noteID: NoteID) async throws {
        try await repository.apply(.updateContent(noteID: noteID, content: content))
    }
    
    public func toggleChecklistItem(noteID: NoteID, blockID: UUID) async throws {
        try await repository.apply(.toggleChecklistItem(noteID: noteID, blockID: blockID))
    }
}
