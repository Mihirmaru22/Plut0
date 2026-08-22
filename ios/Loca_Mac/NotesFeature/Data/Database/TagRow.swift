import Foundation

/// Direct database row representation of the `tags` SQLite table.
public struct TagRow: Sendable, Codable, Equatable {
    public var id: String
    public var name: String
    public var createdAt: Double
    
    public init(
        id: String,
        name: String,
        createdAt: Double = Date().timeIntervalSince1970
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}
