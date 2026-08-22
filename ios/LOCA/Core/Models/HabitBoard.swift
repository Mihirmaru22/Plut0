import SwiftData
import Foundation

// MARK: - HabitBoard

/// The primary entity representing a single tracked habit.
///
/// A `HabitBoard` owns all configuration for one habit: its name, metric kind,
/// daily target, display color, and the log history that builds its heatmap.
/// Streak counters are maintained as cached stored properties updated incrementally
/// on each `LogEntry` write, avoiding O(n) walks of the full log history on every
/// view update (Engineering Principles §5).
///
/// ## CloudKit Sync Constraints
/// - `@Attribute(.unique)` is absent throughout — CloudKit forbids uniqueness constraints.
/// - Every stored property carries a default value or is `Optional` to survive sync merges
///   from devices running a different app version.
/// - The `logs` relationship uses `.nullify` delete rule. See ADR-001.
///
/// ## Deletion
/// `modelContext.delete()` is **never** called on a `HabitBoard`. Set `archivedAt = Date()`
/// and save instead. See `archive(in:)` and ADR-001.
@Model
final class HabitBoard {

    // MARK: - Identity

    /// Stable identifier used as the join key for `LogEntry.boardID` (ADR-003).
    ///
    /// Not `@Attribute(.unique)` — CloudKit forbids uniqueness constraints.
    /// Two devices creating a board simultaneously produce two records with distinct
    /// UUIDs. This is intentional product behaviour, not a defect (post-critique notes).
    var id: UUID = UUID()

    // MARK: - Configuration

    /// The user-visible name of this habit (e.g., "Running", "Reading").
    var name: String = ""

    /// Encodes whether this board tracks a binary (0) or quantitative (1) metric.
    ///
    /// Stored as `Int` for CloudKit compatibility. Use the `metric` computed
    /// property for type-safe access via `MetricType`.
    var metricType: Int = MetricType.binary.rawValue

    /// The daily completion threshold.
    ///
    /// `nil` for binary habits — all computation sites use `effectiveTarget`,
    /// which substitutes `1.0` when this property is `nil`. For quantitative habits
    /// this is the numeric goal in `unitLabel` units (e.g., 5.0 miles).
    var targetValue: Double? = nil

    /// The unit label for quantitative habits (e.g., "mi", "mins", "cal").
    /// `nil` for binary habits.
    var unitLabel: String? = nil

    /// Index into `ColorPalette.colors` for this board's heatmap accent color.
    ///
    /// Stored as `Int` to enable O(1) `Color` construction at render time —
    /// no hex string parsing occurs in the heatmap's hot path. See ADR-002.
    var colorIndex: Int = 0

    /// If true, the habit row displays with a tinted background (10% opacity of the habit color).
    /// Defaults to false (neutral background).
    var useColorBackground: Bool = false

    /// Optional emoji displayed on the habit card (e.g., "🏃", "📚").
    /// If `nil`, a default icon is shown. Users set this via HabitFormView.
    var emoji: String? = nil

    /// Which life dimension this habit affects (for calibration feedback).
    /// Valid values: "energy", "stress", "focus", "mood". `nil` if unspecified.
    /// Used by CalibrationManager to tag explicit logs for inference model recalibration.
    var dimension: String? = nil

    /// Stores `HabitKind` as an `Int` for CloudKit compatibility.
    /// Use the `habitKind` computed property for type-safe access.
    /// Raw values are permanent — do not renumber.
    var habitKindRaw: Int = HabitKind.keystone.rawValue

    /// Preferred reminder time in HH:MM format (e.g., "06:30").
    /// `nil` if no reminder is set. Inferred from logging patterns in Phase 2.3.
    var preferredReminderTime: String? = nil

    /// Timestamp of the last weekly reflection prompt shown to the user.
    /// Used to throttle reflection prompts to once per week.
    var lastReflectionPromptTime: Date? = nil

    /// The timestamp at which this board was first created.
    var createdAt: Date = Date()

    /// When non-`nil`, this board is soft-deleted and excluded from active queries.
    ///
    /// All `@Query` predicates on active boards filter on `archivedAt == nil`.
    /// See `archive(in:)` for the canonical mutation and ADR-001 for the rationale.
    var archivedAt: Date? = nil

    /// Ghost Mode link properties (Migration v4 / Ghost Sprint)
    var ghostRuleID: String? = nil
    var ghostRingRaw: String? = nil // "body", "mind", "silence"

    // MARK: - Cached Streak Properties

    // MARK: Streak Caching
    //
    // Streaks are maintained as stored properties updated incrementally on each
    // `LogEntry` insertion via `updateStreak(using:)`. This avoids O(n_total) walks
    // of the full log history at render time.
    //
    // On a clean install these start at 0 and accumulate correctly over time.
    // After a schema migration or a CloudKit bulk import, `StreakCalculator` (Phase 2)
    // performs a single historical walk to repopulate these values, then calls
    // `resetStreakCache()` first to clear any stale state.

    /// Consecutive calendar days ending on or including today where the daily
    /// target was met. Updated incrementally by `updateStreak(using:)`.
    var currentStreak: Int = 0

    /// The longest streak ever achieved for this board.
    var longestStreak: Int = 0

    /// The most recent calendar day on which `updateStreak(using:)` recorded a
    /// completed day. `nil` means no day has ever been completed.
    var lastCheckedDate: Date? = nil

    // MARK: - Streak Cache Invalidation

    // MARK: CloudKit Streak Cache Safety (H1)
    //
    // `currentStreak`, `longestStreak`, and `lastCheckedDate` are stored properties
    // synced through CloudKit with last-write-wins semantics. This creates a known
    // data integrity risk: if two devices hold different log histories during an
    // offline period and then sync, the merged LogEntry set is correct (all records
    // survive as distinct UUIDs), but the scalar streak cache properties reflect
    // whichever device wrote last — not the merged history.
    //
    // `needsStreakRecalculation` is the invalidation hook for this scenario.
    //
    // Set to `true` by the `NSPersistentCloudKitContainerEvent` observer in
    // `LOCAApp` (via `CloudKitSyncCoordinator`, Phase 0) whenever a bulk import
    // event may have delivered LogEntry records that the incremental
    // `updateStreak(using:)` path did not process.
    //
    // Read and cleared to `false` by `StreakCalculator` (Phase 2) after it
    // completes a full historical recalculation and saves the correct values.
    //
    // If the app is killed between `resetStreakCache()` and the save of
    // recalculated values, this flag remains `true` in the persistent store.
    // On next launch, `StreakCalculator` detects the flag and re-runs
    // recalculation before the UI reads streak values.

    /// When `true`, the cached streak properties may be stale and must be
    /// recalculated from the full log history by `StreakCalculator` before display.
    ///
    /// Set to `true` by the `NSPersistentCloudKitContainerEvent` handler when a
    /// CloudKit bulk import may have changed the effective log history for this board.
    /// Cleared to `false` by `StreakCalculator` after a successful full recalculation
    /// and context save.
    ///
    /// A crash between `resetStreakCache()` and the completion save leaves this
    /// flag as `true`, ensuring recalculation is retried on next launch rather
    /// than silently displaying zeroed streaks.
    var needsStreakRecalculation: Bool = false

    // MARK: - Relationship

    /// All log entries belonging to this board.
    ///
    /// `Optional` to satisfy CloudKit sync: a `nil` relationship is treated as an
    /// empty array at all query and computation sites.
    ///
    /// Delete rule is `.nullify`: when (or if) a board is hard-deleted,
    /// associated `LogEntry` records lose their `board` back-reference but remain
    /// in the store. In practice, hard deletion never occurs — see ADR-001.
    @Relationship(deleteRule: .nullify, inverse: \LogEntry.board)
    var logs: [LogEntry]? = nil

    /// Active (non-archived) log entries for this board.
    ///
    /// Filters `logs` to include only entries where `archivedAt == nil`.
    /// Use this computed property in all UI and calculation sites to exclude
    /// soft-deleted entries from streaks, heatmaps, and progress calculations.
    /// Archived entries remain queryable via the full `logs` array for audit purposes.
    var activeLogs: [LogEntry] {
        (logs ?? []).filter { $0.archivedAt == nil }
    }

    // MARK: - Initialiser

    /// Creates a new `HabitBoard` with the given configuration.
    ///
    /// Streak cache properties (`currentStreak`, `longestStreak`, `lastCheckedDate`),
    /// `archivedAt`, and `logs` are always initialised to their zero/nil defaults
    /// and must not be set at creation time.
    ///
    /// - Parameters:
    ///   - id: Stable UUID. Defaults to a new `UUID()`.
    ///   - name: User-visible habit name.
    ///   - metricType: Raw value of `MetricType`. Use `MetricType.binary.rawValue` or
    ///                 `MetricType.quantitative.rawValue`.
    ///   - targetValue: Daily completion threshold. Pass `nil` for binary habits.
    ///   - unitLabel: Display unit for quantitative habits. Pass `nil` for binary.
    ///   - colorIndex: Index into `ColorPalette.colors`. Must be in `0 ..< ColorPalette.count`.
    ///   - createdAt: Creation timestamp. Defaults to `Date()`.
    init(
        id: UUID = UUID(),
        name: String,
        metricType: Int = MetricType.binary.rawValue,
        targetValue: Double? = nil,
        unitLabel: String? = nil,
        colorIndex: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.metricType = metricType
        self.targetValue = targetValue
        self.unitLabel = unitLabel
        self.colorIndex = colorIndex
        self.createdAt = createdAt
    }
}

// MARK: - HabitKind

extension HabitBoard {

    /// Distinguishes keystone habits (Habits pillar, full feature set) from daily
    /// routines (Journal checklist, lightweight checkbox only).
    ///
    /// Persisted as `habitKindRaw: Int` for CloudKit compatibility.
    /// Raw values are permanent — do not renumber cases across releases.
    enum HabitKind: Int, CaseIterable {
        case keystone = 0
        case daily    = 1
    }

    /// Type-safe accessor for `habitKindRaw`. Falls back to `.keystone` so any
    /// record written by an older build (before this field existed, defaulting to 0)
    /// is treated as a keystone habit — the correct default.
    var habitKind: HabitKind {
        get { HabitKind(rawValue: habitKindRaw) ?? .keystone }
        set { habitKindRaw = newValue.rawValue }
    }
}

// MARK: - MetricType

extension HabitBoard {

    /// The measurement model for a habit board.
    ///
    /// Persisted as `metricType: Int` for CloudKit compatibility.
    /// Raw values are permanent — do not renumber cases across releases.
    enum MetricType: Int, CaseIterable, Identifiable {
        /// A habit that is either done or not done each day.
        /// Log value is always `1.0`; any single entry completes the day.
        case binary = 0

        /// A habit tracked by a cumulative daily amount (miles, minutes, calories, etc.).
        /// Multiple entries per day are summed against `targetValue`.
        case quantitative = 1

        var id: Int { rawValue }

        /// Short label for `MetricTypePicker` UI (Phase 7).
        var label: String {
            switch self {
            case .binary:       return "Check-off"
            case .quantitative: return "Amount"
            }
        }
    }

    /// Type-safe accessor for the stored `metricType` integer.
    ///
    /// Falls back to `.binary` if the persisted integer has no matching case —
    /// this prevents a crash when a record from a future app version (with new
    /// metric types) syncs to an older build via CloudKit.
    var metric: MetricType {
        MetricType(rawValue: metricType) ?? .binary
    }

    /// The effective daily target used by all computation sites.
    ///
    /// Returns `targetValue` when it is positive, `1.0` when `targetValue`
    /// is `nil` (binary habit default), and `1.0` when `targetValue` is zero
    /// or negative (corrupt CloudKit record defence).
    var effectiveTarget: Double {
        let raw = targetValue ?? 1.0
        return raw > 0 ? raw : 1.0
    }

    /// Today's aggregated progress ratio in [0.0, 1.0] with strict finite & NaN safety.
    var todayProgress: Double {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let todayLogs = activeLogs.filter { cal.isDate($0.timestamp, inSameDayAs: todayStart) }
        let total = todayLogs.reduce(0.0) { $0 + $1.value }
        let target = effectiveTarget
        guard target > 0, total > 0 else { return 0.0 }
        let ratio = total / target
        return ratio.isFinite ? min(max(ratio, 0.0), 1.0) : 0.0
    }

    /// Whether today's target has been met.
    var isCompletedToday: Bool {
        todayProgress >= 1.0 - 1e-9
    }
}

// MARK: - Soft Delete

extension HabitBoard {

    /// Soft-deletes this board by setting `archivedAt` to the current date and saving.
    ///
    /// This is the **only** permitted deletion path for `HabitBoard` (ADR-001).
    /// `modelContext.delete()` is never called. Hard deletion risks CloudKit orphan
    /// accumulation: if a device receives the board tombstone before all associated
    /// `LogEntry` tombstones during sync propagation, orphaned entries accumulate
    /// indefinitely in the sync store. Soft deletion avoids this entirely.
    ///
    /// On save failure, `archivedAt` is restored to its value before the call —
    /// which may be `nil` (board was active) or a prior non-`nil` `Date` (board
    /// was already archived). Restoring the exact prior value prevents a failed
    /// retry from resurrecting an already-archived board.
    ///
    /// - Parameter context: The `ModelContext` in which to persist the change.
    /// - Throws: `PersistenceError.saveFailed` wrapping the underlying store error.
    @MainActor
    func archive(in context: ModelContext) throws {
        let previousArchivedAt = archivedAt       // Capture before mutation (C1)
        archivedAt = Date()
        do {
            try context.save()
        } catch {
            archivedAt = previousArchivedAt       // Restore exact prior value, not unconditionally nil
            throw PersistenceError.saveFailed(underlying: error)
        }
    }

    // MARK: Active Board Predicate (Phase 3 — closes Phase 1 review finding M1)
    //
    // `archivedAt == nil` is the single most important query invariant in this
    // model: it's the line between what the user sees and what they deleted.
    // Left as an ad-hoc predicate written independently at every @Query call site,
    // it is guaranteed to be forgotten at least once. Phase 3's HabitSidebarView
    // is the first presentation-layer query against HabitBoard, making this the
    // correct point to introduce the canonical predicate — before a second or
    // third call site exists to drift out of sync with it.

    /// The canonical predicate for fetching non-archived ("active") boards.
    ///
    /// Every `@Query` that lists `HabitBoard`s for presentation **must** use this
    /// predicate rather than an ad-hoc `archivedAt == nil` expression written at
    /// the call site:
    ///
    /// ```swift
    /// @Query(filter: HabitBoard.activePredicate, sort: \HabitBoard.createdAt)
    /// private var activeBoards: [HabitBoard]
    /// ```
    static var activePredicate: Predicate<HabitBoard> {
        #Predicate<HabitBoard> { $0.archivedAt == nil }
    }
}

// MARK: - Streak Cache

extension HabitBoard {

    // MARK: - Incremental Streak Update
    //
    // Streak is maintained as cached stored properties updated on each `LogEntry` insertion.
    // This method handles the common incremental case: a new entry has just been inserted
    // and we update the streak without walking all historical logs.
    //
    // Algorithm:
    //   1. Precompute today's half-open window [todayStart, tomorrowStart) using
    //      calendar.date(byAdding:) — computed once, not per entry.
    //   2. Filter `self.logs` for entries in that window using two Date comparisons
    //      per entry (O(1) each), rather than one calendar.startOfDay(for:) call
    //      per entry (O(calendar arithmetic) each). Sum their values.
    //      Total traversal is O(n_logs_for_board).
    //   3. If today's total < effectiveTarget, the day is not yet complete. Return early.
    //   4. If `lastCheckedDate` is nil (first ever completion), set currentStreak = 1.
    //   5. If `lastCheckedDate` is already today, we have already counted this day. Return early.
    //   6. If today is the calendar day immediately after `lastCheckedDate`, extend streak.
    //   7. Otherwise a gap has occurred — reset currentStreak to 1.
    //   8. Update `lastCheckedDate` to now and `longestStreak` if currentStreak exceeds it.
    //
    // DST note:
    //   `Calendar.startOfDay(for:)` and `calendar.date(byAdding: .day, value: 1, to:)`
    //   are both DST-aware. On a fall-back night, tomorrowStart is 25 hours after
    //   todayStart; on a spring-forward night, 23 hours. The half-open interval
    //   handles both cases correctly. The ±90-minute grace window described in
    //   Engineering Principles §8.3 applies to `StreakCalculator`'s full historical
    //   walk (Phase 2), not to this incremental path.

    /// Updates the cached streak properties after a new `LogEntry` has been inserted.
    ///
    /// Call this **after** `context.insert(entry)` and **before** `context.save()`.
    /// The new entry must already be reflected in `self.logs` for today's total to
    /// include it — SwiftData propagates relationship changes immediately upon insert
    /// within the same `ModelContext`.
    ///
    /// **Incremental-Only Contract:** This fast path is valid *only* for an entry dated
    /// **today**. It inspects today's window exclusively and can only start or extend a
    /// streak — it never decrements. Any mutation that touches another day (a backdated
    /// or future insert, an edit, or a delete) must instead set `needsStreakRecalculation`
    /// and route through `StreakCalculator` (see `StreakMaintenanceCoordinator`), which
    /// rebuilds the cache from the full log history. Calling this for a non-today mutation
    /// leaves the cached streak silently wrong.
    ///
    /// **Verification:** All call sites route correctly via `CheckInWriter`, which checks
    /// `Calendar.current.isDateInToday(timestamp)` and calls `updateStreak()` only for
    /// today's entries. Edits, deletes, and non-today inserts set `needsStreakRecalculation`
    /// instead. No call site violates this contract.
    ///
    /// Today's entries are identified using a precomputed half-open interval
    /// `[todayStart, tomorrowStart)`, avoiding per-entry Calendar calls. Total
    /// traversal is O(n_logs_for_board). Phase 2's `DailyAggregator` handles
    /// high-volume pre-computation off the main thread.
    ///
    /// Returns early without mutating state if today's total is below
    /// `effectiveTarget`, if today is already counted, or if `calendar.date(byAdding:)`
    /// fails (which is not expected under any supported timezone or calendar).
    ///
    /// - Parameter calendar: Calendar for day boundary computation.
    ///                       Always pass `Calendar.current` to respect the user's
    ///                       current timezone and locale.
    @MainActor
    func updateStreak(using calendar: Calendar = .current) {
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        // Precompute both bounds of today's window before entering the filter
        // closure. Using a half-open interval [todayStart, tomorrowStart) avoids
        // calling calendar.startOfDay(for:) once per log entry — a Calendar call
        // involves timezone lookup and DateComponents decomposition, whereas a
        // Date comparison is a single floating-point compare. (H5)
        guard let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) else {
            // Calendar arithmetic failure is not recoverable — defensive exit
            // without mutating streak state.
            return
        }

        let todaysTotal = (logs ?? [])
            .filter { $0.timestamp >= todayStart && $0.timestamp < tomorrowStart }
            .reduce(0.0) { $0 + $1.value }

        // Day not yet complete — nothing to update
        guard todaysTotal >= effectiveTarget else { return }

        if let lastDate = lastCheckedDate {
            let lastStart = calendar.startOfDay(for: lastDate)

            // Already counted today — streak is current, no change needed
            guard lastStart != todayStart else { return }

            // Determine whether today directly follows the last completed day
            if let expectedNext = calendar.date(byAdding: .day, value: 1, to: lastStart),
               calendar.startOfDay(for: expectedNext) == todayStart {
                currentStreak += 1
            } else {
                // Gap: one or more days passed without a completed entry
                currentStreak = 1
            }
        } else {
            // First ever completed day for this board
            currentStreak = 1
        }

        lastCheckedDate = now
        longestStreak = Swift.max(longestStreak, currentStreak)
    }

    /// Resets all cached streak properties to their initial zero/nil state.
    ///
    /// Called by `StreakCalculator` (Phase 2) immediately before a full historical
    /// recalculation. Not for use in view or check-in code.
    ///
    /// Does **not** modify `needsStreakRecalculation`. `StreakCalculator` manages
    /// that flag itself: it reads the flag to decide whether to run, and clears
    /// it to `false` only after a successful recalculation and context save.
    @MainActor
    func resetStreakCache() {
        currentStreak = 0
        longestStreak = 0
        lastCheckedDate = nil
    }
}
