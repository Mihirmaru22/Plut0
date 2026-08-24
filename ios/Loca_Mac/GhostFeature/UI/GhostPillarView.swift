import SwiftUI
import SwiftData

/// Ghost Mode — Root Pillar View
/// 3-tab inner navigation: Today / Season / Intel
/// Replaces the old single-scroll GhostDashboardView.
public struct GhostPillarView: View {

    public enum Tab: String, CaseIterable {
        case today    = "today"
        case progress = "progress"

        var label: String {
            switch self {
            case .today:    return "Today"
            case .progress: return "Visual Progress & Charts"
            }
        }

        var icon: String {
            switch self {
            case .today:    return "scope"
            case .progress: return "chart.xyaxis.line"
            }
        }
    }

    // MARK: - State

    @State private var selectedTab:      Tab = .today
    @State private var activeSeason:     GhostSeason? = nil
    @State private var todayRecord:      GhostDay? = nil
    @State private var streakStatus:     GhostEngine.StreakStatus = GhostEngine.StreakStatus()
    @State private var ridgePoints:      [GhostRidgePoint] = []
    @State private var protocolRules:    [GhostProtocolRule] = []
    @State private var todayReceipts:    [GhostReceipt] = []
    @State private var chainCells:       [GhostEngine.GhostChainCell] = []
    @State private var darkHoursSummary: GhostEngine.DarkHoursSummary = GhostEngine.DarkHoursSummary()
    @State private var evolutionReport:  GhostEngine.GhostEvolutionReport = GhostEngine.GhostEvolutionReport()
    @State private var photoArtifacts:   [GhostEngine.GhostPhotoArtifact] = []
    @State private var isOfflineDark:    Bool = false
    @State private var darkStartTime:    Date? = nil
    @State private var isLoading:        Bool = true

    @State private var showOnboarding:     Bool = false
    @State private var showPhotoWall:      Bool = false
    @State private var showRuleEditor:     Bool = false
    @State private var showNewSeason:      String = ""
    @State private var previewPassportData: WinterArcPassportData? = nil

    @ObservedObject private var vaultManager: LocaVaultAuthManager = LocaVaultAuthManager.shared

    public init() {}

    public var body: some View {
        Group {
            if vaultManager.isLocked(for: "Ghost Mode") {
                MacVaultLockView(sectionTitle: "Ghost Mode")
            } else if isLoading {
                loadingView
            } else if let season = activeSeason {
                mainContent(season: season)
            } else {
                emptyHero
            }
        }
        .background(.ultraThinMaterial)
        .background(DS.Theme.canvas)
        .sheet(isPresented: $showOnboarding) {
            ContractOnboardingView { newSeason in
                activeSeason = newSeason
                loadData()
            }
            .frame(minWidth: 840, idealWidth: 960, maxWidth: .infinity, minHeight: 640, idealHeight: 740, maxHeight: .infinity)
        }
        .sheet(isPresented: $showPhotoWall) {
            GhostPhotoWallView(photos: photoArtifacts)
        }
        .sheet(isPresented: $showRuleEditor) {
            GhostRuleEditorSheet { rule in
                Task {
                    try? await GhostEngine.shared.saveCustomRule(rule)
                    loadData()
                }
            }
        }
        .sheet(item: Binding<IdentifiablePassportData?>(
            get: { previewPassportData.map { IdentifiablePassportData(data: $0) } },
            set: { previewPassportData = $0?.data }
        )) { item in
            GhostPassportPreviewSheet(passportData: item.data)
        }
        .onAppear { loadData() }
    }

    // MARK: - Main Content

    private func mainContent(season: GhostSeason) -> some View {
        VStack(spacing: 0) {
            // Top bar: season name + streak + tab picker
            topBar(season: season)

            // Tab content
            switch selectedTab {
            case .today:
                GhostTodayView(
                    season:        season,
                    todayRecord:   $todayRecord,
                    protocolRules: $protocolRules,
                    todayReceipts: $todayReceipts,
                    streakStatus:  $streakStatus,
                    onLogReceipt:  handleLogReceipt,
                    onToggleRing:  toggleRingAction,
                    onAddCustomRule: { showRuleEditor = true },
                    onReload:      loadData
                )

            case .progress:
                GhostSeasonView(
                    season:           season,
                    streakStatus:     $streakStatus,
                    ridgePoints:      $ridgePoints,
                    chainCells:       $chainCells,
                    darkHoursSummary: $darkHoursSummary,
                    evolutionReport:  $evolutionReport,
                    photoArtifacts:   $photoArtifacts,
                    isOfflineDark:    $isOfflineDark,
                    darkStartTime:    $darkStartTime,
                    onToggleDark:     toggleDark,
                    onExportPassport: { handlePassportExport(season: season) },
                    onShowPhotoWall:  { showPhotoWall = true },
                    onReconfigureCovenant: { showOnboarding = true },
                    onReload:         loadData
                )
            }
        }
    }

    // MARK: - Top Bar

    private func topBar(season: GhostSeason) -> some View {
        HStack(spacing: 0) {
            // Season identity
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(DS.Theme.amber)
                        .frame(width: 5, height: 5)
                    Text(season.name.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.Theme.amber)
                        .tracking(1.2)
                }
                Text("Day \(season.elapsedDays) of \(season.totalDays)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DS.Theme.textPrimary)
            }
            .frame(minWidth: 160, alignment: .leading)

            Spacer()

            // 3-Tab Picker (centered)
            HStack(spacing: 2) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { selectedTab = tab }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 11, weight: .medium))
                            Text(tab.label)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(selectedTab == tab ? DS.Theme.canvas : DS.Theme.textTertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            selectedTab == tab
                                ? DS.Theme.amber
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(DS.Theme.border, lineWidth: 1))

            Spacer()

            // Right Actions: Reconfigure Covenant + Streak Badge
            HStack(spacing: 8) {
                Button {
                    showOnboarding = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 11, weight: .bold))
                        Text("Covenant")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundStyle(DS.Theme.amber)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(DS.Theme.amber.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Theme.amber.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Reconfigure Sovereign Covenant Protocol & Rules")

                // Streak badge
                HStack(spacing: 6) {
                    Image(systemName: streakStatus.rank.glyph)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DS.Theme.amber)
                        .opacity(streakStatus.rank.opacity)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 3) {
                            Text("\(streakStatus.currentStreak)")
                                .font(.system(size: 15, weight: .black, design: .monospaced))
                                .foregroundStyle(DS.Theme.textPrimary)
                            Text("DAY")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(DS.Theme.textMuted)
                        }
                        Text(streakStatus.rank.rawValue.uppercased())
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(DS.Theme.amber)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Theme.border, lineWidth: 1))
            }
            .frame(minWidth: 160, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(DS.Theme.surface)
        .overlay(
            Rectangle()
                .fill(DS.Theme.border)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading arc data...")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DS.Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty Hero

    private var emptyHero: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(DS.Theme.amber.opacity(0.06))
                    .frame(width: 88, height: 88)
                    .overlay(Circle().stroke(DS.Theme.amber.opacity(0.2), lineWidth: 1))
                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(DS.Theme.amber)
            }

            VStack(spacing: 6) {
                Text("GHOST MODE · THE WINTER ARC")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.Theme.amber)
                    .tracking(2.0)
                Text("Disappear. Execute. Return sovereign.")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DS.Theme.textPrimary)
                Text("Sign the season contract to begin sealing the Three Rings — Body, Mind, and Silence — day by day.")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            Button {
                showOnboarding = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "seal.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Sign Season Contract")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(DS.Theme.canvas)
                .padding(.horizontal, 22)
                .padding(.vertical, 11)
                .background(DS.Theme.amber, in: RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(32)
    }

    // MARK: - Data Loading

    private func loadData() {
        Task {
            let season   = try? await GhostEngine.shared.fetchActiveSeason()
            let day      = try? await GhostEngine.shared.getOrCreateDayRecord(for: Date())
            let streak   = (try? await GhostEngine.shared.computeStreakStatus()) ?? streakStatus
            let ridge    = (try? await GhostEngine.shared.fetchRidgeSeries()) ?? []
            let rules    = await GhostEngine.shared.fetchRules(for: season)
            let receipts = (try? await GhostEngine.shared.fetchReceipts(for: Date())) ?? []
            let grid     = (try? await GhostEngine.shared.fetchChainGrid()) ?? []
            let dark     = (try? await GhostEngine.shared.fetchDarkHoursSummary()) ?? darkHoursSummary
            let evo      = (try? await GhostEngine.shared.fetchEvolutionReport()) ?? evolutionReport
            let photos   = (try? await GhostEngine.shared.fetchAllPhotoArtifacts()) ?? []

            await MainActor.run {
                self.activeSeason     = season
                self.todayRecord      = day
                self.streakStatus     = streak
                self.ridgePoints      = ridge
                self.protocolRules    = rules
                self.todayReceipts    = receipts
                self.chainCells       = grid
                self.darkHoursSummary = dark
                self.evolutionReport  = evo
                self.photoArtifacts   = photos
                self.isLoading        = false
            }
        }
    }

    // MARK: - Actions

    private func handleLogReceipt(rule: GhostProtocolRule, proofKind: GhostProofKind, value: Double, photoPath: String?) {
        Task {
            if let result = try? await GhostEngine.shared.logReceipt(
                ruleID: rule.id, proofKind: proofKind, value: value, photoPath: photoPath
            ) {
                let streak = try? await GhostEngine.shared.computeStreakStatus()
                let ridge  = (try? await GhostEngine.shared.fetchRidgeSeries()) ?? []
                let grid   = (try? await GhostEngine.shared.fetchChainGrid()) ?? []
                await MainActor.run {
                    self.todayRecord = result.day
                    var current = self.todayReceipts.filter { $0.ruleID != rule.id }
                    if let updated = result.receipts.first(where: { $0.ruleID == rule.id }) {
                        current.append(updated)
                    }
                    self.todayReceipts = current
                    if let s = streak { self.streakStatus = s }
                    self.ridgePoints = ridge
                    self.chainCells  = grid
                }
            }
        }
    }

    private func toggleRingAction(_ ring: GhostRing) {
        guard let day = todayRecord else { return }
        let isCurrentlyClosed: Bool
        switch ring {
        case .body:    isCurrentlyClosed = day.bodyClosed
        case .mind:    isCurrentlyClosed = day.mindClosed
        case .silence: isCurrentlyClosed = day.silenceClosed
        }
        Task {
            let updated = try? await GhostEngine.shared.toggleRing(ring: ring, isClosed: !isCurrentlyClosed)
            let streak  = try? await GhostEngine.shared.computeStreakStatus()
            let ridge   = (try? await GhostEngine.shared.fetchRidgeSeries()) ?? []
            let grid    = (try? await GhostEngine.shared.fetchChainGrid()) ?? []
            await MainActor.run {
                if let u = updated { self.todayRecord = u }
                if let s = streak  { self.streakStatus = s }
                self.ridgePoints = ridge
                self.chainCells  = grid
            }
        }
    }

    private func toggleDark() {
        if !isOfflineDark {
            isOfflineDark = true
            darkStartTime = Date()
        } else {
            isOfflineDark = false
            if let start = darkStartTime {
                Task {
                    _ = try? await GhostEngine.shared.recordOfflineInterval(start: start, end: Date())
                    loadData()
                }
            }
            darkStartTime = nil
        }
    }

    private func handlePassportExport(season: GhostSeason) {
        let passportData = WinterArcPassportData(
            season: season,
            streakStatus: streakStatus,
            ridgePoints: ridgePoints,
            days: [],
            receipts: todayReceipts,
            photos: photoArtifacts,
            darkHours: darkHoursSummary,
            evolution: evolutionReport,
            callsign: season.name
        )
        self.previewPassportData = passportData
    }
}

// MARK: - IdentifiablePassportData

private struct IdentifiablePassportData: Identifiable {
    var id: String { data.serial }
    let data: WinterArcPassportData
}

