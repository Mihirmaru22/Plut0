import SwiftUI
import AppKit

// MARK: - Native Liquid Glass Styles

public enum PlutoGlassStyle {
    case regular
    case interactive
    case prominent
    case tinted(Color)
    case brightActive
}

// MARK: - Spring Vocabulary (Crisp & Snappy)

public enum PlutoSpring {
    /// For sliding indicators, selection pills, and spatial tracking
    public static let snappy: Animation = .snappy(duration: 0.22, extraBounce: 0.0)
    /// For content swaps, focus transitions, and disclosure rotations
    public static let smooth: Animation = .smooth(duration: 0.20)
    /// For checkmark toggle
    public static let bouncy: Animation = .bouncy(duration: 0.25, extraBounce: 0.15)
    /// Fallback crossfade for reduce motion
    public static let reduceMotion: Animation = .linear(duration: 0.12)
}

// MARK: - Native Liquid Glass View Modifier

public struct PlutoGlassModifier<S: Shape>: ViewModifier {
    let style: PlutoGlassStyle
    let shape: S

    /// A semantic native-glass choice, not a simulated blur-strength control.
    /// The resulting material still follows macOS appearance and accessibility.
    @AppStorage("mac_glass_variant") private var glassVariant = "regular"

    public func body(content: Content) -> some View {
        content.glassEffect(glass, in: shape)
    }

    private var glass: Glass {
        let base: Glass = glassVariant == "clear" ? .clear : .regular
        switch style {
        case .regular, .prominent:
            return base
        case .interactive:
            return base.interactive()
        case .tinted(let color):
            return base.tint(color)
        case .brightActive:
            return Glass.clear.interactive()
        }
    }
}

// MARK: - Native Liquid Glass Button Styles

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

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("mac_glass_variant") private var glassVariant = "regular"

    var body: some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .glassEffect(nativeGlass, in: shape)
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(reduceMotion ? nil : PlutoSpring.snappy, value: configuration.isPressed)
    }

    private var nativeGlass: Glass {
        let base: Glass = glassVariant == "clear" ? .clear : .regular
        if let tint {
            return base.tint(tint).interactive()
        }
        if isProminent {
            return base.tint(DS.Theme.amber).interactive()
        }
        return base.interactive()
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

extension ButtonStyle where Self == PlutoGlassButtonStyle<Circle> {
    public static var plutoGlassCircle: PlutoGlassButtonStyle<Circle> {
        PlutoGlassButtonStyle(shape: Circle(), tint: nil, isProminent: false)
    }

    public static func plutoGlassCircle(tint: Color? = nil) -> PlutoGlassButtonStyle<Circle> {
        PlutoGlassButtonStyle(shape: Circle(), tint: tint, isProminent: false)
    }
}

extension ButtonStyle {
    public static func plutoGlass<S: Shape>(shape: S, tint: Color? = nil, isProminent: Bool = false) -> PlutoGlassButtonStyle<S> where Self == PlutoGlassButtonStyle<S> {
        PlutoGlassButtonStyle(shape: shape, tint: tint, isProminent: isProminent)
    }

    public static func plutoGlassProminent<S: Shape>(shape: S, tint: Color? = nil) -> PlutoGlassButtonStyle<S> where Self == PlutoGlassButtonStyle<S> {
        PlutoGlassButtonStyle(shape: shape, tint: tint, isProminent: true)
    }
}

extension ButtonStyle where Self == PlutoGlassButtonStyle<RoundedRectangle> {
    public static func plutoGlass(cornerRadius: CGFloat = 6, tint: Color? = nil, isProminent: Bool = false) -> PlutoGlassButtonStyle<RoundedRectangle> {
        PlutoGlassButtonStyle(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), tint: tint, isProminent: isProminent)
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

// MARK: - PlutoGlassCluster

public struct PlutoGlassCluster<Content: View>: View {
    public let spacing: CGFloat
    @ViewBuilder public let content: () -> Content

    public init(spacing: CGFloat = 3, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        GlassEffectContainer(spacing: spacing) {
            HStack(spacing: spacing) {
                content()
            }
        }
    }
}

// MARK: - Native Liquid Glass Active Pill

public struct LiquidGlassLensPill: View {
    public let namespace: Namespace.ID
    public var id: String = "liquidGlassLensPill"

    public init(namespace: Namespace.ID, id: String = "liquidGlassLensPill") {
        self.namespace = namespace
        self.id = id
    }

    public var body: some View {
        Capsule()
            .fill(.clear)
            .glassEffect(.regular.interactive(), in: Capsule())
            .glassEffectID(id, in: namespace)
            .glassEffectTransition(.matchedGeometry)
    }
}

// MARK: - Native Liquid Glass Segmented Switcher

public struct PlutoGlassSegmentedPicker<SelectionValue: Hashable, Content: View>: View {
    @Binding public var selection: SelectionValue
    public let items: [SelectionValue]
    public let content: (SelectionValue, Bool) -> Content
    public let externalNamespace: Namespace.ID?

    @Namespace private var internalNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var effectiveNamespace: Namespace.ID {
        externalNamespace ?? internalNamespace
    }

    public init(
        selection: Binding<SelectionValue>,
        items: [SelectionValue],
        namespace: Namespace.ID? = nil,
        @ViewBuilder content: @escaping (SelectionValue, Bool) -> Content
    ) {
        self._selection = selection
        self.items = items
        self.externalNamespace = namespace
        self.content = content
    }
    
    public var body: some View {
        GlassEffectContainer(spacing: 2) {
            HStack(spacing: 2) {
                ForEach(items, id: \.self) { item in
                    let isSelected = selection == item
                    Button {
                        guard selection != item else { return }
                        if reduceMotion {
                            selection = item
                        } else {
                            withAnimation(PlutoSpring.snappy) {
                                selection = item
                            }
                        }
                        Haptics.selection()
                    } label: {
                        content(item, isSelected)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .background {
                        if isSelected {
                            LiquidGlassLensPill(namespace: effectiveNamespace)
                        }
                    }
                }
            }
        }
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
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.60))
        }
    }
}

// MARK: - Ambient Light Glow View (Zero Glow in Plain Canvas)

public struct PlutoAmbientGlowView: View {
    public let accent: Color

    public init(accent: Color) {
        self.accent = accent
    }

    public var body: some View {
        Color.clear
            .allowsHitTesting(false)
    }
}

// MARK: - AppKit Window Configurator

public struct PlutoWindowAccessor: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.isOpaque = false
                window.backgroundColor = NSColor(white: 0.09, alpha: 0.88)
                window.styleMask.insert(.fullSizeContentView)
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
            }
        }
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {}
}
