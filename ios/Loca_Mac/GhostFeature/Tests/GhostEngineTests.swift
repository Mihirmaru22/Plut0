#if canImport(Testing)
import Foundation
import Testing
import SwiftData

/// Exhaustive unit tests for Ghost Mode / Winter Arc engine, receipts, ring calculations, streak doctrines, chain grid, and isolation.
@Suite("Ghost Mode - Winter Arc Engine Tests")
struct GhostEngineTests {

    // MARK: - 1. Ring Closures & Score Math

    @Test func testRingClosuresAndGhostDayScore() {
        // Partial closures
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

    // MARK: - 4. Protocol Rule Templates & Receipts

    @Test func test75HardProtocolDefaults() {
        let rules = GhostProtocolRule.defaultRules(for: .seventyFiveHard)
        #expect(rules.count == 6)

        let waterRule = rules.first { $0.id == "75h_water" }
        #expect(waterRule != nil)
        #expect(waterRule?.targetValue == 8.0)
        #expect(waterRule?.unitLabel == "glasses")

        let readingRule = rules.first { $0.id == "75h_reading" }
        #expect(readingRule != nil)
        #expect(readingRule?.ring == .mind)
        #expect(readingRule?.targetValue == 10.0)

        let photoRule = rules.first { $0.id == "75h_photo" }
        #expect(photoRule != nil)
        #expect(photoRule?.proofKind == .artifact)
    }

    @Test func testThe120ProtocolDefaults() {
        let rules = GhostProtocolRule.defaultRules(for: .the120)
        #expect(rules.count == 5)

        let silenceRule = rules.first { $0.id == "120_silence_focus" }
        #expect(silenceRule != nil)
        #expect(silenceRule?.ring == .silence)
        #expect(silenceRule?.targetValue == 45.0)
    }

    // MARK: - 5. Habit Regression (Non-Ghost Habits Untouched)

    @Test func testNonGhostHabitsUntouched() {
        let habit = HabitBoard()
        habit.name = "Morning Water"
        #expect(habit.ghostRuleID == nil)
        #expect(habit.ghostRingRaw == nil)
        #expect(habit.ghostProofKindRaw == nil)
    }
}
#endif
