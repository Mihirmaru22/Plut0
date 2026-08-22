import Foundation

/// Use case moving a note to a different folder.
public struct MoveNoteUseCase: Sendable {
    private let repository: NotesRepository
    
    public init(repository: NotesRepository) {
        self.repository = repository
    }
    
    public func execute(noteID: NoteID, to folderID: FolderID?) async throws {
        try await repository.apply(.move(noteID: noteID, folderID: folderID))
    }
}
