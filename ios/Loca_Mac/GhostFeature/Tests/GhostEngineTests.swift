#if canImport(Testing)
import Foundation
import Testing
import SwiftData

/// Exhaustive unit tests for Ghost Mode / Winter Arc engine, receipts, ring calculations, streak doctrines, chain grid, and vector passport.
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

    // MARK: - 5. MRZ Round-Trip Encoding & Decoding

    @Test func testMRZRoundTripEncodingAndDecoding() {
        let callsign = "SPIDERMAN"
        let serial = "WA26-MAC1-9A3F"
        let doctrine = GhostDoctrine.hard
        let expiry = Date(timeIntervalSince1970: 1798761600) // 2026-12-31
        let ghostDays = 42

        let (line1, line2) = WinterArcMRZEngine.encode(
            callsign: callsign,
            serial: serial,
            doctrine: doctrine,
            expiryDate: expiry,
            ghostDays: ghostDays
        )

        #expect(line1.count == 44)
        #expect(line2.count == 44)
        #expect(line1.hasPrefix("P<PLTSPIDERMAN"))

        let decoded = WinterArcMRZEngine.decode(line1: line1, line2: line2)
        #expect(decoded != nil)
        #expect(decoded?.callsign == "SPIDERMAN")
        #expect(decoded?.doctrine == "HARD")
        #expect(decoded?.ghostDays == 42)
    }

    // MARK: - 6. Vector Passport PDF Generation

    @Test @MainActor func testPassportPDFGenerationDayZero() {
        let season = GhostSeason(name: "The Winter Arc 2026")
        let streak = GhostEngine.StreakStatus(currentStreak: 0, bestStreak: 0, effectiveDayNumber: 1, isRestarted: false, rank: .uninitiated, isDented: false, totalGhostDays: 0)
        let passportData = WinterArcPassportData(season: season, streakStatus: streak, callsign: "NEO")

        let pdfData = WinterArcPassportPDFGenerator.generatePDFData(data: passportData)
        #expect(!pdfData.isEmpty)
        #expect(pdfData.count > 1000)

        // Check PDF Header Magic
        let header = String(data: pdfData.prefix(5), encoding: .ascii)
        #expect(header == "%PDF-")
    }

    // MARK: - 7. Habit Regression (Non-Ghost Habits Untouched)

    @Test func testNonGhostHabitsUntouched() {
        let habit = HabitBoard()
        habit.name = "Morning Water"
        #expect(habit.ghostRuleID == nil)
        #expect(habit.ghostRingRaw == nil)
        #expect(habit.ghostProofKindRaw == nil)
    }

    // MARK: - 8. Custom Protocol Rules & Ordering

    @Test func testCustomRuleCreationAndDefaults() {
        let custom = GhostProtocolRule(
            id: "custom_cold_shower",
            title: "Cold Shower",
            subtitle: "3 mins icy water",
            ring: .body,
            phase: .morning,
            proofKind: .duration,
            targetValue: 3.0,
            unitLabel: "mins",
            icon: "drop.fill",
            isCustom: true,
            isEnabled: true,
            sortOrder: 10
        )

        #expect(custom.isCustom)
        #expect(custom.isEnabled)
        #expect(custom.ring == .body)
        #expect(custom.targetValue == 3.0)
    }

    // MARK: - 9. Season Final Stats & Lifecycle Snapshot

    @Test func testSeasonFinalStatsSerialization() throws {
        let stats = SeasonFinalStats(
            totalGhostDays: 85,
            totalElapsedDays: 120,
            bestStreak: 45,
            finalStreak: 12,
            completionRate: 70.83,
            bodyRate: 90.0,
            mindRate: 85.0,
            silenceRate: 75.0,
            averageScore: 82.5,
            finalRank: "wraith"
        )

        let encoded = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode(SeasonFinalStats.self, from: encoded)

        #expect(decoded.totalGhostDays == 85)
        #expect(decoded.finalRank == "wraith")
        #expect(decoded.completionRate == 70.83)
    }

    // MARK: - 10. Time-of-Day Pattern & Burnout Risk Math

    @Test func testTimeOfDayPatternDistribution() {
        var hourly: [Int: Int] = [:]
        hourly[7] = 10  // 7 AM morning
        hourly[8] = 5   // 8 AM morning
        hourly[14] = 3  // 2 PM afternoon
        hourly[21] = 2  // 9 PM evening

        let pattern = TimeOfDayPattern(hourlyCounts: hourly)
        #expect(pattern.peakHour == 7)
        #expect(pattern.morningShare > 0.7)
    }

    @Test func testBurnoutRiskScoreLevels() {
        let lowRisk = BurnoutRisk(score: 15, recentGhostRate: 0.9, missedDayCluster: 0)
        #expect(lowRisk.riskLevel == .low)

        let moderateRisk = BurnoutRisk(score: 45, recentGhostRate: 0.6, missedDayCluster: 1)
        #expect(moderateRisk.riskLevel == .moderate)

        let elevatedRisk = BurnoutRisk(score: 70, recentGhostRate: 0.4, missedDayCluster: 2)
        #expect(elevatedRisk.riskLevel == .elevated)

        let highRisk = BurnoutRisk(score: 90, recentGhostRate: 0.1, missedDayCluster: 4)
        #expect(highRisk.riskLevel == .high)
    }

    // MARK: - 11. Season Comparison Deltas

    @Test func testSeasonComparisonDeltaCalculations() {
        let sideA = SeasonComparison.Side(
            id: "season_1",
            name: "Winter Arc 1",
            protocolKind: "The 120",
            totalDays: 120,
            ghostDays: 60,
            completionRate: 50.0,
            bestStreak: 14,
            bodyRate: 60.0,
            mindRate: 70.0,
            silenceRate: 50.0,
            averageScore: 65.0,
            rank: "shadow"
        )

        let sideB = SeasonComparison.Side(
            id: "season_2",
            name: "Winter Arc 2",
            protocolKind: "The 120",
            totalDays: 120,
            ghostDays: 90,
            completionRate: 75.0,
            bestStreak: 30,
            bodyRate: 85.0,
            mindRate: 80.0,
            silenceRate: 75.0,
            averageScore: 82.0,
            rank: "phantom"
        )

        let comp = SeasonComparison(seasonA: sideA, seasonB: sideB)
        #expect(comp.completionDelta == 25.0)
        #expect(comp.bestStreakDelta == 16)
        #expect(comp.ghostDaysDelta == 30)
        #expect(comp.scoreDelta == 17.0)
    }
}
#endif

