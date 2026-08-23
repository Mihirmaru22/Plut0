import SwiftUI

/// Weekly Evolution Card displaying on-device adherence rates across rules and rings with calm guidance.
public struct GhostEvolutionCard: View {
    public let report: GhostEngine.GhostEvolutionReport

    public init(report: GhostEngine.GhostEvolutionReport) {
        self.report = report
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            headerView

            // Ring Adherence Progress Bars
            HStack(spacing: 12) {
                ringAdherenceBar(title: "Body Ring", percent: report.bodyAdherence, color: Color(hex: "#E54D2E"))
                ringAdherenceBar(title: "Mind Ring", percent: report.mindAdherence, color: Color(hex: "#3E63DD"))
                ringAdherenceBar(title: "Silence Ring", percent: report.silenceAdherence, color: Color(hex: "#0091FF"))
            }

            // Per-Rule Adherence List
            if !report.ruleAdherences.isEmpty {
                VStack(spacing: 6) {
                    ForEach(report.ruleAdherences) { ruleStat in
                        ruleRowView(ruleStat)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.02))
                )
            }

            // Calm Suggestion Banner
            if !report.suggestion.isEmpty {
                suggestionBanner
            }
        }
        .padding(14)
        .plutoGlass(.regular, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DS.Theme.cyan)
                Text("WEEKLY DISCIPLINE EVOLUTION")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.Theme.textSecondary)
                    .tracking(1.0)
            }

            Spacer()

            Text("\(Int(report.weeklyGhostRate))% Ghost Days")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.Theme.cyan)
                .contentTransition(.numericText())
        }
    }

    private func ruleRowView(_ ruleStat: GhostEngine.RuleAdherence) -> some View {
        HStack {
            Circle()
                .fill(Color(hex: ruleStat.ring.accentHex))
                .frame(width: 5, height: 5)

            Text(ruleStat.title)
                .font(.system(size: 11))
                .foregroundStyle(DS.Theme.textPrimary)

            Spacer()

            Text("\(ruleStat.completedDays)/\(ruleStat.totalDays)d (\(Int(ruleStat.ratePercent))%)")
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(DS.Theme.textTertiary)
        }
    }

    private var suggestionBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkle")
                .font(.system(size: 11))
                .foregroundStyle(DS.Theme.cyan)
            Text(report.suggestion)
                .font(.system(size: 11))
                .foregroundStyle(DS.Theme.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(DS.Theme.cyan.opacity(0.06))
        )
    }

    private func ringAdherenceBar(title: String, percent: Double, color: Color) -> some View {
        let clampedRatio = CGFloat(min(1.0, max(0.0, percent / 100.0)))

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DS.Theme.textTertiary)
                Spacer()
                Text("\(Int(percent))%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: max(0, geo.size.width * clampedRatio), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
        )
    }
}
