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

    public func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(DS.Theme.card, in: shape)
                .overlay(shape.stroke(DS.Theme.border, lineWidth: 1))
        } else {
            content
                .background(glassBackground, in: shape)
                .overlay(glassHighlightStroke)
                .shadow(color: Color.black.opacity(0.14), radius: 4, x: 0, y: 1.5)
        }
    }

    @ViewBuilder
    private var glassBackground: some View {
        switch style {
        case .regular:
            Material.ultraThinMaterial
        case .interactive:
            Material.regularMaterial
        case .prominent:
            Material.thinMaterial
        case .tinted(let color):
            ZStack {
                Material.ultraThinMaterial
                color.opacity(0.12)
            }
        }
    }

    private var glassHighlightStroke: some View {
        let opacityTop: Double = {
            switch style {
            case .regular: return 0.24
            case .interactive: return 0.40
            case .prominent: return 0.48
            case .tinted: return 0.32
            }
        }()

        return shape.stroke(
            LinearGradient(
                colors: [
                    Color.white.opacity(opacityTop),
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
