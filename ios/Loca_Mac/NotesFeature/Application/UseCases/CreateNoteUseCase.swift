import Foundation

/// Use case creating a new note within an optional folder.
public struct CreateNoteUseCase: Sendable {
    private let repository: NotesRepository
    
    public init(repository: NotesRepository) {
        self.repository = repository
    }
    
    @discardableResult
    public func execute(in folderID: FolderID? = nil) async throws -> NoteID {
        let noteID = NoteID()
        try await repository.apply(.createNote(noteID: noteID, folderID: folderID))
        return noteID
    }
}
