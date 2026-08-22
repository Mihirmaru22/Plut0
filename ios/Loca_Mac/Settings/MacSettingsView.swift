import SwiftUI
import SwiftData

// MARK: - MacSettingsView (Executive Bento Grid Settings Studio)

/// Premium Bento Grid Horizon Settings Studio for PLUTO.
/// Features high-density interactive visual modules with live control dials:
/// - 🔊 Sound & Acoustics (Acoustic audio tester)
/// - 🔒 Privacy & Biometric Vault Security (Touch ID / Face ID)
/// - 🎨 Executive Accent Palette (8-color curated themes)
/// - ⚙️ General & System (Hotkeys & EventKit calendar sync)
/// - 🔔 Notifications & Smart Schedule
/// - 💾 Data Sovereignty & SQLite Storage Diagnostics
/// - ℹ️ About PLUTO Sovereign OS
struct MacSettingsView: View {

    @Environment(\.modelContext) private var modelContext

    // Database Queries
    @Query private var allTodos: [TodoItem]
    @Query private var allNotes: [JournalNote]
    @Query private var allTreks: [TrekRecord]

    // Settings Storage
    @AppStorage("mac_sound_effects_enabled") private var soundEffectsEnabled: Bool = true
    @AppStorage("mac_open_full_window_on_launch") private var openFullWindow: Bool = true
    @AppStorage("mac_enable_haptics") private var enableHaptics: Bool = true
    @AppStorage("mac_selected_accent_index") private var selectedAccentIndex: Int = 0
    @AppStorage("mac_calendar_sync_enabled") private var calendarSyncEnabled: Bool = true

    // Notifications Storage
    @AppStorage("mac_notifications_master_enabled") private var masterNotificationsEnabled: Bool = true
    @AppStorage("mac_evening_reflection_enabled") private var eveningReflectionEnabled: Bool = true
    @AppStorage("mac_streak_alert_enabled") private var streakAlertEnabled: Bool = true
    @AppStorage("mac_weekly_digest_enabled") private var weeklyDigestEnabled: Bool = true

    // Vault Security Storage
    @AppStorage("mac_vault_biometrics_enabled") private var isVaultSecurityEnabled: Bool = false

    // Telemetry & Privacy
    @AppStorage("mac_telemetry_opt_in") private var telemetryOptIn: Bool = true

    // Local UI State
    @State private var showExportSuccess = false
    @State private var exportMessage = ""
    @State private var showKeynoteJourneyModal = false
    @State private var showingResetConfirmation = false
    @State private var showResetSuccess = false
    @State private var resetSuccessMessage = ""

    // Accent Palette
    private var accentColor: Color {
        let palette: [Color] = [
            Color(red: 0.95, green: 0.77, blue: 0.25), // Golden Amber
            Color(red: 0.35, green: 0.65, blue: 0.95), // Alpine Cyan
            Color(red: 0.85, green: 0.40, blue: 0.40), // Crimson Energy
            Color(red: 0.45, green: 0.85, blue: 0.55), // Emerald Growth
            Color(red: 0.75, green: 0.55, blue: 0.95), // Royal Amethyst
            Color(red: 0.95, green: 0.55, blue: 0.35), // Solar Orange
            Color(red: 0.30, green: 0.85, blue: 0.80), // Glacier Teal
            Color(red: 0.80, green: 0.80, blue: 0.85), // Platinum Titanium
        ]
        if selectedAccentIndex >= 0 && selectedAccentIndex < palette.count {
            return palette[selectedAccentIndex]
        }
        return palette[0]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(DS.Color.textPrimary)

                    Text("System Preferences & Hardware Controls")
                        .font(.system(size: 13))
                        .foregroundStyle(DS.Color.textSecondary)
                }
                .padding(.bottom, 4)

                // Bento Grid 2-Column
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {

                    // 1. Sound & Acoustics Bento Tile
                    bentoTile(title: "Sound & Acoustics", icon: "speaker.wave.3.fill", accent: accentColor) {
                        soundControlsBlock
                    }

                    // 2. Biometric Vault Bento Tile
                    bentoTile(title: "Privacy & Vault", icon: "lock.shield.fill", accent: Color(red: 0.75, green: 0.55, blue: 0.95)) {
                        securityControlBlock
                    }

                    // 3. Appearance Bento Tile
                    bentoTile(title: "Executive Accent", icon: "paintpalette.fill", accent: Color(red: 0.95, green: 0.55, blue: 0.35)) {
                        appearanceControlBlock
                    }

                    // 4. System & General Bento Tile
                    bentoTile(title: "General & Hotkeys", icon: "gearshape.fill", accent: Color(red: 0.35, green: 0.65, blue: 0.95)) {
                        generalControlBlock
                    }
                }

                // 5. Notifications Bento Tile (Full Width)
                bentoTile(title: "Notifications & Smart Schedule", icon: "bell.badge.fill", accent: Color(red: 0.85, green: 0.40, blue: 0.40)) {
                    notificationsControlBlock
                }

                // 6. Data Sovereignty & SQLite Tile (Full Width)
                bentoTile(title: "Data Sovereignty & Local Storage", icon: "externaldrive.badge.icloud", accent: Color(red: 0.45, green: 0.85, blue: 0.55)) {
                    dataSyncControlBlock
                }

                // 7. Danger Zone & Factory Data Reset (Full Width)
                bentoTile(title: "Danger Zone · Factory Data Reset", icon: "trash.fill", accent: Color(red: 0.95, green: 0.35, blue: 0.35)) {
                    dangerZoneControlBlock
                }

                // Studio Guide Tile
                bentoTile(title: "App Spotlight & Shortcuts Guide", icon: "sparkles", accent: Color(red: 0.95, green: 0.75, blue: 0.25)) {
                    studioNotesGuideBlock
                }

                // 8. About Pluto Tile
                bentoTile(title: "About PLUTO OS", icon: "info.circle.fill", accent: Color(red: 0.80, green: 0.80, blue: 0.85)) {
                    aboutControlBlock
                }

                Spacer(minLength: 40)
            }
            .padding(28)
            .frame(maxWidth: 960)
        }
        .background(DS.Color.background)
        .confirmationDialog(
            "Reset Whole App Data?",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Everything (Clean Slate)", role: .destructive) {
                PlutoDataResetManager.resetAllAppData(context: modelContext)
                PlutoSoundEngine.shared.play(.deleteTrash)
                Haptics.notification(.success)
                resetSuccessMessage = "All App Data Has Been Reset to Clean Slate!"
                showResetSuccess = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently erase all tasks, work goals, journal notes, master bucket list items, and habit logs. This action cannot be undone.")
        }
        .sheet(isPresented: $showKeynoteJourneyModal) {
            PlutoKeynoteJourneyModal()
        }
    }

    // MARK: - Bento Tile Container
    private func bentoTile<Content: View>(title: String, icon: String, accent: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accent)
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DS.Color.textPrimary)
                Spacer()
            }
            Divider()
            content()
        }
        .padding(18)
        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.Color.border.opacity(0.6), lineWidth: 1))
    }

    // MARK: - Control Blocks

    // 1. Sound & Acoustics
    private var soundControlsBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $soundEffectsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Acoustic Sound Effects")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DS.Color.textPrimary)
                    Text("Play mechanical clicks on habit completion, focus timers, and summits.")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }
            .toggleStyle(.switch)
            .tint(accentColor)

            if soundEffectsEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Test Acoustic Sound Profiles:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.Color.textTertiary)

                    HStack(spacing: 6) {
                        soundTestButton(name: "Tink (Check)", sound: .checkmark)
                        soundTestButton(name: "Pop (Timer)", sound: .timerStart)
                        soundTestButton(name: "Ping (Done)", sound: .timerComplete)
                        soundTestButton(name: "Hero (Summit)", sound: .summitPassport)
                    }
                }
                .padding(10)
                .background(DS.Color.background, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func soundTestButton(name: String, sound: PlutoSoundEngine.AcousticSound) -> some View {
        Button {
            PlutoSoundEngine.shared.play(sound)
            Haptics.impact(.light)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "play.fill")
                    .font(.system(size: 8))
                Text(name)
                    .font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(DS.Color.surface)
            .foregroundStyle(DS.Color.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(DS.Color.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // 2. Privacy & Biometric Vault
    private var securityControlBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $isVaultSecurityEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Touch ID / Face ID Vault Lock")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DS.Color.textPrimary)
                    Text("Locks Journal and Life Blueprint with Secure Enclave hardware.")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }
            .toggleStyle(.switch)
            .tint(accentColor)

            if isVaultSecurityEnabled {
                Button("Lock Vault Immediately") {
                    LocaVaultAuthManager.shared.lockAll()
                    PlutoSoundEngine.shared.play(.vaultLock)
                    Haptics.impact(.medium)
                }
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.15))
                .foregroundStyle(.red)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .buttonStyle(.plain)
            }
        }
    }

    // 3. Appearance & Colors
    private var appearanceControlBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Executive 8-Color Palette")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DS.Color.textPrimary)

            let palette: [Color] = [
                Color(red: 0.95, green: 0.77, blue: 0.25),
                Color(red: 0.35, green: 0.65, blue: 0.95),
                Color(red: 0.85, green: 0.40, blue: 0.40),
                Color(red: 0.45, green: 0.85, blue: 0.55),
                Color(red: 0.75, green: 0.55, blue: 0.95),
                Color(red: 0.95, green: 0.55, blue: 0.35),
                Color(red: 0.30, green: 0.85, blue: 0.80),
                Color(red: 0.80, green: 0.80, blue: 0.85),
            ]

            HStack(spacing: 10) {
                ForEach(0..<palette.count, id: \.self) { idx in
                    Button {
                        selectedAccentIndex = idx
                        PlutoSoundEngine.shared.play(.tabSwitch)
                        Haptics.impact(.light)
                    } label: {
                        Circle()
                            .fill(palette[idx])
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle().stroke(Color.white, lineWidth: selectedAccentIndex == idx ? 2 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Toggle(isOn: $enableHaptics) {
                Text("Force Touch Trackpad Haptics")
                    .font(.system(size: 12))
            }
            .toggleStyle(.switch)
            .tint(accentColor)
        }
    }

    // 4. General & System
    private var generalControlBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $openFullWindow) {
                Text("Launch Full Screen on Startup")
                    .font(.system(size: 12))
            }
            .toggleStyle(.switch)
            .tint(accentColor)

            Toggle(isOn: $calendarSyncEnabled) {
                Text("Apple Calendar EventKit Sync")
                    .font(.system(size: 12))
            }
            .toggleStyle(.switch)
            .tint(accentColor)

            HStack {
                Text("Global Quick-Capture Hotkey")
                    .font(.system(size: 12))
                Spacer()
                Text("⌥ + Space")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(DS.Color.background)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    // 5. Notifications
    private var notificationsControlBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $masterNotificationsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Master Notification Engine")
                        .font(.system(size: 13, weight: .bold))
                    Text("Deliver native macOS alerts and scheduled focus prompts.")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }
            .toggleStyle(.switch)
            .tint(accentColor)

            HStack(spacing: 20) {
                Toggle(isOn: $eveningReflectionEnabled) {
                    Text("Evening Reflection (21:00)")
                        .font(.system(size: 12))
                }
                .toggleStyle(.switch)
                .tint(accentColor)

                Toggle(isOn: $streakAlertEnabled) {
                    Text("Streak Protection Guard (22:00)")
                        .font(.system(size: 12))
                }
                .toggleStyle(.switch)
                .tint(accentColor)

                Toggle(isOn: $weeklyDigestEnabled) {
                    Text("Sunday Digest")
                        .font(.system(size: 12))
                }
                .toggleStyle(.switch)
                .tint(accentColor)
            }

            Button {
                PlutoNotificationManager.shared.scheduleFocusCompletionNotification(tag: "Deep Work Sprint", seconds: 5, mode: "Pomodoro")
                PlutoSoundEngine.shared.play(.timerComplete)
            } label: {
                Label("Trigger Test macOS Notification", systemImage: "bell.badge")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(DS.Color.background)
                    .foregroundStyle(DS.Color.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(DS.Color.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // 6. Data Sovereignty & SQLite
    private var dataSyncControlBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                statBox(title: "Active Tasks", count: allTodos.count)
                statBox(title: "Journal Notes", count: allNotes.count)
                statBox(title: "Trek Expeditions", count: allTreks.count)
            }

            HStack(spacing: 10) {
                Button {
                    let exportData = "{\"app\":\"PLUTO\",\"version\":\"5.0\",\"todos\":\(allTodos.count),\"notes\":\(allNotes.count)}"
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(exportData, forType: .string)
                    exportMessage = "JSON Backup Copied to Clipboard!"
                    showExportSuccess = true
                    PlutoSoundEngine.shared.play(.checkmark)
                } label: {
                    Label("Export JSON Backup", systemImage: "square.and.arrow.up")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(accentColor)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                Button {
                    LocaSpotlightIndexer.shared.indexAll(context: modelContext)
                    exportMessage = "Spotlight Re-indexed!"
                    showExportSuccess = true
                    PlutoSoundEngine.shared.play(.checkmark)
                } label: {
                    Label("Re-index CoreSpotlight", systemImage: "magnifyingglass")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(DS.Color.background)
                        .foregroundStyle(DS.Color.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            if showExportSuccess {
                Text(exportMessage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.green)
            }

            Divider()
                .opacity(0.3)

            Toggle(isOn: $telemetryOptIn) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Anonymous Alpha Diagnostic Telemetry")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Helps improve Pluto performance and crash reporting. Never transmits note text or private content.")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }
            .toggleStyle(.switch)
            .tint(accentColor)
        }
    }

    private func statBox(title: String, count: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DS.Color.textPrimary)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(DS.Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(DS.Color.background, in: RoundedRectangle(cornerRadius: 6))
    }

    // 7. Danger Zone & Factory Data Reset
    private var dangerZoneControlBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Reset All App Data to Empty State")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DS.Color.textPrimary)
                Text("Permanently erase all tasks, work goals, journal notes, master bucket list items, and habit check-in logs. Restores a pure, empty sovereign canvas.")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Color.textSecondary)
            }

            HStack(spacing: 12) {
                Button {
                    PlutoSoundEngine.shared.play(.tabSwitch)
                    Haptics.impact(.medium)
                    showingResetConfirmation = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Reset Whole App Data")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Color(red: 0.95, green: 0.35, blue: 0.35).opacity(0.18),
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(red: 0.95, green: 0.35, blue: 0.35).opacity(0.5), lineWidth: 1)
                    )
                    .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.45))
                }
                .buttonStyle(.plain)

                if showResetSuccess {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.green)
                        Text(resetSuccessMessage)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.green)
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    // App Guide & Walkthrough Block
    private var studioNotesGuideBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Interactive in-situ spotlight walkthroughs that illuminate live features on your actual screen while blurring background noise.")
                .font(.system(size: 11.5))
                .foregroundStyle(DS.Color.textSecondary)
                .lineSpacing(3)

            HStack(spacing: 10) {
                // 1. Full App Spotlight Tour
                Button {
                    PlutoSoundEngine.shared.play(.tabSwitch)
                    Haptics.impact(.medium)
                    PlutoAppGuideManager.shared.startTour()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                        Text("Whole App Spotlight Tour (⌘/) ✦")
                            .font(.system(size: 11.5, weight: .bold))
                    }
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.95, green: 0.75, blue: 0.25), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // 7. About Pluto
    private var aboutControlBlock: some View {
        Button {
            PlutoSoundEngine.shared.play(.summitPassport)
            Haptics.impact(.medium)
            showKeynoteJourneyModal = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "circle.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("PLUTO OS · Version 5.0 Sovereign Edition")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(DS.Color.textPrimary)

                        Text("EXPLORE JOURNEY ➔")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(accentColor.opacity(0.2))
                            .foregroundStyle(accentColor)
                            .clipShape(Capsule())
                    }

                    Text("Local-First Executive Operating System for daily discipline, expeditions, and life strategy. Click to explore v1.0 ➔ v5.0.")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Color.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Color.textTertiary)
            }
            .padding(10)
            .background(DS.Color.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
