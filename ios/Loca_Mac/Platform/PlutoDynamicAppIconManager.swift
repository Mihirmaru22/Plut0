import AppKit
import Combine

/// Manages dynamic Light & Dark mode Dock App Icon switching on macOS.
/// Automatically updates `NSApplication.shared.applicationIconImage` when the system appearance toggles.
@MainActor
public final class PlutoDynamicAppIconManager: ObservableObject {
    public static let shared = PlutoDynamicAppIconManager()

    private var cancellables = Set<AnyCancellable>()

    private var lightIconImage: NSImage? {
        if let image = NSImage(named: "light_512x512@2x") ?? NSImage(named: "light_512x512") {
            return image
        }
        // Fallback to loading from AppIcon asset
        return NSImage(named: "AppIcon")
    }

    private var darkIconImage: NSImage? {
        if let image = NSImage(named: "dark_512x512@2x") ?? NSImage(named: "dark_512x512") {
            return image
        }
        return NSImage(named: "AppIcon")
    }

    private init() {}

    /// Starts monitoring macOS appearance changes and applies the appropriate app icon.
    public func startMonitoring() {
        updateDockIcon()

        // 1. Listen to macOS interface theme change notification
        DistributedNotificationCenter.default()
            .publisher(for: Notification.Name("AppleInterfaceThemeChangedNotification"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateDockIcon()
            }
            .store(in: &cancellables)

        // 2. Also listen to NSApplication effectiveAppearance changes
        NSApp.publisher(for: \.effectiveAppearance)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateDockIcon()
            }
            .store(in: &cancellables)
    }

    /// Evaluates current macOS appearance and applies either the Light or Dark Ghostty App Icon to the Dock.
    public func updateDockIcon() {
        let isDarkMode: Bool
        if let appearance = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) {
            isDarkMode = (appearance == .darkAqua)
        } else {
            isDarkMode = NSApp.effectiveAppearance.name.rawValue.lowercased().contains("dark")
        }

        if isDarkMode {
            if let darkIcon = darkIconImage {
                NSApplication.shared.applicationIconImage = darkIcon
            }
        } else {
            if let lightIcon = lightIconImage {
                NSApplication.shared.applicationIconImage = lightIcon
            }
        }
    }
}
