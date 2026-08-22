import Foundation
import SQLite3

/// Actor managing the persistence of encrypted CRDT document states in SQLite.
public actor CRDTStore {
    
    private let database: NotesDatabase
    
    public init(database: NotesDatabase) {
        self.database = database
    }
    
    public func saveEncryptedDoc(payload: EncryptedPayload, vectorClock: CRDTVectorClock, for noteID: NoteID) throws {
        try database.write { db in
            let payloadData = try JSONEncoder().encode(payload)
            let clockData = try JSONEncoder().encode(vectorClock)
            let clockJSON = String(data: clockData, encoding: .utf8) ?? "{}"
            let now = Date().timeIntervalSince1970
            
            let sql = """
            INSERT OR REPLACE INTO crdt_states (note_id, encrypted_doc_data, vector_clock_json, updated_at)
            VALUES (?, ?, ?, ?);
            """
            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }
            
            SQLiteHelper.bind(text: noteID.raw.uuidString, at: 1, statement: statement)
            payloadData.withUnsafeBytes { rawBuffer in
                sqlite3_bind_blob(statement, 2, rawBuffer.baseAddress, Int32(payloadData.count), nil)
            }
            SQLiteHelper.bind(text: clockJSON, at: 3, statement: statement)
            SQLiteHelper.bind(double: now, at: 4, statement: statement)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                throw NotesError.persistenceFailure("Failed to persist CRDT state: \(errorMsg)")
            }
        }
    }
    
    public func loadEncryptedDoc(for noteID: NoteID) throws -> (payload: EncryptedPayload, vectorClock: CRDTVectorClock)? {
        try database.read { db in
            let sql = "SELECT encrypted_doc_data, vector_clock_json FROM crdt_states WHERE note_id = ? LIMIT 1;"
            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }
            
            SQLiteHelper.bind(text: noteID.raw.uuidString, at: 1, statement: statement)
            if sqlite3_step(statement) == SQLITE_ROW {
                guard let blobPointer = sqlite3_column_blob(statement, 0) else { return nil }
                let blobLength = Int(sqlite3_column_bytes(statement, 0))
                let blobData = Data(bytes: blobPointer, count: blobLength)
                let clockJSON = SQLiteHelper.nonNullText(at: 1, statement: statement)
                
                guard let payload = try? JSONDecoder().decode(EncryptedPayload.self, from: blobData),
                      let clockData = clockJSON.data(using: .utf8),
                      let clock = try? JSONDecoder().decode(CRDTVectorClock.self, from: clockData) else {
                    return nil
                }
                return (payload, clock)
            }
            return nil
        }
    }
    
    public func deleteDoc(for noteID: NoteID) throws {
        try database.write { db in
            let sql = "DELETE FROM crdt_states WHERE note_id = ?;"
            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }
            
            SQLiteHelper.bind(text: noteID.raw.uuidString, at: 1, statement: statement)
            sqlite3_step(statement)
        }
    }
}
