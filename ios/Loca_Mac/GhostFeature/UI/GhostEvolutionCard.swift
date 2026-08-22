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
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
                    Text("WEEKLY DISCIPLINE EVOLUTION")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .tracking(1.0)
                }

                Spacer()

                Text("\(Int(report.weeklyGhostRate))% Ghost Days")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
            }

            // Ring Adherence Progress Bars
            HStack(spacing: 12) {
                ringAdherenceBar(title: "Body Ring", percent: report.bodyAdherence, color: Color(hex: "#E54D2E") ?? .red)
                ringAdherenceBar(title: "Mind Ring", percent: report.mindAdherence, color: Color(hex: "#3E63DD") ?? .blue)
                ringAdherenceBar(title: "Silence Ring", percent: report.silenceAdherence, color: Color(hex: "#0091FF") ?? .cyan)
            }

            // Per-Rule Adherence List
            if !report.ruleAdherences.isEmpty {
                VStack(spacing: 6) {
                    ForEach(report.ruleAdherences) { ruleStat in
                        HStack {
                            Circle()
                                .fill(Color(hex: ruleStat.ring.accentHex) ?? .white)
                                .frame(width: 5, height: 5)

                            Text(ruleStat.title)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.white.opacity(0.8))

                            Spacer()

                            Text("\(ruleStat.completedDays)/\(ruleStat.totalDays)d (\(Int(ruleStat.ratePercent))%)")
                                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.55))
                        }
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 8))
            }

            // Calm Suggestion Banner
            HStack(spacing: 8) {
                Image(systemName: "sparkle")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
                Text(report.suggestion)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.75))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.06, green: 0.06, blue: 0.08))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    private func ringAdherenceBar(title: String, percent: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.6))
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
                        .frame(width: geo.size.width * CGFloat(min(1.0, max(0.0, percent / 100.0))), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
    }
}
