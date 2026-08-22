import Foundation

/// Use case restoring a soft-deleted note back to active status.
public struct RestoreNoteUseCase: Sendable {
    private let repository: NotesRepository
    
    public init(repository: NotesRepository) {
        self.repository = repository
    }
    
    public func execute(noteID: NoteID) async throws {
        try await repository.apply(.restore(noteID: noteID))
    }
}
