import Foundation

/// Atomic, mutation-based command enum for note writes, preparing for future CRDT/sync replay.
public enum NoteMutation: Sendable {
    case createNote(noteID: NoteID, folderID: FolderID?)
    case setTitle(noteID: NoteID, title: String)
    case updateContent(noteID: NoteID, content: NoteContent)
    case move(noteID: NoteID, folderID: FolderID?)
    case setPinned(noteID: NoteID, isPinned: Bool)
    case setLocked(noteID: NoteID, isLocked: Bool)
    case markDeleted(noteID: NoteID)
    case restore(noteID: NoteID)
    case permanentlyDelete(noteID: NoteID)
    case toggleChecklistItem(noteID: NoteID, blockID: UUID)
    case materializeFromSync(noteID: NoteID, title: String, content: NoteContent, plainTextCache: String, preview: String)
}
