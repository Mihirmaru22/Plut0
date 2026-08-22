import SwiftUI
import SwiftData

/// Master Ghost Mode / Winter Arc Dashboard Canvas.
/// Sovereign personal operating surface for 120-day silence, Protocol Board receipts, and chain execution.
public struct GhostDashboardView: View {

    @State private var activeSeason: GhostSeason? = nil
    @State private var todayRecord: GhostDay? = nil
    @State private var streakStatus: GhostEngine.StreakStatus = GhostEngine.StreakStatus()
    @State private var ridgePoints: [GhostRidgePoint] = []
    @State private var protocolRules: [GhostProtocolRule] = []
    @State private var todayReceipts: [GhostReceipt] = []
    @State private var chainCells: [GhostEngine.GhostChainCell] = []
    @State private var darkHoursSummary: GhostEngine.DarkHoursSummary = GhostEngine.DarkHoursSummary(
        todayMinutes: 0, weekMinutes: 0, longestStretchMinutes: 0, recentIntervals: []
    )
    @State private var evolutionReport: GhostEngine.GhostEvolutionReport = GhostEngine.GhostEvolutionReport(
        weeklyGhostRate: 0, bodyAdherence: 0, mindAdherence: 0, silenceAdherence: 0, ruleAdherences: [], suggestion: ""
    )
    @State private var photoArtifacts: [GhostEngine.GhostPhotoArtifact] = []

    @State private var isLoading: Bool = true
    @State private var showOnboardingModal: Bool = false
    @State private var showCheckInSheet: Bool = false
    @State private var showPhotoWallModal: Bool = false
    @State private var selectedLedgerCell: GhostEngine.GhostChainCell? = nil
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
        .sheet(isPresented: $showPhotoWallModal) {
            GhostPhotoWallView(photos: photoArtifacts)
        }
        .sheet(item: $selectedLedgerCell) { cell in
            dayLedgerSheet(cell: cell)
        }
        .onAppear {
            loadData()
        }
    }

    // MARK: - Active Dashboard

    private func dashboardContent(season: GhostSeason) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Top Master Header
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

                        if streakStatus.isRestarted && season.doctrine == .hard {
                            HStack(spacing: 8) {
                                Text("Day \(streakStatus.effectiveDayNumber)")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(Color.white)
                                Text("• Back to Day 1 (Season Day \(season.elapsedDays) of \(season.totalDays))")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.55))
                            }
                        } else {
                            Text("Day \(season.elapsedDays) of \(season.totalDays)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(Color.white)
                        }
                    }

                    Spacer()

                    // Ghost Streak & Rank Badge
                    HStack(spacing: 12) {
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

                    // Photo Wall Button
                    Button {
                        showPhotoWallModal = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "photo.stack.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("Photo Wall")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)

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

                // Three Rings Header (Dynamic Next Task Name)
                HStack(spacing: 14) {
                    let nextBody = GhostEngine.shared.nextPendingRule(for: .body, receipts: todayReceipts, rules: protocolRules)
                    ringCard(
                        ring: .body,
                        isClosed: todayRecord?.bodyClosed ?? false,
                        title: "Body Ring",
                        subtitle: "Physical Forge",
                        statusText: (todayRecord?.bodyClosed ?? false) ? "Sealed Today" : (nextBody ?? "Pending Task")
                    ) {
                        toggleRingAction(.body)
                    }

                    let nextMind = GhostEngine.shared.nextPendingRule(for: .mind, receipts: todayReceipts, rules: protocolRules)
                    ringCard(
                        ring: .mind,
                        isClosed: todayRecord?.mindClosed ?? false,
                        title: "Mind Ring",
                        subtitle: "Mental Synthesis",
                        statusText: (todayRecord?.mindClosed ?? false) ? "Sealed Today" : (nextMind ?? "Pending Reflection")
                    ) {
                        toggleRingAction(.mind)
                    }

                    let nextSilence = GhostEngine.shared.nextPendingRule(for: .silence, receipts: todayReceipts, rules: protocolRules)
                    ringCard(
                        ring: .silence,
                        isClosed: todayRecord?.silenceClosed ?? false,
                        title: "Silence Ring",
                        subtitle: "Focus Silence",
                        statusText: (todayRecord?.silenceClosed ?? false) ? "\(todayRecord?.totalSilenceMinutes ?? 0)m Logged" : (nextSilence ?? "45m Focus")
                    ) {
                        toggleRingAction(.silence)
                    }
                }

                // Daily Protocol Board
                GhostProtocolBoardView(
                    rules: protocolRules,
                    receipts: todayReceipts
                ) { rule, proofKind, value, photoPath in
                    handleLogReceipt(rule: rule, proofKind: proofKind, value: value, photoPath: photoPath)
                }

                // 120-Day Discipline Chain Grid
                GhostChainGridView(cells: chainCells) { cell in
                    selectedLedgerCell = cell
                }

                // Season Ridge Mountain Elevation Profile Chart
                GhostRidgeProfileChart(points: ridgePoints)

                // Dark Hours Silence Strip
                GhostDarkHoursStrip(summary: darkHoursSummary)

                // Weekly Evolution Card
                GhostEvolutionCard(report: evolutionReport)

                // Neural Tone Insight
                neuralValenceInsightCard

                // Offline Dark Mode & PDF Actions Row
                HStack(spacing: 14) {
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
                        .foregroundStyle(isClosed ? Color(hex: ring.accentHex) ?? Color.white : Color.white.opacity(0.6))
                        .lineLimit(1)
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

    // MARK: - Day Ledger Sheet

    private func dayLedgerSheet(cell: GhostEngine.GhostChainCell) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DAY LEDGER • DAY \(cell.dayIndex)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
                        .tracking(1.0)
                    Text(cell.dateString)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)
                }
                Spacer()
                Button("Done") {
                    selectedLedgerCell = nil
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
            }

            Divider().opacity(0.12)

            HStack(spacing: 12) {
                ledgerBadge(label: "Body Ring", isClosed: cell.bodyClosed, color: Color(hex: "#E54D2E") ?? .red)
                ledgerBadge(label: "Mind Ring", isClosed: cell.mindClosed, color: Color(hex: "#3E63DD") ?? .blue)
                ledgerBadge(label: "Silence Ring", isClosed: cell.silenceClosed, color: Color(hex: "#0091FF") ?? .cyan)
            }

            Text("Daily Score: \(cell.score)/100 • \(cell.ghostDay ? "🔥 Ghost Day Achieved" : "Unsealed")")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(cell.ghostDay ? Color(red: 0.0, green: 0.85, blue: 1.0) : Color.white.opacity(0.6))
        }
        .padding(20)
        .frame(width: 400, height: 200)
        .background(Color(red: 0.07, green: 0.07, blue: 0.10))
    }

    private func ledgerBadge(label: String, isClosed: Bool, color: Color) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(isClosed ? color : Color.white.opacity(0.1))
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isClosed ? Color.white : Color.white.opacity(0.4))
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
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
            let rules = GhostEngine.shared.fetchRules(for: season)
            let receipts = (try? await GhostEngine.shared.fetchReceipts(for: Date())) ?? []
            let grid = (try? await GhostEngine.shared.fetchChainGrid()) ?? []
            let dark = (try? await GhostEngine.shared.fetchDarkHoursSummary()) ?? darkHoursSummary
            let evo = (try? await GhostEngine.shared.fetchEvolutionReport()) ?? evolutionReport
            let photos = (try? await GhostEngine.shared.fetchAllPhotoArtifacts()) ?? []

            await MainActor.run {
                self.activeSeason = season
                self.todayRecord = day
                self.streakStatus = streak
                self.ridgePoints = ridge
                self.protocolRules = rules
                self.todayReceipts = receipts
                self.chainCells = grid
                self.darkHoursSummary = dark
                self.evolutionReport = evo
                self.photoArtifacts = photos
                self.isLoading = false
            }
        }
    }

    private func handleLogReceipt(rule: GhostProtocolRule, proofKind: GhostProofKind, value: Double, photoPath: String?) {
        Task {
            if let result = try? await GhostEngine.shared.logReceipt(
                ruleID: rule.id,
                proofKind: proofKind,
                value: value,
                photoPath: photoPath
            ) {
                let streak = (try? await GhostEngine.shared.computeStreakStatus()) ?? streakStatus
                let ridge = (try? await GhostEngine.shared.fetchRidgeSeries()) ?? []
                let grid = (try? await GhostEngine.shared.fetchChainGrid()) ?? []
                let photos = (try? await GhostEngine.shared.fetchAllPhotoArtifacts()) ?? []

                await MainActor.run {
                    self.todayRecord = result.day
                    self.todayReceipts = result.receipts
                    self.streakStatus = streak
                    self.ridgePoints = ridge
                    self.chainCells = grid
                    self.photoArtifacts = photos
                }
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
            let grid = (try? await GhostEngine.shared.fetchChainGrid()) ?? []
            await MainActor.run {
                if let updated = updated { self.todayRecord = updated }
                if let streak = streak { self.streakStatus = streak }
                self.ridgePoints = ridge
                self.chainCells = grid
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
