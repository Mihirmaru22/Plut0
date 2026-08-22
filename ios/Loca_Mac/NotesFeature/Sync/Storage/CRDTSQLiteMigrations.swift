import Foundation
import SQLite3

/// Migration v2 introducing offline sync queues and encrypted CRDT blob tables.
public enum CRDTSQLiteMigrations {
    
    public static func runMigrationV2(on db: OpaquePointer?) throws {
        try NotesMigrations.runMigration(version: 2, on: db) { pointer in
            let sql = """
            CREATE TABLE IF NOT EXISTS crdt_states (
                note_id TEXT PRIMARY KEY,
                encrypted_doc_data BLOB NOT NULL,
                vector_clock_json TEXT NOT NULL,
                updated_at REAL NOT NULL,
                FOREIGN KEY(note_id) REFERENCES notes(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS outbound_sync_queue (
                id TEXT PRIMARY KEY,
                note_id TEXT NOT NULL,
                message_json TEXT NOT NULL,
                created_at REAL NOT NULL,
                retry_count INTEGER NOT NULL DEFAULT 0
            );

            CREATE INDEX IF NOT EXISTS idx_outbound_queue_created ON outbound_sync_queue(created_at ASC);
            """
            try NotesMigrations.execute(sql: sql, on: pointer)
        }
    }
}
