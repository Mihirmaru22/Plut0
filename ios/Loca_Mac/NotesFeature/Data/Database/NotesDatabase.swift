import Foundation
import SQLite3

/// Low-level thread-safe SQLite connection wrapper executing prepared statements and managing transactions.
public final class NotesDatabase: @unchecked Sendable {
    
    private var dbPointer: OpaquePointer?
    private let queue = DispatchQueue(label: "com.pluto.notes.database", qos: .userInitiated)
    
    public init(fileURL: URL?) throws {
        let path = fileURL?.path ?? ":memory:"
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        
        if sqlite3_open_v2(path, &db, flags, nil) != SQLITE_OK {
            let msg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Failed to open SQLite database at \(path)"
            throw NotesError.persistenceFailure(msg)
        }
        
        self.dbPointer = db
        try NotesMigrations.runMigrations(on: db)
    }
    
    deinit {
        if let db = dbPointer {
            sqlite3_close_v2(db)
        }
    }
    
    // MARK: - Synchronized Execution
    
    public func read<T>(_ block: (OpaquePointer) throws -> T) throws -> T {
        try queue.sync {
            guard let db = dbPointer else {
                throw NotesError.persistenceFailure("Database closed")
            }
            return try block(db)
        }
    }
    
    public func write<T>(_ block: (OpaquePointer) throws -> T) throws -> T {
        try queue.sync {
            guard let db = dbPointer else {
                throw NotesError.persistenceFailure("Database closed")
            }
            
            sqlite3_exec(db, "BEGIN IMMEDIATE TRANSACTION;", nil, nil, nil)
            do {
                let result = try block(db)
                sqlite3_exec(db, "COMMIT TRANSACTION;", nil, nil, nil)
                return result
            } catch {
                sqlite3_exec(db, "ROLLBACK TRANSACTION;", nil, nil, nil)
                throw error
            }
        }
    }
    
    // MARK: - In-Memory Factory
    
    public static func inMemory() throws -> NotesDatabase {
        try NotesDatabase(fileURL: nil)
    }
}

// MARK: - SQLite Statement Execution & Value Binding Helpers

public enum SQLiteHelper {
    
    public static func prepare(sql: String, on db: OpaquePointer) throws -> OpaquePointer {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            throw NotesError.persistenceFailure("Prepare SQL Failed: '\(sql)' error: \(errorMsg)")
        }
        guard let stmt = statement else {
            throw NotesError.persistenceFailure("Statement is null for SQL: '\(sql)'")
        }
        return stmt
    }
    
    public static func bind(text: String?, at index: Int32, statement: OpaquePointer) {
        if let text = text {
            sqlite3_bind_text(statement, index, (text as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }
    
    public static func bind(int: Int, at index: Int32, statement: OpaquePointer) {
        sqlite3_bind_int64(statement, index, Int64(int))
    }
    
    public static func bind(double: Double?, at index: Int32, statement: OpaquePointer) {
        if let double = double {
            sqlite3_bind_double(statement, index, double)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }
    
    public static func text(at index: Int32, statement: OpaquePointer) -> String? {
        guard let cString = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: cString)
    }
    
    public static func nonNullText(at index: Int32, statement: OpaquePointer) -> String {
        guard let cString = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: cString)
    }
    
    public static func int(at index: Int32, statement: OpaquePointer) -> Int {
        Int(sqlite3_column_int64(statement, index))
    }
    
    public static func double(at index: Int32, statement: OpaquePointer) -> Double? {
        if sqlite3_column_type(statement, index) == SQLITE_NULL {
            return nil
        }
        return sqlite3_column_double(statement, index)
    }
    
    public static func nonNullDouble(at index: Int32, statement: OpaquePointer) -> Double {
        sqlite3_column_double(statement, index)
    }
}
