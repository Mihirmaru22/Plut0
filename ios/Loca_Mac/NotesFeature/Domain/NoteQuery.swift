import Foundation

/// Expressive specification for fetching or observing filtered notes.
public struct NoteQuery: Hashable, Codable, Sendable {
    public var folderID: FolderID?
    public var includeDeleted: Bool
    public var searchText: String?
    public var tagIDs: [TagID]
    public var sortOrder: NoteSortOrder
    public var limit: Int?
    
    public init(
        folderID: FolderID? = nil,
        includeDeleted: Bool = false,
        searchText: String? = nil,
        tagIDs: [TagID] = [],
        sortOrder: NoteSortOrder = .updatedAtDescending,
        limit: Int? = nil
    ) {
        self.folderID = folderID
        self.includeDeleted = includeDeleted
        self.searchText = searchText
        self.tagIDs = tagIDs
        self.sortOrder = sortOrder
        self.limit = limit
    }
    
    /// Default query for all active (non-deleted) notes.
    public static var all: NoteQuery {
        NoteQuery(
            folderID: nil,
            includeDeleted: false,
            searchText: nil,
            tagIDs: [],
            sortOrder: .updatedAtDescending,
            limit: nil
        )
    }
    
    /// Query targeting the Recently Deleted bin.
    public static var recentlyDeleted: NoteQuery {
        NoteQuery(
            folderID: nil,
            includeDeleted: true,
            searchText: nil,
            tagIDs: [],
            sortOrder: .updatedAtDescending,
            limit: nil
        )
    }
}
