import SwiftUI

// MARK: - MacSidebarView (Linear Precision Obsidian Sidebar)

/// Master Navigation Sidebar designed with Linear / Raycast precision dark obsidian aesthetic.
struct MacSidebarView: View {

    @Binding var selection: MacSection?
    @State private var hoveredSection: MacSection? = nil

    private let mainSections: [MacSection] = [.today, .notes, .studio, .life]

    var body: some View {
        ZStack(alignment: .trailing) {
            // Dark Obsidian Backing
            VStack(spacing: 0) {

                // Top Workspace Brand Header
                brandHeader
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 12)

                Divider()
                    .opacity(0.12)
                    .padding(.horizontal, 10)

                // Main Navigation Section List
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(mainSections) { section in
                            sidebarItemButton(section: section)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
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

            // Right-hand 1px Machined Boundary Divider
            Rectangle()
                .fill(DS.Theme.border)
                .frame(width: 1)
        }
        .navigationTitle("PLUTO")
    }

    // MARK: - Top Brand Header

    private var brandHeader: some View {
        HStack(spacing: 9) {
            // Illuminated Precision Monolith Icon
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DS.Theme.amber,
                                Color(red: 0.88, green: 0.45, blue: 0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 22, height: 22)
                    .shadow(color: DS.Theme.amber.opacity(0.35), radius: 6, x: 0, y: 1)

                Image(systemName: "circle.circle.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.85))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("PLUTO")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .tracking(1.2)

                Text("EXECUTIVE OS")
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DS.Theme.textTertiary)
                    .tracking(0.8)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Sidebar Item Button

    private func sidebarItemButton(section: MacSection) -> some View {
        let isSelected = selection == section
        let isHovered = hoveredSection == section
        let accent = sectionAccent(section)

        return Button {
            selection = section
            Haptics.impact(.light)
        } label: {
            HStack(spacing: 10) {
                // Section Icon with subtle tinting
                Image(systemName: section.systemImage)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? accent : (isHovered ? Color.white : DS.Theme.textSecondary))
                    .frame(width: 20, height: 20)

                // Section Title
                Text(section.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.white : (isHovered ? Color.white : DS.Theme.textSecondary))
                    .lineLimit(1)

                Spacer(minLength: 4)

                // Monospaced Keyboard Shortcut Pill (Linear style)
                if let kbd = shortcutFor(section) {
                    Text(kbd)
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isSelected ? accent.opacity(0.9) : DS.Theme.textMuted)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            isSelected ? accent.opacity(0.12) : Color.white.opacity(0.04),
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isSelected ? accent.opacity(0.30) : Color.white.opacity(0.06), lineWidth: 0.8)
                        )
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                ZStack(alignment: .leading) {
                    if isSelected {
                        // Selected Card Fill
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(DS.Theme.cardSelected)

                        // Left Active Indicator Bar
                        RoundedRectangle(cornerRadius: 2)
                            .fill(accent)
                            .frame(width: 3, height: 16)
                            .padding(.leading, 2)
                            .shadow(color: accent.opacity(0.8), radius: 4)
                    } else if isHovered {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.12) : Color.clear, lineWidth: 1)
            )
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
        case .settings: return "⌘,"
        }
    }

    private func sectionAccent(_ section: MacSection) -> Color {
        switch section {
        case .today:    return DS.Theme.amber
        case .notes:    return DS.Theme.cyan
        case .studio:   return DS.Theme.violet
        case .life:     return DS.Theme.emerald
        case .settings: return Color.white.opacity(0.85)
        }
    }
}
