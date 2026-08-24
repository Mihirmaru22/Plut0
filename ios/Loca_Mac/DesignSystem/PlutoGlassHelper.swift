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

// MARK: - Native Liquid Glass Button Styles (macOS Golden Gate HIG)

public struct PlutoGlassButtonStyle<S: Shape>: ButtonStyle {
    public let shape: S
    public let tint: Color?
    public let isProminent: Bool

    public init(shape: S, tint: Color? = nil, isProminent: Bool = false) {
        self.shape = shape
        self.tint = tint
        self.isProminent = isProminent
    }

    public func makeBody(configuration: Configuration) -> some View {
        PlutoGlassButtonBody(configuration: configuration, shape: shape, tint: tint, isProminent: isProminent)
    }
}

private struct PlutoGlassButtonBody<S: Shape>: View {
    let configuration: ButtonStyle.Configuration
    let shape: S
    let tint: Color?
    let isProminent: Bool

    @State private var isHovered: Bool = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                if reduceTransparency {
                    shape
                        .fill(isProminent ? (tint ?? DS.Theme.amber) : DS.Theme.card)
                } else if isProminent {
                    // Prominent Glass Fill
                    ZStack {
                        let baseColor = tint ?? DS.Theme.amber
                        shape
                            .fill(
                                LinearGradient(
                                    colors: [
                                        baseColor.opacity(isHovered ? 0.95 : 0.85),
                                        baseColor.opacity(isHovered ? 0.80 : 0.70)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        shape
                            .stroke(Color.white.opacity(0.40), lineWidth: 0.8)
                    }
                    .shadow(color: (tint ?? DS.Theme.amber).opacity(isHovered ? 0.35 : 0.20), radius: isHovered ? 6 : 3, y: 1.5)
                } else {
                    // Standard Liquid Glass Fill
                    ZStack {
                        if let tint = tint {
                            shape.fill(tint.opacity(isHovered ? 0.18 : 0.10))
                        } else {
                            shape.fill(Color.white.opacity(isHovered ? 0.12 : 0.05))
                        }
                    }
                    .background(.ultraThinMaterial, in: shape)
                    .overlay(
                        shape.stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isHovered ? 0.45 : 0.25),
                                    Color.white.opacity(isHovered ? 0.15 : 0.04)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.8
                        )
                    )
                    .shadow(color: Color.black.opacity(isHovered ? 0.20 : 0.10), radius: isHovered ? 5 : 2.5, y: 1.5)
                }
            }
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.96 : (isHovered ? 1.01 : 1.0))
            .opacity(isEnabled ? (configuration.isPressed ? 0.88 : 1.0) : 0.45)
            .animation(reduceMotion ? nil : PlutoSpring.snappy, value: isHovered)
            .animation(reduceMotion ? nil : PlutoSpring.snappy, value: configuration.isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
    }

    private var foregroundColor: Color {
        if !isEnabled { return DS.Theme.textTertiary }
        if isProminent {
            return (tint == nil || tint == DS.Theme.amber) ? Color.black.opacity(0.92) : Color.white
        }
        if let tint = tint {
            return tint
        }
        return isHovered ? Color.white : DS.Theme.textPrimary
    }
}

// MARK: - ButtonStyle Static Extensions

extension ButtonStyle where Self == PlutoGlassButtonStyle<Capsule> {
    public static var plutoGlass: PlutoGlassButtonStyle<Capsule> {
        PlutoGlassButtonStyle(shape: Capsule(), tint: nil, isProminent: false)
    }

    public static var plutoGlassProminent: PlutoGlassButtonStyle<Capsule> {
        PlutoGlassButtonStyle(shape: Capsule(), tint: nil, isProminent: true)
    }

    public static func plutoGlass(isProminent: Bool = false, tint: Color? = nil) -> PlutoGlassButtonStyle<Capsule> {
        PlutoGlassButtonStyle(shape: Capsule(), tint: tint, isProminent: isProminent)
    }

    public static func plutoGlass(tint: Color?) -> PlutoGlassButtonStyle<Capsule> {
        PlutoGlassButtonStyle(shape: Capsule(), tint: tint, isProminent: false)
    }

    public static func plutoGlassProminent(tint: Color?) -> PlutoGlassButtonStyle<Capsule> {
        PlutoGlassButtonStyle(shape: Capsule(), tint: tint, isProminent: true)
    }
}

extension ButtonStyle {
    public static func plutoGlass<S: Shape>(shape: S, isProminent: Bool = false, tint: Color? = nil) -> PlutoGlassButtonStyle<S> {
        PlutoGlassButtonStyle(shape: shape, tint: tint, isProminent: isProminent)
    }

    public static func plutoGlass<S: Shape>(shape: S, tint: Color?) -> PlutoGlassButtonStyle<S> {
        PlutoGlassButtonStyle(shape: shape, tint: tint, isProminent: false)
    }

    public static func plutoGlassProminent<S: Shape>(shape: S, tint: Color? = nil) -> PlutoGlassButtonStyle<S> {
        PlutoGlassButtonStyle(shape: shape, tint: tint, isProminent: true)
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

// MARK: - Liquid Glass Optical Lens Pill (Chromatic Aberration & Spectral Rim)

public struct LiquidGlassLensPill: View {
    public let namespace: Namespace.ID
    public var id: String = "liquidGlassLensPill"
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(namespace: Namespace.ID, id: String = "liquidGlassLensPill") {
        self.namespace = namespace
        self.id = id
    }

    public var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.24),
                        Color.white.opacity(0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .background(.ultraThinMaterial, in: Capsule())
            // Top/Bottom Specular Edge Reflection
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.90),
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.45)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.0
                    )
            )
            // Chromatic Spectral Dispersion Rim (Cyan ➔ Amber ➔ Magenta Prismatic Refraction)
            .overlay(
                Capsule()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.70),
                                Color.white.opacity(0.95),
                                Color(red: 1.0, green: 0.65, blue: 0.15).opacity(0.75),
                                Color(red: 0.95, green: 0.35, blue: 0.75).opacity(0.60),
                                Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.70)
                            ]),
                            center: .center
                        ),
                        lineWidth: 0.9
                    )
                    .blendMode(.screen)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 7, x: 0, y: 2.5)
            .matchedGeometryEffect(id: id, in: namespace)
    }
}

// MARK: - PlutoGlassSegmentedPicker (macOS Golden Gate Segmented Glass Control)

public struct PlutoGlassSegmentedPicker<SelectionValue: Hashable, Content: View>: View {
    @Binding public var selection: SelectionValue
    public let items: [SelectionValue]
    public let content: (SelectionValue, Bool) -> Content
    
    @Namespace private var pickerNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init(
        selection: Binding<SelectionValue>,
        items: [SelectionValue],
        @ViewBuilder content: @escaping (SelectionValue, Bool) -> Content
    ) {
        self._selection = selection
        self.items = items
        self.content = content
    }
    
    public var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.self) { item in
                let isSelected = selection == item
                Button {
                    guard selection != item else { return }
                    withAnimation(reduceMotion ? nil : PlutoSpring.snappy) {
                        selection = item
                    }
                    Haptics.selection()
                } label: {
                    content(item, isSelected)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5.5)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .background {
                    if isSelected {
                        LiquidGlassLensPill(namespace: pickerNamespace)
                    }
                }
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
                .background(.ultraThinMaterial, in: Capsule())
        )
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.20),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
        )
    }
}

public struct PlutoGlassSegmentedControl: View {
    @Binding public var selection: String
    public let options: [String]
    
    public init(selection: Binding<String>, options: [String]) {
        self._selection = selection
        self.options = options
    }
    
    public var body: some View {
        PlutoGlassSegmentedPicker(selection: $selection, items: options) { item, isSelected in
            Text(item)
                .font(.system(size: 12.5, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.65))
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
