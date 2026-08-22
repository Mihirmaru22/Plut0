import Foundation

/// Lightweight summary projection for fast list rendering and low memory footprint.
public struct NoteSummary: Identifiable, Hashable, Sendable {
    public let id: NoteID
    public var title: String
    public var preview: String
    public var folderID: FolderID?
    public var isPinned: Bool
    public var isLocked: Bool
    public var isDeleted: Bool
    public var updatedAt: Date
    
    public init(
        id: NoteID,
        title: String,
        preview: String,
        folderID: FolderID? = nil,
        isPinned: Bool = false,
        isLocked: Bool = false,
        isDeleted: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.preview = preview
        self.folderID = folderID
        self.isPinned = isPinned
        self.isLocked = isLocked
        self.isDeleted = isDeleted
        self.updatedAt = updatedAt
    }
}
