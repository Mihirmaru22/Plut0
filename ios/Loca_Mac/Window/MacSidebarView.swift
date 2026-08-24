import SwiftUI

// MARK: - MacSidebarView (Linear Precision Obsidian Sidebar)

/// Master Navigation Sidebar designed with Linear / Raycast precision dark obsidian aesthetic.
struct MacSidebarView: View {

    @Binding var selection: MacSection?
    @State private var hoveredSection: MacSection? = nil
    @Namespace private var sidebarNamespace

    private let mainSections: [MacSection] = [.today, .notes, .studio, .life, .ghost]

    var body: some View {
        ZStack(alignment: .trailing) {
            // Material Sidebar Backing (Tahoe Flush)
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
            .background(.ultraThinMaterial)
            .ignoresSafeArea()

            // Right-hand 1px Boundary Divider
            Rectangle()
                .fill(DS.Theme.border)
                .frame(width: 1)
                .ignoresSafeArea()
        }
        .navigationTitle("PLUTO")
    }

    // MARK: - Sidebar Item Button (Sliding Glass Selection Pill)

    private func sidebarItemButton(section: MacSection) -> some View {
        let isSelected = selection == section
        let isHovered = hoveredSection == section
        let accent = sectionAccent(section)

        return Button {
            withAnimation(PlutoSpring.snappy) {
                selection = section
            }
            Haptics.impact(.light)
        } label: {
            HStack(spacing: 10) {
                // Section Icon with subtle tinting and bounce
                Image(systemName: section.systemImage)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.black.opacity(0.9) : (isHovered ? Color.white : DS.Theme.textSecondary))
                    .symbolEffect(.bounce, value: isSelected)
                    .frame(width: 20, height: 20)

                // Section Title
                Text(section.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.black.opacity(0.92) : (isHovered ? Color.white : DS.Theme.textSecondary))
                    .lineLimit(1)

                Spacer(minLength: 4)

                // Monospaced Keyboard Shortcut Pill
                if let kbd = shortcutFor(section) {
                    Text(kbd)
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(isSelected ? Color.black.opacity(0.7) : DS.Theme.textMuted)
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
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.98), Color(white: 0.90)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.white.opacity(0.9), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
                        .matchedGeometryEffect(id: "sidebarSelectionPill", in: sidebarNamespace)
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

    private func sectionAccent(_ section: MacSection) -> Color {
        switch section {
        case .today:    return DS.Theme.amber
        case .notes:    return DS.Theme.cyan
        case .studio:   return DS.Theme.violet
        case .life:     return DS.Theme.emerald
        case .ghost:    return Color(red: 0.0, green: 0.85, blue: 1.0)
        case .settings: return Color.white.opacity(0.85)
        }
    }
}
