import Foundation

/// Direct database row representation of the `attachments` SQLite table.
public struct AttachmentRow: Sendable, Codable, Equatable {
    public var id: String
    public var noteID: String
    public var kind: String
    public var filePath: String
    public var createdAt: Double
    public var metadataJSON: String?
    
    public init(
        id: String,
        noteID: String,
        kind: String,
        filePath: String,
        createdAt: Double = Date().timeIntervalSince1970,
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
