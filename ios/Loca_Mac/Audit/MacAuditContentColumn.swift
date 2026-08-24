import SwiftUI
import SwiftData

// MARK: - MacAuditContentColumn

/// Middle column for the Audit section in macOS 3-pane layout.
/// Serves as a quick horizon selector.
struct MacAuditContentColumn: View {

    @AppStorage("mac_audit_selected_horizon") private var selectedHorizon: HorizonCategory = .all

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Strategic Horizons")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(DS.Color.textTertiary)
                Spacer()
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, DS.Space.sm)

            Divider()

            // Navigation List with Unified Theme
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(HorizonCategory.allCases, id: \.self) { horizon in
                        HorizonRowButton(horizon: horizon, isSelected: selectedHorizon == horizon) {
                            selectedHorizon = horizon
                            Haptics.selection()
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 12)
            }
        }
        .navigationTitle("Audit")
    }
}

// MARK: - HorizonRowButton

private struct HorizonRowButton: View {

    let horizon: HorizonCategory
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    private var icon: String {
        switch horizon {
        case .all:     return "circle.grid.2x2.fill"
        case .quarter: return "chart.bar.fill"
        case .year:    return "calendar"
        case .vision:  return "binoculars.fill"
        case .bucket:  return "trophy.fill"
        }
    }

    private var subtitle: String {
        switch horizon {
        case .all:     return "All active milestones"
        case .quarter: return "Immediate focus"
        case .year:    return "Annual targets"
        case .vision:  return "Long-range vision"
        case .bucket:  return "Lifetime dreams"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : DS.Color.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(
                        isSelected ? Color.accentColor.opacity(0.18) : DS.Color.surfaceRecessed,
                        in: RoundedRectangle(cornerRadius: 6)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(horizon.rawValue)
                        .font(DS.Text.body)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? DS.Color.textPrimary : (isHovered ? DS.Color.textPrimary : DS.Color.textSecondary))

                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(isSelected ? DS.Color.textSecondary : DS.Color.textTertiary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? DS.Color.surfaceRecessed
                    : (isHovered ? DS.Color.surfaceRecessed.opacity(0.5) : Color.clear),
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
