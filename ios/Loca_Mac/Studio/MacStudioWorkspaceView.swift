import SwiftUI
import SwiftData

// MARK: - MacStudioWorkspaceView (Unified Projects + Journal Sovereign Studio)

/// Unified Knowledge & Execution Workspace combining Work Projects and Apple Journal.
struct MacStudioWorkspaceView: View {

    @AppStorage("mac_studio_active_tab") private var activeTab: StudioTab = .projects

    enum StudioTab: String, CaseIterable, Identifiable {
        case projects = "Projects"
        case journal  = "Journal"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .projects: return "briefcase.fill"
            case .journal:  return "book.pages.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            
            // Top Studio Liquid Glass Switcher Bar
            HStack {
                Text("Studio")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white)

                Spacer()

                // Liquid Glass Segmented Switcher
                PlutoGlassCluster(spacing: 2) {
                    ForEach(StudioTab.allCases) { tab in
                        tabButton(for: tab)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(nsColor: NSColor(red: 0.09, green: 0.09, blue: 0.10, alpha: 1.0)))
            .background(PlutoAmbientGlowView(accent: Color(red: 0.68, green: 0.32, blue: 0.88)))

            Divider().opacity(0.12)

            // Active Workspace Content
            Group {
                switch activeTab {
                case .projects:
                    MacWorkWorkspaceView()
                case .journal:
                    MacAppleJournalView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DS.Color.background)
    }

    @ViewBuilder
    private func tabButton(for tab: StudioTab) -> some View {
        let isSelected = activeTab == tab
        Button {
            withAnimation(PlutoSpring.snappy) {
                activeTab = tab
            }
            Haptics.impact(.light)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                    .symbolEffect(.bounce, value: isSelected)
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
            }
            .foregroundStyle(isSelected ? Color.black.opacity(0.92) : DS.Theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background {
                if isSelected {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.98), Color(white: 0.90)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(Capsule().stroke(Color.white.opacity(0.9), lineWidth: 0.8))
                        .shadow(color: Color.black.opacity(0.20), radius: 4, y: 1)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
