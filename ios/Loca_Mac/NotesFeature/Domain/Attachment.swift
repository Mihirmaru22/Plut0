import Foundation

public enum AttachmentKind: String, Codable, Sendable {
    case image
    case pdf
    case audio
    case video
    case drawing
    case other
}

/// Domain metadata model for an attachment associated with a note.
public struct Attachment: Identifiable, Hashable, Sendable {
    public let id: AttachmentID
    public let noteID: NoteID
    public var kind: AttachmentKind
    public var filePath: String
    public var createdAt: Date
    public var metadataJSON: String?
    
    public init(
        id: AttachmentID = AttachmentID(),
        noteID: NoteID,
        kind: AttachmentKind,
        filePath: String,
        createdAt: Date = Date(),
        metadataJSON: String? = nil
    ) {
        self.id = id
        self.noteID = noteID
        self.kind = kind
        self.filePath = filePath
        self.createdAt = createdAt
        self.metadataJSON = metadataJSON
    }
}
