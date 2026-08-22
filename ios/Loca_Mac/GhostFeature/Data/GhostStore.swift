import Foundation
import SQLite3

/// Actor handling SQLite persistence for Ghost Mode seasons, days, and streaks.
public actor GhostStore {
    
    public static let shared: GhostStore = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let plutoDir = appSupport.appendingPathComponent("Pluto", isDirectory: true)
        try? FileManager.default.createDirectory(at: plutoDir, withIntermediateDirectories: true)
        let dbURL = plutoDir.appendingPathComponent("notes_v1.sqlite")
        
        do {
            let db = try NotesDatabase(fileURL: dbURL)
            return GhostStore(database: db)
        } catch {
            let inMemoryDB = try! NotesDatabase(fileURL: nil)
            return GhostStore(database: inMemoryDB)
        }
    }()

    private let database: NotesDatabase
    private let jsonDecoder = JSONDecoder()
    private let jsonEncoder = JSONEncoder()

    public init(database: NotesDatabase) {
        self.database = database
    }

    // MARK: - Season CRUD

    public func saveSeason(_ season: GhostSeason) throws {
        try database.write { db in
            let sql = """
            INSERT OR REPLACE INTO ghost_seasons (
                id, name, protocol_kind, start_date, end_date, doctrine, signed_at, device_id
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """

            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }

            SQLiteHelper.bind(text: season.id, at: 1, statement: statement)
            SQLiteHelper.bind(text: season.name, at: 2, statement: statement)
            SQLiteHelper.bind(text: season.protocolKind.rawValue, at: 3, statement: statement)
            SQLiteHelper.bind(double: season.startDate.timeIntervalSince1970, at: 4, statement: statement)
            SQLiteHelper.bind(double: season.endDate.timeIntervalSince1970, at: 5, statement: statement)
            SQLiteHelper.bind(text: season.doctrine.rawValue, at: 6, statement: statement)
            SQLiteHelper.bind(double: season.signedAt.timeIntervalSince1970, at: 7, statement: statement)
            SQLiteHelper.bind(text: season.deviceID, at: 8, statement: statement)

            if sqlite3_step(statement) != SQLITE_DONE {
                let msg = String(cString: sqlite3_errmsg(db))
                throw NotesError.persistenceFailure("Failed to save ghost season: \(msg)")
            }
        }
    }

    public func fetchActiveSeason() throws -> GhostSeason? {
        try database.read { db in
            let sql = """
            SELECT id, name, protocol_kind, start_date, end_date, doctrine, signed_at, device_id
            FROM ghost_seasons
            ORDER BY signed_at DESC
            LIMIT 1;
            """

            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }

            if sqlite3_step(statement) == SQLITE_ROW {
                return extractSeason(from: statement)
            }
            return nil
        }
    }

    // MARK: - Day Records CRUD

    public func saveDay(_ day: GhostDay) throws {
        try database.write { db in
            let intervalsJSON = (try? String(data: self.jsonEncoder.encode(day.offlineIntervals), encoding: .utf8)) ?? "[]"

            let sql = """
            INSERT OR REPLACE INTO ghost_days (
                id, season_id, date, body_closed, mind_closed, silence_closed,
                ghost_day, score, silence_minutes_verified, silence_minutes_attested,
                offline_intervals_json, reflection_note_id, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """

            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }

            SQLiteHelper.bind(text: day.id, at: 1, statement: statement)
            SQLiteHelper.bind(text: day.seasonID, at: 2, statement: statement)
            SQLiteHelper.bind(text: day.dateString, at: 3, statement: statement)
            SQLiteHelper.bind(int: day.bodyClosed ? 1 : 0, at: 4, statement: statement)
            SQLiteHelper.bind(int: day.mindClosed ? 1 : 0, at: 5, statement: statement)
            SQLiteHelper.bind(int: day.silenceClosed ? 1 : 0, at: 6, statement: statement)
            SQLiteHelper.bind(int: day.ghostDay ? 1 : 0, at: 7, statement: statement)
            SQLiteHelper.bind(int: day.score, at: 8, statement: statement)
            SQLiteHelper.bind(int: day.silenceMinutesVerified, at: 9, statement: statement)
            SQLiteHelper.bind(int: day.silenceMinutesAttested, at: 10, statement: statement)
            SQLiteHelper.bind(text: intervalsJSON, at: 11, statement: statement)
            SQLiteHelper.bind(text: day.reflectionNoteID, at: 12, statement: statement)
            SQLiteHelper.bind(double: day.createdAt.timeIntervalSince1970, at: 13, statement: statement)

            if sqlite3_step(statement) != SQLITE_DONE {
                let msg = String(cString: sqlite3_errmsg(db))
                throw NotesError.persistenceFailure("Failed to save ghost day: \(msg)")
            }
        }
    }

    public func fetchDay(seasonID: String, dateString: String) throws -> GhostDay? {
        try database.read { db in
            let sql = """
            SELECT id, season_id, date, body_closed, mind_closed, silence_closed,
                   ghost_day, score, silence_minutes_verified, silence_minutes_attested,
                   offline_intervals_json, reflection_note_id, created_at
            FROM ghost_days
            WHERE season_id = ? AND date = ?
            LIMIT 1;
            """

            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }

            SQLiteHelper.bind(text: seasonID, at: 1, statement: statement)
            SQLiteHelper.bind(text: dateString, at: 2, statement: statement)

            if sqlite3_step(statement) == SQLITE_ROW {
                return extractDay(from: statement)
            }
            return nil
        }
    }

    public func fetchAllDays(seasonID: String) throws -> [GhostDay] {
        try database.read { db in
            let sql = """
            SELECT id, season_id, date, body_closed, mind_closed, silence_closed,
                   ghost_day, score, silence_minutes_verified, silence_minutes_attested,
                   offline_intervals_json, reflection_note_id, created_at
            FROM ghost_days
            WHERE season_id = ?
            ORDER BY date ASC;
            """

            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }

            SQLiteHelper.bind(text: seasonID, at: 1, statement: statement)

            var days: [GhostDay] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                if let day = extractDay(from: statement) {
                    days.append(day)
                }
            }
            return days
        }
    }

    // MARK: - Receipts CRUD (Migration v5)

    public func saveReceipt(_ receipt: GhostReceipt) throws {
        try database.write { db in
            let sql = """
            INSERT OR REPLACE INTO ghost_receipts (
                id, day_id, rule_id, kind, value_real, photo_path, logged_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?);
            """

            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }

            SQLiteHelper.bind(text: receipt.id, at: 1, statement: statement)
            SQLiteHelper.bind(text: receipt.dayID, at: 2, statement: statement)
            SQLiteHelper.bind(text: receipt.ruleID, at: 3, statement: statement)
            SQLiteHelper.bind(text: receipt.kind.rawValue, at: 4, statement: statement)
            SQLiteHelper.bind(double: receipt.valueReal, at: 5, statement: statement)
            SQLiteHelper.bind(text: receipt.photoPath, at: 6, statement: statement)
            SQLiteHelper.bind(double: receipt.loggedAt.timeIntervalSince1970, at: 7, statement: statement)

            if sqlite3_step(statement) != SQLITE_DONE {
                let msg = String(cString: sqlite3_errmsg(db))
                throw NotesError.persistenceFailure("Failed to save ghost receipt: \(msg)")
            }
        }
    }

    public func fetchReceipts(dayID: String) throws -> [GhostReceipt] {
        try database.read { db in
            let sql = """
            SELECT id, day_id, rule_id, kind, value_real, photo_path, logged_at
            FROM ghost_receipts
            WHERE day_id = ?
            ORDER BY logged_at ASC;
            """

            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }

            SQLiteHelper.bind(text: dayID, at: 1, statement: statement)

            var receipts: [GhostReceipt] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                if let receipt = extractReceipt(from: statement) {
                    receipts.append(receipt)
                }
            }
            return receipts
        }
    }

    public func fetchAllReceipts(seasonID: String) throws -> [GhostReceipt] {
        try database.read { db in
            let sql = """
            SELECT r.id, r.day_id, r.rule_id, r.kind, r.value_real, r.photo_path, r.logged_at
            FROM ghost_receipts r
            INNER JOIN ghost_days d ON r.day_id = d.id
            WHERE d.season_id = ?
            ORDER BY r.logged_at ASC;
            """

            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }

            SQLiteHelper.bind(text: seasonID, at: 1, statement: statement)

            var receipts: [GhostReceipt] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                if let receipt = extractReceipt(from: statement) {
                    receipts.append(receipt)
                }
            }
            return receipts
        }
    }

    public func deleteReceipt(id: String) throws {
        try database.write { db in
            let sql = "DELETE FROM ghost_receipts WHERE id = ?;"
            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }

            SQLiteHelper.bind(text: id, at: 1, statement: statement)
            _ = sqlite3_step(statement)
        }
    }

    // MARK: - Mappers

    private func extractSeason(from statement: OpaquePointer) -> GhostSeason? {
        let id = SQLiteHelper.nonNullText(at: 0, statement: statement)
        let name = SQLiteHelper.nonNullText(at: 1, statement: statement)
        let kindRaw = SQLiteHelper.nonNullText(at: 2, statement: statement)
        let doctrineRaw = SQLiteHelper.nonNullText(at: 5, statement: statement)
        let startDate = Date(timeIntervalSince1970: SQLiteHelper.nonNullDouble(at: 3, statement: statement))
        let endDate = Date(timeIntervalSince1970: SQLiteHelper.nonNullDouble(at: 4, statement: statement))
        let signedAt = Date(timeIntervalSince1970: SQLiteHelper.nonNullDouble(at: 6, statement: statement))
        let deviceID = SQLiteHelper.text(at: 7, statement: statement) ?? "Mac"

        let kind = GhostProtocolKind(rawValue: kindRaw) ?? .the120
        let doctrine = GhostDoctrine(rawValue: doctrineRaw) ?? .hard

        return GhostSeason(
            id: id,
            name: name,
            protocolKind: kind,
            startDate: startDate,
            endDate: endDate,
            doctrine: doctrine,
            signedAt: signedAt,
            deviceID: deviceID
        )
    }

    private func extractDay(from statement: OpaquePointer) -> GhostDay? {
        let id = SQLiteHelper.nonNullText(at: 0, statement: statement)
        let seasonID = SQLiteHelper.nonNullText(at: 1, statement: statement)
        let dateStr = SQLiteHelper.nonNullText(at: 2, statement: statement)

        let bodyClosed = SQLiteHelper.int(at: 3, statement: statement) == 1
        let mindClosed = SQLiteHelper.int(at: 4, statement: statement) == 1
        let silenceClosed = SQLiteHelper.int(at: 5, statement: statement) == 1
        let ghostDay = SQLiteHelper.int(at: 6, statement: statement) == 1
        let score = SQLiteHelper.int(at: 7, statement: statement)
        let verifiedMin = SQLiteHelper.int(at: 8, statement: statement)
        let attestedMin = SQLiteHelper.int(at: 9, statement: statement)
        let intervalsStr = SQLiteHelper.text(at: 10, statement: statement) ?? "[]"
        let noteID = SQLiteHelper.text(at: 11, statement: statement)
        let createdAt = Date(timeIntervalSince1970: SQLiteHelper.nonNullDouble(at: 12, statement: statement))

        let intervals = (try? jsonDecoder.decode([GhostOfflineInterval].self, from: Data(intervalsStr.utf8))) ?? []

        return GhostDay(
            id: id,
            seasonID: seasonID,
            dateString: dateStr,
            bodyClosed: bodyClosed,
            mindClosed: mindClosed,
            silenceClosed: silenceClosed,
            ghostDay: ghostDay,
            score: score,
            silenceMinutesVerified: verifiedMin,
            silenceMinutesAttested: attestedMin,
            offlineIntervals: intervals,
            reflectionNoteID: noteID,
            createdAt: createdAt
        )
    }

    private func extractReceipt(from statement: OpaquePointer) -> GhostReceipt? {
        let id = SQLiteHelper.nonNullText(at: 0, statement: statement)
        let dayID = SQLiteHelper.nonNullText(at: 1, statement: statement)
        let ruleID = SQLiteHelper.nonNullText(at: 2, statement: statement)
        let kindRaw = SQLiteHelper.nonNullText(at: 3, statement: statement)
        let valueReal = SQLiteHelper.nonNullDouble(at: 4, statement: statement)
        let photoPath = SQLiteHelper.text(at: 5, statement: statement)
        let loggedAt = Date(timeIntervalSince1970: SQLiteHelper.nonNullDouble(at: 6, statement: statement))

        let kind = GhostProofKind(rawValue: kindRaw) ?? .binary

        return GhostReceipt(
            id: id,
            dayID: dayID,
            ruleID: ruleID,
            kind: kind,
            valueReal: valueReal,
            photoPath: photoPath,
            loggedAt: loggedAt
        )
    }
}
