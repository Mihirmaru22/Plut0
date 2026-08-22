import Foundation

/// Direct database row representation of the `notes` SQLite table.
public struct NoteRow: Sendable, Codable, Equatable {
    public var id: String
    public var folderID: String?
    public var title: String
    public var contentJSON: String
    public var plainTextCache: String
    public var preview: String
    public var isPinned: Int
    public var isLocked: Int
    public var isDeleted: Int
    public var createdAt: Double
    public var updatedAt: Double
    public var deletedAt: Double?
    public var sortKey: String
    public var schemaVersion: Int
    public var clientUpdatedAt: Double
    public var deviceID: String
    
    public init(
        id: String,
        folderID: String? = nil,
        title: String = "",
        contentJSON: String = "{\"version\":1,\"blocks\":[]}",
        plainTextCache: String = "",
        preview: String = "",
        isPinned: Int = 0,
        isLocked: Int = 0,
        isDeleted: Int = 0,
        createdAt: Double = Date().timeIntervalSince1970,
        updatedAt: Double = Date().timeIntervalSince1970,
        deletedAt: Double? = nil,
        sortKey: String = String(format: "%014.3f", Date().timeIntervalSince1970),
        schemaVersion: Int = 1,
        clientUpdatedAt: Double = Date().timeIntervalSince1970,
        deviceID: String = "local-device"
    ) {
        self.id = id
        self.folderID = folderID
        self.title = title
        self.contentJSON = contentJSON
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
