import Foundation

/// Domain model representing a note organization tag.
public struct Tag: Identifiable, Hashable, Sendable {
    public let id: TagID
    public var name: String
    public var createdAt: Date
    
    public init(
        id: TagID = TagID(),
        name: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}
