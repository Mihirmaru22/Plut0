#if canImport(Testing)
import Foundation
import Testing
import SwiftData

/// Exhaustive unit tests for Ghost Mode / Winter Arc engine, ring calculations, streak doctrines, and isolation.
@Suite("Ghost Mode - Winter Arc Engine Tests")
struct GhostEngineTests {

    // MARK: - 1. Ring Closures & Score Math

    @Test func testRingClosuresAndGhostDayScore() {
        // Test partial closures
        let (ghost1, score1) = GhostDay.computeScore(
            body: true, mind: false, silence: false,
            verifiedMinutes: 0, attestedMinutes: 0
        )
        #expect(!ghost1)
        #expect(score1 == 25)

        let (ghost2, score2) = GhostDay.computeScore(
            body: true, mind: true, silence: false,
            verifiedMinutes: 0, attestedMinutes: 0
        )
        #expect(!ghost2)
        #expect(score2 == 50)

        // All three closed -> Ghost Day
        let (ghost3, score3) = GhostDay.computeScore(
            body: true, mind: true, silence: true,
            verifiedMinutes: 45, attestedMinutes: 0
        )
        #expect(ghost3)
        #expect(score3 >= 75)

        // Perfect score (90+ minutes verified silence)
        let (ghost4, score4) = GhostDay.computeScore(
            body: true, mind: true, silence: true,
            verifiedMinutes: 90, attestedMinutes: 0
        )
        #expect(ghost4)
        #expect(score4 == 100)
    }

    // MARK: - 2. Ghost Rank Math

    @Test func testGhostRankProgression() {
        #expect(GhostRank.rank(forStreak: 0) == .uninitiated)
        #expect(GhostRank.rank(forStreak: 1) == .apparition)
        #expect(GhostRank.rank(forStreak: 6) == .apparition)
        #expect(GhostRank.rank(forStreak: 7) == .shadow)
        #expect(GhostRank.rank(forStreak: 20) == .shadow)
        #expect(GhostRank.rank(forStreak: 21) == .phantom)
        #expect(GhostRank.rank(forStreak: 45) == .wraith)
        #expect(GhostRank.rank(forStreak: 75) == .specter)
        #expect(GhostRank.rank(forStreak: 120) == .sovereign)
        #expect(GhostRank.rank(forStreak: 150) == .sovereign)
    }

    // MARK: - 3. Ridge Point Elevation Curve

    @Test func testRidgePointElevationCurve() {
        let ghostPt = GhostRidgePoint(
            dayIndex: 10,
            dateString: "2026-09-10",
            score: 100,
            isGhostDay: true
        )
        let missedPt = GhostRidgePoint(
            dayIndex: 10,
            dateString: "2026-09-10",
            score: 0,
            isGhostDay: false
        )

        #expect(ghostPt.elevationMeters > missedPt.elevationMeters)
        #expect(ghostPt.isGhostDay)
        #expect(!missedPt.isGhostDay)
    }

    // MARK: - 4. Habit Regression (Non-Ghost Habits Untouched)

    @Test func testNonGhostHabitsUntouched() {
        let habit = HabitBoard()
        habit.name = "Morning Water"
        #expect(habit.ghostRuleID == nil)
        #expect(habit.ghostRingRaw == nil)
    }
}
#endif
