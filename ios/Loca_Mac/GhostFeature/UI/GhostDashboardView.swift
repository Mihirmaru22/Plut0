import SwiftUI
import SwiftData

/// Master Ghost Mode / Winter Arc Dashboard Canvas.
/// Sovereign personal operating surface for 120-day silence and discipline.
public struct GhostDashboardView: View {

    @State private var activeSeason: GhostSeason? = nil
    @State private var todayRecord: GhostDay? = nil
    @State private var streakStatus: GhostEngine.StreakStatus = GhostEngine.StreakStatus(
        currentStreak: 0, bestStreak: 0, rank: .uninitiated, isDented: false, totalGhostDays: 0
    )
    @State private var ridgePoints: [GhostRidgePoint] = []
    @State private var isLoading: Bool = true
    @State private var showOnboardingModal: Bool = false
    @State private var showCheckInSheet: Bool = false
    @State private var isOfflineDark: Bool = false
    @State private var darkStartTime: Date? = nil

    @ObservedObject private var vaultManager: LocaVaultAuthManager = LocaVaultAuthManager.shared
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\JournalNote.date, order: .reverse)])
    private var allJournalNotes: [JournalNote]

    private var recentJournalNotes: [JournalNote] {
        allJournalNotes.filter { !$0.isArchived }
    }

    public init() {}

    public var body: some View {
        Group {
            if vaultManager.isLocked(for: "Ghost Mode") {
                MacVaultLockView(sectionTitle: "Ghost Mode")
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let season = activeSeason {
                dashboardContent(season: season)
            } else {
                emptyContractHero
            }
        }
        .background(Color(red: 0.04, green: 0.04, blue: 0.06))
        .sheet(isPresented: $showOnboardingModal) {
            ContractOnboardingView { newSeason in
                self.activeSeason = newSeason
                loadData()
            }
        }
        .sheet(isPresented: $showCheckInSheet) {
            GhostCheckInSheet {
                loadData()
            }
        }
        .onAppear {
            loadData()
        }
    }

    // MARK: - Active Dashboard

    private func dashboardContent(season: GhostSeason) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header: Season Title, Doctrine Tag, Streak Rank Badge & Check-In Action
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(red: 0.0, green: 0.85, blue: 1.0))
                                .frame(width: 7, height: 7)
                            Text(season.name.uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
                                .tracking(1.5)

                            Text("•")
                                .foregroundStyle(Color.white.opacity(0.3))

                            Text(season.doctrine.title)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.6))
                        }

                        Text("Day \(season.elapsedDays) of \(season.totalDays)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Color.white)
                    }

                    Spacer()

                    // Ghost Streak & Rank Badge
                    HStack(spacing: 12) {
                        // Ghost Glyph with Opacity Matched to Streak
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.04))
                                .frame(width: 44, height: 44)

                            Image(systemName: streakStatus.rank.glyph)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
                                .opacity(streakStatus.rank.opacity)
                        }
                        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text("\(streakStatus.currentStreak)")
                                    .font(.system(size: 18, weight: .black, design: .monospaced))
                                    .foregroundStyle(Color.white)
                                Text("DAY STREAK")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                            }
                            Text(streakStatus.rank.rawValue.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.08, green: 0.08, blue: 0.11), in: RoundedRectangle(cornerRadius: 10))

                    // Evening Check-In Button
                    Button {
                        showCheckInSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil.and.outline")
                                .font(.system(size: 11, weight: .bold))
                            Text("Evening Check-In")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color(red: 0.0, green: 0.85, blue: 1.0), in: RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                }

                // Three Rings Header
                HStack(spacing: 14) {
                    ringCard(
                        ring: .body,
                        isClosed: todayRecord?.bodyClosed ?? false,
                        title: "Body Ring",
                        subtitle: "Physical Forge",
                        statusText: (todayRecord?.bodyClosed ?? false) ? "Sealed Today" : "Pending Action"
                    ) {
                        toggleRingAction(.body)
                    }

                    ringCard(
                        ring: .mind,
                        isClosed: todayRecord?.mindClosed ?? false,
                        title: "Mind Ring",
                        subtitle: "Mental Synthesis",
                        statusText: (todayRecord?.mindClosed ?? false) ? "Sealed Today" : "Pending Reflection"
                    ) {
                        toggleRingAction(.mind)
                    }

                    ringCard(
                        ring: .silence,
                        isClosed: todayRecord?.silenceClosed ?? false,
                        title: "Silence Ring",
                        subtitle: "Focus Silence",
                        statusText: "\(todayRecord?.totalSilenceMinutes ?? 0)m Logged"
                    ) {
                        toggleRingAction(.silence)
                    }
                }

                // Season Ridge Elevation Profile Chart
                GhostRidgeProfileChart(points: ridgePoints)

                // Burnout Risk & Neural Tone Insight
                neuralValenceInsightCard

                // Offline Dark Mode & Actions Row
                HStack(spacing: 14) {
                    // Went Dark Button
                    Button {
                        toggleWentDark()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: isOfflineDark ? "sun.max.fill" : "moon.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(isOfflineDark ? Color.orange : Color(red: 0.0, green: 0.85, blue: 1.0))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(isOfflineDark ? "Resurface to Grid" : "Go Dark (Offline Mode)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.white)
                                Text(isOfflineDark ? "Currently in total off-grid silence" : "Log intentional offline disconnect period")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(Color.white.opacity(0.55))
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isOfflineDark ? Color.orange.opacity(0.08) : Color.white.opacity(0.03))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isOfflineDark ? Color.orange.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)

                    // Export Passport PDF
                    Button {
                        WinterArcPassportPDFGenerator.exportCertificatePDF(
                            season: season,
                            streak: streakStatus.currentStreak,
                            rank: streakStatus.rank,
                            totalGhostDays: streakStatus.totalGhostDays
                        )
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))

                            VStack(alignment: .leading, spacing: 1) {
                                Text("Export Sovereign Passport PDF")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.white)
                                Text("Authenticated certificate with streak rank")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.white.opacity(0.55))
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.03))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
        }
    }

    // MARK: - Subcomponents

    private func ringCard(
        ring: GhostRing,
        isClosed: Bool,
        title: String,
        subtitle: String,
        statusText: String,
        onToggle: @escaping () -> Void
    ) -> some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 3.5)
                        .frame(width: 42, height: 42)

                    Circle()
                        .trim(from: 0, to: isClosed ? 1.0 : 0.2)
                        .stroke(
                            isClosed ? Color(hex: ring.accentHex) ?? Color.white : Color.white.opacity(0.2),
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 42, height: 42)

                    Image(systemName: isClosed ? "checkmark" : ring.icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isClosed ? Color(hex: ring.accentHex) ?? Color.white : Color.white.opacity(0.4))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white)
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.white.opacity(0.5))
                    Text(statusText)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isClosed ? Color(hex: ring.accentHex) ?? Color.white : Color.white.opacity(0.4))
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isClosed ? (Color(hex: ring.accentHex) ?? Color.white).opacity(0.07) : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isClosed ? (Color(hex: ring.accentHex) ?? Color.white).opacity(0.35) : Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var neuralValenceInsightCard: some View {
        let report = LocaNeuralEngine.analyzeJournalNotes(recentJournalNotes)
        let isBurnoutRisk = report.averageSentiment < -0.15 && report.totalEntriesAnalyzed >= 5

        return HStack(spacing: 12) {
            Image(systemName: isBurnoutRisk ? "exclamationmark.triangle.fill" : "brain.head.profile")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(isBurnoutRisk ? Color.orange : Color(red: 0.0, green: 0.85, blue: 1.0))

            VStack(alignment: .leading, spacing: 2) {
                Text(isBurnoutRisk ? "Burnout Risk Detected — Recovery Advisory" : "Neural Engine Cognitive State")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white)

                Text(isBurnoutRisk
                     ? "Your 14-day journal valence trend indicates mental strain. Emphasize full-night sleep debt recovery and non-stimulant walks."
                     : "\(report.toneLabel) • Tone Score: \(String(format: "%.2f", report.averageSentiment)) • \(report.correlationInsight)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.65))
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isBurnoutRisk ? Color.orange.opacity(0.08) : Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isBurnoutRisk ? Color.orange.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - Empty State

    private var emptyContractHero: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.06))
                    .frame(width: 88, height: 88)

                Image(systemName: "sparkles")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
            }
            .overlay(Circle().stroke(Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.25), lineWidth: 1))

            VStack(spacing: 6) {
                Text("GHOST MODE: THE WINTER ARC")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
                    .tracking(2.0)

                Text("Disappear for 120 Days")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.white)

                Text("Sign the sovereign covenant to seal the Three Rings (Body, Mind, Silence) and ascend the Season Ridge.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            Button {
                showOnboardingModal = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "seal.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Sign Season Contract")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Color.black)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(red: 0.0, green: 0.85, blue: 1.0), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(32)
    }

    // MARK: - Actions

    private func loadData() {
        Task {
            let season = try? await GhostEngine.shared.fetchActiveSeason()
            let day = try? await GhostEngine.shared.getOrCreateDayRecord(for: Date())
            let streak = (try? await GhostEngine.shared.computeStreakStatus()) ?? streakStatus
            let ridge = (try? await GhostEngine.shared.fetchRidgeSeries()) ?? []

            await MainActor.run {
                self.activeSeason = season
                self.todayRecord = day
                self.streakStatus = streak
                self.ridgePoints = ridge
                self.isLoading = false
            }
        }
    }

    private func toggleRingAction(_ ring: GhostRing) {
        guard let day = todayRecord else { return }
        Haptics.impact(.medium)
        let isCurrentlyClosed: Bool
        switch ring {
        case .body:    isCurrentlyClosed = day.bodyClosed
        case .mind:    isCurrentlyClosed = day.mindClosed
        case .silence: isCurrentlyClosed = day.silenceClosed
        }

        Task {
            let updated = try? await GhostEngine.shared.toggleRing(ring: ring, isClosed: !isCurrentlyClosed)
            let streak = try? await GhostEngine.shared.computeStreakStatus()
            let ridge = (try? await GhostEngine.shared.fetchRidgeSeries()) ?? []
            await MainActor.run {
                if let updated = updated { self.todayRecord = updated }
                if let streak = streak { self.streakStatus = streak }
                self.ridgePoints = ridge
            }
        }
    }

    private func toggleWentDark() {
        Haptics.impact(.rigid)
        if !isOfflineDark {
            isOfflineDark = true
            darkStartTime = Date()
        } else {
            isOfflineDark = false
            if let start = darkStartTime {
                let finish = Date()
                Task {
                    _ = try? await GhostEngine.shared.recordOfflineInterval(start: start, end: finish)
                    loadData()
                }
            }
            darkStartTime = nil
        }
    }
}
