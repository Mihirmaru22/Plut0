import SwiftUI

/// Ghost Mode — Page 2: Season Overview
/// Chain grid, ridge elevation chart, streaks, dark hours, evolution card, export actions.
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

    var onToggleDark:   () -> Void
    var onExportPassport: () -> Void
    var onShowPhotoWall: () -> Void
    var onReload:       () -> Void

    @State private var selectedLedgerCell: GhostEngine.GhostChainCell? = nil
    @State private var showCompleteConfirm: Bool = false

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // ── Season Header ────────────────────────────────────
                seasonHeader
                    .padding(20)

                Divider().opacity(0.1).padding(.horizontal, 20)

                VStack(spacing: 18) {
                    // Streak Stats Row
                    streakStatsRow
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    // Chain Grid
                    GhostChainGridView(cells: chainCells) { cell in
                        selectedLedgerCell = cell
                    }

                    // Ridge Profile
                    GhostRidgeProfileChart(points: ridgePoints)

                    // Dark Hours
                    GhostDarkHoursStrip(summary: darkHoursSummary)

                    // Evolution Card
                    GhostEvolutionCard(report: evolutionReport)

                    // Actions
                    actionButtons
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
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
            Text("This will freeze your season stats and move it to Campaign History. You can then start a new arc.")
        }
    }

    // MARK: - Season Header

    private var seasonHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(season.protocolKind.title.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.Theme.textTertiary)
                    .tracking(1.5)
                Text(season.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DS.Theme.textPrimary)
                Text("\(season.doctrine.title)")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Theme.textTertiary)
            }

            Spacer()

            // Progress ring
            ZStack {
                Circle()
                    .stroke(DS.Theme.border, lineWidth: 5)
                    .frame(width: 60, height: 60)
                Circle()
                    .trim(from: 0, to: progressFraction)
                    .stroke(
                        DS.Theme.amber,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 60, height: 60)
                    .animation(.easeOut(duration: 0.6), value: progressFraction)
                VStack(spacing: 0) {
                    Text("\(season.elapsedDays)")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .foregroundStyle(DS.Theme.textPrimary)
                    Text("/ \(season.totalDays)")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(DS.Theme.textTertiary)
                }
            }

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: streakStatus.rank.glyph)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DS.Theme.amber)
                        .opacity(streakStatus.rank.opacity)
                    Text(streakStatus.rank.rawValue.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.Theme.amber)
                }
                Button("Photo Wall") { onShowPhotoWall() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.Theme.textSecondary)
            }
        }
    }

    private var progressFraction: CGFloat {
        guard season.totalDays > 0 else { return 0 }
        return CGFloat(season.elapsedDays) / CGFloat(season.totalDays)
    }

    // MARK: - Streak Stats

    private var streakStatsRow: some View {
        HStack(spacing: 10) {
            statPill(value: "\(streakStatus.currentStreak)", label: "Current Streak", accent: DS.Theme.amber)
            statPill(value: "\(streakStatus.bestStreak)", label: "Best Streak", accent: DS.Theme.cyan)
            statPill(value: "\(streakStatus.totalGhostDays)", label: "Ghost Days", accent: DS.Theme.emerald)
            statPill(value: "Day \(season.elapsedDays)", label: "Elapsed", accent: DS.Theme.textSecondary)
        }
    }

    private func statPill(value: String, label: String, accent: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .monospaced))
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

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                // Go Dark toggle
                Button { onToggleDark() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isOfflineDark ? "sun.max.fill" : "moon.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(isOfflineDark ? .orange : DS.Theme.cyan)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(isOfflineDark ? "Resurface" : "Go Dark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(DS.Theme.textPrimary)
                            Text(isOfflineDark ? "Exit off-grid mode" : "Log silence interval")
                                .font(.system(size: 10))
                                .foregroundStyle(DS.Theme.textTertiary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(
                        isOfflineDark ? Color.orange.opacity(0.07) : DS.Theme.card,
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isOfflineDark ? Color.orange.opacity(0.3) : DS.Theme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Export Passport
                Button { onExportPassport() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(DS.Theme.amber)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Export Passport")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(DS.Theme.textPrimary)
                            Text("4-page A4 booklet · MRZ · Visas")
                                .font(.system(size: 10))
                                .foregroundStyle(DS.Theme.textTertiary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(DS.Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            // Complete Season
            Button { showCompleteConfirm = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Complete & Archive Season")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(DS.Theme.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Day Ledger Sheet

    private func dayLedgerSheet(cell: GhostEngine.GhostChainCell) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DAY LEDGER · \(cell.dayIndex)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.Theme.amber)
                        .tracking(1.0)
                    Text(cell.dateString)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DS.Theme.textPrimary)
                }
                Spacer()
                Button("Done") { selectedLedgerCell = nil }
                    .buttonStyle(.plain)
                    .foregroundStyle(DS.Theme.amber)
                    .font(.system(size: 12, weight: .semibold))
            }

            Divider().opacity(0.12)

            HStack(spacing: 10) {
                ledgerBadge("Body",    cell.bodyClosed,    Color(hex: "#E54D2E"))
                ledgerBadge("Mind",    cell.mindClosed,    Color(hex: "#3E63DD"))
                ledgerBadge("Silence", cell.silenceClosed, Color(hex: "#0091FF"))
            }

            HStack(spacing: 6) {
                Image(systemName: cell.ghostDay ? "checkmark.seal.fill" : "seal")
                    .foregroundStyle(cell.ghostDay ? DS.Theme.amber : DS.Theme.textMuted)
                Text(cell.ghostDay ? "Ghost Day · Score \(cell.score)/100" : "Unsealed · Score \(cell.score)/100")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(cell.ghostDay ? DS.Theme.amber : DS.Theme.textTertiary)
            }
        }
        .padding(20)
        .frame(width: 360, height: 200)
        .background(DS.Theme.surface)
    }

    private func ledgerBadge(_ label: String, _ closed: Bool, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(closed ? color : DS.Theme.border)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(closed ? DS.Theme.textPrimary : DS.Theme.textMuted)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 6))
    }
}
