import SwiftUI
import AppKit

// MARK: - DS.Theme (Linear / Raycast Precision Theme Tokens)

extension DS {

    enum Theme {

        // MARK: - Canvas & Surfaces (Obsidian Slate Hierarchy)

        /// Deepest background canvas (e.g. Window body, behind split panes). `#0C0D0F`
        public static let canvas = SwiftUI.Color(nsColor: NSColor(red: 0.048, green: 0.052, blue: 0.059, alpha: 1.0))

        /// Sidebar background tone. `#101215`
        public static let sidebar = SwiftUI.Color(nsColor: NSColor(red: 0.063, green: 0.071, blue: 0.082, alpha: 1.0))

        /// Content column surface. `#14171B`
        public static let surface = SwiftUI.Color(nsColor: NSColor(red: 0.078, green: 0.090, blue: 0.106, alpha: 1.0))

        /// Elevated bento card fill. `#191D22`
        public static let card = SwiftUI.Color(nsColor: NSColor(red: 0.098, green: 0.114, blue: 0.133, alpha: 1.0))

        /// Interactive card hover state. `#1F242B`
        public static let cardHover = SwiftUI.Color(nsColor: NSColor(red: 0.122, green: 0.141, blue: 0.169, alpha: 1.0))

        /// Selected item background. `#242A33`
        public static let cardSelected = SwiftUI.Color(nsColor: NSColor(red: 0.141, green: 0.165, blue: 0.200, alpha: 1.0))

        // MARK: - Machined Borders & Rim Lighting

        /// Standard 1px precision boundary stroke.
        public static let border = SwiftUI.Color.white.opacity(0.08)

        /// Extremely subtle internal divider.
        public static let borderSubtle = SwiftUI.Color.white.opacity(0.04)

        /// Focused / Active element outline.
        public static let borderActive = SwiftUI.Color.white.opacity(0.20)

        // MARK: - Vivid Precision Accents

        /// Primary Executive Gold / Amber (Linear style).
        public static let amber = SwiftUI.Color(red: 0.96, green: 0.65, blue: 0.18)

        /// Universal Accent Token
        public static let accent = amber

        /// Raycast-style Electric Cyan.
        public static let cyan = SwiftUI.Color(red: 0.08, green: 0.72, blue: 0.88)

        /// Flow / Active Emerald Mint.
        public static let emerald = SwiftUI.Color(red: 0.12, green: 0.78, blue: 0.52)

        /// Studio Iris / Violet.
        public static let violet = SwiftUI.Color(red: 0.62, green: 0.44, blue: 0.98)

        /// High Priority / Alert Coral.
        public static let coral = SwiftUI.Color(red: 0.96, green: 0.32, blue: 0.45)

        // MARK: - Typography Shades

        public static let textPrimary = SwiftUI.Color.white
        public static let textSecondary = SwiftUI.Color.white.opacity(0.68)
        public static let textTertiary = SwiftUI.Color.white.opacity(0.40)
        public static let textMuted = SwiftUI.Color.white.opacity(0.22)
    }
}

// MARK: - Machined Precision Card ViewModifier

public struct MachinedCardModifier: ViewModifier {
    var isHovered: Bool = false
    var isSelected: Bool = false
    var cornerRadius: CGFloat = 10
    var accentColor: SwiftUI.Color? = nil

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        isSelected
                            ? DS.Theme.cardSelected
                            : (isHovered ? DS.Theme.cardHover : DS.Theme.card)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: (accentColor ?? SwiftUI.Color.white).opacity(isSelected ? 0.35 : (isHovered ? 0.22 : 0.10)), location: 0.0),
                                .init(color: SwiftUI.Color.white.opacity(isSelected ? 0.12 : (isHovered ? 0.06 : 0.03)), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: SwiftUI.Color.black.opacity(isHovered ? 0.35 : 0.18),
                radius: isHovered ? 8 : 4,
                x: 0,
                y: isHovered ? 3 : 1.5
            )
    }
}

extension View {
    public func machinedCard(isHovered: Bool = false, isSelected: Bool = false, cornerRadius: CGFloat = 10, accent: SwiftUI.Color? = nil) -> some View {
        self.modifier(MachinedCardModifier(isHovered: isHovered, isSelected: isSelected, cornerRadius: cornerRadius, accentColor: accent))
    }

    /// Monospaced keyboard shortcut pill (e.g. `⌘1`, `⌘N`)
    public func linearKbdBadge(_ shortcut: String) -> some View {
        HStack(spacing: 0) {
            self
            Spacer(minLength: 4)
            Text(shortcut)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(DS.Theme.textTertiary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(SwiftUI.Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(SwiftUI.Color.white.opacity(0.08), lineWidth: 0.8))
        }
    }
}

/// Instant response button style without standard platform animation delays.
public struct PlutoFastButtonStyle: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1.0)
    }
}

