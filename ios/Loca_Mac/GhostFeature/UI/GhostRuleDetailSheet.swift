import SwiftUI

/// Deep-dive drilldown sheet for an individual protocol rule.
/// Shows 30-day execution timeline, weekday adherence breakdown, and target parameters.
public struct GhostRuleDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let ruleID: String
    @State private var report: GhostEngine.RuleHistoryReport?
    @State private var isLoading: Bool = true

    public init(ruleID: String) {
        self.ruleID = ruleID
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RULE FORENSICS")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.Theme.amber)
                        .tracking(1.5)
                    Text(report?.title ?? "Rule Details")
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

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading rule history...")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DS.Theme.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let r = report {
                ScrollView {
                    VStack(spacing: 16) {
                        // Quick KPI row
                        HStack(spacing: 10) {
                            kpiPill(label: "Completion", value: String(format: "%.0f%%", r.completionRate * 100), color: DS.Theme.emerald)
                            kpiPill(label: "Ring", value: r.ring.title.uppercased(), color: ringColor(r.ring))
                            kpiPill(label: "Target", value: "\(Int(r.targetValue)) \(r.unitLabel)", color: DS.Theme.textSecondary)
                        }

                        // 30-Day Execution Timeline
                        VStack(alignment: .leading, spacing: 10) {
                            Text("30-DAY EXECUTION TIMELINE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(DS.Theme.textTertiary)
                                .tracking(1.2)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 10), spacing: 4) {
                                ForEach(r.timeline) { day in
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(day.isCompleted ? ringColor(r.ring) : DS.Theme.borderSubtle)
                                            .frame(height: 26)
                                        if day.isCompleted {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 9, weight: .black))
                                                .foregroundStyle(Color.black.opacity(0.7))
                                        }
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(DS.Theme.border, lineWidth: 1))

                        // Weekday Adherence Distribution
                        VStack(alignment: .leading, spacing: 10) {
                            Text("WEEKDAY ADHERENCE BREAKDOWN")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(DS.Theme.textTertiary)
                                .tracking(1.2)

                            let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                            HStack(spacing: 6) {
                                ForEach(1...7, id: \.self) { wd in
                                    let rate = r.weekdayRates[wd] ?? 0.0
                                    VStack(spacing: 3) {
                                        Text(String(format: "%.0f%%", rate * 100))
                                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                                            .foregroundStyle(DS.Theme.textTertiary)

                                        GeometryReader { geo in
                                            VStack(spacing: 0) {
                                                Spacer(minLength: 0)
                                                RoundedRectangle(cornerRadius: 2)
                                                    .fill(ringColor(r.ring).opacity(0.3 + rate * 0.7))
                                                    .frame(height: max(3, geo.size.height * rate))
                                            }
                                        }
                                        .frame(height: 38)

                                        Text(days[(wd - 1) % 7])
                                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                                            .foregroundStyle(DS.Theme.textTertiary)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .padding(14)
                        .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(DS.Theme.border, lineWidth: 1))
                    }
                    .padding(22)
                }
            }
        }
        .frame(width: 480, height: 490)
        .background(DS.Theme.canvas)
        .onAppear { loadData() }
    }

    private func kpiPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(color)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Theme.border, lineWidth: 1))
    }

    private func ringColor(_ ring: GhostRing) -> Color {
        switch ring {
        case .body:    return Color(hex: "#E54D2E")
        case .mind:    return Color(hex: "#3E63DD")
        case .silence: return Color(hex: "#0091FF")
        }
    }

    private func loadData() {
        isLoading = true
        Task {
            let res = try? await GhostEngine.shared.fetchRuleHistory(ruleID: ruleID)
            await MainActor.run {
                self.report = res
                self.isLoading = false
            }
        }
    }
}
