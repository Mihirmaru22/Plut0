import SwiftUI
import AppKit

// MARK: - DS.Theme (Dynamic Linear / Raycast Precision Theme Tokens)

extension DS {

    public enum Theme {

        // MARK: - Dynamic Color Factory Helper
        
        private static func dynamic(dark: NSColor, light: NSColor) -> SwiftUI.Color {
            SwiftUI.Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
                let match = appearance.bestMatch(from: [.darkAqua, .aqua])
                return match == .darkAqua ? dark : light
            }))
        }

        // MARK: - Canvas & Surfaces (Solid Plain Canvas Obsidian Hierarchy)

        /// Deepest background canvas (e.g. Window body, behind split panes).
        public static let canvas = dynamic(
            dark: NSColor(red: 0.035, green: 0.038, blue: 0.044, alpha: 1.0),
            light: NSColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1.0)
        )

        /// Sidebar background tone.
        public static let sidebar = dynamic(
            dark: NSColor(red: 0.048, green: 0.052, blue: 0.060, alpha: 1.0),
            light: NSColor(red: 0.95, green: 0.95, blue: 0.96, alpha: 1.0)
        )

        /// Content column surface.
        public static let surface = dynamic(
            dark: NSColor(red: 0.058, green: 0.062, blue: 0.072, alpha: 1.0),
            light: NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        )

        /// Elevated card fill.
        public static let card = dynamic(
            dark: NSColor(red: 0.072, green: 0.078, blue: 0.090, alpha: 1.0),
            light: NSColor(red: 0.94, green: 0.94, blue: 0.96, alpha: 1.0)
        )

        /// Interactive card hover state.
        public static let cardHover = dynamic(
            dark: NSColor(red: 0.092, green: 0.098, blue: 0.112, alpha: 1.0),
            light: NSColor(red: 0.90, green: 0.90, blue: 0.92, alpha: 1.0)
        )

        /// Selected item background.
        public static let cardSelected = dynamic(
            dark: NSColor(red: 0.110, green: 0.118, blue: 0.135, alpha: 1.0),
            light: NSColor(red: 0.86, green: 0.86, blue: 0.89, alpha: 1.0)
        )

        // MARK: - Hairline Borders

        /// Standard 1px precision boundary stroke.
        public static let border = dynamic(
            dark: NSColor(white: 1.0, alpha: 0.07),
            light: NSColor(white: 0.0, alpha: 0.08)
        )

        /// Extremely subtle internal divider.
        public static let borderSubtle = dynamic(
            dark: NSColor(white: 1.0, alpha: 0.035),
            light: NSColor(white: 0.0, alpha: 0.045)
        )

        /// Focused / Active element outline.
        public static let borderActive = dynamic(
            dark: NSColor(white: 1.0, alpha: 0.18),
            light: NSColor(white: 0.0, alpha: 0.20)
        )

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

        public static let textPrimary = dynamic(
            dark: NSColor(white: 1.0, alpha: 1.0),
            light: NSColor(red: 0.10, green: 0.11, blue: 0.13, alpha: 1.0)
        )
        
        public static let textSecondary = dynamic(
            dark: NSColor(white: 1.0, alpha: 0.68),
            light: NSColor(red: 0.36, green: 0.38, blue: 0.42, alpha: 1.0)
        )
        
        public static let textTertiary = dynamic(
            dark: NSColor(white: 1.0, alpha: 0.40),
            light: NSColor(red: 0.56, green: 0.58, blue: 0.62, alpha: 1.0)
        )
        
        public static let textMuted = dynamic(
            dark: NSColor(white: 1.0, alpha: 0.22),
            light: NSColor(red: 0.72, green: 0.74, blue: 0.78, alpha: 1.0)
        )
    }
}

// MARK: - Machined Precision Card ViewModifier

public struct MachinedCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var isHovered: Bool = false
    var isSelected: Bool = false
    var cornerRadius: CGFloat = 10
    var accentColor: SwiftUI.Color? = nil

    public func body(content: Content) -> some View {
        let isDark = colorScheme == .dark
        let strokeBase = isDark ? SwiftUI.Color.white : SwiftUI.Color.black

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
                                .init(color: (accentColor ?? strokeBase).opacity(isSelected ? 0.35 : (isHovered ? 0.22 : 0.10)), location: 0.0),
                                .init(color: strokeBase.opacity(isSelected ? 0.12 : (isHovered ? 0.06 : 0.03)), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: SwiftUI.Color.black.opacity(isDark ? (isHovered ? 0.35 : 0.18) : (isHovered ? 0.10 : 0.04)),
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
                .background(DS.Theme.borderSubtle, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(DS.Theme.border, lineWidth: 0.8))
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
