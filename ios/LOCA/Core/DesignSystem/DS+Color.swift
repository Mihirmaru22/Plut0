//
//  DS+Color.swift
//  LOCA
//
//  Phase 11 — Semantic color roles.
//
//  These roles layer ON TOP OF the frozen 12-entry ColorPalette (ADR-002). The
//  palette is never reordered or replaced; DS.Color only adds semantic surface,
//  text, and separator roles plus a typed accent accessor.
//
//  Cross-platform note: iOS system background/label colors are UIKit-backed and
//  unavailable on macOS. Surface and line roles are therefore defined with
//  #if os(iOS) / #else(AppKit) branches so both platforms build and each uses its
//  native semantic colors. Text tiers use SwiftUI's cross-platform semantic colors.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension DS {

    /// Semantic color roles. Habit accent colors still come from `ColorPalette`
    /// (indexed, append-only); these roles cover surfaces, text tiers, and lines.
    enum Color {

        // MARK: Accent (bridges to the frozen palette)

        /// The accent color for a given palette index (ADR-002). Thin wrapper so
        /// views depend on `DS.Color` rather than reaching into `ColorPalette`.
        static func accent(_ colorIndex: Int) -> SwiftUI.Color {
            ColorPalette[colorIndex]
        }

        // MARK: Surfaces (container tiers) — platform-native

        /// App background — the base canvas.
        static let background: SwiftUI.Color = {
            #if canImport(UIKit)
            SwiftUI.Color(uiColor: .systemBackground)
            #else
            SwiftUI.Color(nsColor: .windowBackgroundColor)
            #endif
        }()

        /// Raised surface — cards, tiles (one step above background).
        static let surface: SwiftUI.Color = {
            #if canImport(UIKit)
            SwiftUI.Color(uiColor: .secondarySystemBackground)
            #else
            SwiftUI.Color(nsColor: .controlBackgroundColor)
            #endif
        }()

        /// Recessed / grouped surface.
        static let surfaceRecessed: SwiftUI.Color = {
            #if canImport(UIKit)
            SwiftUI.Color(uiColor: .tertiarySystemBackground)
            #else
            SwiftUI.Color(nsColor: .underPageBackgroundColor)
            #endif
        }()

        // MARK: Text tiers (cross-platform semantic)

        static let textPrimary = SwiftUI.Color.primary
        static let textSecondary = SwiftUI.Color.secondary
        static let textTertiary: SwiftUI.Color = {
            #if canImport(UIKit)
            SwiftUI.Color(uiColor: .tertiaryLabel)
            #else
            SwiftUI.Color(nsColor: .tertiaryLabelColor)
            #endif
        }()

        // MARK: Lines

        /// Hairline separator — LOCA prefers these over container nesting.
        static let separator: SwiftUI.Color = {
            #if canImport(UIKit)
            SwiftUI.Color(uiColor: .separator)
            #else
            SwiftUI.Color(nsColor: .separatorColor)
            #endif
        }()

        /// Card / control border. Same underlying color as `separator` but named
        /// for the stroke role so callers reading `.stroke(DS.Color.border, ...)`
        /// document intent. Introduced when Phase 5 views expected this alias.
        static let border: SwiftUI.Color = separator

        // MARK: Heatmap (contribution grid)

        /// Inactive/empty heatmap cell — neutral adaptive tone visible in both
        /// light and dark modes. Using a near-zero-opacity accent on a light surface
        /// renders invisible; textPrimary at low opacity provides reliable contrast
        /// independent of theme and card background. Matches the approach used by
        /// Apple Calendar, GitHub contributions, and Apple Health activity rings:
        /// empty cells are a neutral gray, not a near-invisible tint of the accent.
        static let heatmapCellEmpty = SwiftUI.Color.primary.opacity(0.09)

        /// Future (not-yet-reached) heatmap cell — visually recessed to convey
        /// "not yet" without disappearing entirely.
        static let heatmapCellFuture = SwiftUI.Color.primary.opacity(0.04)

        // MARK: Unified App-Wide Palette Tokens (Single source of truth)

        /// Success / Complete indicator across Habits, Todos, Life, and Audit (Mint).
        static let success = ColorPalette[1]

        /// Primary active / in-progress indicator (Ocean Blue).
        static let active = ColorPalette[0]

        /// Warning / Streak Flame indicator (Amber).
        static let warning = ColorPalette[4]
        static let streak = ColorPalette[4]

        /// Danger / High-Priority / Urgency indicator (Terracotta / Coral).
        static let danger = ColorPalette[2]

        /// Unified Priority Color scale for Tasks and Milestones.
        static let priorityNone = textTertiary
        static let priorityLow = ColorPalette[9]      // Slate
        static let priorityMedium = ColorPalette[4]   // Amber
        static let priorityHigh = ColorPalette[2]     // Terracotta
    }
}

// MARK: - Universal Color Hex Initializer

extension SwiftUI.Color {
    public init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let r, g, b, a: Double
        switch cleanHex.count {
        case 3: // RGB (12-bit)
            (r, g, b, a) = (
                Double((int >> 8) * 17) / 255,
                Double((int >> 4 & 0xF) * 17) / 255,
                Double((int & 0xF) * 17) / 255,
                1.0
            )
        case 6: // RGB (24-bit)
            (r, g, b, a) = (
                Double((int >> 16) & 0xFF) / 255,
                Double((int >> 8) & 0xFF) / 255,
                Double(int & 0xFF) / 255,
                1.0
            )
        case 8: // ARGB (32-bit)
            (r, g, b, a) = (
                Double((int >> 16) & 0xFF) / 255,
                Double((int >> 8) & 0xFF) / 255,
                Double(int & 0xFF) / 255,
                Double((int >> 24) & 0xFF) / 255
            )
        default:
            (r, g, b, a) = (1, 1, 1, 1)
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

