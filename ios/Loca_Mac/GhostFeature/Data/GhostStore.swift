import Foundation
import SQLite3

/// Actor handling SQLite persistence for Ghost Mode seasons, days, and streaks.
public actor GhostStore {
    public static let shared = GhostStore()

    private var dbPointer: OpaquePointer? {
        NotesDatabase.shared.dbPointer
    }

    private let jsonDecoder = JSONDecoder()
    private let jsonEncoder = JSONEncoder()

    public init() {}

    // MARK: - Season CRUD

    public func saveSeason(_ season: GhostSeason) throws {
        guard let db = dbPointer else {
            throw NotesError.persistenceFailure("Database pointer is null")
        }

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

    public func fetchActiveSeason() throws -> GhostSeason? {
        guard let db = dbPointer else { return nil }

        let sql = """
        SELECT id, name, protocol_kind, start_date, end_date, doctrine, signed_at, device_id
        FROM ghost_seasons
        ORDER BY signed_at DESC
        LIMIT 1;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        if sqlite3_step(statement) == SQLITE_ROW {
            return extractSeason(from: statement)
        }
        return nil
    }

    // MARK: - Day Records CRUD

    public func saveDay(_ day: GhostDay) throws {
        guard let db = dbPointer else {
            throw NotesError.persistenceFailure("Database pointer is null")
        }

        let intervalsJSON = (try? String(data: jsonEncoder.encode(day.offlineIntervals), encoding: .utf8)) ?? "[]"

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
        SQLiteHelper.bind(optionalText: day.reflectionNoteID, at: 12, statement: statement)
        SQLiteHelper.bind(double: day.createdAt.timeIntervalSince1970, at: 13, statement: statement)

        if sqlite3_step(statement) != SQLITE_DONE {
            let msg = String(cString: sqlite3_errmsg(db))
            throw NotesError.persistenceFailure("Failed to save ghost day: \(msg)")
        }
    }

    public func fetchDay(seasonID: String, dateString: String) throws -> GhostDay? {
        guard let db = dbPointer else { return nil }

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

    public func fetchAllDays(seasonID: String) throws -> [GhostDay] {
        guard let db = dbPointer else { return [] }

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

    // MARK: - Mappers

    private func extractSeason(from statement: OpaquePointer?) -> GhostSeason? {
        guard let stmt = statement else { return nil }
        guard let id = SQLiteHelper.columnText(at: 0, statement: stmt),
              let name = SQLiteHelper.columnText(at: 1, statement: stmt),
              let kindRaw = SQLiteHelper.columnText(at: 2, statement: stmt),
              let doctrineRaw = SQLiteHelper.columnText(at: 5, statement: stmt) else {
            return nil
        }

        let startDate = Date(timeIntervalSince1970: SQLiteHelper.columnDouble(at: 3, statement: stmt))
        let endDate = Date(timeIntervalSince1970: SQLiteHelper.columnDouble(at: 4, statement: stmt))
        let signedAt = Date(timeIntervalSince1970: SQLiteHelper.columnDouble(at: 6, statement: stmt))
        let deviceID = SQLiteHelper.columnText(at: 7, statement: stmt) ?? "Mac"

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

    private func extractDay(from statement: OpaquePointer?) -> GhostDay? {
        guard let stmt = statement else { return nil }
        guard let id = SQLiteHelper.columnText(at: 0, statement: stmt),
              let seasonID = SQLiteHelper.columnText(at: 1, statement: stmt),
              let dateStr = SQLiteHelper.columnText(at: 2, statement: stmt) else {
            return nil
        }

        let bodyClosed = SQLiteHelper.columnInt(at: 3, statement: stmt) == 1
        let mindClosed = SQLiteHelper.columnInt(at: 4, statement: stmt) == 1
        let silenceClosed = SQLiteHelper.columnInt(at: 5, statement: stmt) == 1
        let ghostDay = SQLiteHelper.columnInt(at: 6, statement: stmt) == 1
        let score = SQLiteHelper.columnInt(at: 7, statement: stmt)
        let verifiedMin = SQLiteHelper.columnInt(at: 8, statement: stmt)
        let attestedMin = SQLiteHelper.columnInt(at: 9, statement: stmt)
        let intervalsStr = SQLiteHelper.columnText(at: 10, statement: stmt) ?? "[]"
        let noteID = SQLiteHelper.columnText(at: 11, statement: stmt)
        let createdAt = Date(timeIntervalSince1970: SQLiteHelper.columnDouble(at: 12, statement: stmt))

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
}
