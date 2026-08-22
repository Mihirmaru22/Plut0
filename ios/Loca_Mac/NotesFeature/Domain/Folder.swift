import Foundation

/// Domain model representing a hierarchical note collection folder.
public struct Folder: Identifiable, Hashable, Sendable {
    public let id: FolderID
    public var name: String
    public var parentID: FolderID?
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: FolderID = FolderID(),
        name: String,
        parentID: FolderID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.parentID = parentID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
