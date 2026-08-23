import SwiftUI
import AppKit

// MARK: - Pluto Glass Styles

public enum PlutoGlassStyle {
    case regular
    case interactive
    case prominent
    case tinted(Color)
    case brightActive
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

// MARK: - Liquid Glass View Modifier (Real Glass on macOS 26+, Anatomy Fallback Below)

public struct PlutoGlassModifier<S: Shape>: ViewModifier {
    let style: PlutoGlassStyle
    let shape: S

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered: Bool = false
    @State private var sheenOffset: CGFloat = -1.0

    @ViewBuilder
    public func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(DS.Theme.card, in: shape)
                .overlay(shape.stroke(DS.Theme.border, lineWidth: 1))
        } else if #available(macOS 26.0, *) {
            // MARK: - Real Native Liquid Glass (macOS 26+)
            switch style {
            case .regular:
                content.glassEffect(.regular, in: shape)

            case .interactive:
                content.glassEffect(.regular.interactive(), in: shape)

            case .prominent:
                content.glassEffect(.regular, in: shape)

            case .tinted(let color):
                content.glassEffect(.regular.tint(color), in: shape)

            case .brightActive:
                content
                    .background(
                        LinearGradient(
                            colors: [
                                Color(white: 0.98),
                                Color(white: 0.90)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        in: shape
                    )
                    .overlay(
                        shape.stroke(
                            Color.white.opacity(0.85),
                            lineWidth: 1.0
                        )
                    )
                    .shadow(color: Color.black.opacity(0.30), radius: 6, x: 0, y: 2)
            }
        } else {
            // MARK: - Legacy Simulated Glass Anatomy Fallback (< macOS 26)
            switch style {
            case .regular:
                content
                    .background(glassFillGradient, in: shape)
                    .background(.ultraThinMaterial, in: shape)
                    .overlay(glassHighlightStroke(topOpacity: 0.28, bottomOpacity: 0.04))
                    .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 1.5)

            case .interactive:
                content
                    .background(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHovered ? 0.14 : 0.08),
                                Color.white.opacity(isHovered ? 0.05 : 0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        in: shape
                    )
                    .background(.regularMaterial, in: shape)
                    .overlay(glassHighlightStroke(topOpacity: isHovered ? 0.50 : 0.38, bottomOpacity: 0.06))
                    .overlay(sheenOverlay)
                    .shadow(color: Color.black.opacity(isHovered ? 0.25 : 0.16), radius: isHovered ? 6 : 4, x: 0, y: 2)
                    .onHover { hovering in
                        withAnimation(PlutoSpring.snappy) {
                            isHovered = hovering
                        }
                        if hovering && !reduceMotion {
                            sheenOffset = -1.0
                            withAnimation(.easeInOut(duration: 0.45)) {
                                sheenOffset = 1.5
                            }
                        }
                    }

            case .prominent:
                content
                    .background(
                        LinearGradient(
                            colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        in: shape
                    )
                    .background(.thinMaterial, in: shape)
                    .overlay(glassHighlightStroke(topOpacity: 0.55, bottomOpacity: 0.08))
                    .shadow(color: Color.black.opacity(0.28), radius: 8, x: 0, y: 3)

            case .tinted(let color):
                content
                    .background(color.opacity(0.14), in: shape)
                    .background(glassFillGradient, in: shape)
                    .background(.ultraThinMaterial, in: shape)
                    .overlay(
                        shape.stroke(
                            LinearGradient(
                                colors: [
                                    color.opacity(0.50),
                                    color.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.0
                        )
                    )
                    .shadow(color: color.opacity(0.18), radius: 5, x: 0, y: 2)

            case .brightActive:
                content
                    .background(
                        LinearGradient(
                            colors: [
                                Color(white: 0.98),
                                Color(white: 0.90)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        in: shape
                    )
                    .overlay(
                        shape.stroke(
                            Color.white.opacity(0.85),
                            lineWidth: 1.0
                        )
                    )
                    .shadow(color: Color.black.opacity(0.30), radius: 6, x: 0, y: 2)
            }
        }
    }

    private var glassFillGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.08),
                Color.white.opacity(0.02)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func glassHighlightStroke(topOpacity: Double, bottomOpacity: Double) -> some View {
        shape.stroke(
            LinearGradient(
                colors: [
                    Color.white.opacity(topOpacity),
                    Color.white.opacity(bottomOpacity)
                ],
                startPoint: .top,
                endPoint: .bottom
            ),
            lineWidth: 1.0
        )
    }

    @ViewBuilder
    private var sheenOverlay: some View {
        if isHovered && !reduceMotion {
            shape
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.35),
                            Color.clear
                        ],
                        startPoint: UnitPoint(x: sheenOffset - 0.3, y: 0.0),
                        endPoint: UnitPoint(x: sheenOffset + 0.3, y: 1.0)
                    ),
                    lineWidth: 1.5
                )
                .allowsHitTesting(false)
        }
    }
}

// MARK: - View Extensions

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

// MARK: - PlutoGlassCluster (Unshadowed Container Helper)

public struct PlutoGlassCluster<Content: View>: View {
    public let spacing: CGFloat
    @ViewBuilder public let content: () -> Content

    public init(spacing: CGFloat = 4, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                HStack(spacing: spacing) {
                    content()
                }
            }
        } else {
            HStack(spacing: spacing) {
                content()
            }
            .padding(3)
            .plutoGlass(.regular, in: Capsule())
        }
    }
}

// MARK: - Ambient Light Glow View (6-10% Opacity Mesh / Drift)

public struct PlutoAmbientGlowView: View {
    public let accent: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(accent: Color) {
        self.accent = accent
    }

    public var body: some View {
        if reduceMotion {
            RadialGradient(
                colors: [
                    accent.opacity(0.08),
                    accent.opacity(0.02),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 10,
                endRadius: 460
            )
            .allowsHitTesting(false)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let phase = (now.truncatingRemainder(dividingBy: 60.0)) / 60.0
                let xOffset = sin(phase * 2 * .pi) * 0.12
                let yOffset = cos(phase * 2 * .pi) * 0.08

                RadialGradient(
                    colors: [
                        accent.opacity(0.09),
                        accent.opacity(0.03),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.25 + xOffset, y: 0.15 + yOffset),
                    startRadius: 20,
                    endRadius: 480
                )
                .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - AppKit Window Configurator (Desktop Wallpaper Blur Through Sidebar)

public struct PlutoWindowAccessor: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.isOpaque = false
                window.backgroundColor = .clear
                window.styleMask.insert(.fullSizeContentView)
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
            }
        }
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {}
}
