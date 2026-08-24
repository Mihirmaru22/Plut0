import SwiftUI
import SwiftData
import AppKit
import os.log

// MARK: - LOCAMacApp

/// macOS entry point for LOCA.
///
/// Mirrors `LOCAApp` in the iOS target but omits iOS-only coordinators
/// (WidgetRefresh, Reminders, HealthKit framing sheets) and instead
/// provides a multi-window `WindowGroup` with `NavigationSplitView`
/// shell and a native menu bar via `LOCACommands`.
///
/// Container construction follows the same single-call-site discipline
/// as the iOS target: `ModelContainerFactory.makeConfiguredContainer()`
/// is called exactly once here, and the resulting container is injected
/// into the environment for all child views via `.modelContainer(_:)`.
///
/// Deployment target: macOS 14.0 (Sonoma) — required for SwiftData and
/// the `NavigationSplitView` APIs used by `MacRootView`.
@main
@MainActor
struct LOCAMacApp: App {

    private let container: ModelContainer?
    nonisolated private let logger = Logger(subsystem: "com.mihirmaru.loca.mac", category: "app")

    init() {
        // Runtime Reality Logging
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let isGlassActive: Bool
        if #available(macOS 26.0, *) {
            isGlassActive = true
        } else {
            isGlassActive = false
        }
        print("🚀 [Pluto Runtime Reality] macOS \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion) | macOS 26+ Glass Active: \(isGlassActive)")

        // Initialize Apple Native Notification Delegate & Categories (A1-A8)
        PlutoNotificationManager.shared.configure()

        // NOTE: Global hotkey monitoring is deferred to .onAppear in the
        // WindowGroup body. Calling startMonitoring() here — before the
        // NSApplication run loop is fully initialized — freezes the Cocoa
        // event dispatch pipeline and makes the entire UI unclickable.

        do {
            self.container = try ModelContainerFactory.makeConfiguredContainer()
            #if DEBUG
            if let c = self.container {
                PlutoDataResetManager.resetCheckInDataIfNeeded(context: c.mainContext)
            }
            #endif
        } catch {
            logger.error("Configured container init failed: \(error.localizedDescription). Initializing fallback local container.")
            self.container = (try? ModelContainerFactory.makeLocalContainer()) ?? (try? ModelContainerFactory.makeInMemoryContainer())
        }
    }

    @AppStorage("mac_appearance_mode") private var appearanceMode: String = "dark"

    private var preferredScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some Scene {
        WindowGroup("Pluto") {
            if let container {
                MacRootView()
                    .modelContainer(container)
                    .preferredColorScheme(preferredScheme)
                    .background(PlutoWindowAccessor())
                    .frame(minWidth: DS.Mac.windowMinWidth, minHeight: DS.Mac.windowMinHeight)
                    .onAppear {
                        // Seed calm initial workspace notes & projects if first launch
                        EmptyStateSeeder.shared.seedInitialDataIfNeeded(context: container.mainContext)

                        // Start dynamic Light/Dark Dock App Icon manager
                        PlutoDynamicAppIconManager.shared.startMonitoring()

                        // Start invisible alpha telemetry engine
                        PlutoTelemetryEngine.shared.start()

                        // Check & request notification authorization, sync active schedules
                        Task {
                            _ = await PlutoNotificationManager.shared.requestAuthorization()
                            PlutoNotificationManager.shared.rescheduleAllFromAppStorage()
                        }

                        // Defer global hotkey registration until the app
                        // window is fully displayed and the run loop is active.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            PlutoGlobalHotkeyManager.shared.startMonitoring()
                        }
                    }
            } else {
                MacContainerUnavailableView()
                    .frame(minWidth: 480, minHeight: 320)
            }
        }
        .defaultSize(width: 1280, height: 800)
        .commands {
            LOCACommands()
        }
        .windowStyle(.titleBar)
    }
}

// MARK: - MacContainerUnavailableView

private struct MacContainerUnavailableView: View {
    var body: some View {
        VStack(spacing: DS.Space.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Unable to Load Data")
                .font(DS.Text.title)
            Text("LOCA couldn't set up its data store. Please reinstall the app.")
                .font(DS.Text.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(DS.Space.xxxl)
    }
}

