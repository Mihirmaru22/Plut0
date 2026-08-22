import XCTest
import SwiftData
@testable import LOCA

/// Exhaustive unit tests for Ghost Mode / Winter Arc engine, ring calculations, streak doctrines, and isolation.
final class GhostEngineTests: XCTestCase {

    // MARK: - 1. Ring Closures & Score Math

    func testRingClosuresAndGhostDayScore() {
        // Test partial closures
        let (ghost1, score1) = GhostDay.computeScore(
            body: true, mind: false, silence: false,
            verifiedMinutes: 0, attestedMinutes: 0
        )
        XCTAssertFalse(ghost1)
        XCTAssertEqual(score1, 25)

        let (ghost2, score2) = GhostDay.computeScore(
            body: true, mind: true, silence: false,
            verifiedMinutes: 0, attestedMinutes: 0
        )
        XCTAssertFalse(ghost2)
        XCTAssertEqual(score2, 50)

        // All three closed -> Ghost Day
        let (ghost3, score3) = GhostDay.computeScore(
            body: true, mind: true, silence: true,
            verifiedMinutes: 45, attestedMinutes: 0
        )
        XCTAssertTrue(ghost3)
        XCTAssertGreaterThanOrEqual(score3, 75)

        // Perfect score (90+ minutes verified silence)
        let (ghost4, score4) = GhostDay.computeScore(
            body: true, mind: true, silence: true,
            verifiedMinutes: 90, attestedMinutes: 0
        )
        XCTAssertTrue(ghost4)
        XCTAssertEqual(score4, 100)
    }

    // MARK: - 2. Ghost Rank Math

    func testGhostRankProgression() {
        XCTAssertEqual(GhostRank.rank(forStreak: 0), .uninitiated)
        XCTAssertEqual(GhostRank.rank(forStreak: 1), .apparition)
        XCTAssertEqual(GhostRank.rank(forStreak: 6), .apparition)
        XCTAssertEqual(GhostRank.rank(forStreak: 7), .shadow)
        XCTAssertEqual(GhostRank.rank(forStreak: 20), .shadow)
        XCTAssertEqual(GhostRank.rank(forStreak: 21), .phantom)
        XCTAssertEqual(GhostRank.rank(forStreak: 45), .wraith)
        XCTAssertEqual(GhostRank.rank(forStreak: 75), .specter)
        XCTAssertEqual(GhostRank.rank(forStreak: 120), .sovereign)
        XCTAssertEqual(GhostRank.rank(forStreak: 150), .sovereign)
    }

    // MARK: - 3. Ridge Point Elevation Curve

    func testRidgePointElevationCurve() {
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

        XCTAssertGreaterThan(ghostPt.elevationMeters, missedPt.elevationMeters)
        XCTAssertTrue(ghostPt.isGhostDay)
        XCTAssertFalse(missedPt.isGhostDay)
    }

    // MARK: - 4. Habit Regression (Non-Ghost Habits Untouched)

    func testNonGhostHabitsUntouched() {
        let habit = HabitBoard()
        habit.name = "Morning Water"
        XCTAssertNil(habit.ghostRuleID)
        XCTAssertNil(habit.ghostRingRaw)
    }
}
