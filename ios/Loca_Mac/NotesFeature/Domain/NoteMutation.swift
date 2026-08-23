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
    case setPrivate(noteID: NoteID, isPrivate: Bool)
    case materializeFromSync(noteID: NoteID, title: String, content: NoteContent, plainTextCache: String, preview: String)
    
    public var noteID: NoteID {
        switch self {
        case .createNote(let id, _): return id
        case .setTitle(let id, _): return id
        case .updateContent(let id, _): return id
        case .move(let id, _): return id
        case .setPinned(let id, _): return id
        case .setLocked(let id, _): return id
        case .markDeleted(let id): return id
        case .restore(let id): return id
        case .permanentlyDelete(let id): return id
        case .toggleChecklistItem(let id, _): return id
        case .setPrivate(let id, _): return id
        case .materializeFromSync(let id, _, _, _, _): return id
        }
    }
}
