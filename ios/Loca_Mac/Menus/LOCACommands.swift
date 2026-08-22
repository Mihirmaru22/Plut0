import SwiftUI

// MARK: - LOCACommands

/// LOCA's native macOS menu bar commands.
///
/// Registered on the `WindowGroup` scene via `.commands { LOCACommands() }`.
/// Keyboard shortcuts:
/// - ⌘N   New Task / Block
/// - ⌘⇧H  New Habit
/// - ⌘L   Log Today
/// - ⌘1–4 Jump to sidebar section (Today, Notes, Studio, Life)
/// - ⌘,   Settings & Preferences
struct LOCACommands: Commands {

    var body: some Commands {
        // MARK: Habit menu
        CommandMenu("Habit") {
            Button("New Habit") {
                NotificationCenter.default.post(name: .locaNewHabit, object: nil)
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])

            Button("Log Today") {
                NotificationCenter.default.post(name: .locaLogToday, object: nil)
            }
            .keyboardShortcut("l", modifiers: [.command])

            Divider()

            // Section jump shortcuts mirror standard Mac sidebar navigation.
            Button("Today") { NotificationCenter.default.post(name: .locaJumpToSection, object: MacSection.today) }
                .keyboardShortcut("1", modifiers: [.command])

            Button("Studio") { NotificationCenter.default.post(name: .locaJumpToSection, object: MacSection.studio) }
                .keyboardShortcut("2", modifiers: [.command])

            Button("Life") { NotificationCenter.default.post(name: .locaJumpToSection, object: MacSection.life) }
                .keyboardShortcut("3", modifiers: [.command])

            Button("Settings") { NotificationCenter.default.post(name: .locaJumpToSection, object: MacSection.settings) }
                .keyboardShortcut(",", modifiers: [.command])
        }

        // MARK: Today menu
        CommandMenu("Today") {
            Button("New Task / Block") {
                NotificationCenter.default.post(name: .locaAddBlock, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button("Jump to Today") {
                NotificationCenter.default.post(name: .locaJumpToToday, object: nil)
            }
            .keyboardShortcut("t", modifiers: [.command])

            Divider()

            Button("Previous Day") {
                NotificationCenter.default.post(name: .locaShiftDay, object: -1)
            }
            .keyboardShortcut(.leftArrow, modifiers: [.option])

            Button("Next Day") {
                NotificationCenter.default.post(name: .locaShiftDay, object: 1)
            }
            .keyboardShortcut(.rightArrow, modifiers: [.option])

            Divider()

            Button("Nudge Block Earlier") {
                NotificationCenter.default.post(name: .locaNudgeBlock, object: -5)
            }
            .keyboardShortcut(.upArrow, modifiers: [.option])

            Button("Nudge Block Later") {
                NotificationCenter.default.post(name: .locaNudgeBlock, object: 5)
            }
            .keyboardShortcut(.downArrow, modifiers: [.option])

            Divider()

            Button("Complete Task") {
                NotificationCenter.default.post(name: .locaCompleteSelected, object: nil)
            }
            .keyboardShortcut(.return, modifiers: [.command])

            Button("Archive Task") {
                NotificationCenter.default.post(name: .locaArchiveSelected, object: nil)
            }
            .keyboardShortcut(.delete, modifiers: [.command])
        }

        // MARK: - App Info Menu
        CommandGroup(replacing: .appInfo) {
            Button("About Pluto") {
                NSApplication.shared.orderFrontStandardAboutPanel(
                    options: [
                        NSApplication.AboutPanelOptionKey.applicationName: "Pluto",
                        NSApplication.AboutPanelOptionKey.version: "3.5.0",
                        NSApplication.AboutPanelOptionKey.applicationVersion: "V3.5 (Alpha)"
                    ]
                )
            }
        }

        // MARK: Help menu
        CommandGroup(replacing: .help) {
            Button("Welcome & Feature Tour…") {
                NotificationCenter.default.post(name: .locaShowOnboarding, object: nil)
            }
        }
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let locaNewHabit         = Notification.Name("com.mihirmaru.loca.mac.newHabit")
    static let locaLogToday         = Notification.Name("com.mihirmaru.loca.mac.logToday")
    static let locaJumpToSection    = Notification.Name("com.mihirmaru.loca.mac.jumpToSection")
    static let locaJumpToToday      = Notification.Name("com.mihirmaru.loca.mac.jumpToToday")
    static let locaShiftDay         = Notification.Name("com.mihirmaru.loca.mac.shiftDay")
    static let locaNudgeBlock       = Notification.Name("com.mihirmaru.loca.mac.nudgeBlock")
    static let locaAddBlock         = Notification.Name("com.mihirmaru.loca.mac.addBlock")
    static let locaCompleteSelected = Notification.Name("com.mihirmaru.loca.mac.completeSelected")
    static let locaArchiveSelected  = Notification.Name("com.mihirmaru.loca.mac.archiveSelected")
    static let locaFocusQuickAdd    = Notification.Name("com.mihirmaru.loca.mac.focusQuickAdd")
    static let locaOpenTask         = Notification.Name("com.mihirmaru.loca.mac.openTask")
    static let locaShowOnboarding   = Notification.Name("com.mihirmaru.loca.mac.showOnboarding")
    static let locaDeepLink         = Notification.Name("com.mihirmaru.loca.mac.deepLink")
    static let locaLockVault        = Notification.Name("com.mihirmaru.loca.mac.lockVault")
}
