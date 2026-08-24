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
            SELECT id, name, protocol_kind, start_date, end_date, doctrine, signed_at, device_id,
                   completed_at, final_stats_json, passport_pdf_path
            FROM ghost_seasons
            WHERE completed_at IS NULL
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

    /// Fetch all seasons (active + completed) ordered by sign date descending.
    public func fetchAllSeasons() throws -> [GhostSeason] {
        try database.read { db in
            let sql = """
            SELECT id, name, protocol_kind, start_date, end_date, doctrine, signed_at, device_id,
                   completed_at, final_stats_json, passport_pdf_path
            FROM ghost_seasons
            ORDER BY signed_at DESC;
            """

            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }

            var seasons: [GhostSeason] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                if let s = extractSeason(from: statement) { seasons.append(s) }
            }
            return seasons
        }
    }

    /// Mark a season as completed and freeze final stats snapshot.
    public func completeSeason(_ season: GhostSeason) throws {
        try database.write { db in
            let statsJSON: String?
            if let stats = season.finalStats,
               let data = try? JSONEncoder().encode(stats),
               let str  = String(data: data, encoding: .utf8) {
                statsJSON = str
            } else {
                statsJSON = nil
            }

            let sql = """
            UPDATE ghost_seasons
            SET completed_at = ?, final_stats_json = ?, passport_pdf_path = ?
            WHERE id = ?;
            """
            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }

            let completedTime = season.completedAt?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
            SQLiteHelper.bind(double: completedTime,          at: 1, statement: statement)
            SQLiteHelper.bind(text:   statsJSON,              at: 2, statement: statement)
            SQLiteHelper.bind(text:   season.passportPDFPath, at: 3, statement: statement)
            SQLiteHelper.bind(text:   season.id,              at: 4, statement: statement)

            if sqlite3_step(statement) != SQLITE_DONE {
                let msg = String(cString: sqlite3_errmsg(db))
                throw NotesError.persistenceFailure("Failed to complete ghost season: \(msg)")
            }
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

    public func deleteReceipts(dayID: String, ruleID: String) throws {
        try database.write { db in
            let sql = "DELETE FROM ghost_receipts WHERE day_id = ? AND rule_id = ?;"
            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }

            SQLiteHelper.bind(text: dayID, at: 1, statement: statement)
            SQLiteHelper.bind(text: ruleID, at: 2, statement: statement)
            _ = sqlite3_step(statement)
        }
    }

    // MARK: - Custom Rules CRUD (Migration v6)

    public func saveCustomRule(_ rule: GhostProtocolRule, seasonID: String) throws {
        try database.write { db in
            let sql = """
            INSERT OR REPLACE INTO ghost_custom_rules (
                id, season_id, title, subtitle, ring, phase, proof_kind,
                target_value, unit_label, icon, is_outdoor_required,
                is_enabled, sort_order, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }

            SQLiteHelper.bind(text:   rule.id,                          at: 1,  statement: statement)
            SQLiteHelper.bind(text:   seasonID,                         at: 2,  statement: statement)
            SQLiteHelper.bind(text:   rule.title,                       at: 3,  statement: statement)
            SQLiteHelper.bind(text:   rule.subtitle,                    at: 4,  statement: statement)
            SQLiteHelper.bind(text:   rule.ring.rawValue,               at: 5,  statement: statement)
            SQLiteHelper.bind(text:   rule.phase.rawValue,              at: 6,  statement: statement)
            SQLiteHelper.bind(text:   rule.proofKind.rawValue,          at: 7,  statement: statement)
            SQLiteHelper.bind(double: rule.targetValue,                 at: 8,  statement: statement)
            SQLiteHelper.bind(text:   rule.unitLabel,                   at: 9,  statement: statement)
            SQLiteHelper.bind(text:   rule.icon,                        at: 10, statement: statement)
            SQLiteHelper.bind(int:    rule.isOutdoorRequired ? 1 : 0,   at: 11, statement: statement)
            SQLiteHelper.bind(int:    rule.isEnabled ? 1 : 0,           at: 12, statement: statement)
            SQLiteHelper.bind(int:    rule.sortOrder,                   at: 13, statement: statement)
            SQLiteHelper.bind(double: Date().timeIntervalSince1970,     at: 14, statement: statement)

            if sqlite3_step(statement) != SQLITE_DONE {
                let msg = String(cString: sqlite3_errmsg(db))
                throw NotesError.persistenceFailure("Failed to save custom rule: \(msg)")
            }
        }
    }

    public func fetchCustomRules(seasonID: String) throws -> [GhostProtocolRule] {
        try database.read { db in
            let sql = """
            SELECT id, title, subtitle, ring, phase, proof_kind,
                   target_value, unit_label, icon, is_outdoor_required,
                   is_enabled, sort_order
            FROM ghost_custom_rules
            WHERE season_id = ?
            ORDER BY sort_order ASC, rowid ASC;
            """
            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }

            SQLiteHelper.bind(text: seasonID, at: 1, statement: statement)

            var rules: [GhostProtocolRule] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                if let r = extractCustomRule(from: statement) { rules.append(r) }
            }
            return rules
        }
    }

    public func deleteCustomRule(id: String) throws {
        try database.write { db in
            let sql = "DELETE FROM ghost_custom_rules WHERE id = ?;"
            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }
            SQLiteHelper.bind(text: id, at: 1, statement: statement)
            _ = sqlite3_step(statement)
        }
    }

    public func deleteAllCustomRules(seasonID: String) throws {
        try database.write { db in
            let sql = "DELETE FROM ghost_custom_rules WHERE season_id = ?;"
            let statement = try SQLiteHelper.prepare(sql: sql, on: db)
            defer { sqlite3_finalize(statement) }
            SQLiteHelper.bind(text: seasonID, at: 1, statement: statement)
            _ = sqlite3_step(statement)
        }
    }

    // MARK: - Mappers

    private func extractSeason(from statement: OpaquePointer) -> GhostSeason? {
        let id        = SQLiteHelper.nonNullText(at: 0, statement: statement)
        let name      = SQLiteHelper.nonNullText(at: 1, statement: statement)
        let kindRaw   = SQLiteHelper.nonNullText(at: 2, statement: statement)
        let docRaw    = SQLiteHelper.nonNullText(at: 5, statement: statement)
        let startDate = Date(timeIntervalSince1970: SQLiteHelper.nonNullDouble(at: 3, statement: statement))
        let endDate   = Date(timeIntervalSince1970: SQLiteHelper.nonNullDouble(at: 4, statement: statement))
        let signedAt  = Date(timeIntervalSince1970: SQLiteHelper.nonNullDouble(at: 6, statement: statement))
        let deviceID  = SQLiteHelper.text(at: 7, statement: statement) ?? "Mac"

        // v6 lifecycle columns (indices 8, 9, 10)
        let completedAtRaw   = SQLiteHelper.double(at: 8, statement: statement)
        let finalStatsJSON   = SQLiteHelper.text(at: 9, statement: statement)
        let passportPDFPath  = SQLiteHelper.text(at: 10, statement: statement)

        let completedAt = completedAtRaw.map { Date(timeIntervalSince1970: $0) }
        let finalStats: SeasonFinalStats? = finalStatsJSON.flatMap {
            try? JSONDecoder().decode(SeasonFinalStats.self, from: Data($0.utf8))
        }

        let kind    = GhostProtocolKind(rawValue: kindRaw) ?? .the120
        let doctrine = GhostDoctrine(rawValue: docRaw) ?? .hard

        return GhostSeason(
            id: id,
            name: name,
            protocolKind: kind,
            startDate: startDate,
            endDate: endDate,
            doctrine: doctrine,
            signedAt: signedAt,
            deviceID: deviceID,
            completedAt: completedAt,
            finalStats: finalStats,
            passportPDFPath: passportPDFPath
        )
    }

    private func extractCustomRule(from statement: OpaquePointer) -> GhostProtocolRule? {
        let id          = SQLiteHelper.nonNullText(at: 0, statement: statement)
        let title       = SQLiteHelper.nonNullText(at: 1, statement: statement)
        let subtitle    = SQLiteHelper.text(at: 2, statement: statement) ?? ""
        let ringRaw     = SQLiteHelper.nonNullText(at: 3, statement: statement)
        let phaseRaw    = SQLiteHelper.nonNullText(at: 4, statement: statement)
        let proofRaw    = SQLiteHelper.nonNullText(at: 5, statement: statement)
        let targetVal   = SQLiteHelper.nonNullDouble(at: 6, statement: statement)
        let unitLabel   = SQLiteHelper.text(at: 7, statement: statement) ?? ""
        let icon        = SQLiteHelper.text(at: 8, statement: statement) ?? "star.fill"
        let isOutdoor   = SQLiteHelper.int(at: 9,  statement: statement) == 1
        let isEnabled   = SQLiteHelper.int(at: 10, statement: statement) == 1
        let sortOrder   = SQLiteHelper.int(at: 11, statement: statement)

        let ring    = GhostRing(rawValue: ringRaw)             ?? .body
        let phase   = GhostProtocolPhase(rawValue: phaseRaw)  ?? .day
        let proof   = GhostProofKind(rawValue: proofRaw)      ?? .binary

        return GhostProtocolRule(
            id: id, title: title, subtitle: subtitle,
            ring: ring, phase: phase, proofKind: proof,
            targetValue: targetVal, unitLabel: unitLabel, icon: icon,
            isOutdoorRequired: isOutdoor,
            isCustom: true, isEnabled: isEnabled, sortOrder: sortOrder
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

    // MARK: - Factory Reset Ghost Mode Data

    public func resetGhostData() throws {
        try database.write { db in
            let statements = [
                "DELETE FROM ghost_receipts;",
                "DELETE FROM ghost_days;",
                "DELETE FROM ghost_custom_rules;",
                "DELETE FROM ghost_seasons;"
            ]
            for sql in statements {
                if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
                    let msg = String(cString: sqlite3_errmsg(db))
                    throw NotesError.persistenceFailure("Failed to reset ghost data: \(msg)")
                }
            }
        }
    }
}

