import Foundation
import SQLite3

/// Actor-isolated local persistence engine executing asynchronous queries against SQLite.
public actor LocalNotesStore {
    
    private let database: NotesDatabase
    
    public init(database: NotesDatabase) {
        self.database = database
    }
    
    // MARK: - Search Term Sanitizer
    
    /// Sanitizes terms for SQLite LIKE clauses escaping `\`, `%`, and `_`.
    public static func sanitizeForLike(_ term: String) -> String {
        var escaped = ""
        for char in term {
            if char == "\\" || char == "%" || char == "_" {
                escaped.append("\\")
            }
            escaped.append(char)
        }
        return escaped
    }
    
    // MARK: - Notes Queries
    
    public func fetchNoteRows(matching query: NoteQuery) throws -> [NoteRow] {
        try database.read { db in
            var conditions: [String] = []
            var bindings: [(index: Int32, value: Any)] = []
            var bindIndex: Int32 = 1
            
            // Soft delete condition
            if query.includeDeleted {
                conditions.append("is_deleted = 1")
            } else {
                conditions.append("is_deleted = 0")
            }
            
            // Folder condition
            if let folderID = query.folderID {
                conditions.append("folder_id = ?")
                bindings.append((bindIndex, folderID.raw.uuidString))
                bindIndex += 1
            }
            
            // Search condition with ESCAPE clause
            if let search = query.searchText, !search.trimmingCharacters(in: .whitespaces).isEmpty {
                conditions.append("(title LIKE ? ESCAPE '\\' OR plain_text_cache LIKE ? ESCAPE '\\')")
                let sanitized = LocalNotesStore.sanitizeForLike(search)
                let pattern = "%\(sanitized)%"
                bindings.append((bindIndex, pattern))
                bindIndex += 1
                bindings.append((bindIndex, pattern))
                bindIndex += 1
            }
            
            // Tags condition
            if !query.tagIDs.isEmpty {
                let tagPlaceholders = Array(repeating: "?", count: query.tagIDs.count).joined(separator: ", ")
                conditions.append("id IN (SELECT note_id FROM note_tags WHERE tag_id IN (\(tagPlaceholders)))")
                for tagID in query.tagIDs {
                    bindings.append((bindIndex, tagID.raw.uuidString))
                    bindIndex += 1
                }
            }
            
            let whereClause = conditions.isEmpty ? "" : "WHERE " + conditions.joined(separator: " AND ")
            
            // Order by clause
            var orderClause = "ORDER BY is_pinned DESC, "
            switch query.sortOrder {
            case .updatedAtDescending:
                orderClause += "updated_at DESC"
            case .createdAtDescending:
                orderClause += "created_at DESC"
            case .titleAscending:
                orderClause += "title COLLATE NOCASE ASC"
            case .manual:
                orderClause += "sort_key ASC"
            }
            
            var limitClause = ""
            if let limit = query.limit {
                limitClause = "LIMIT \(limit)"
            }
            
            let sql = "SELECT id, folder_id, title, content_json, plain_text_cache, preview, is_pinned, is_locked, is_deleted, is_private, created_at, updated_at, deleted_at, sort_key, schema_version, client_updated_at, device_id FROM notes \(whereClause) \(orderClause) \(limitClause);"
            
            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }
            
            for b in bindings {
                if let str = b.value as? String {
                    SQLiteHelper.bind(text: str, at: b.index, statement: statement)
                } else if let int = b.value as? Int {
                    SQLiteHelper.bind(int: int, at: b.index, statement: statement)
                }
            }
            
            var rows: [NoteRow] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                rows.append(readFullNoteRow(from: statement))
            }
            return rows
        }
    }
    
    public func fetchNoteSummaries(matching query: NoteQuery) throws -> [NoteSummary] {
        try database.read { db in
            var conditions: [String] = []
            var bindings: [(index: Int32, value: Any)] = []
            var bindIndex: Int32 = 1
            
            if query.includeDeleted {
                conditions.append("is_deleted = 1")
            } else {
                conditions.append("is_deleted = 0")
            }
            
            if let folderID = query.folderID {
                conditions.append("folder_id = ?")
                bindings.append((bindIndex, folderID.raw.uuidString))
                bindIndex += 1
            }
            
            if let search = query.searchText, !search.trimmingCharacters(in: .whitespaces).isEmpty {
                conditions.append("(title LIKE ? ESCAPE '\\' OR plain_text_cache LIKE ? ESCAPE '\\')")
                let sanitized = LocalNotesStore.sanitizeForLike(search)
                let pattern = "%\(sanitized)%"
                bindings.append((bindIndex, pattern))
                bindIndex += 1
                bindings.append((bindIndex, pattern))
                bindIndex += 1
            }
            
            if !query.tagIDs.isEmpty {
                let tagPlaceholders = Array(repeating: "?", count: query.tagIDs.count).joined(separator: ", ")
                conditions.append("id IN (SELECT note_id FROM note_tags WHERE tag_id IN (\(tagPlaceholders)))")
                for tagID in query.tagIDs {
                    bindings.append((bindIndex, tagID.raw.uuidString))
                    bindIndex += 1
                }
            }
            
            let whereClause = conditions.isEmpty ? "" : "WHERE " + conditions.joined(separator: " AND ")
            
            var orderClause = "ORDER BY is_pinned DESC, "
            switch query.sortOrder {
            case .updatedAtDescending:
                orderClause += "updated_at DESC"
            case .createdAtDescending:
                orderClause += "created_at DESC"
            case .titleAscending:
                orderClause += "title COLLATE NOCASE ASC"
            case .manual:
                orderClause += "sort_key ASC"
            }
            
            var limitClause = ""
            if let limit = query.limit {
                limitClause = "LIMIT \(limit)"
            }
            
            let sql = "SELECT id, folder_id, title, preview, is_pinned, is_locked, is_deleted, is_private, updated_at FROM notes \(whereClause) \(orderClause) \(limitClause);"
            
            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }
            
            for b in bindings {
                if let str = b.value as? String {
                    SQLiteHelper.bind(text: str, at: b.index, statement: statement)
                } else if let int = b.value as? Int {
                    SQLiteHelper.bind(int: int, at: b.index, statement: statement)
                }
            }
            
            var summaries: [NoteSummary] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                let idStr = SQLiteHelper.nonNullText(at: 0, statement: statement)
                let folderIDStr = SQLiteHelper.text(at: 1, statement: statement)
                let title = SQLiteHelper.nonNullText(at: 2, statement: statement)
                let preview = SQLiteHelper.nonNullText(at: 3, statement: statement)
                let isPinned = SQLiteHelper.int(at: 4, statement: statement) != 0
                let isLocked = SQLiteHelper.int(at: 5, statement: statement) != 0
                let isDeleted = SQLiteHelper.int(at: 6, statement: statement) != 0
                let isPrivate = SQLiteHelper.int(at: 7, statement: statement) != 0
                let updatedAt = Date(timeIntervalSince1970: SQLiteHelper.nonNullDouble(at: 8, statement: statement))
                
                summaries.append(
                    NoteSummary(
                        id: NoteID(raw: UUID(uuidString: idStr) ?? UUID()),
                        title: title,
                        preview: preview,
                        folderID: folderIDStr.flatMap { UUID(uuidString: $0) }.map { FolderID(raw: $0) },
                        isPinned: isPinned,
                        isLocked: isLocked,
                        isDeleted: isDeleted,
                        isPrivate: isPrivate,
                        updatedAt: updatedAt
                    )
                )
            }
            return summaries
        }
    }
    
    public func fetchNoteRow(id: String) throws -> NoteRow? {
        try database.read { db in
            try fetchNoteRow(id: id, on: db)
        }
    }
    
    public func insertNoteRow(_ row: NoteRow) throws {
        try database.write { db in
            try insertNoteRow(row, on: db)
        }
    }
    
    public func updateNoteRow(_ row: NoteRow) throws {
        try database.write { db in
            try updateNoteRow(row, on: db)
        }
    }
    
    public func deleteNoteRow(id: String) throws {
        try database.write { db in
            try deleteNoteRow(id: id, on: db)
        }
    }
    
    // MARK: - Batch Mutations Execution (Single Atomic Transaction)
    
    public func applyBatchMutations(_ mutations: [NoteMutation]) throws -> [NotesEvent] {
        try database.write { db in
            var events: [NotesEvent] = []
            for mutation in mutations {
                let event = try applyMutation(mutation, on: db)
                events.append(event)
            }
            return events
        }
    }
    
    private func applyMutation(_ mutation: NoteMutation, on db: OpaquePointer) throws -> NotesEvent {
        switch mutation {
        case .createNote(let noteID, let folderID):
            let now = Date()
            let content = NoteContent.empty
            let plainText = NoteTextExtractor.plainText(from: content)
            let preview = NotePreviewGenerator.preview(from: plainText)
            
            let note = Note(
                id: noteID,
                folderID: folderID,
                title: "",
                content: content,
                plainTextCache: plainText,
                preview: preview,
                isPinned: false,
                isLocked: false,
                isDeleted: false,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil,
                sortKey: String(format: "%014.3f", now.timeIntervalSince1970),
                schemaVersion: 1,
                clientUpdatedAt: now,
                deviceID: "local-device"
            )
            let row = NotesMappers.noteRow(from: note)
            try insertNoteRow(row, on: db)
            return .noteCreated(noteID)
            
        case .setTitle(let noteID, let title):
            guard var row = try fetchNoteRow(id: noteID.raw.uuidString, on: db) else {
                throw NotesError.noteNotFound(noteID)
            }
            let now = Date().timeIntervalSince1970
            row.title = title
            row.updatedAt = now
            row.clientUpdatedAt = now
            try updateNoteRow(row, on: db)
            return .noteUpdated(noteID)
            
        case .updateContent(let noteID, let content):
            guard var row = try fetchNoteRow(id: noteID.raw.uuidString, on: db) else {
                throw NotesError.noteNotFound(noteID)
            }
            let now = Date().timeIntervalSince1970
            let plainText = NoteTextExtractor.plainText(from: content)
            let derivedTitle = NotePreviewGenerator.deriveTitle(from: content)
            let preview = NotePreviewGenerator.derivePreview(from: content)
            
            var note = NotesMappers.note(from: row)
            note.title = derivedTitle
            note.content = content
            note.plainTextCache = plainText
            note.preview = preview
            
            let updatedRow = NotesMappers.noteRow(from: note)
            row.title = derivedTitle
            row.contentJSON = updatedRow.contentJSON
            row.plainTextCache = plainText
            row.preview = preview
            row.updatedAt = now
            row.clientUpdatedAt = now
            try updateNoteRow(row, on: db)
            return .noteUpdated(noteID)
            
        case .move(let noteID, let folderID):
            guard var row = try fetchNoteRow(id: noteID.raw.uuidString, on: db) else {
                throw NotesError.noteNotFound(noteID)
            }
            let now = Date().timeIntervalSince1970
            row.folderID = folderID?.raw.uuidString
            row.updatedAt = now
            row.clientUpdatedAt = now
            try updateNoteRow(row, on: db)
            return .noteMoved(noteID)
            
        case .setPinned(let noteID, let isPinned):
            guard var row = try fetchNoteRow(id: noteID.raw.uuidString, on: db) else {
                throw NotesError.noteNotFound(noteID)
            }
            let now = Date().timeIntervalSince1970
            row.isPinned = isPinned ? 1 : 0
            row.updatedAt = now
            row.clientUpdatedAt = now
            try updateNoteRow(row, on: db)
            return .notePinned(noteID)
            
        case .setLocked(let noteID, let isLocked):
            guard var row = try fetchNoteRow(id: noteID.raw.uuidString, on: db) else {
                throw NotesError.noteNotFound(noteID)
            }
            let now = Date().timeIntervalSince1970
            row.isLocked = isLocked ? 1 : 0
            row.updatedAt = now
            row.clientUpdatedAt = now
            try updateNoteRow(row, on: db)
            return .noteUpdated(noteID)
            
        case .setPrivate(let noteID, let isPrivate):
            guard var row = try fetchNoteRow(id: noteID.raw.uuidString, on: db) else {
                throw NotesError.noteNotFound(noteID)
            }
            let now = Date().timeIntervalSince1970
            row.isPrivate = isPrivate ? 1 : 0
            row.updatedAt = now
            row.clientUpdatedAt = now
            try updateNoteRow(row, on: db)
            return .noteUpdated(noteID)
            
        case .markDeleted(let noteID):
            guard var row = try fetchNoteRow(id: noteID.raw.uuidString, on: db) else {
                throw NotesError.noteNotFound(noteID)
            }
            let now = Date().timeIntervalSince1970
            row.isDeleted = 1
            row.deletedAt = now
            row.updatedAt = now
            row.clientUpdatedAt = now
            try updateNoteRow(row, on: db)
            return .noteDeleted(noteID)
            
        case .restore(let noteID):
            guard var row = try fetchNoteRow(id: noteID.raw.uuidString, on: db) else {
                throw NotesError.noteNotFound(noteID)
            }
            let now = Date().timeIntervalSince1970
            row.isDeleted = 0
            row.deletedAt = nil
            row.updatedAt = now
            row.clientUpdatedAt = now
            try updateNoteRow(row, on: db)
            return .noteRestored(noteID)
            
        case .permanentlyDelete(let noteID):
            try deleteNoteRow(id: noteID.raw.uuidString, on: db)
            return .notePermanentlyDeleted(noteID)
            
        case .toggleChecklistItem(let noteID, let blockID):
            guard let row = try fetchNoteRow(id: noteID.raw.uuidString, on: db) else {
                throw NotesError.noteNotFound(noteID)
            }
            var note = NotesMappers.note(from: row)
            var mutatedBlocks = note.content.blocks
            var didMutate = false
            for (idx, block) in mutatedBlocks.enumerated() {
                if case .checklistItem(var item) = block, item.id == blockID {
                    item.isChecked.toggle()
                    mutatedBlocks[idx] = .checklistItem(item)
                    didMutate = true
                    break
                }
            }
            if didMutate {
                let now = Date()
                let newContent = NoteContent(version: note.content.version, blocks: mutatedBlocks)
                let plainText = NoteTextExtractor.plainText(from: newContent)
                let preview = NotePreviewGenerator.preview(from: plainText)
                
                note.content = newContent
                note.plainTextCache = plainText
                note.preview = preview
                note.updatedAt = now
                note.clientUpdatedAt = now
                
                let updatedRow = NotesMappers.noteRow(from: note)
                try updateNoteRow(updatedRow, on: db)
            }
            return .noteUpdated(noteID)
            
        case .materializeFromSync(let noteID, let title, let content, let plainTextCache, let preview):
            let now = Date().timeIntervalSince1970
            if var row = try fetchNoteRow(id: noteID.raw.uuidString, on: db) {
                row.title = title
                let dummyNote = Note(
                    id: noteID,
                    folderID: nil,
                    title: title,
                    content: content,
                    plainTextCache: plainTextCache,
                    preview: preview,
                    isPinned: false,
                    isLocked: false,
                    isDeleted: false,
                    createdAt: Date(),
                    updatedAt: Date(),
                    deletedAt: nil,
                    sortKey: "",
                    schemaVersion: 1,
                    clientUpdatedAt: Date(),
                    deviceID: ""
                )
                let noteRow = NotesMappers.noteRow(from: dummyNote)
                row.contentJSON = noteRow.contentJSON
                row.plainTextCache = plainTextCache
                row.preview = preview
                row.updatedAt = now
                row.clientUpdatedAt = now
                try updateNoteRow(row, on: db)
                return .noteUpdated(noteID)
            } else {
                let note = Note(
                    id: noteID,
                    folderID: nil,
                    title: title,
                    content: content,
                    plainTextCache: plainTextCache,
                    preview: preview,
                    isPinned: false,
                    isLocked: false,
                    isDeleted: false,
                    createdAt: Date(timeIntervalSince1970: now),
                    updatedAt: Date(timeIntervalSince1970: now),
                    deletedAt: nil,
                    sortKey: FractionalIndex.initial,
                    schemaVersion: 1,
                    clientUpdatedAt: Date(timeIntervalSince1970: now),
                    deviceID: "sync-device"
                )
                let row = NotesMappers.noteRow(from: note)
                try insertNoteRow(row, on: db)
                return .noteCreated(noteID)
            }
        }
    }
    
    // MARK: - Direct Row Operations on DB Pointer
    
    private func fetchNoteRow(id: String, on db: OpaquePointer) throws -> NoteRow? {
        let sql = "SELECT id, folder_id, title, content_json, plain_text_cache, preview, is_pinned, is_locked, is_deleted, is_private, created_at, updated_at, deleted_at, sort_key, schema_version, client_updated_at, device_id FROM notes WHERE id = ? LIMIT 1;"
        let statement = try SQLiteHelper.prepare(sql: sql, on: db)
        defer { sqlite3_finalize(statement) }
        
        SQLiteHelper.bind(text: id, at: 1, statement: statement)
        if sqlite3_step(statement) == SQLITE_ROW {
            return readFullNoteRow(from: statement)
        }
        return nil
    }
    
    private func insertNoteRow(_ row: NoteRow, on db: OpaquePointer) throws {
        let sql = """
        INSERT INTO notes (id, folder_id, title, content_json, plain_text_cache, preview, is_pinned, is_locked, is_deleted, is_private, created_at, updated_at, deleted_at, sort_key, schema_version, client_updated_at, device_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        let statement = try SQLiteHelper.prepare(sql: sql, on: db)
        defer { sqlite3_finalize(statement) }
        
        bindFullNoteRow(row, statement: statement)
        if sqlite3_step(statement) != SQLITE_DONE {
            let msg = String(cString: sqlite3_errmsg(db))
            throw NotesError.persistenceFailure("Failed to insert note: \(msg)")
        }
    }
    
    private func updateNoteRow(_ row: NoteRow, on db: OpaquePointer) throws {
        let sql = """
        UPDATE notes SET folder_id = ?, title = ?, content_json = ?, plain_text_cache = ?, preview = ?, is_pinned = ?, is_locked = ?, is_deleted = ?, is_private = ?, updated_at = ?, deleted_at = ?, sort_key = ?, schema_version = ?, client_updated_at = ?, device_id = ?
        WHERE id = ?;
        """
        let statement = try SQLiteHelper.prepare(sql: sql, on: db)
        defer { sqlite3_finalize(statement) }
        
        SQLiteHelper.bind(text: row.folderID, at: 1, statement: statement)
        SQLiteHelper.bind(text: row.title, at: 2, statement: statement)
        SQLiteHelper.bind(text: row.contentJSON, at: 3, statement: statement)
        SQLiteHelper.bind(text: row.plainTextCache, at: 4, statement: statement)
        SQLiteHelper.bind(text: row.preview, at: 5, statement: statement)
        SQLiteHelper.bind(int: row.isPinned, at: 6, statement: statement)
        SQLiteHelper.bind(int: row.isLocked, at: 7, statement: statement)
        SQLiteHelper.bind(int: row.isDeleted, at: 8, statement: statement)
        SQLiteHelper.bind(int: row.isPrivate, at: 9, statement: statement)
        SQLiteHelper.bind(double: row.updatedAt, at: 10, statement: statement)
        SQLiteHelper.bind(double: row.deletedAt, at: 11, statement: statement)
        SQLiteHelper.bind(text: row.sortKey, at: 12, statement: statement)
        SQLiteHelper.bind(int: row.schemaVersion, at: 13, statement: statement)
        SQLiteHelper.bind(double: row.clientUpdatedAt, at: 14, statement: statement)
        SQLiteHelper.bind(text: row.deviceID, at: 15, statement: statement)
        SQLiteHelper.bind(text: row.id, at: 16, statement: statement)
        
        if sqlite3_step(statement) != SQLITE_DONE {
            let msg = String(cString: sqlite3_errmsg(db))
            throw NotesError.persistenceFailure("Failed to update note: \(msg)")
        }
    }
    
    private func deleteNoteRow(id: String, on db: OpaquePointer) throws {
        let sql = "DELETE FROM notes WHERE id = ?;"
        let statement = try SQLiteHelper.prepare(sql: sql, on: db)
        defer { sqlite3_finalize(statement) }
        
        SQLiteHelper.bind(text: id, at: 1, statement: statement)
        if sqlite3_step(statement) != SQLITE_DONE {
            let msg = String(cString: sqlite3_errmsg(db))
            throw NotesError.persistenceFailure("Failed to delete note: \(msg)")
        }
    }
    
    // MARK: - Folders
    
    public func fetchFolderRows() throws -> [FolderRow] {
        try database.read { db in
            let sql = "SELECT id, name, parent_id, created_at, updated_at FROM folders ORDER BY name COLLATE NOCASE ASC;"
            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }
            
            var folders: [FolderRow] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                folders.append(
                    FolderRow(
                        id: SQLiteHelper.nonNullText(at: 0, statement: statement),
                        name: SQLiteHelper.nonNullText(at: 1, statement: statement),
                        parentID: SQLiteHelper.text(at: 2, statement: statement),
                        createdAt: SQLiteHelper.nonNullDouble(at: 3, statement: statement),
                        updatedAt: SQLiteHelper.nonNullDouble(at: 4, statement: statement)
                    )
                )
            }
            return folders
        }
    }
    
    public func insertFolderRow(_ row: FolderRow) throws {
        try database.write { db in
            let sql = "INSERT INTO folders (id, name, parent_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?);"
            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }
            
            SQLiteHelper.bind(text: row.id, at: 1, statement: statement)
            SQLiteHelper.bind(text: row.name, at: 2, statement: statement)
            SQLiteHelper.bind(text: row.parentID, at: 3, statement: statement)
            SQLiteHelper.bind(double: row.createdAt, at: 4, statement: statement)
            SQLiteHelper.bind(double: row.updatedAt, at: 5, statement: statement)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                let msg = String(cString: sqlite3_errmsg(db))
                throw NotesError.persistenceFailure("Failed to insert folder: \(msg)")
            }
        }
    }
    
    public func deleteFolderRow(id: String) throws {
        try database.write { db in
            let detachSql = "UPDATE notes SET folder_id = NULL WHERE folder_id = ?;"
            let detachStmt = try SQLiteHelper.prepare(sql: detachSql, on: db)
            SQLiteHelper.bind(text: id, at: 1, statement: detachStmt)
            _ = sqlite3_step(detachStmt)
            sqlite3_finalize(detachStmt)
            
            let sql = "DELETE FROM folders WHERE id = ?;"
            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }
            
            SQLiteHelper.bind(text: id, at: 1, statement: statement)
            if sqlite3_step(statement) != SQLITE_DONE {
                let msg = String(cString: sqlite3_errmsg(db))
                throw NotesError.persistenceFailure("Failed to delete folder: \(msg)")
            }
        }
    }
    
    // MARK: - Tags
    
    public func fetchTagRows() throws -> [TagRow] {
        try database.read { db in
            let sql = "SELECT id, name, created_at FROM tags ORDER BY name COLLATE NOCASE ASC;"
            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }
            
            var tags: [TagRow] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                tags.append(
                    TagRow(
                        id: SQLiteHelper.nonNullText(at: 0, statement: statement),
                        name: SQLiteHelper.nonNullText(at: 1, statement: statement),
                        createdAt: SQLiteHelper.nonNullDouble(at: 2, statement: statement)
                    )
                )
            }
            return tags
        }
    }
    
    public func insertTagRow(_ row: TagRow) throws {
        try database.write { db in
            let sql = "INSERT INTO tags (id, name, created_at) VALUES (?, ?, ?);"
            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }
            
            SQLiteHelper.bind(text: row.id, at: 1, statement: statement)
            SQLiteHelper.bind(text: row.name, at: 2, statement: statement)
            SQLiteHelper.bind(double: row.createdAt, at: 3, statement: statement)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                let msg = String(cString: sqlite3_errmsg(db))
                throw NotesError.persistenceFailure("Failed to insert tag: \(msg)")
            }
        }
    }
    
    public func addTagToNote(tagID: String, noteID: String) throws {
        try database.write { db in
            let sql = "INSERT OR IGNORE INTO note_tags (note_id, tag_id) VALUES (?, ?);"
            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }
            
            SQLiteHelper.bind(text: noteID, at: 1, statement: statement)
            SQLiteHelper.bind(text: tagID, at: 2, statement: statement)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                let msg = String(cString: sqlite3_errmsg(db))
                throw NotesError.persistenceFailure("Failed to associate tag to note: \(msg)")
            }
        }
    }
    
    public func removeTagFromNote(tagID: String, noteID: String) throws {
        try database.write { db in
            let sql = "DELETE FROM note_tags WHERE note_id = ? AND tag_id = ?;"
            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }
            
            SQLiteHelper.bind(text: noteID, at: 1, statement: statement)
            SQLiteHelper.bind(text: tagID, at: 2, statement: statement)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                let msg = String(cString: sqlite3_errmsg(db))
                throw NotesError.persistenceFailure("Failed to remove tag from note: \(msg)")
            }
        }
    }
    
    public func fetchTagsForNote(noteID: String) throws -> [TagRow] {
        try database.read { db in
            let sql = """
            SELECT t.id, t.name, t.created_at
            FROM tags t
            INNER JOIN note_tags nt ON t.id = nt.tag_id
            WHERE nt.note_id = ?
            ORDER BY t.name COLLATE NOCASE ASC;
            """
            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }
            
            SQLiteHelper.bind(text: noteID, at: 1, statement: statement)
            
            var tags: [TagRow] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                tags.append(
                    TagRow(
                        id: SQLiteHelper.nonNullText(at: 0, statement: statement),
                        name: SQLiteHelper.nonNullText(at: 1, statement: statement),
                        createdAt: SQLiteHelper.nonNullDouble(at: 2, statement: statement)
                    )
                )
            }
            return tags
        }
    }
    
    // MARK: - Row Mapping Helpers
    
    private func readFullNoteRow(from statement: OpaquePointer) -> NoteRow {
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
            isPrivate: SQLiteHelper.int(at: 9, statement: statement),
            createdAt: SQLiteHelper.nonNullDouble(at: 10, statement: statement),
            updatedAt: SQLiteHelper.nonNullDouble(at: 11, statement: statement),
            deletedAt: SQLiteHelper.double(at: 12, statement: statement),
            sortKey: SQLiteHelper.nonNullText(at: 13, statement: statement),
            schemaVersion: SQLiteHelper.int(at: 14, statement: statement),
            clientUpdatedAt: SQLiteHelper.nonNullDouble(at: 15, statement: statement),
            deviceID: SQLiteHelper.nonNullText(at: 16, statement: statement)
        )
    }
    
    private func bindFullNoteRow(_ row: NoteRow, statement: OpaquePointer) {
        SQLiteHelper.bind(text: row.id, at: 1, statement: statement)
        SQLiteHelper.bind(text: row.folderID, at: 2, statement: statement)
        SQLiteHelper.bind(text: row.title, at: 3, statement: statement)
        SQLiteHelper.bind(text: row.contentJSON, at: 4, statement: statement)
        SQLiteHelper.bind(text: row.plainTextCache, at: 5, statement: statement)
        SQLiteHelper.bind(text: row.preview, at: 6, statement: statement)
        SQLiteHelper.bind(int: row.isPinned, at: 7, statement: statement)
        SQLiteHelper.bind(int: row.isLocked, at: 8, statement: statement)
        SQLiteHelper.bind(int: row.isDeleted, at: 9, statement: statement)
        SQLiteHelper.bind(int: row.isPrivate, at: 10, statement: statement)
        SQLiteHelper.bind(double: row.createdAt, at: 11, statement: statement)
        SQLiteHelper.bind(double: row.updatedAt, at: 12, statement: statement)
        SQLiteHelper.bind(double: row.deletedAt, at: 13, statement: statement)
        SQLiteHelper.bind(text: row.sortKey, at: 14, statement: statement)
        SQLiteHelper.bind(int: row.schemaVersion, at: 15, statement: statement)
        SQLiteHelper.bind(double: row.clientUpdatedAt, at: 16, statement: statement)
        SQLiteHelper.bind(text: row.deviceID, at: 17, statement: statement)
    }
}
