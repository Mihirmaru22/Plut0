import Foundation

/// Use case pinning or unpinning a note.
public struct PinNoteUseCase: Sendable {
    private let repository: NotesRepository
    
    public init(repository: NotesRepository) {
        self.repository = repository
    }
    
    public func execute(noteID: NoteID, isPinned: Bool) async throws {
        try await repository.apply(.setPinned(noteID: noteID, isPinned: isPinned))
    }
}
