import Foundation

// MARK: - LogSnapshot

/// A lightweight, `Sendable` value-type snapshot of a `LogEntry`'s analytics-relevant fields.
///
/// `LogEntry` is a `@Model` reference type managed by a `ModelContext`. In Swift 6 strict
/// concurrency, reference types that do not conform to `Sendable` cannot cross actor
/// boundaries safely. `LogSnapshot` solves this by extracting the three fields needed for
/// analytics computation into a struct — safe to pass to any actor or async context.
///
/// ## Creation
/// Always create snapshots on the same actor as the `LogEntry`'s `ModelContext` — in standard
/// LOCA usage, this is `@MainActor`:
///
/// ```swift
/// // On @MainActor (view, app coordinator, or task modifier):
/// let snapshots = board.logs?.map(LogSnapshot.init(from:)) ?? []
///
/// // Off @MainActor (cooperative thread pool):
/// let result = await StreakCalculator.calculate(
///     snapshots: snapshots,
///     target: board.effectiveTarget
/// )
/// ```
///
/// ## Test Fixtures
/// Use the direct `init(timestamp:value:boardID:)` initialiser to create synthetic data
/// in unit tests without requiring a live `ModelContext`.
struct LogSnapshot: Sendable, Hashable {

    /// The exact timestamp of the original `LogEntry`. Stored as UTC; `Calendar` converts
    /// to local time during aggregation.
    let timestamp: Date

    /// The logged amount. For binary habits this is always `1.0`. For quantitative habits
    /// this is the user-entered value in `board.unitLabel` units.
    let value: Double

    /// The owning board's identifier. Matches `LogEntry.boardID` (ADR-003). Included in
    /// the snapshot so callers can verify snapshot provenance in tests.
    let boardID: UUID

    // MARK: Initialisers

    /// Creates a snapshot from a live `LogEntry` model object.
    ///
    /// Must be called from `@MainActor` (the actor that owns this project's `ModelContext`,
    /// per `ModelContainerFactory`) because reading properties on a `@Model` type from a
    /// different actor is a Swift 6 data-race violation. The resulting `LogSnapshot` is
    /// `Sendable` and safe to pass to any context.
    ///
    /// - Parameter entry: A `LogEntry` managed by the current `ModelContext`.
    @MainActor
    init(from entry: LogEntry) {
        self.timestamp = entry.timestamp
        self.value     = entry.value
        self.boardID   = entry.boardID
    }

    /// Direct initialiser for test fixtures and synthetic data.
    ///
    /// Does not require `@MainActor` — no live `@Model` object is accessed.
    ///
    /// - Parameters:
    ///   - timestamp: The log timestamp.
    ///   - value: The logged amount.
    ///   - boardID: The owning board's UUID. Defaults to a new UUID for single-board tests.
    init(timestamp: Date, value: Double, boardID: UUID = UUID()) {
        self.timestamp = timestamp
        self.value     = value
        self.boardID   = boardID
    }
}

// MARK: - DayTotal

/// The aggregated log data for a single calendar day, produced by `aggregateByDay` or
/// `aggregateByDayWithGrace`.
///
/// `DayTotal` carries two totals:
///
/// - `total`: The sum of values from entries whose primary calendar day is this date.
///   Used for heatmap display (intensity) and journal summaries. Reflects exactly what
///   the user logged on this calendar day.
///
/// - `graceTotal`: `total` plus grace credits from entries in adjacent days that fall
///   within 90 minutes of this day's midnight boundary. Used exclusively by
///   `StreakCalculator` for streak completion checks. Never used for display.
///   Equal to `total` (no grace applied) when produced by `aggregateByDay`.
///
/// The distinction matters during DST transitions: an entry logged at 12:05 AM on Day N+1
/// has a primary day of N+1, but within 90 minutes of Day N's midnight. `graceTotal` on
/// Day N includes that entry's value, allowing Day N's streak to be preserved if the user
/// intended to log before midnight but the clock shifted.
struct DayTotal: Sendable, Hashable {

    /// The `calendar.startOfDay`-normalised date for this entry group.
    let date: Date

    /// Sum of values from entries primarily attributed to this calendar day.
    /// Used for heatmap intensity and display totals. Never includes grace credits.
    let total: Double

    /// `total` plus values from adjacent-day entries within the ±90-minute DST grace window.
    /// Used only by `StreakCalculator.calculateStreaks` for streak completion checks.
    /// Equal to `total` when produced by `aggregateByDay` (no grace applied).
    let graceTotal: Double

    /// Number of `LogEntry` records with primary attribution to this calendar day.
    /// Zero only for days synthesised with no entries (does not occur in `aggregateByDay`
    /// output; those days are skipped). Used by `DayCell.hasEntry`.
    let entryCount: Int

    // MARK: Completion Checks

    // MARK: Floating-Point Tolerance (Phase 2 review finding H2)
    //
    // Repeated Double summation of fractional log values (e.g., 0.1-unit increments
    // logged ten times to reach a target of 1.0) accumulates IEEE 754 representation
    // error. A mathematically exact sum of 1.0 can be stored as 0.9999999999999998.
    // Without tolerance, an exact `total >= target` comparison would classify a
    // genuinely completed day as incomplete. `completionEpsilon` is shared by both
    // completion checks here and by HeatmapDataProvider's intensity calculation,
    // so a single boundary definition governs every "did the user hit the goal"
    // decision in the compute layer.

    /// Floating-point tolerance applied to every goal-completion comparison in the
    /// compute layer. See the algorithm note above this property for why it exists.
    static let completionEpsilon: Double = 1e-9

    /// Returns `true` if this day's primary total meets or exceeds `target`, within
    /// `completionEpsilon` tolerance.
    /// Used for heatmap display: did the user actually hit the goal on this day?
    func isComplete(for target: Double) -> Bool {
        total >= target - Self.completionEpsilon
    }

    /// Returns `true` if `graceTotal` meets or exceeds `target`, within
    /// `completionEpsilon` tolerance.
    /// Used exclusively for streak computation: could this day be considered complete
    /// accounting for DST-borderline entries?
    func isCompleteWithGrace(for target: Double) -> Bool {
        graceTotal >= target - Self.completionEpsilon
    }
}

// MARK: - StreakResult

/// The output of `StreakCalculator.calculate`. Apply to a `HabitBoard` on `@MainActor`
/// after a full historical recalculation triggered by `needsStreakRecalculation`.
///
/// ## Applying to HabitBoard
/// ```swift
/// // On @MainActor, after awaiting StreakCalculator.calculate:
/// board.currentStreak           = result.currentStreak
/// board.longestStreak           = result.longestStreak
/// board.lastCheckedDate         = result.lastCompletedDate
/// board.needsStreakRecalculation = false
/// try context.save()
/// ```
struct StreakResult: Sendable, Equatable {

    /// Consecutive calendar days ending on or including today on which the target was met.
    /// Zero when the streak is broken (last completed day was more than 1 day ago).
    ///
    /// A streak remains non-zero if the last completed day is **yesterday** — today may
    /// still be in progress. It becomes zero only when yesterday was also not completed.
    let currentStreak: Int

    /// The longest run of consecutive completed days found in the full log history,
    /// excluding any day later than the calculation's reference date (see H1 fix note
    /// in `calculateStreaks`).
    /// Always ≥ `currentStreak`.
    let longestStreak: Int

    /// The most recent calendar day (midnight-normalised), no later than the calculation's
    /// reference date, on which the target was met. `nil` only when no day has ever been
    /// completed. Present even when `currentStreak` is zero — it records when the last
    /// active period ended.
    ///
    /// Maps to `HabitBoard.lastCheckedDate` after applying the result.
    let lastCompletedDate: Date?

    /// A zero-value result representing no completed history.
    static let zero = StreakResult(currentStreak: 0, longestStreak: 0, lastCompletedDate: nil)
}

// MARK: - Aggregation Kernel

// MARK: aggregateByDay / aggregateByDayWithGrace — Two Functions, Not One (Phase 2 review finding H3)
//
// Earlier draft of this file had a single `aggregateByDay` that always computed both
// primary attribution AND grace-window credits in two sequential passes. HeatmapDataProvider
// never reads `graceTotal` — only StreakCalculator does — so every heatmap render was
// unconditionally paying for grace-window computation it never used. This is now split:
//
//   aggregateByDay(snapshots:calendar:)            — primary attribution ONLY.
//                                                     Used by HeatmapDataProvider.
//                                                     graceTotal == total (no grace applied).
//
//   aggregateByDayWithGrace(snapshots:calendar:)   — primary attribution AND grace credits.
//                                                     Used by StreakCalculator.
//
// Both functions are `internal` (module-visible) so HeatmapDataProvider and StreakCalculator
// can call the one they need directly, without a cross-type dependency.
//
// Within `aggregateByDayWithGrace`, `calendar.startOfDay(for:)` is computed exactly ONCE
// per snapshot via a single `map` pass at the top of the function, and the result is reused
// by both the primary-attribution loop and the grace-credit loop (Phase 2 review finding H4).
// The original implementation recomputed this for every snapshot in two separate loops —
// doubling the cost of the single most expensive operation in the algorithm for no reason.
//
// Time complexity:
//   aggregateByDay:           O(N log D)  — one O(N) pass + O(D log D) sort
//   aggregateByDayWithGrace:  O(N log D)  — one O(N) pass to compute snapshotDays,
//                                            two further O(N) dictionary-only passes
//                                            reusing it, + O(D log D) sort
// Space complexity: O(N) for the snapshotDays array (aggregateByDayWithGrace only) + O(D)
//                    for the result array and auxiliary dictionaries.
//
// DST Handling:
//   Calendar.startOfDay(for:) is DST-aware. On a fall-back night (25-hour day),
//   startOfDay returns the correct local midnight; all entries timestamped in that
//   25-hour window correctly map to the same local date. No special treatment is needed
//   at the primary-attribution level.
//
// Grace Window (±90 minutes):
//   An entry timestamped within 90 minutes of a day boundary is also credited to the
//   adjacent day's `graceTotal`. This covers the case where a user logs just after
//   midnight on Day N+1, intending it for Day N (e.g., during a DST fall-back where
//   the clock reset mid-session). The credit does NOT appear in `total` — it is additive
//   only in `graceTotal`, which StreakCalculator uses exclusively for streak checks.
//
//   Grace credits are only applied to days that already have primary entries. A day with
//   zero primary entries will not have a DayTotal in the result at all, so grace from a
//   neighbour cannot make a day appear complete when the user logged nothing on it.
//
// Cross-Timezone Note (documented design tradeoff, Phase 2 review finding M2):
//   Day-boundary computation always uses the `calendar` parameter passed by the caller
//   (typically `Calendar.current` at call time), not any timezone recorded at the moment
//   a LogEntry was created. A user who logs in one timezone and reviews their history after
//   traveling may see a past entry's calendar-day attribution shift, because `startOfDay`
//   is evaluated against the CURRENT device timezone. This is an intentional choice
//   consistent with a local-first, single-user mental model — "today" is always defined by
//   where the user is now — not an oversight. Left undocumented in an earlier draft.

/// Groups log snapshots by calendar day and sums their values. Primary attribution only —
/// does not compute DST grace-window credits.
///
/// Use this function when only the display total matters (heatmap intensity, journal
/// totals). `HeatmapDataProvider.buildDayGrid` calls this exclusively; it never needs
/// `graceTotal`, so it never pays for the grace-window computation that
/// `aggregateByDayWithGrace` performs.
///
/// The returned array is sorted ascending by `DayTotal.date`. Days with no primary
/// entries are omitted — `HeatmapDataProvider.buildDayGrid` synthesises empty `DayCell`
/// values for those dates from the full trailing-window range.
///
/// - Parameters:
///   - snapshots: Log snapshots for a single board. Passing mixed-board snapshots produces
///                incorrect per-day totals; the caller is responsible for pre-filtering.
///   - calendar:  The calendar for day boundary computation. Pass `Calendar.current`.
/// - Returns: `[DayTotal]` sorted ascending by date, with `graceTotal == total` for every
///            element. Empty if `snapshots` is empty.
func aggregateByDay(snapshots: [LogSnapshot], calendar: Calendar) -> [DayTotal] {
    guard !snapshots.isEmpty else { return [] }

    var primaryTotals: [Date: Double] = [:]
    var primaryCounts: [Date: Int]    = [:]
    primaryTotals.reserveCapacity(snapshots.count)
    primaryCounts.reserveCapacity(snapshots.count)

    for snapshot in snapshots {
        let day = calendar.startOfDay(for: snapshot.timestamp)
        primaryTotals[day, default: 0] += snapshot.value
        primaryCounts[day, default: 0] += 1
    }

    var result: [DayTotal] = []
    result.reserveCapacity(primaryTotals.count)
    for (day, total) in primaryTotals {
        result.append(DayTotal(
            date:       day,
            total:      total,
            graceTotal: total,                       // no grace applied
            entryCount: primaryCounts[day] ?? 0
        ))
    }

    result.sort { $0.date < $1.date }
    return result
}

/// Groups log snapshots by calendar day, sums their values, and computes DST grace-window
/// credits. Use this function only when streak completion (not display) is the goal.
///
/// `StreakCalculator.calculate` calls this exclusively. The day for each snapshot is
/// computed exactly once (see the algorithm note above this section) and reused by both
/// the primary-attribution pass and the grace-credit pass.
///
/// - Parameters:
///   - snapshots: Log snapshots for a single board. Passing mixed-board snapshots produces
///                incorrect per-day totals; the caller is responsible for pre-filtering.
///   - calendar:  The calendar for day boundary computation. Pass `Calendar.current`.
/// - Returns: `[DayTotal]` sorted ascending by date. Empty if `snapshots` is empty.
func aggregateByDayWithGrace(snapshots: [LogSnapshot], calendar: Calendar) -> [DayTotal] {
    guard !snapshots.isEmpty else { return [] }

    // Compute each snapshot's day exactly once. Reused below by both the primary
    // attribution pass and the grace-credit pass — eliminates the redundant
    // recomputation flagged as Phase 2 review finding H4.
    let snapshotDays: [(snapshot: LogSnapshot, day: Date)] = snapshots.map {
        ($0, calendar.startOfDay(for: $0.timestamp))
    }

    // ── Pass 1: Primary Attribution ─────────────────────────────────────────────
    var primaryTotals: [Date: Double] = [:]
    var primaryCounts: [Date: Int]    = [:]
    primaryTotals.reserveCapacity(snapshots.count)
    primaryCounts.reserveCapacity(snapshots.count)

    for (snapshot, day) in snapshotDays {
        primaryTotals[day, default: 0] += snapshot.value
        primaryCounts[day, default: 0] += 1
    }

    // ── Pass 2: Grace Window Credits ────────────────────────────────────────────
    //
    // For each entry within 90 minutes of a day boundary, also add its value to the
    // adjacent day's grace credit. Two cases:
    //
    //   A. distanceFromStart < 90 min  → entry is just after midnight of `day`.
    //      Credit the PREVIOUS day. (User may have intended to log before midnight.)
    //
    //   B. distanceBeforeEnd < 90 min  → entry is just before midnight of `day`.
    //      Credit the NEXT day. (User may have intended to log after midnight.)
    //
    // A single entry can satisfy at most one of these conditions: a standard calendar
    // day is ≥ 23 hours (82,800 seconds), so the start-grace and end-grace windows
    // (each 5,400 seconds) cannot both contain the same entry.
    //
    // `prevDay`/`nextDay` are computed via calendar.date(byAdding:.day,to:) starting
    // from an already-startOfDay-normalised `day`. Apple's Calendar guarantees this
    // preserves the midnight property — the result is already at day-start, so no
    // additional `startOfDay` re-normalisation call is needed (a redundant pair of
    // calls present in an earlier draft, also addressed by H4).

    let graceInterval: TimeInterval = 90 * 60     // 5,400 seconds
    var graceCredits: [Date: Double] = [:]

    for (snapshot, day) in snapshotDays {
        let distanceFromStart = snapshot.timestamp.timeIntervalSince(day)

        if distanceFromStart < graceInterval {
            // Case A: entry is within 90 min after midnight — credit previous day
            if let prevDay = calendar.date(byAdding: .day, value: -1, to: day),
               primaryTotals[prevDay] != nil {
                graceCredits[prevDay, default: 0] += snapshot.value
            }
        } else {
            // Case B: check if within 90 min before midnight
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                continue
            }
            let distanceBeforeEnd = nextDay.timeIntervalSince(snapshot.timestamp)

            if distanceBeforeEnd < graceInterval, primaryTotals[nextDay] != nil {
                graceCredits[nextDay, default: 0] += snapshot.value
            }
        }
    }

    // ── Build Result Array ───────────────────────────────────────────────────────
    var result: [DayTotal] = []
    result.reserveCapacity(primaryTotals.count)

    for (day, total) in primaryTotals {
        result.append(DayTotal(
            date:       day,
            total:      total,
            graceTotal: total + (graceCredits[day] ?? 0),
            entryCount: primaryCounts[day] ?? 0
        ))
    }

    // Sort ascending by date — required by StreakCalculator.calculateStreaks which
    // performs a single linear walk over the sorted completed-day sequence.
    result.sort { $0.date < $1.date }
    return result
}

// MARK: - StreakCalculator

/// Computes streak metrics from a board's full log history.
///
/// `StreakCalculator` is a pure-computation namespace with no mutable state. All methods
/// are `async` and `nonisolated` (via `enum` membership), running on Swift's cooperative
/// thread pool when called with `await` from `@MainActor`. No `ModelContext` is accessed —
/// the caller provides log data as `[LogSnapshot]` and writes the returned `StreakResult`
/// back to the model on `@MainActor`.
///
/// ## Typical Call Pattern
///
/// This is called when `board.needsStreakRecalculation == true` — triggered after a
/// CloudKit bulk import or at app launch if a prior recalculation was interrupted.
///
/// ```swift
/// // ── On @MainActor (view coordinator or app entry point) ──
/// guard board.needsStreakRecalculation else { return }
/// let snapshots = board.logs?.map(LogSnapshot.init(from:)) ?? []
/// let target    = board.effectiveTarget
///
/// // ── Off @MainActor (cooperative thread pool) ──
/// let result = await StreakCalculator.calculate(
///     snapshots: snapshots,
///     target:    target,
///     calendar:  .current
///     // referenceDate defaults to Date() — pass explicitly only in tests
/// )
///
/// // ── Back on @MainActor ──
/// board.currentStreak            = result.currentStreak
/// board.longestStreak            = result.longestStreak
/// board.lastCheckedDate          = result.lastCompletedDate
/// board.needsStreakRecalculation  = false
/// try context.save()
/// ```
///
/// ## Test Usage (DST Mandatory Dates, Engineering Principles §8.3)
///
/// ```swift
/// // Inject a fixed referenceDate so "is the streak active" is deterministic —
/// // a real unit test, not dependent on the system clock at test-run time.
/// let result = await StreakCalculator.calculate(
///     snapshots:     fallBackTransitionSnapshots,
///     target:        1.0,
///     calendar:      usEasternCalendar,
///     referenceDate: dstFallBackDate  // e.g. 2024-11-03
/// )
/// ```
///
/// ## Thread Safety
/// All methods are stateless free functions over value types. Concurrent calls with
/// different inputs are safe and produce no data races.
///
/// ## Relationship to `HabitBoard.updateStreak(using:)`
/// The incremental `updateStreak(using:)` method on `HabitBoard` handles the common
/// fast path: a single new entry arrives and extends (or starts) the streak. This full
/// recalculation handles the recovery path: after a CloudKit sync delivers entries that
/// the incremental path never saw (because the device was offline), the cached streak
/// properties are potentially stale and must be rebuilt from the complete log history.
enum StreakCalculator {

    // MARK: - Public API

    /// Computes complete streak metrics from a snapshot of a board's log history.
    ///
    /// ## Algorithm Overview
    ///
    /// ```
    /// 1. aggregateByDayWithGrace(snapshots, calendar)  → [DayTotal]   O(N log D)
    /// 2. filter to date <= referenceDate AND grace-complete → [Date]  O(D)
    /// 3. walk completed dates for consecutive runs     → StreakResult O(D)
    ///
    /// Total: O(N log D)  where N = snapshot count, D = distinct calendar days
    /// ```
    ///
    /// For a user with 3 years of history at 2 logs/day (N ≈ 2,200, D ≈ 1,095),
    /// this completes in well under 1 ms on modern hardware.
    ///
    /// ## Streak Semantics
    ///
    /// A calendar day is **complete** if `graceTotal >= target` within floating-point
    /// tolerance (see `DayTotal.isCompleteWithGrace`). `graceTotal` includes the primary
    /// total plus values from adjacent-day entries within 90 minutes of midnight (DST
    /// grace window). For display purposes, `total` is used rather than `graceTotal` —
    /// the grace only affects whether the streak is considered unbroken.
    ///
    /// Any day later than `referenceDate` is excluded before the streak walk begins
    /// (see the algorithm note on `calculateStreaks` below). This prevents a single
    /// clock-skewed or future-dated `LogEntry` — plausible after a multi-device CloudKit
    /// sync where one device's clock is wrong — from suppressing an otherwise-active
    /// streak or inflating the longest streak.
    ///
    /// The current streak counts the consecutive run of complete days ending on **today or
    /// yesterday** (relative to `referenceDate`). A streak remains active (non-zero) when
    /// today has not yet been completed, because the user may still log later in the day.
    /// It becomes zero only when the last complete day was two or more days ago.
    ///
    /// ## DST Correctness
    ///
    /// `Calendar.date(byAdding: .day, value: 1, to:)` correctly advances by one civil day,
    /// producing the right midnight even during fall-back (25-hour day) and spring-forward
    /// (23-hour day) transitions. The `areConsecutiveDays` check uses strict equality on
    /// `startOfDay`-normalised dates, which are always exact midnights. No floating-point
    /// tolerance is applied at the day-comparison level — only at the goal-completion
    /// level (`DayTotal.completionEpsilon`).
    ///
    /// - Parameters:
    ///   - snapshots: `[LogSnapshot]` for a single board. Pre-filter by `boardID` if needed.
    ///                Must be created on `@MainActor`; safe to pass here.
    ///   - target:   The board's `effectiveTarget`. Must be `> 0`.
    ///   - calendar: The calendar for all day boundary computations.
    ///               Pass `Calendar.current` at the call site to capture the user's
    ///               current timezone; do not cache across timezone changes.
    ///   - referenceDate: The instant treated as "now" for determining today/yesterday
    ///               and for excluding future-dated entries. Defaults to `Date()`.
    ///               Tests should pass an explicit fixed date — this is what makes the
    ///               Engineering Principles §8.3 mandatory DST test dates deterministic
    ///               and repeatable rather than dependent on the system clock at test-run
    ///               time.
    /// - Returns: A `StreakResult` with current streak, longest streak, and last completed date.
    ///            Returns `StreakResult.zero` if `snapshots` is empty or no day is ever complete.
    static func calculate(
        snapshots:     [LogSnapshot],
        target:        Double,
        calendar:      Calendar = .current,
        referenceDate: Date     = Date()
    ) async -> StreakResult {
        guard !snapshots.isEmpty, target > 0 else { return .zero }

        let dayTotals = aggregateByDayWithGrace(snapshots: snapshots, calendar: calendar)
        return calculateStreaks(
            from:          dayTotals,
            target:        target,
            calendar:      calendar,
            referenceDate: referenceDate
        )
    }

    // MARK: - Internal Computation

    // MARK: Streak Calculation Algorithm
    //
    // Input:  [DayTotal] sorted ascending by date, target value, calendar, referenceDate.
    // Output: StreakResult.
    //
    // ── Step 1: Establish today/yesterday anchors ───────────────────────────────
    //   Both derived from `referenceDate`, not a direct internal Date() call (Phase 2
    //   review finding H5). This makes the "is the streak active" determination
    //   deterministic and testable: a unit test can inject a fixed referenceDate and
    //   get a reproducible result, including for the four mandatory DST transition
    //   dates in Engineering Principles §8.3.
    //
    // ── Step 2: Filter to complete days no later than today ─────────────────────
    //   Uses isCompleteWithGrace(for:) so the DST grace window applies, AND excludes
    //   any date > today (Phase 2 review finding H1). Without this exclusion, a single
    //   future-dated LogEntry — plausible from a multi-device CloudKit sync where one
    //   device's clock is wrong — would become `completedDates.last`, incorrectly
    //   suppressing an active streak (today/yesterday no longer match the spurious last
    //   date) and potentially inflating `longestStreak` if the bogus date happened to be
    //   calendar-consecutive with real entries.
    //
    // ── Step 3: Walk completed dates, tracking consecutive runs ──────────────────
    //   A single O(D) forward pass computes:
    //     - currentRun:          length of the run currently being extended
    //     - longestRun:          maximum run length seen so far (updated at every step)
    //     - runLengthAtLastDate: the run length at the final element (= current streak
    //                            candidate if that date is today or yesterday)
    //
    //   "Consecutive" means areConsecutiveDays(earlier, later, calendar) is true —
    //   exactly 1 civil day apart per Calendar arithmetic.
    //
    // ── Step 4: Determine active / broken ────────────────────────────────────────
    //   The streak is ACTIVE if the last completed date == today OR == yesterday.
    //   (Today's streak can still be in progress; yesterday's is still valid.)
    //   The streak is BROKEN if the last completed date is ≥ 2 days ago.
    //
    // ── Edge Cases ───────────────────────────────────────────────────────────────
    //   completedDates.count == 0  → StreakResult.zero
    //   completedDates.count == 1  → longestRun = 1, runLengthAtLastDate = 1 (initials)
    //   All dates non-consecutive  → longestRun = 1, current = 0 if last is old
    //   All dates consecutive      → longestRun = D, current = D if last is today/yesterday
    //   calendar.date(byAdding:) fails for `yesterday` → StreakResult.zero (defensive exit)

    private static func calculateStreaks(
        from dayTotals: [DayTotal],
        target:         Double,
        calendar:       Calendar,
        referenceDate:  Date
    ) -> StreakResult {
        let today = calendar.startOfDay(for: referenceDate)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            // Calendar arithmetic failure — defensive exit; cannot determine streak status
            return .zero
        }

        // Filter: grace-completeness for streak semantics, AND exclude any day later
        // than `today` (H1 fix — see algorithm note above).
        let completedDates = dayTotals
            .filter { $0.date <= today && $0.isCompleteWithGrace(for: target) }
            .map    { $0.date }                              // dates are already sorted ascending

        guard !completedDates.isEmpty else { return .zero }

        // ── Single-element fast path ─────────────────────────────────────────────
        if completedDates.count == 1 {
            let only     = completedDates[0]
            let isActive = only == today || only == yesterday
            return StreakResult(
                currentStreak:    isActive ? 1 : 0,
                longestStreak:    1,
                lastCompletedDate: only
            )
        }

        // ── Multi-element walk ───────────────────────────────────────────────────
        var longestRun          = 1    // maximum run length encountered
        var currentRun          = 1    // run length at the current position
        var runLengthAtLastDate = 1    // run length ending at completedDates.last

        for i in 1 ..< completedDates.count {
            if areConsecutiveDays(completedDates[i - 1], completedDates[i], calendar: calendar) {
                currentRun += 1
            } else {
                currentRun = 1
            }

            if currentRun > longestRun { longestRun = currentRun }

            if i == completedDates.count - 1 {
                runLengthAtLastDate = currentRun
            }
        }

        let lastDate = completedDates.last!           // safe: count >= 2
        let isActive = lastDate == today || lastDate == yesterday

        return StreakResult(
            currentStreak:     isActive ? runLengthAtLastDate : 0,
            longestStreak:     longestRun,
            lastCompletedDate: lastDate
        )
    }

    // MARK: - Day Consecutiveness Check

    // MARK: areConsecutiveDays Implementation
    //
    // Two startOfDay-normalised dates are "consecutive" if the second is exactly one
    // civil day after the first per calendar.date(byAdding: .day, value: 1, to:).
    //
    // This computation is DST-correct by construction:
    //   - On a fall-back night (25-hour day), dayAdding(.day, 1) → correct next midnight
    //   - On a spring-forward night (23-hour day), same result
    //
    // No floating-point tolerance is applied here. The grace window for DST borderline
    // entries is handled at the aggregation level (graceTotal) — not at day comparison.
    // Applying tolerance here could incorrectly treat a 2-day gap (genuine streak break)
    // as consecutive if it were within 90 minutes of two standard days.

    /// Returns `true` if `later` is exactly one civil day after `earlier` per `calendar`.
    ///
    /// Both dates must be `calendar.startOfDay`-normalised (as guaranteed by
    /// `aggregateByDayWithGrace`). Returns `false` if `calendar.date(byAdding:)` fails,
    /// which is not expected for any timezone or calendar supported by the system.
    public static func areConsecutiveDays(
        _ earlier: Date,
        _ later:   Date,
        calendar:  Calendar = .current
    ) -> Bool {
        guard let expectedNext = calendar.date(byAdding: .day, value: 1, to: earlier) else {
            return false
        }
        return expectedNext == later
    }

    /// Determines whether two dates fall on consecutive calendar days using normalized day boundaries.
    public static func isConsecutiveDay(
        _ date1: Date,
        _ date2: Date,
        calendar: Calendar = .current
    ) -> Bool {
        let day1 = calendar.startOfDay(for: date1)
        let day2 = calendar.startOfDay(for: date2)
        let diff = calendar.dateComponents([.day], from: day1, to: day2).day ?? 0
        return abs(diff) == 1
    }

    /// Calculates the current consecutive day streak from a list of check-in dates.
    ///
    /// Normalizes each timestamp to `calendar.startOfDay(for:)`, deduplicates multiple check-ins
    /// on the same day, and computes the contiguous run of consecutive days leading up to the most recent check-in.
    public static func calculateStreak(
        for checkIns: [Date],
        calendar: Calendar = .current
    ) -> Int {
        guard !checkIns.isEmpty else { return 0 }

        let uniqueDays = Set(checkIns.map { calendar.startOfDay(for: $0) })
        let sortedDays = uniqueDays.sorted(by: >) // Most recent first

        guard !sortedDays.isEmpty else { return 0 }
        var streak = 1
        var previousDay = sortedDays[0]

        for day in sortedDays.dropFirst() {
            let diff = calendar.dateComponents([.day], from: day, to: previousDay).day ?? 0
            if diff == 1 {
                streak += 1
                previousDay = day
            } else {
                break // Streak broken
            }
        }

        return streak
    }
}

// MARK: - HabitCheckIn

/// Represents a single habit check-in event with timestamp and timezone metadata.
public struct HabitCheckIn: Codable, Sendable, Hashable {
    public let timestamp: Date // UTC timestamp
    public let timezoneOffset: Int // Offset in seconds from UTC at check-in time

    public init(timestamp: Date, timezoneOffset: Int = TimeZone.current.secondsFromGMT()) {
        self.timestamp = timestamp
        self.timezoneOffset = timezoneOffset
    }

    public func day(in calendar: Calendar = .current) -> Date {
        return calendar.startOfDay(for: timestamp)
    }
}

// MARK: - Global Convenience Helpers

/// Determines whether two dates fall on consecutive calendar days using normalized day boundaries.
public func isConsecutiveDay(_ date1: Date, _ date2: Date, calendar: Calendar = .current) -> Bool {
    StreakCalculator.isConsecutiveDay(date1, date2, calendar: calendar)
}

/// Calculates the current consecutive day streak from a list of check-in dates.
public func calculateStreak(for checkIns: [Date], calendar: Calendar = .current) -> Int {
    StreakCalculator.calculateStreak(for: checkIns, calendar: calendar)
}

