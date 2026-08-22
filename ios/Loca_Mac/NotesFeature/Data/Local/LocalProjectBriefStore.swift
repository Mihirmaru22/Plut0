import Foundation
import SQLite3

/// Sovereign SQLite store actor strictly dedicated to the `project_briefs` table.
/// Ensures complete physical and logical isolation from standard user notes.
public actor LocalProjectBriefStore {
    
    private let database: NotesDatabase
    private let deviceID: String
    
    public init(database: NotesDatabase, deviceID: String = "local-brief-device") {
        self.database = database
        self.deviceID = deviceID
    }
    
    // MARK: - Core Fetch & Search
    
    public func fetchBrief(id: NoteID) throws -> Note? {
        try database.read { db in
            guard let row = try fetchBriefRow(id: id.raw.uuidString, on: db) else {
                return nil
            }
            return NotesMappers.note(from: row)
        }
    }
    
    public func searchBriefs(term: String) throws -> [NoteSummary] {
        try database.read { db in
            let sanitized = LocalNotesStore.sanitizeForLike(term)
            let sql = """
            SELECT id, NULL, '', content_json, plain_text_cache, preview, 0, 0, 0,
                   created_at, updated_at, NULL, '', schema_version, client_updated_at, device_id
            FROM project_briefs
            WHERE (plain_text_cache LIKE ? ESCAPE '\\' OR preview LIKE ? ESCAPE '\\')
            ORDER BY updated_at DESC;
            """
            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }
            
            let likePattern = "%\(sanitized)%"
            SQLiteHelper.bind(text: likePattern, at: 1, statement: statement)
            SQLiteHelper.bind(text: likePattern, at: 2, statement: statement)
            
            var summaries: [NoteSummary] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                let row = readBriefRow(from: statement)
                summaries.append(NotesMappers.noteSummary(from: row))
            }
            return summaries
        }
    }
    
    // MARK: - Mutations
    
    public func apply(_ mutation: NoteMutation) throws -> NotesEvent {
        try database.write { db in
            try applySingleMutation(mutation, on: db)
        }
    }
    
    public func apply(mutations: [NoteMutation]) throws -> [NotesEvent] {
        try database.write { db in
            var events: [NotesEvent] = []
            for mutation in mutations {
                let event = try applySingleMutation(mutation, on: db)
                events.append(event)
            }
            return events
        }
    }
    
    private func applySingleMutation(_ mutation: NoteMutation, on db: OpaquePointer) throws -> NotesEvent {
        switch mutation {
        case .createNote(let noteID, _):
            let now = Date().timeIntervalSince1970
            let content = NoteContent.empty
            let plainText = NoteTextExtractor.plainText(from: content)
            let preview = NotePreviewGenerator.derivePreview(from: content)
            
            let row = NoteRow(
                id: noteID.raw.uuidString,
                folderID: nil,
                title: "",
                contentJSON: encodeJSON(content),
                plainTextCache: plainText,
                preview: preview,
                isPinned: 0,
                isLocked: 0,
                isDeleted: 0,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil,
                sortKey: String(format: "%014.3f", now),
                schemaVersion: 1,
                clientUpdatedAt: now,
                deviceID: deviceID
            )
            try insertBriefRow(row, on: db)
            return .noteCreated(noteID)
            
        case .updateContent(let noteID, let content):
            let now = Date().timeIntervalSince1970
            let plainText = NoteTextExtractor.plainText(from: content)
            let preview = NotePreviewGenerator.derivePreview(from: content)
            let contentJSON = encodeJSON(content)
            
            if var row = try fetchBriefRow(id: noteID.raw.uuidString, on: db) {
                row.contentJSON = contentJSON
                row.plainTextCache = plainText
                row.preview = preview
                row.updatedAt = now
                row.clientUpdatedAt = now
                try updateBriefRow(row, on: db)
            } else {
                let row = NoteRow(
                    id: noteID.raw.uuidString,
                    folderID: nil,
                    title: "",
                    contentJSON: contentJSON,
                    plainTextCache: plainText,
                    preview: preview,
                    isPinned: 0,
                    isLocked: 0,
                    isDeleted: 0,
                    createdAt: now,
                    updatedAt: now,
                    deletedAt: nil,
                    sortKey: String(format: "%014.3f", now),
                    schemaVersion: 1,
                    clientUpdatedAt: now,
                    deviceID: deviceID
                )
                try insertBriefRow(row, on: db)
            }
            return .noteUpdated(noteID)
            
        case .markDeleted(let noteID):
            try deleteBriefRow(id: noteID.raw.uuidString, on: db)
            return .noteDeleted(noteID)
            
        case .permanentlyDelete(let noteID):
            try deleteBriefRow(id: noteID.raw.uuidString, on: db)
            return .noteDeleted(noteID)
            
        default:
            return .noteUpdated(mutation.noteID)
        }
    }
    
    // MARK: - Row Level CRUD
    
    private func fetchBriefRow(id: String, on db: OpaquePointer) throws -> NoteRow? {
        let sql = """
        SELECT id, NULL, '', content_json, plain_text_cache, preview, 0, 0, 0,
               created_at, updated_at, NULL, '', schema_version, client_updated_at, device_id
        FROM project_briefs
        WHERE id = ?;
        """
        let statement = try SQLiteHelper.prepare(sql: sql, on: db)
        defer { sqlite3_finalize(statement) }
        
        SQLiteHelper.bind(text: id, at: 1, statement: statement)
        if sqlite3_step(statement) == SQLITE_ROW {
            return readBriefRow(from: statement)
        }
        return nil
    }
    
    private func insertBriefRow(_ row: NoteRow, on db: OpaquePointer) throws {
        let sql = """
        INSERT OR REPLACE INTO project_briefs (
            id, content_json, plain_text_cache, preview,
            created_at, updated_at, schema_version, client_updated_at, device_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        let statement = try SQLiteHelper.prepare(sql: sql, on: db)
        defer { sqlite3_finalize(statement) }
        
        SQLiteHelper.bind(text: row.id, at: 1, statement: statement)
        SQLiteHelper.bind(text: row.contentJSON, at: 2, statement: statement)
        SQLiteHelper.bind(text: row.plainTextCache, at: 3, statement: statement)
        SQLiteHelper.bind(text: row.preview, at: 4, statement: statement)
        SQLiteHelper.bind(double: row.createdAt, at: 5, statement: statement)
        SQLiteHelper.bind(double: row.updatedAt, at: 6, statement: statement)
        SQLiteHelper.bind(int: row.schemaVersion, at: 7, statement: statement)
        SQLiteHelper.bind(double: row.clientUpdatedAt, at: 8, statement: statement)
        SQLiteHelper.bind(text: row.deviceID, at: 9, statement: statement)
        
        if sqlite3_step(statement) != SQLITE_DONE {
            let msg = String(cString: sqlite3_errmsg(db))
            throw NotesError.persistenceFailure("Failed to insert brief: \(msg)")
        }
    }
    
    private func updateBriefRow(_ row: NoteRow, on db: OpaquePointer) throws {
        let sql = """
        UPDATE project_briefs
        SET content_json = ?, plain_text_cache = ?, preview = ?,
            updated_at = ?, client_updated_at = ?
        WHERE id = ?;
        """
        let statement = try SQLiteHelper.prepare(sql: sql, on: db)
        defer { sqlite3_finalize(statement) }
        
        SQLiteHelper.bind(text: row.contentJSON, at: 1, statement: statement)
        SQLiteHelper.bind(text: row.plainTextCache, at: 2, statement: statement)
        SQLiteHelper.bind(text: row.preview, at: 3, statement: statement)
        SQLiteHelper.bind(double: row.updatedAt, at: 4, statement: statement)
        SQLiteHelper.bind(double: row.clientUpdatedAt, at: 5, statement: statement)
        SQLiteHelper.bind(text: row.id, at: 6, statement: statement)
        
        if sqlite3_step(statement) != SQLITE_DONE {
            let msg = String(cString: sqlite3_errmsg(db))
            throw NotesError.persistenceFailure("Failed to update brief: \(msg)")
        }
    }
    
    private func deleteBriefRow(id: String, on db: OpaquePointer) throws {
        let sql = "DELETE FROM project_briefs WHERE id = ?;"
        let statement = try SQLiteHelper.prepare(sql: sql, on: db)
        defer { sqlite3_finalize(statement) }
        
        SQLiteHelper.bind(text: id, at: 1, statement: statement)
        if sqlite3_step(statement) != SQLITE_DONE {
            let msg = String(cString: sqlite3_errmsg(db))
            throw NotesError.persistenceFailure("Failed to delete brief: \(msg)")
        }
    }
    
    private func readBriefRow(from statement: OpaquePointer) -> NoteRow {
        NoteRow(
            id: SQLiteHelper.nonNullText(at: 0, statement: statement),
            folderID: SQLiteHelper.text(at: 1, statement: statement),
            title: SQLiteHelper.nonNullText(at: 2, statement: statement),
            contentJSON: SQLiteHelper.nonNullText(at: 3, statement: statement),
            plainTextCache: SQLiteHelper.nonNullText(at: 4, statement: statement),
            preview: SQLiteHelper.nonNullText(at: 5, statement: statement),
            isPinned: SQLiteHelper.int(at: 6, statement: statement),
            isLocked: SQLiteHelper.int(at: 7, statement: statement),
            isDeleted: SQLiteHelper.int(at: 8, statement: statement),
            createdAt: SQLiteHelper.nonNullDouble(at: 9, statement: statement),
            updatedAt: SQLiteHelper.nonNullDouble(at: 10, statement: statement),
            deletedAt: SQLiteHelper.double(at: 11, statement: statement),
            sortKey: SQLiteHelper.nonNullText(at: 12, statement: statement),
            schemaVersion: SQLiteHelper.int(at: 13, statement: statement),
            clientUpdatedAt: SQLiteHelper.nonNullDouble(at: 14, statement: statement),
            deviceID: SQLiteHelper.nonNullText(at: 15, statement: statement)
        )
    }
    
    private func encodeJSON(_ content: NoteContent) -> String {
        (try? JSONEncoder().encode(content)).flatMap { String(data: $0, encoding: .utf8) } ?? "{\"version\":1,\"blocks\":[]}"
    }
}
