import Foundation
import SQLite3

/// Schema migrations manager for the SQLite notes database with explicit version tracking.
public enum NotesMigrations {
    
    public static func runMigrations(on db: OpaquePointer?) throws {
        try execute(sql: "PRAGMA foreign_keys = ON;", on: db)
        try execute(sql: "PRAGMA journal_mode = WAL;", on: db)
        
        // 1. Ensure schema_migrations table exists
        let initMigrationsTable = """
        CREATE TABLE IF NOT EXISTS schema_migrations (
            version INTEGER PRIMARY KEY,
            applied_at REAL NOT NULL
        );
        """
        try execute(sql: initMigrationsTable, on: db)
        
        let applied = try appliedVersions(on: db)
        
        // 2. Migration v1: Initial Core Schema
        if !applied.contains(1) {
            try runMigrationV1(on: db)
            try recordMigration(version: 1, on: db)
        }
        
        // 3. Migration v2: CRDT States and Outbound Sync Queue
        try CRDTSQLiteMigrations.runMigrationV2(on: db)
        
        // 4. Migration v3: Project Briefs Table
        if !applied.contains(3) {
            try runMigrationV3(on: db)
            try recordMigration(version: 3, on: db)
        }
        
        // 5. Migration v4: Ghost Mode Seasons & Days (Winter Arc)
        if !applied.contains(4) {
            try runMigrationV4(on: db)
            try recordMigration(version: 4, on: db)
        }

        // 6. Migration v5: Ghost Protocol Receipts
        if !applied.contains(5) {
            try runMigrationV5(on: db)
            try recordMigration(version: 5, on: db)
        }

        // 7. Migration v6: Ghost Season Lifecycle + Custom Rules
        if !applied.contains(6) {
            try runMigrationV6(on: db)
            try recordMigration(version: 6, on: db)
        }

        // 8. Migration v7: Private Notes Barrier (Ghost Mode Privacy)
        if !applied.contains(7) {
            try runMigrationV7(on: db)
            try recordMigration(version: 7, on: db)
        }
    }
    
    // MARK: - Migration Version Gating & Inspection
    
    public static func appliedVersions(on db: OpaquePointer?) throws -> Set<Int> {
        guard let db = db else {
            throw NotesError.persistenceFailure("Database connection pointer is null")
        }
        
        let sql = "SELECT version FROM schema_migrations ORDER BY version ASC;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            return []
        }
        defer { sqlite3_finalize(statement) }
        
        var versions = Set<Int>()
        while sqlite3_step(statement) == SQLITE_ROW {
            let ver = Int(sqlite3_column_int64(statement, 0))
            versions.insert(ver)
        }
        return versions
    }
    
    public static func recordMigration(version: Int, on db: OpaquePointer?) throws {
        guard let db = db else {
            throw NotesError.persistenceFailure("Database connection pointer is null")
        }
        let sql = "INSERT OR REPLACE INTO schema_migrations (version, applied_at) VALUES (?, ?);"
        let statement = try SQLiteHelper.prepare(sql: sql, on: db)
        defer { sqlite3_finalize(statement) }
        
        SQLiteHelper.bind(int: version, at: 1, statement: statement)
        SQLiteHelper.bind(double: Date().timeIntervalSince1970, at: 2, statement: statement)
        
        if sqlite3_step(statement) != SQLITE_DONE {
            let msg = String(cString: sqlite3_errmsg(db))
            throw NotesError.migrationFailure("Failed to record migration v\(version): \(msg)")
        }
    }
    
    public static func runMigration(version: Int, on db: OpaquePointer?, migration: (OpaquePointer) throws -> Void) throws {
        guard let db = db else {
            throw NotesError.persistenceFailure("Database connection pointer is null")
        }
        let applied = try appliedVersions(on: db)
        guard !applied.contains(version) else { return }
        
        try migration(db)
        try recordMigration(version: version, on: db)
    }
    
    // MARK: - Migrations
    
    private static func runMigrationV1(on db: OpaquePointer?) throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS notes (
            id TEXT PRIMARY KEY,
            folder_id TEXT,
            title TEXT NOT NULL DEFAULT '',
            content_json TEXT NOT NULL,
            plain_text_cache TEXT NOT NULL DEFAULT '',
            preview TEXT NOT NULL DEFAULT '',
            is_pinned INTEGER NOT NULL DEFAULT 0,
            is_locked INTEGER NOT NULL DEFAULT 0,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            deleted_at REAL,
            sort_key TEXT NOT NULL,
            schema_version INTEGER NOT NULL DEFAULT 1,
            client_updated_at REAL NOT NULL,
            device_id TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS folders (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            parent_id TEXT,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );

        CREATE TABLE IF NOT EXISTS tags (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            created_at REAL NOT NULL
        );

        CREATE TABLE IF NOT EXISTS note_tags (
            note_id TEXT NOT NULL,
            tag_id TEXT NOT NULL,
            PRIMARY KEY (note_id, tag_id),
            FOREIGN KEY(note_id) REFERENCES notes(id) ON DELETE CASCADE,
            FOREIGN KEY(tag_id) REFERENCES tags(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS attachments (
            id TEXT PRIMARY KEY,
            note_id TEXT NOT NULL,
            kind TEXT NOT NULL,
            file_path TEXT NOT NULL,
            created_at REAL NOT NULL,
            metadata_json TEXT,
            FOREIGN KEY(note_id) REFERENCES notes(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_notes_folder ON notes(folder_id);
        CREATE INDEX IF NOT EXISTS idx_notes_updated ON notes(updated_at DESC);
        CREATE INDEX IF NOT EXISTS idx_notes_deleted ON notes(is_deleted);
        CREATE INDEX IF NOT EXISTS idx_notes_pinned ON notes(is_pinned);
        CREATE INDEX IF NOT EXISTS idx_notes_sort ON notes(sort_key);
        """
        
        try execute(sql: sql, on: db)
    }
    
    private static func runMigrationV3(on db: OpaquePointer?) throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS project_briefs (
            id TEXT PRIMARY KEY,
            content_json TEXT NOT NULL,
            plain_text_cache TEXT NOT NULL DEFAULT '',
            preview TEXT NOT NULL DEFAULT '',
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            schema_version INTEGER NOT NULL DEFAULT 1,
            client_updated_at REAL NOT NULL,
            device_id TEXT NOT NULL
        );
        """
        try execute(sql: sql, on: db)
    }

    private static func runMigrationV4(on db: OpaquePointer?) throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS ghost_seasons (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            protocol_kind TEXT NOT NULL,
            start_date REAL NOT NULL,
            end_date REAL NOT NULL,
            doctrine TEXT NOT NULL,
            signed_at REAL NOT NULL,
            device_id TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS ghost_days (
            id TEXT PRIMARY KEY,
            season_id TEXT NOT NULL,
            date TEXT NOT NULL,
            body_closed INTEGER NOT NULL DEFAULT 0,
            mind_closed INTEGER NOT NULL DEFAULT 0,
            silence_closed INTEGER NOT NULL DEFAULT 0,
            ghost_day INTEGER NOT NULL DEFAULT 0,
            score INTEGER NOT NULL DEFAULT 0,
            silence_minutes_verified INTEGER NOT NULL DEFAULT 0,
            silence_minutes_attested INTEGER NOT NULL DEFAULT 0,
            offline_intervals_json TEXT NOT NULL DEFAULT '[]',
            reflection_note_id TEXT,
            created_at REAL NOT NULL,
            FOREIGN KEY(season_id) REFERENCES ghost_seasons(id) ON DELETE CASCADE
        );

        CREATE UNIQUE INDEX IF NOT EXISTS idx_ghost_days_season_date ON ghost_days(season_id, date);
        CREATE INDEX IF NOT EXISTS idx_ghost_days_date ON ghost_days(date);
        """
        try execute(sql: sql, on: db)
    }

    private static func runMigrationV5(on db: OpaquePointer?) throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS ghost_receipts (
            id TEXT PRIMARY KEY,
            day_id TEXT NOT NULL,
            rule_id TEXT NOT NULL,
            kind TEXT NOT NULL,
            value_real REAL NOT NULL DEFAULT 0.0,
            photo_path TEXT,
            logged_at REAL NOT NULL,
            FOREIGN KEY(day_id) REFERENCES ghost_days(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_ghost_receipts_day_rule ON ghost_receipts(day_id, rule_id);
        CREATE INDEX IF NOT EXISTS idx_ghost_receipts_rule ON ghost_receipts(rule_id);
        """
        try execute(sql: sql, on: db)
    }

    private static func runMigrationV6(on db: OpaquePointer?) throws {
        // Add lifecycle columns to ghost_seasons (ALTER TABLE is additive-safe)
        let alterSeasons = """
        ALTER TABLE ghost_seasons ADD COLUMN completed_at REAL;
        """
        // Ignore error if column already exists (SQLite returns error on duplicate ADD COLUMN)
        _ = try? execute(sql: alterSeasons, on: db)

        let alterSeasonStats = """
        ALTER TABLE ghost_seasons ADD COLUMN final_stats_json TEXT;
        """
        _ = try? execute(sql: alterSeasonStats, on: db)

        let alterSeasonPDF = """
        ALTER TABLE ghost_seasons ADD COLUMN passport_pdf_path TEXT;
        """
        _ = try? execute(sql: alterSeasonPDF, on: db)

        // Create ghost_custom_rules table for user-defined protocol rules
        let createCustomRules = """
        CREATE TABLE IF NOT EXISTS ghost_custom_rules (
            id TEXT PRIMARY KEY,
            season_id TEXT NOT NULL,
            title TEXT NOT NULL,
            subtitle TEXT NOT NULL DEFAULT '',
            ring TEXT NOT NULL,
            phase TEXT NOT NULL,
            proof_kind TEXT NOT NULL,
            target_value REAL NOT NULL DEFAULT 1.0,
            unit_label TEXT NOT NULL DEFAULT '',
            icon TEXT NOT NULL DEFAULT 'star.fill',
            is_outdoor_required INTEGER NOT NULL DEFAULT 0,
            is_enabled INTEGER NOT NULL DEFAULT 1,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at REAL NOT NULL,
            FOREIGN KEY(season_id) REFERENCES ghost_seasons(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_ghost_custom_rules_season ON ghost_custom_rules(season_id);
        """
        try execute(sql: createCustomRules, on: db)
    }
    
    private static func runMigrationV7(on db: OpaquePointer?) throws {
        // Add is_private column to notes table (ALTER TABLE is additive-safe)
        let alterNotes = """
        ALTER TABLE notes ADD COLUMN is_private INTEGER NOT NULL DEFAULT 0;
        """
        _ = try? execute(sql: alterNotes, on: db)
    }
    
    public static func execute(sql: String, on db: OpaquePointer?) throws {
        guard let db = db else {
            throw NotesError.persistenceFailure("Database connection pointer is null")
        }
        var errorMessage: UnsafeMutablePointer<CChar>? = nil
        let result = sqlite3_exec(db, sql, nil, nil, &errorMessage)
        if result != SQLITE_OK {
            let msg = errorMessage.map { String(cString: $0) } ?? "Unknown SQLite error (code \(result))"
            sqlite3_free(errorMessage)
            throw NotesError.migrationFailure(msg)
        }
    }
}
