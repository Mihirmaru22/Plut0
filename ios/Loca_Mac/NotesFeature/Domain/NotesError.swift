import Foundation

/// Strongly typed domain errors for the Notes engine, ensuring no database errors leak to UI.
public enum NotesError: Error, Hashable, Sendable, CustomStringConvertible {
    case noteNotFound(NoteID)
    case folderNotFound(FolderID)
    case tagNotFound(TagID)
    case invalidContent
    case persistenceFailure(String)
    case migrationFailure(String)
    
    public var description: String {
        switch self {
        case .noteNotFound(let id):
            return "Note not found: \(id.raw)"
        case .folderNotFound(let id):
            return "Folder not found: \(id.raw)"
        case .tagNotFound(let id):
            return "Tag not found: \(id.raw)"
        case .invalidContent:
            return "Invalid note content payload."
        case .persistenceFailure(let message):
            return "Persistence failure: \(message)"
        case .migrationFailure(let message):
            return "Migration failure: \(message)"
        }
    }
}
