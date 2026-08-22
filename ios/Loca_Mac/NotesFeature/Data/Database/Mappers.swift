import Foundation

/// Bidirectional, type-safe mappers bridging SQLite rows and clean Domain entities.
public enum NotesMappers {
    
    // MARK: - Note <-> NoteRow
    
    public static func note(from row: NoteRow) -> Note {
        let noteID = NoteID(raw: UUID(uuidString: row.id) ?? UUID())
        let folderID = row.folderID.flatMap { UUID(uuidString: $0) }.map { FolderID(raw: $0) }
        
        let content: NoteContent
        if let data = row.contentJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(NoteContent.self, from: data) {
            content = decoded
        } else {
            content = .empty
        }
        
        return Note(
            id: noteID,
            folderID: folderID,
            title: row.title,
            content: content,
            plainTextCache: row.plainTextCache,
            preview: row.preview,
            isPinned: row.isPinned != 0,
            isLocked: row.isLocked != 0,
            isDeleted: row.isDeleted != 0,
            createdAt: Date(timeIntervalSince1970: row.createdAt),
            updatedAt: Date(timeIntervalSince1970: row.updatedAt),
            deletedAt: row.deletedAt.map { Date(timeIntervalSince1970: $0) },
            sortKey: row.sortKey,
            schemaVersion: row.schemaVersion,
            clientUpdatedAt: Date(timeIntervalSince1970: row.clientUpdatedAt),
            deviceID: row.deviceID
        )
    }
    
    public static func noteRow(from note: Note) -> NoteRow {
        let contentJSON: String
        if let data = try? JSONEncoder().encode(note.content),
           let string = String(data: data, encoding: .utf8) {
            contentJSON = string
        } else {
            contentJSON = "{\"version\":1,\"blocks\":[]}"
        }
        
        return NoteRow(
            id: note.id.raw.uuidString,
            folderID: note.folderID?.raw.uuidString,
            title: note.title,
            contentJSON: contentJSON,
            plainTextCache: note.plainTextCache,
            preview: note.preview,
            isPinned: note.isPinned ? 1 : 0,
            isLocked: note.isLocked ? 1 : 0,
            isDeleted: note.isDeleted ? 1 : 0,
            createdAt: note.createdAt.timeIntervalSince1970,
            updatedAt: note.updatedAt.timeIntervalSince1970,
            deletedAt: note.deletedAt?.timeIntervalSince1970,
            sortKey: note.sortKey,
            schemaVersion: note.schemaVersion,
            clientUpdatedAt: note.clientUpdatedAt.timeIntervalSince1970,
            deviceID: note.deviceID
        )
    }
    
    public static func summary(from row: NoteRow) -> NoteSummary {
        NoteSummary(
            id: NoteID(raw: UUID(uuidString: row.id) ?? UUID()),
            title: row.title,
            preview: row.preview,
            folderID: row.folderID.flatMap { UUID(uuidString: $0) }.map { FolderID(raw: $0) },
            isPinned: row.isPinned != 0,
            isLocked: row.isLocked != 0,
            isDeleted: row.isDeleted != 0,
            updatedAt: Date(timeIntervalSince1970: row.updatedAt)
        )
    }
    
    // MARK: - Folder <-> FolderRow
    
    public static func folder(from row: FolderRow) -> Folder {
        Folder(
            id: FolderID(raw: UUID(uuidString: row.id) ?? UUID()),
            name: row.name,
            parentID: row.parentID.flatMap { UUID(uuidString: $0) }.map { FolderID(raw: $0) },
            createdAt: Date(timeIntervalSince1970: row.createdAt),
            updatedAt: Date(timeIntervalSince1970: row.updatedAt)
        )
    }
    
    public static func folderRow(from folder: Folder) -> FolderRow {
        FolderRow(
            id: folder.id.raw.uuidString,
            name: folder.name,
            parentID: folder.parentID?.raw.uuidString,
            createdAt: folder.createdAt.timeIntervalSince1970,
            updatedAt: folder.updatedAt.timeIntervalSince1970
        )
    }
    
    // MARK: - Tag <-> TagRow
    
    public static func tag(from row: TagRow) -> Tag {
        Tag(
            id: TagID(raw: UUID(uuidString: row.id) ?? UUID()),
            name: row.name,
            createdAt: Date(timeIntervalSince1970: row.createdAt)
        )
    }
    
    public static func tagRow(from tag: Tag) -> TagRow {
        TagRow(
            id: tag.id.raw.uuidString,
            name: tag.name,
            createdAt: tag.createdAt.timeIntervalSince1970
        )
    }
    
    // MARK: - Attachment <-> AttachmentRow
    
    public static func attachment(from row: AttachmentRow) -> Attachment {
        Attachment(
            id: AttachmentID(raw: UUID(uuidString: row.id) ?? UUID()),
            noteID: NoteID(raw: UUID(uuidString: row.noteID) ?? UUID()),
            kind: AttachmentKind(rawValue: row.kind) ?? .other,
            filePath: row.filePath,
            createdAt: Date(timeIntervalSince1970: row.createdAt),
            metadataJSON: row.metadataJSON
        )
    }
    
    public static func attachmentRow(from attachment: Attachment) -> AttachmentRow {
        AttachmentRow(
            id: attachment.id.raw.uuidString,
            noteID: attachment.noteID.raw.uuidString,
            kind: attachment.kind.rawValue,
            filePath: attachment.filePath,
            createdAt: attachment.createdAt.timeIntervalSince1970,
            metadataJSON: attachment.metadataJSON
        )
    }
}
