import Foundation

/// Direct database row representation of the `folders` SQLite table.
public struct FolderRow: Sendable, Codable, Equatable {
    public var id: String
    public var name: String
    public var parentID: String?
    public var createdAt: Double
    public var updatedAt: Double
    
    public init(
        id: String,
        name: String,
        parentID: String? = nil,
        createdAt: Double = Date().timeIntervalSince1970,
        updatedAt: Double = Date().timeIntervalSince1970
    ) {
        self.id = id
        self.name = name
        self.parentID = parentID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
