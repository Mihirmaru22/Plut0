import Foundation

/// Lifecycle events published by the Notes engine on successful mutations.
public enum NotesEvent: Sendable, Hashable {
    case noteCreated(NoteID)
    case noteUpdated(NoteID)
    case noteDeleted(NoteID)
    case noteRestored(NoteID)
    case notePermanentlyDeleted(NoteID)
    case noteMoved(NoteID)
    case notePinned(NoteID)
    case tagsChanged(NoteID)
    case folderCreated(FolderID)
    case folderDeleted(FolderID)
    case tagCreated(TagID)
    case databaseReset
}
