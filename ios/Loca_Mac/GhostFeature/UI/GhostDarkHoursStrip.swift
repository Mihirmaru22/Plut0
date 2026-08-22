import SwiftUI

/// Visual Dark Hours Strip showing offline disconnect periods, weekly total, and longest silence streak.
public struct GhostDarkHoursStrip: View {
    public let summary: GhostEngine.DarkHoursSummary

    public init(summary: GhostEngine.DarkHoursSummary) {
        self.summary = summary
    }

    public var body: some View {
        HStack(spacing: 16) {
            // Icon & Title
            HStack(spacing: 8) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))

                VStack(alignment: .leading, spacing: 1) {
                    Text("DARK HOURS SILENCE")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .tracking(1.0)
                    Text("\(summary.todayMinutes)m Today")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white)
                }
            }

            Divider().opacity(0.12).frame(height: 24)

            // Timeline Blocks / Intervals
            HStack(spacing: 6) {
                if summary.recentIntervals.isEmpty {
                    Text("No off-grid dark intervals logged today.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.white.opacity(0.4))
                } else {
                    ForEach(Array(summary.recentIntervals.enumerated()), id: \.offset) { _, interval in
                        HStack(spacing: 4) {
                            Circle().fill(Color(red: 0.0, green: 0.85, blue: 1.0)).frame(width: 5, height: 5)
                            Text("\(interval.durationMinutes)m")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.8))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
            }

            Spacer()

            // Weekly & Longest Stats
            HStack(spacing: 14) {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("WEEKLY TOTAL")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.45))
                    Text("\(String(format: "%.1f", Double(summary.weekMinutes) / 60.0)) hrs")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.85))
                }

                VStack(alignment: .trailing, spacing: 1) {
                    Text("LONGEST STRETCH")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.45))
                    Text("\(summary.longestStretchMinutes)m")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.06, green: 0.06, blue: 0.08))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }
}
