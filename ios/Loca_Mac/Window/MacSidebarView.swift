import SwiftUI

// MARK: - MacSidebarView (Linear Precision Obsidian Sidebar)

/// Master Navigation Sidebar designed with Linear / Raycast precision dark obsidian aesthetic.
struct MacSidebarView: View {

    @Binding var selection: MacSection?
    @State private var hoveredSection: MacSection? = nil
    @Namespace private var sidebarNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let mainSections: [MacSection] = [.today, .notes, .studio, .life, .ghost]

    var body: some View {
        ZStack(alignment: .trailing) {
            // A stable navigation canvas keeps labels readable; the selected
            // navigation control above it supplies the native glass surface.
            sidebarContent
                // The selected item is the only custom glass surface in this
                // navigation layer. Keeping the container at this scope lets
                // SwiftUI morph it between section rows efficiently.
                .modifier(SidebarGlassContainerModifier())

            // Right-hand 1px Boundary Divider
            Rectangle()
                .fill(DS.Theme.border)
                .frame(width: 1)
                .ignoresSafeArea()
        }
        .navigationTitle("PLUTO")
    }

    private var sidebarContent: some View {
        VStack(spacing: 0) {

                // Main Navigation Section List
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(mainSections) { section in
                            sidebarItemButton(section: section)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 46)
                    .padding(.bottom, 8)
                }

                Spacer(minLength: 0)

                // Pinned Bottom Tray for Settings & Help
                VStack(spacing: 6) {
                    Divider()
                        .opacity(0.12)
                        .padding(.horizontal, 10)

                    sidebarItemButton(section: .settings)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 12)
                }
        }
        .background(DS.Theme.sidebar)
        .ignoresSafeArea()
    }

    // MARK: - Sidebar Item Button (Sliding Glass Selection Pill)

    private func sidebarItemButton(section: MacSection) -> some View {
        let isSelected = selection == section
        let isHovered = hoveredSection == section

        return Button {
            withAnimation(reduceMotion ? nil : PlutoSpring.snappy) {
                selection = section
            }
            Haptics.impact(.light)
        } label: {
            HStack(spacing: 10) {
                // Section Icon with subtle tinting and bounce
                Image(systemName: section.systemImage)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? selectedForeground : (isHovered ? Color.white : DS.Theme.textSecondary))
                    .symbolEffect(.bounce, value: isSelected)
                    .frame(width: 20, height: 20)

                // Section Title
                Text(section.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? selectedForeground : (isHovered ? Color.white : DS.Theme.textSecondary))
                    .lineLimit(1)

                Spacer(minLength: 4)

                // Monospaced Keyboard Shortcut Pill
                if let kbd = shortcutFor(section) {
                    Text(kbd)
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(isSelected ? selectedShortcutForeground : DS.Theme.textMuted)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            isSelected ? Color.black.opacity(0.08) : Color.white.opacity(0.04),
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    selectedItemBackground(for: section)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                }
            }
            .animation(PlutoSpring.snappy, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredSection = hovering ? section : nil
        }
    }

    @ViewBuilder
    private func selectedItemBackground(for section: MacSection) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        Color.clear
            .glassEffect(.regular.interactive(), in: shape)
            .glassEffectID(section.id, in: sidebarNamespace)
            .glassEffectTransition(.matchedGeometry)
    }

    private var selectedForeground: Color {
        DS.Theme.textPrimary
    }

    private var selectedShortcutForeground: Color {
        DS.Theme.textSecondary
    }

    private func shortcutFor(_ section: MacSection) -> String? {
        switch section {
        case .today:    return "⌘1"
        case .notes:    return "⌘2"
        case .studio:   return "⌘3"
        case .life:     return "⌘4"
        case .ghost:    return "⌘5"
        case .settings: return "⌘,"
        }
    }

}

/// Groups the sidebar's moving selection surface for efficient morphing.
private struct SidebarGlassContainerModifier: ViewModifier {
    func body(content: Content) -> some View {
        GlassEffectContainer(spacing: 8) {
            content
        }
    }
}
