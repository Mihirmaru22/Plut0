import SwiftUI
import Charts

/// Ghost Mode — Visual Progress & Charts Dashboard.
/// 100% Visual Telemetry:
/// - Hero Progress Gauge & Sovereign Rank
/// - 120-Day Alpine Ridge Elevation Profile Chart (SwiftCharts)
/// - 120-Day Discipline Chain Heatmap Matrix
/// - Weekly 3-Ring Consistency Breakdown Bar Chart (Body, Mind, Silence)
/// - Streak Momentum Badges & Deep Silence Hours
/// - Direct Visual Action Toolbar (Photo Wall, Winter Arc Passport PDF, Covenant Setup)
public struct GhostSeasonView: View {

    let season:         GhostSeason
    @Binding var streakStatus:    GhostEngine.StreakStatus
    @Binding var ridgePoints:     [GhostRidgePoint]
    @Binding var chainCells:      [GhostEngine.GhostChainCell]
    @Binding var darkHoursSummary: GhostEngine.DarkHoursSummary
    @Binding var evolutionReport: GhostEngine.GhostEvolutionReport
    @Binding var photoArtifacts:  [GhostEngine.GhostPhotoArtifact]
    @Binding var isOfflineDark:   Bool
    @Binding var darkStartTime:   Date?

    var onToggleDark:     () -> Void
    var onExportPassport: () -> Void
    var onShowPhotoWall:  () -> Void
    var onReconfigureCovenant: () -> Void = {}
    var onReload:         () -> Void

    @State private var selectedLedgerCell: GhostEngine.GhostChainCell? = nil
    @State private var showCompleteConfirm: Bool = false

    public init(
        season: GhostSeason,
        streakStatus: Binding<GhostEngine.StreakStatus>,
        ridgePoints: Binding<[GhostRidgePoint]>,
        chainCells: Binding<[GhostEngine.GhostChainCell]>,
        darkHoursSummary: Binding<GhostEngine.DarkHoursSummary>,
        evolutionReport: Binding<GhostEngine.GhostEvolutionReport>,
        photoArtifacts: Binding<[GhostEngine.GhostPhotoArtifact]>,
        isOfflineDark: Binding<Bool>,
        darkStartTime: Binding<Date?>,
        onToggleDark: @escaping () -> Void,
        onExportPassport: @escaping () -> Void,
        onShowPhotoWall: @escaping () -> Void,
        onReconfigureCovenant: @escaping () -> Void = {},
        onReload: @escaping () -> Void
    ) {
        self.season = season
        self._streakStatus = streakStatus
        self._ridgePoints = ridgePoints
        self._chainCells = chainCells
        self._darkHoursSummary = darkHoursSummary
        self._evolutionReport = evolutionReport
        self._photoArtifacts = photoArtifacts
        self._isOfflineDark = isOfflineDark
        self._darkStartTime = darkStartTime
        self.onToggleDark = onToggleDark
        self.onExportPassport = onExportPassport
        self.onShowPhotoWall = onShowPhotoWall
        self.onReconfigureCovenant = onReconfigureCovenant
        self.onReload = onReload
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // 1. Hero Season Progress Banner
                heroProgressBanner
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                // 2. High-Impact Streak & Telemetry Metric Pills
                streakMetricsRow
                    .padding(.horizontal, 20)

                // 3. Chart 1: 120-Day Alpine Ridge Elevation Profile
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "mountain.2.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DS.Theme.amber)
                        Text("120-DAY ELEVATION ASCENT RIDGE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(DS.Theme.amber)
                            .tracking(1.2)
                        Spacer()
                        Text("Dec 31 Summit Peak")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(DS.Theme.textTertiary)
                    }

                    GhostRidgeProfileChart(points: ridgePoints)
                }
                .padding(16)
                .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.Theme.border, lineWidth: 1))
                .padding(.horizontal, 20)

                // 4. Chart 2: 120-Day Discipline Chain Heatmap Matrix
                VStack(alignment: .leading, spacing: 10) {
                    GhostChainGridView(cells: chainCells) { cell in
                        selectedLedgerCell = cell
                    }
                }
                .padding(.horizontal, 20)

                // 5. Chart 3: Weekly 3-Ring Consistency Breakdown (SwiftCharts)
                weeklyRingConsistencyChartSection
                    .padding(.horizontal, 20)

                // 6. Sovereign Rank Evolution Ladder
                GhostEvolutionCard(report: evolutionReport)
                    .padding(.horizontal, 20)

                // 7. Visual Action Toolbar
                actionToolbar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
        .background(DS.Theme.canvas)
        .sheet(item: $selectedLedgerCell) { cell in
            dayLedgerSheet(cell: cell)
        }
        .alert("Complete Season?", isPresented: $showCompleteConfirm) {
            Button("Complete & Archive", role: .destructive) {
                Task {
                    try? await GhostEngine.shared.completeSeason()
                    onReload()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will freeze your season stats and archive it to Campaign History. You can then seal a fresh arc.")
        }
    }

    // MARK: - Hero Progress Banner

    private var heroProgressBanner: some View {
        HStack(spacing: 20) {
            // Radial Progress Ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 8)
                    .frame(width: 76, height: 76)

                Circle()
                    .trim(from: 0, to: max(0.01, progressFraction))
                    .stroke(
                        LinearGradient(
                            colors: [DS.Theme.amber, Color(red: 0.0, green: 0.85, blue: 1.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 76, height: 76)
                    .animation(.easeOut(duration: 0.8), value: progressFraction)

                VStack(spacing: 1) {
                    Text("\(Int(progressFraction * 100))%")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.white)
                    Text("DONE")
                        .font(.system(size: 7.5, weight: .black, design: .monospaced))
                        .foregroundStyle(DS.Theme.textTertiary)
                }
            }

            // Season Identity & Countdown
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(DS.Theme.amber)
                        .frame(width: 6, height: 6)
                    Text(season.name.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.Theme.amber)
                        .tracking(1.5)

                    Text("•")
                        .foregroundStyle(DS.Theme.textMuted)

                    Text(season.doctrine.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DS.Theme.textSecondary)
                }

                HStack(spacing: 8) {
                    Text("Day \(season.elapsedDays) of \(season.totalDays)")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(Color.white)

                    Text("(\(max(0, season.totalDays - season.elapsedDays)) Days Remaining)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DS.Theme.textSecondary)
                }
            }

            Spacer()

            // Sovereign Rank Badge
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(DS.Theme.amber.opacity(0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: streakStatus.rank.glyph)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(DS.Theme.amber)
                }
                .overlay(Circle().stroke(DS.Theme.amber.opacity(0.3), lineWidth: 1))

                VStack(alignment: .leading, spacing: 2) {
                    Text("SOVEREIGN RANK")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.Theme.textTertiary)
                    Text(streakStatus.rank.rawValue.uppercased())
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(DS.Theme.border, lineWidth: 1))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.07, green: 0.08, blue: 0.11))
        )
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }

    private var progressFraction: CGFloat {
        guard season.totalDays > 0 else { return 0 }
        return CGFloat(season.elapsedDays) / CGFloat(season.totalDays)
    }

    // MARK: - Streak Metrics Row

    private var streakMetricsRow: some View {
        HStack(spacing: 12) {
            statMetricCard(
                value: "\(streakStatus.currentStreak)",
                unit: "DAYS",
                label: "Current Streak",
                icon: "flame.fill",
                accent: DS.Theme.amber
            )
            statMetricCard(
                value: "\(streakStatus.bestStreak)",
                unit: "DAYS",
                label: "Longest Streak",
                icon: "trophy.fill",
                accent: Color(red: 0.0, green: 0.85, blue: 1.0)
            )
            statMetricCard(
                value: "\(streakStatus.totalGhostDays)",
                unit: "SEALED",
                label: "Conquered Days",
                icon: "checkmark.seal.fill",
                accent: Color(hex: "#30A46C")
            )
            statMetricCard(
                value: "\(darkHoursSummary.totalSilenceMinutes / 60)h",
                unit: "SILENCE",
                label: "Deep Focus Time",
                icon: "speaker.slash.fill",
                accent: Color(hex: "#3E63DD")
            )
        }
    }

    private func statMetricCard(value: String, unit: String, label: String, icon: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accent)
                Spacer()
                Text(unit)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.Theme.textTertiary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.white)
            }

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DS.Theme.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(DS.Theme.border, lineWidth: 1))
    }

    // MARK: - Chart 3: Weekly 3-Ring Consistency Breakdown

    private var weeklyRingConsistencyChartSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
                Text("WEEKLY THREE-RING CONSISTENCY BREAKDOWN")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
                    .tracking(1.2)

                Spacer()

                // Legend
                HStack(spacing: 12) {
                    legendBadge(color: Color(hex: "#E54D2E"), label: "Body Forge")
                    legendBadge(color: Color(hex: "#3E63DD"), label: "Mind Synthesis")
                    legendBadge(color: Color(hex: "#0091FF"), label: "Silence Focus")
                }
            }

            let weeklyData = computeWeeklyRingData()

            if weeklyData.isEmpty {
                Text("Consistency breakdown will chart automatically as you log days.")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Theme.textTertiary)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Chart {
                    ForEach(weeklyData) { item in
                        BarMark(
                            x: .value("Week", item.weekLabel),
                            y: .value("Rate", item.bodyRate)
                        )
                        .foregroundStyle(Color(hex: "#E54D2E"))
                        .position(by: .value("Ring", "Body"))

                        BarMark(
                            x: .value("Week", item.weekLabel),
                            y: .value("Rate", item.mindRate)
                        )
                        .foregroundStyle(Color(hex: "#3E63DD"))
                        .position(by: .value("Ring", "Mind"))

                        BarMark(
                            x: .value("Week", item.weekLabel),
                            y: .value("Rate", item.silenceRate)
                        )
                        .foregroundStyle(Color(hex: "#0091FF"))
                        .position(by: .value("Ring", "Silence"))
                    }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                            .foregroundStyle(Color.white.opacity(0.08))
                        AxisValueLabel {
                            if let intVal = value.as(Int.self) {
                                Text("\(intVal)%")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(DS.Theme.textTertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let str = value.as(String.self) {
                                Text(str)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(DS.Theme.textSecondary)
                            }
                        }
                    }
                }
                .frame(height: 160)
            }
        }
        .padding(16)
        .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.Theme.border, lineWidth: 1))
    }

    private func legendBadge(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(DS.Theme.textSecondary)
        }
    }

    private struct WeeklyRingMetric: Identifiable {
        let id: String
        let weekLabel: String
        let bodyRate: Double
        let mindRate: Double
        let silenceRate: Double
    }

    private func computeWeeklyRingData() -> [WeeklyRingMetric] {
        let elapsedCells = chainCells.filter { !$0.isFuture }
        guard !elapsedCells.isEmpty else {
            return [
                WeeklyRingMetric(id: "w1", weekLabel: "Wk 1", bodyRate: 100, mindRate: 100, silenceRate: 100)
            ]
        }

        var results: [WeeklyRingMetric] = []
        let chunkSize = 7
        var offset = 0
        var weekIndex = 1

        while offset < elapsedCells.count {
            let chunk = Array(elapsedCells[offset..<min(offset + chunkSize, elapsedCells.count)])
            let count = Double(chunk.count)
            let body = (Double(chunk.filter(\.bodyClosed).count) / count) * 100.0
            let mind = (Double(chunk.filter(\.mindClosed).count) / count) * 100.0
            let sil  = (Double(chunk.filter(\.silenceClosed).count) / count) * 100.0

            results.append(WeeklyRingMetric(
                id: "w_\(weekIndex)",
                weekLabel: "Wk \(weekIndex)",
                bodyRate: body,
                mindRate: mind,
                silenceRate: sil
            ))

            offset += chunkSize
            weekIndex += 1
        }

        return results
    }

    // MARK: - Action Toolbar

    private var actionToolbar: some View {
        HStack(spacing: 12) {
            // Photo Wall
            Button { onShowPhotoWall() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Photo Wall")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Export Passport PDF
            Button { onExportPassport() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Winter Arc Passport")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Reconfigure Covenant Rules
            Button { onReconfigureCovenant() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11, weight: .bold))
                    Text("Reconfigure Rules")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(DS.Theme.amber)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(DS.Theme.amber.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Theme.amber.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            // Complete & Archive Season
            Button { showCompleteConfirm = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "flag.checkered.2.crossed")
                        .font(.system(size: 11, weight: .bold))
                    Text("Seal & Archive Season")
                        .font(.system(size: 11.5, weight: .medium))
                }
                .foregroundStyle(DS.Theme.textTertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(DS.Theme.border, lineWidth: 1))
    }

    // MARK: - Day Ledger Sheet

    private func dayLedgerSheet(cell: GhostEngine.GhostChainCell) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DAY \(cell.dayIndex) OF \(season.totalDays)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.Theme.amber)
                        .tracking(1.5)
                    Text(cell.dateString)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.Theme.textPrimary)
                }
                Spacer()
                Button("Close") { selectedLedgerCell = nil }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Theme.textSecondary)
            }

            Divider().opacity(0.12)

            HStack(spacing: 10) {
                ringLedgerBadge(title: "Body Ring", isClosed: cell.bodyClosed, color: Color(hex: "#E54D2E"))
                ringLedgerBadge(title: "Mind Ring", isClosed: cell.mindClosed, color: Color(hex: "#3E63DD"))
                ringLedgerBadge(title: "Silence Ring", isClosed: cell.silenceClosed, color: Color(hex: "#0091FF"))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("DAY SCORE: \(cell.score) / 3 RINGS SEALED")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(cell.ghostDay ? DS.Theme.amber : DS.Theme.textSecondary)

                if cell.ghostDay {
                    Text("🔥 Full Ghost Day Conquered! Elevation ascent recorded on Alpine Ridge.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
                } else if cell.isFuture {
                    Text("Pending future season date.")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Theme.textTertiary)
                } else {
                    Text("Day concluded with partial ring completion.")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Theme.textTertiary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Theme.surface, in: RoundedRectangle(cornerRadius: 8))

            Spacer()
        }
        .padding(20)
        .frame(width: 380, height: 260)
        .background(DS.Theme.canvas)
    }

    private func ringLedgerBadge(title: String, isClosed: Bool, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: isClosed ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(isClosed ? color : DS.Theme.textMuted)
            Text(title)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(isClosed ? Color.white : DS.Theme.textTertiary)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(isClosed ? color.opacity(0.12) : Color.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(isClosed ? color.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1))
    }
}
