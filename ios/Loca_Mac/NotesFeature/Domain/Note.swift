import Foundation

/// Primary domain entity representing a Note in the local-first Notes engine.
public struct Note: Identifiable, Hashable, Sendable {
    public let id: NoteID
    public var folderID: FolderID?
    public var title: String
    public var content: NoteContent
    public var plainTextCache: String
    public var preview: String
    public var isPinned: Bool
    public var isLocked: Bool
    public var isDeleted: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?
    public var sortKey: String
    public var schemaVersion: Int
    public var clientUpdatedAt: Date
    public var deviceID: String
    
    public init(
        id: NoteID = NoteID(),
        folderID: FolderID? = nil,
        title: String = "",
        content: NoteContent = .empty,
        plainTextCache: String = "",
        preview: String = "",
        isPinned: Bool = false,
        isLocked: Bool = false,
        isDeleted: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        sortKey: String = String(format: "%014.3f", Date().timeIntervalSince1970),
        schemaVersion: Int = 1,
        clientUpdatedAt: Date = Date(),
        deviceID: String = "local-device"
    ) {
        self.id = id
        self.folderID = folderID
        self.title = title
        self.content = content
        self.plainTextCache = plainTextCache
        self.preview = preview
        self.isPinned = isPinned
        self.isLocked = isLocked
        self.isDeleted = isDeleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.sortKey = sortKey
        self.schemaVersion = schemaVersion
        self.clientUpdatedAt = clientUpdatedAt
        self.deviceID = deviceID
    }
}
