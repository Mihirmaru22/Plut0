import Foundation

/// Use case handling soft deletion and permanent purging of notes.
public struct DeleteNoteUseCase: Sendable {
    private let repository: NotesRepository
    
    public init(repository: NotesRepository) {
        self.repository = repository
    }
    
    public func softDelete(noteID: NoteID) async throws {
        try await repository.apply(.markDeleted(noteID: noteID))
    }
    
    public func permanentlyDelete(noteID: NoteID) async throws {
        try await repository.apply(.permanentlyDelete(noteID: noteID))
    }
}
