import SwiftUI

/// Ghost Mode — Page 3: Intel Dashboard
/// Ring trend charts, rule forensics with drilldowns, time patterns, weekday adherence, campaign history, and season comparisons.
public struct GhostIntelView: View {

    @State private var analyticsReport: GhostAnalyticsReport = GhostAnalyticsReport()
    @State private var allSeasons:      [GhostSeason]        = []
    @State private var isLoading:       Bool                  = true
    @State private var trendWindow:     Int                   = 30
    @State private var expandedSeasonID: String?             = nil

    // Interactive drill-down sheets
    @State private var selectedRuleIDForDetail: String?      = nil
    @State private var showSeasonComparison:     Bool         = false
    @State private var previewPassportData:      WinterArcPassportData? = nil

    public init() {}

    private let windowOptions = [7, 30, 90]

    public var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Computing intel...")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DS.Theme.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        intelHeader
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)

                        Divider().opacity(0.1).padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 20) {
                            // Overview cards
                            overviewCards
                                .padding(.horizontal, 20)
                                .padding(.top, 16)

                            // Burnout Risk
                            burnoutRiskCard
                                .padding(.horizontal, 20)

                            // Ring Trend Charts
                            ringTrendSection
                                .padding(.horizontal, 20)

                            // Rule Forensics
                            ruleForensicsSection
                                .padding(.horizontal, 20)

                            // Time Patterns
                            timePatternsSection
                                .padding(.horizontal, 20)

                            // Weekday Pattern
                            weekdaySection
                                .padding(.horizontal, 20)

                            Divider().opacity(0.1).padding(.horizontal, 20)

                            // Campaign History
                            campaignHistorySection
                                .padding(.horizontal, 20)
                                .padding(.bottom, 24)
                        }
                    }
                }
            }
        }
        .background(DS.Theme.canvas)
        .onAppear { loadIntel() }
        .sheet(item: Binding<IdentifiableString?>(
            get: { selectedRuleIDForDetail.map { IdentifiableString(id: $0) } },
            set: { selectedRuleIDForDetail = $0?.id }
        )) { item in
            GhostRuleDetailSheet(ruleID: item.id)
        }
        .sheet(isPresented: $showSeasonComparison) {
            GhostSeasonComparisonSheet(allSeasons: allSeasons)
        }
        .sheet(item: Binding<IdentifiablePassportData?>(
            get: { previewPassportData.map { IdentifiablePassportData(data: $0) } },
            set: { previewPassportData = $0?.data }
        )) { item in
            GhostPassportPreviewSheet(passportData: item.data)
        }
    }

    // MARK: - Intel Header

    private var intelHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("GHOST INTEL")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.Theme.amber)
                    .tracking(1.5)
                Text("Discipline Forensics")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DS.Theme.textPrimary)
            }
            Spacer()
            // Window picker
            HStack(spacing: 4) {
                ForEach(windowOptions, id: \.self) { days in
                    Button {
                        trendWindow = days
                        loadIntel()
                    } label: {
                        Text("\(days)d")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(trendWindow == days ? DS.Theme.amber : DS.Theme.textTertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                trendWindow == days ? DS.Theme.amber.opacity(0.12) : DS.Theme.card,
                                in: RoundedRectangle(cornerRadius: 5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Overview Cards

    private var overviewCards: some View {
        HStack(spacing: 10) {
            intelCard(
                value: String(format: "%.0f%%", analyticsReport.overallCompletionRate),
                label: "Completion",
                accent: DS.Theme.emerald
            )
            intelCard(
                value: "\(analyticsReport.currentStreak)",
                label: "Streak",
                accent: DS.Theme.amber
            )
            intelCard(
                value: "\(analyticsReport.bestStreak)",
                label: "Best",
                accent: DS.Theme.cyan
            )
            intelCard(
                value: String(format: "%.0f", analyticsReport.averageScore),
                label: "Avg Score",
                accent: DS.Theme.textSecondary
            )
        }
    }

    private func intelCard(value: String, label: String, accent: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundStyle(accent)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.Theme.textMuted)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(DS.Theme.border, lineWidth: 1))
    }

    // MARK: - Burnout Risk

    private var burnoutRiskCard: some View {
        let risk = analyticsReport.burnoutRisk
        let color: Color = {
            switch risk.riskLevel {
            case .low:      return DS.Theme.emerald
            case .moderate: return DS.Theme.amber
            case .elevated: return .orange
            case .high:     return DS.Theme.coral
            }
        }()

        return HStack(spacing: 12) {
            // Gauge
            ZStack {
                Circle()
                    .stroke(DS.Theme.border, lineWidth: 4)
                    .frame(width: 52, height: 52)
                Circle()
                    .trim(from: 0, to: CGFloat(risk.score) / 100.0)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 52, height: 52)
                    .animation(.easeOut(duration: 0.6), value: risk.score)
                Text("\(risk.score)")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("BURNOUT RISK")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.Theme.textTertiary)
                        .tracking(1.2)
                    Text(risk.riskLevel.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.15), in: Capsule())
                }
                Text(risk.advisory)
                    .font(.system(size: 11, design: .serif))
                    .foregroundStyle(DS.Theme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Ring Trend Charts

    private var ringTrendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Ring Trends · \(trendWindow)-Day Window")

            VStack(spacing: 8) {
                ForEach(GhostRing.allCases) { ring in
                    let windows = analyticsReport.trendWindows[ring] ?? []
                    ringTrendRow(ring: ring, windows: windows)
                }
            }
        }
    }

    private func ringTrendRow(ring: GhostRing, windows: [RingTrendWindow]) -> some View {
        let ringColor: Color = {
            switch ring {
            case .body:    return Color(hex: "#E54D2E")
            case .mind:    return Color(hex: "#3E63DD")
            case .silence: return Color(hex: "#0091FF")
            }
        }()

        let avgRate = windows.isEmpty ? 0.0 : windows.map(\.completionRate).reduce(0, +) / Double(windows.count)

        return HStack(spacing: 10) {
            Text(ring.title.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(ringColor)
                .frame(width: 52, alignment: .leading)

            // Bar chart
            HStack(spacing: 3) {
                ForEach(windows.indices, id: \.self) { i in
                    let w = windows[i]
                    VStack(spacing: 2) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ringColor.opacity(0.2 + w.completionRate * 0.8))
                            .frame(height: max(4, 48 * w.completionRate))
                    }
                    .frame(maxWidth: .infinity, maxHeight: 48)
                }
            }
            .frame(height: 48)

            Text(String(format: "%.0f%%", avgRate * 100))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(avgRate > 0.7 ? DS.Theme.emerald : avgRate > 0.4 ? DS.Theme.amber : DS.Theme.coral)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(10)
        .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Theme.border, lineWidth: 1))
    }

    // MARK: - Rule Forensics

    private var ruleForensicsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("Rule Forensics · Sorted by Ghost Day Correlation")
                Spacer()
                Text("Click row to inspect")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(DS.Theme.textMuted)
            }

            VStack(spacing: 2) {
                // Header
                HStack {
                    Text("Rule")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Rate")
                        .frame(width: 44, alignment: .trailing)
                    Text("Correlation")
                        .frame(width: 80, alignment: .trailing)
                    Text("Trend")
                        .frame(width: 66, alignment: .trailing)
                }
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.Theme.textMuted)
                .padding(.horizontal, 10)
                .padding(.bottom, 4)

                ForEach(analyticsReport.ruleCorrelations) { correlation in
                    Button {
                        selectedRuleIDForDetail = correlation.ruleID
                    } label: {
                        forensicsRow(correlation)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func forensicsRow(_ c: RuleCorrelation) -> some View {
        let ringColor: Color = {
            switch c.ring {
            case .body:    return Color(hex: "#E54D2E")
            case .mind:    return Color(hex: "#3E63DD")
            case .silence: return Color(hex: "#0091FF")
            }
        }()
        let coeffStr = String(format: "%.2f", c.correlationCoefficient)
        let rateStr  = String(format: "%.0f%%", c.completionRate * 100)
        let coeffColor: Color = c.correlationCoefficient > 0.6 ? DS.Theme.emerald :
                                c.correlationCoefficient > 0.3 ? DS.Theme.amber : DS.Theme.textTertiary

        return HStack(spacing: 0) {
            // Ring dot
            Circle()
                .fill(ringColor)
                .frame(width: 6, height: 6)
                .padding(.trailing, 8)

            Text(c.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DS.Theme.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(rateStr)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.Theme.textSecondary)
                .frame(width: 44, alignment: .trailing)

            Text(coeffStr)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(coeffColor)
                .frame(width: 80, alignment: .trailing)

            HStack(spacing: 3) {
                Image(systemName: c.trendDirection.icon)
                    .font(.system(size: 10, weight: .bold))
                Text(c.trendDirection.label.prefix(2))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(
                c.trendDirection == .improving ? DS.Theme.emerald :
                c.trendDirection == .declining ? DS.Theme.coral : DS.Theme.textTertiary
            )
            .frame(width: 66, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Time Patterns

    private var timePatternsSection: some View {
        let pattern = analyticsReport.timePattern
        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("When You Execute")

            HStack(spacing: 10) {
                timeShareCard("Morning", pattern.morningShare, "sunrise.fill", DS.Theme.amber)
                timeShareCard("Afternoon", pattern.afternoonShare, "sun.max.fill", DS.Theme.cyan)
                timeShareCard("Evening", pattern.eveningShare, "moon.stars.fill", DS.Theme.violet)
            }

            // Hour bars
            HStack(spacing: 2) {
                ForEach(0..<24, id: \.self) { hr in
                    let count = pattern.hourlyCounts[hr] ?? 0
                    let maxCount = max(1, pattern.hourlyCounts.values.max() ?? 1)
                    let ratio = CGFloat(count) / CGFloat(maxCount)
                    VStack(spacing: 2) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(hr == pattern.peakHour ? DS.Theme.amber : DS.Theme.cyan.opacity(0.5))
                            .frame(height: max(2, 32 * ratio))
                        if hr % 6 == 0 {
                            Text("\(hr)h")
                                .font(.system(size: 7, design: .monospaced))
                                .foregroundStyle(DS.Theme.textMuted)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: 44)
                }
            }
            .padding(10)
            .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Theme.border, lineWidth: 1))
        }
    }

    private func timeShareCard(_ label: String, _ share: Double, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(String(format: "%.0f%%", share * 100))
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(DS.Theme.textPrimary)
                Text(label)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(DS.Theme.textMuted)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Theme.border, lineWidth: 1))
    }

    // MARK: - Weekday Pattern

    private var weekdaySection: some View {
        let pattern = analyticsReport.weekdayPattern
        let names   = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Weekday Adherence")

            HStack(spacing: 6) {
                ForEach(1...7, id: \.self) { wd in
                    let rate  = pattern.ghostRateByWeekday[wd] ?? 0.0
                    let isBest  = wd == pattern.bestWeekday
                    let isWorst = wd == pattern.worstWeekday
                    let barColor: Color = isBest ? DS.Theme.emerald : isWorst ? DS.Theme.coral : DS.Theme.cyan.opacity(0.6)

                    VStack(spacing: 4) {
                        Text(String(format: "%.0f%%", rate * 100))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(DS.Theme.textSecondary)

                        GeometryReader { geo in
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(barColor)
                                    .frame(height: max(4, geo.size.height * rate))
                            }
                        }
                        .frame(height: 40)

                        Text(names[(wd - 1) % 7])
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(isBest ? DS.Theme.emerald : isWorst ? DS.Theme.coral : DS.Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(12)
            .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Theme.border, lineWidth: 1))
        }
    }

    // MARK: - Campaign History

    private var campaignHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("Campaign History · \(allSeasons.filter(\.isCompleted).count) Archives")
                Spacer()
                if allSeasons.count >= 2 {
                    Button {
                        showSeasonComparison = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 10, weight: .bold))
                            Text("Compare Seasons")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(DS.Theme.amber)
                    }
                    .buttonStyle(.plain)
                }
            }

            let completed = allSeasons.filter(\.isCompleted)
            if completed.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(DS.Theme.textMuted)
                        Text("No completed seasons yet")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Theme.textMuted)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
            } else {
                ForEach(completed) { season in
                    campaignRow(season)
                }
            }
        }
    }

    private func campaignRow(_ season: GhostSeason) -> some View {
        let stats    = season.finalStats
        let expanded = expandedSeasonID == season.id

        return VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedSeasonID = expanded ? nil : season.id
                }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(season.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(DS.Theme.textPrimary)
                        Text("\(formatDate(season.startDate)) → \(formatDate(season.completedAt ?? season.endDate))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(DS.Theme.textTertiary)
                    }
                    Spacer()
                    if let stats = stats {
                        Text(String(format: "%.0f%%", stats.completionRate))
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundStyle(
                                stats.completionRate > 80 ? DS.Theme.emerald :
                                stats.completionRate > 50 ? DS.Theme.amber : DS.Theme.coral
                            )
                        Text(stats.finalRank.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(DS.Theme.amber)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DS.Theme.amber.opacity(0.12), in: Capsule())
                    }
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DS.Theme.textMuted)
                }
                .padding(12)
            }
            .buttonStyle(.plain)

            if expanded, let stats = stats {
                Divider().opacity(0.1)
                campaignExpandedStats(season, stats)
                    .padding(12)
            }
        }
        .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(DS.Theme.border, lineWidth: 1))
    }

    private func campaignExpandedStats(_ season: GhostSeason, _ stats: SeasonFinalStats) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                miniStatChip("\(stats.totalGhostDays)", "Ghost Days", DS.Theme.amber)
                miniStatChip("\(stats.bestStreak)",      "Best Streak", DS.Theme.cyan)
                miniStatChip(String(format: "%.0f", stats.averageScore), "Avg Score", DS.Theme.emerald)
            }
            HStack(spacing: 6) {
                ringBar("Body",    stats.bodyRate,    Color(hex: "#E54D2E"))
                ringBar("Mind",    stats.mindRate,    Color(hex: "#3E63DD"))
                ringBar("Silence", stats.silenceRate, Color(hex: "#0091FF"))
            }

            Button {
                let passport = WinterArcPassportData(
                    season: season,
                    streakStatus: GhostEngine.StreakStatus(
                        currentStreak: stats.finalStreak,
                        bestStreak: stats.bestStreak,
                        effectiveDayNumber: stats.totalElapsedDays,
                        isRestarted: false,
                        rank: GhostRank.allCases.first(where: { $0.rawValue.lowercased() == stats.finalRank.lowercased() }) ?? .uninitiated,
                        isDented: false,
                        totalGhostDays: stats.totalGhostDays
                    ),
                    callsign: season.name
                )
                previewPassportData = passport
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "doc.richtext.fill")
                        .font(.system(size: 11))
                    Text("Preview Passport Booklet")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(DS.Theme.amber)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(DS.Theme.amber.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
    }

    private func miniStatChip(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(color)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(DS.Theme.surface, in: RoundedRectangle(cornerRadius: 6))
    }

    private func ringBar(_ label: String, _ rate: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DS.Theme.textTertiary)
                Spacer()
                Text(String(format: "%.0f%%", rate))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(DS.Theme.border)
                    RoundedRectangle(cornerRadius: 2).fill(color).frame(width: geo.size.width * rate / 100.0)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(DS.Theme.textTertiary)
            .tracking(1.2)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yy"
        return f.string(from: date)
    }

    private func loadIntel() {
        isLoading = true
        Task {
            let report  = (try? await GhostEngine.shared.fetchAnalyticsReport(windowDays: trendWindow)) ?? GhostAnalyticsReport()
            let seasons = (try? await GhostEngine.shared.fetchAllSeasons()) ?? []
            await MainActor.run {
                self.analyticsReport = report
                self.allSeasons      = seasons
                self.isLoading       = false
            }
        }
    }
}

// MARK: - Identifiable Wrappers

private struct IdentifiableString: Identifiable {
    let id: String
}

private struct IdentifiablePassportData: Identifiable {
    var id: String { data.serial }
    let data: WinterArcPassportData
}
