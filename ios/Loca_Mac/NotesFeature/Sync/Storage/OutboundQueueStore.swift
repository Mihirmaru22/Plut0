import Foundation
import SQLite3

public struct OutboundQueueItem: Identifiable, Sendable {
    public let id: UUID
    public let messageID: UUID
    public let noteID: NoteID
    public let message: SyncMessage
    public let createdAt: Double
    public let retryCount: Int
}

/// Actor managing the SQLite offline outbound sync queue with Server-ACK retention.
public actor OutboundQueueStore {
    
    private let database: NotesDatabase
    
    public init(database: NotesDatabase) {
        self.database = database
    }
    
    public func enqueue(messageID: UUID, message: SyncMessage, for noteID: NoteID) throws {
        try database.write { db in
            let id = messageID.uuidString
            let msgData = try JSONEncoder().encode(message)
            let msgJSON = String(data: msgData, encoding: .utf8) ?? "{}"
            let now = Date().timeIntervalSince1970
            
            let sql = "INSERT OR REPLACE INTO outbound_sync_queue (id, note_id, message_json, created_at, retry_count) VALUES (?, ?, ?, ?, 0);"
            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }
            
            SQLiteHelper.bind(text: id, at: 1, statement: statement)
            SQLiteHelper.bind(text: noteID.raw.uuidString, at: 2, statement: statement)
            SQLiteHelper.bind(text: msgJSON, at: 3, statement: statement)
            SQLiteHelper.bind(double: now, at: 4, statement: statement)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                throw NotesError.persistenceFailure("Failed to enqueue sync message: \(errorMsg)")
            }
        }
    }
    
    public func fetchPending(limit: Int = 100) throws -> [OutboundQueueItem] {
        try database.read { db in
            let sql = "SELECT id, note_id, message_json, created_at, retry_count FROM outbound_sync_queue ORDER BY created_at ASC LIMIT \(limit);"
            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }
            
            var items: [OutboundQueueItem] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                let idStr = SQLiteHelper.nonNullText(at: 0, statement: statement)
                let noteIDStr = SQLiteHelper.nonNullText(at: 1, statement: statement)
                let msgJSON = SQLiteHelper.nonNullText(at: 2, statement: statement)
                let createdAt = SQLiteHelper.nonNullDouble(at: 3, statement: statement)
                let retry = SQLiteHelper.int(at: 4, statement: statement)
                
                guard let id = UUID(uuidString: idStr),
                      let noteUUID = UUID(uuidString: noteIDStr),
                      let msgData = msgJSON.data(using: .utf8),
                      let msg = try? JSONDecoder().decode(SyncMessage.self, from: msgData) else {
                    continue
                }
                
                items.append(
                    OutboundQueueItem(
                        id: id,
                        messageID: id,
                        noteID: NoteID(raw: noteUUID),
                        message: msg,
                        createdAt: createdAt,
                        retryCount: retry
                    )
                )
            }
            return items
        }
    }
    
    public func remove(messageID: UUID) throws {
        try database.write { db in
            let sql = "DELETE FROM outbound_sync_queue WHERE id = ?;"
            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }
            
            SQLiteHelper.bind(text: messageID.uuidString, at: 1, statement: statement)
            sqlite3_step(statement)
        }
    }
    
    public func count() throws -> Int {
        try database.read { db in
            let sql = "SELECT COUNT(*) FROM outbound_sync_queue;"
            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }
            
            if sqlite3_step(statement) == SQLITE_ROW {
                return SQLiteHelper.int(at: 0, statement: statement)
            }
            return 0
        }
    }
}
