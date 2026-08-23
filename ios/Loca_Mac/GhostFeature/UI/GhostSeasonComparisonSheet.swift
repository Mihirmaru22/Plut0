import SwiftUI

/// Side-by-side Season Comparison Modal.
/// Compares two seasonal arcs (or active vs past campaign) across completion rates, streaks, and ring disciplines.
public struct GhostSeasonComparisonSheet: View {
    @Environment(\.dismiss) private var dismiss

    let allSeasons: [GhostSeason]
    @State private var selectedSeasonA: GhostSeason?
    @State private var selectedSeasonB: GhostSeason?
    @State private var comparison: SeasonComparison?
    @State private var isLoading: Bool = true

    public init(allSeasons: [GhostSeason], initialSeasonA: GhostSeason? = nil, initialSeasonB: GhostSeason? = nil) {
        self.allSeasons = allSeasons
        _selectedSeasonA = State(initialValue: initialSeasonA ?? allSeasons.first)
        _selectedSeasonB = State(initialValue: initialSeasonB ?? (allSeasons.count > 1 ? allSeasons[1] : allSeasons.first))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(DS.Theme.amber)
                        Text("CAMPAIGN COMPARISON")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(DS.Theme.amber)
                            .tracking(1.5)
                    }
                    Text("Season Forensics & Evolution")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(DS.Theme.textPrimary)
                }

                Spacer()

                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(DS.Theme.amber)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)

            Divider().opacity(0.12)

            // Season Pickers
            HStack(spacing: 16) {
                seasonPicker(title: "ARC A (BASELINE)", selection: $selectedSeasonA)
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DS.Theme.textMuted)
                    .padding(.top, 14)
                seasonPicker(title: "ARC B (TARGET)", selection: $selectedSeasonB)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(DS.Theme.surface)

            Divider().opacity(0.12)

            // Comparison Content
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Computing deltas...")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DS.Theme.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let comp = comparison {
                ScrollView {
                    VStack(spacing: 16) {
                        // Delta Summary Banner
                        deltaBanner(comp)

                        // Core Metrics Comparison
                        VStack(spacing: 10) {
                            metricRow(
                                label: "Completion Rate",
                                valA: String(format: "%.0f%%", comp.seasonA.completionRate),
                                valB: String(format: "%.0f%%", comp.seasonB.completionRate),
                                deltaStr: String(format: "%+.0f%%", comp.completionDelta),
                                isPositive: comp.completionDelta >= 0
                            )

                            metricRow(
                                label: "Total Ghost Days",
                                valA: "\(comp.seasonA.ghostDays)/\(comp.seasonA.totalDays)d",
                                valB: "\(comp.seasonB.ghostDays)/\(comp.seasonB.totalDays)d",
                                deltaStr: String(format: "%+dd", comp.ghostDaysDelta),
                                isPositive: comp.ghostDaysDelta >= 0
                            )

                            metricRow(
                                label: "Best Streak",
                                valA: "\(comp.seasonA.bestStreak) days",
                                valB: "\(comp.seasonB.bestStreak) days",
                                deltaStr: String(format: "%+dd", comp.bestStreakDelta),
                                isPositive: comp.bestStreakDelta >= 0
                            )

                            metricRow(
                                label: "Discipline Score",
                                valA: String(format: "%.0f/100", comp.seasonA.averageScore),
                                valB: String(format: "%.0f/100", comp.seasonB.averageScore),
                                deltaStr: String(format: "%+.0f", comp.scoreDelta),
                                isPositive: comp.scoreDelta >= 0
                            )
                        }

                        // Ring Adherence Deltas
                        VStack(alignment: .leading, spacing: 10) {
                            Text("RING DISCIPLINES")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(DS.Theme.textTertiary)
                                .tracking(1.2)

                            ringDeltaRow("Body Ring", comp.seasonA.bodyRate, comp.seasonB.bodyRate, Color(hex: "#E54D2E"))
                            ringDeltaRow("Mind Ring", comp.seasonA.mindRate, comp.seasonB.mindRate, Color(hex: "#3E63DD"))
                            ringDeltaRow("Silence Ring", comp.seasonA.silenceRate, comp.seasonB.silenceRate, Color(hex: "#0091FF"))
                        }
                        .padding(14)
                        .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(DS.Theme.border, lineWidth: 1))
                    }
                    .padding(22)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundStyle(DS.Theme.textMuted)
                    Text("Select two seasons to compute campaign evolution.")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Theme.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 580, height: 620)
        .background(DS.Theme.canvas)
        .onAppear { loadComparison() }
        .onChange(of: selectedSeasonA) { _, _ in loadComparison() }
        .onChange(of: selectedSeasonB) { _, _ in loadComparison() }
    }

    // MARK: - Subcomponents

    private func seasonPicker(title: String, selection: Binding<GhostSeason?>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.Theme.textTertiary)
                .tracking(1.0)

            Picker("", selection: selection) {
                ForEach(allSeasons) { s in
                    Text(s.name + (s.isCompleted ? " (Archived)" : " (Active)")).tag(Optional(s))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func deltaBanner(_ comp: SeasonComparison) -> some View {
        let isImproved = comp.completionDelta >= 0
        let accent: Color = isImproved ? DS.Theme.emerald : DS.Theme.coral

        return HStack(spacing: 12) {
            Image(systemName: isImproved ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(isImproved ? "POSITIVE ARC EVOLUTION" : "DECLINING ADHERENCE ARC")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(accent)
                    .tracking(1.0)
                Text(isImproved
                     ? "Arc B outperformed Arc A by \(String(format: "%.0f%%", abs(comp.completionDelta))) completion with \(comp.bestStreakDelta >= 0 ? "+\(comp.bestStreakDelta)" : "\(comp.bestStreakDelta)") streak delta."
                     : "Arc B experienced a \(String(format: "%.0f%%", abs(comp.completionDelta))) drop in completion rate relative to Arc A.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(DS.Theme.textSecondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(accent.opacity(0.25), lineWidth: 1))
    }

    private func metricRow(label: String, valA: String, valB: String, deltaStr: String, isPositive: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DS.Theme.textSecondary)
                .frame(width: 140, alignment: .leading)

            Spacer()

            Text(valA)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(DS.Theme.textTertiary)
                .frame(width: 90, alignment: .trailing)

            Image(systemName: "arrow.right")
                .font(.system(size: 9))
                .foregroundStyle(DS.Theme.textMuted)

            Text(valB)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.Theme.textPrimary)
                .frame(width: 90, alignment: .trailing)

            Text(deltaStr)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(isPositive ? DS.Theme.emerald : DS.Theme.coral)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background((isPositive ? DS.Theme.emerald : DS.Theme.coral).opacity(0.12), in: Capsule())
                .frame(width: 60, alignment: .trailing)
        }
        .padding(10)
        .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Theme.border, lineWidth: 1))
    }

    private func ringDeltaRow(_ label: String, _ rateA: Double, _ rateB: Double, _ color: Color) -> some View {
        let delta = rateB - rateA
        return HStack(spacing: 10) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DS.Theme.textSecondary)
                .frame(width: 90, alignment: .leading)

            Text(String(format: "%.0f%%", rateA))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DS.Theme.textTertiary)
                .frame(width: 40, alignment: .trailing)

            Image(systemName: "arrow.right")
                .font(.system(size: 8))
                .foregroundStyle(DS.Theme.textMuted)

            Text(String(format: "%.0f%%", rateB))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.Theme.textPrimary)
                .frame(width: 40, alignment: .trailing)

            Spacer()

            Text(String(format: "%+.0f%%", delta))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(delta >= 0 ? DS.Theme.emerald : DS.Theme.coral)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background((delta >= 0 ? DS.Theme.emerald : DS.Theme.coral).opacity(0.12), in: Capsule())
        }
    }

    private func loadComparison() {
        guard let sA = selectedSeasonA, let sB = selectedSeasonB else { return }
        isLoading = true
        Task {
            let res = try? await GhostEngine.shared.compareSeasons(seasonA: sA, seasonB: sB)
            await MainActor.run {
                self.comparison = res
                self.isLoading = false
            }
        }
    }
}
