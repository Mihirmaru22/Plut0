import SwiftUI

// MARK: - Pluto Glass Styles

public enum PlutoGlassStyle {
    case regular
    case interactive
    case prominent
    case tinted(Color)
}

// MARK: - Spring Vocabulary

public enum PlutoSpring {
    /// For sliding indicators, selection pills, and spatial tracking
    public static let snappy: Animation = .snappy(duration: 0.28, extraBounce: 0.08)
    /// For content swaps, focus transitions, and disclosure rotations
    public static let smooth: Animation = .smooth(duration: 0.25)
    /// ONLY for celebratory actions (e.g. task checkmark completion bounce)
    public static let bouncy: Animation = .bouncy(duration: 0.35, extraBounce: 0.22)
    /// Fallback crossfade for reduce motion
    public static let reduceMotion: Animation = .linear(duration: 0.15)
}

// MARK: - Liquid Glass View Modifier

public struct PlutoGlassModifier<S: Shape>: ViewModifier {
    let style: PlutoGlassStyle
    let shape: S

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    public func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(DS.Theme.card, in: shape)
                .overlay(shape.stroke(DS.Theme.border, lineWidth: 1))
        } else {
            switch style {
            case .regular:
                content
                    .background(.ultraThinMaterial, in: shape)
                    .overlay(glassHighlightStroke(topOpacity: 0.24))
                    .shadow(color: Color.black.opacity(0.14), radius: 4, x: 0, y: 1.5)

            case .interactive:
                content
                    .background(.regularMaterial, in: shape)
                    .overlay(glassHighlightStroke(topOpacity: 0.40))
                    .shadow(color: Color.black.opacity(0.18), radius: 5, x: 0, y: 2)

            case .prominent:
                content
                    .background(.thinMaterial, in: shape)
                    .overlay(glassHighlightStroke(topOpacity: 0.48))
                    .shadow(color: Color.black.opacity(0.20), radius: 6, x: 0, y: 2)

            case .tinted(let color):
                content
                    .background(.ultraThinMaterial, in: shape)
                    .background(shape.fill(color.opacity(0.12)))
                    .overlay(glassHighlightStroke(topOpacity: 0.32))
                    .shadow(color: Color.black.opacity(0.14), radius: 4, x: 0, y: 1.5)
            }
        }
    }

    private func glassHighlightStroke(topOpacity: Double) -> some View {
        shape.stroke(
            LinearGradient(
                colors: [
                    Color.white.opacity(topOpacity),
                    Color.white.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            lineWidth: 0.85
        )
    }
}

// MARK: - View Extension

extension View {
    @ViewBuilder
    public func plutoGlass<S: Shape>(_ style: PlutoGlassStyle = .regular, in shape: S) -> some View {
        self.modifier(PlutoGlassModifier(style: style, shape: shape))
    }

    @ViewBuilder
    public func plutoGlass(_ style: PlutoGlassStyle = .regular) -> some View {
        self.modifier(PlutoGlassModifier(style: style, shape: Capsule()))
    }
}

// MARK: - GlassEffectContainer

public struct GlassEffectContainer<Content: View>: View {
    public let spacing: CGFloat
    @ViewBuilder public let content: () -> Content

    public init(spacing: CGFloat = 4, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        HStack(spacing: spacing) {
            content()
        }
        .padding(3)
        .plutoGlass(.regular, in: Capsule())
    }
}
