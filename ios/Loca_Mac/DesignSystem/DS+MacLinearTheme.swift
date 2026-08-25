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

        // MARK: - Canvas & Surfaces (Unified Column 1 Sidebar Tone across all columns)

        /// Sidebar background tone (Single source of truth for ALL column backgrounds).
        public static let sidebar = SwiftUI.Color(white: 0.09).opacity(0.88)

        /// Deepest background canvas (Single source of truth).
        public static let canvas = sidebar

        /// Content column surface (Single source of truth).
        public static let surface = sidebar

        /// Elevated card fill.
        public static let card = SwiftUI.Color.white.opacity(0.06)

        /// Interactive card hover state.
        public static let cardHover = SwiftUI.Color.white.opacity(0.10)

        /// Selected item background.
        public static let cardSelected = SwiftUI.Color.white.opacity(0.14)

        // MARK: - Hairline Borders

        /// Standard 1px precision boundary stroke.
        public static let border = SwiftUI.Color.white.opacity(0.08)

        /// Extremely subtle internal divider.
        public static let borderSubtle = SwiftUI.Color.white.opacity(0.04)

        /// Focused / Active element outline.
        public static let borderActive = SwiftUI.Color.white.opacity(0.22)

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

        // MARK: - Typography Shades (Always High Contrast White over Wallpaper)

        public static let textPrimary = SwiftUI.Color.white
        
        public static let textSecondary = SwiftUI.Color.white.opacity(0.72)
        
        public static let textTertiary = SwiftUI.Color.white.opacity(0.48)
        
        public static let textMuted = SwiftUI.Color.white.opacity(0.28)
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
