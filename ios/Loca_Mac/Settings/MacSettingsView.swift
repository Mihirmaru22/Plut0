import SwiftUI
import SwiftData
import UserNotifications

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
    @AppStorage("mac_appearance_mode") private var appearanceMode: String = "dark"
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

    // Workday Wellness Storage (Option B: Alternating 💧 Hydrate / 🚶 Stretch)
    @AppStorage("mac_workday_wellness_enabled") private var workdayWellnessEnabled: Bool = true
    @AppStorage("mac_workday_start_hour") private var workdayStartHour: Int = 9
    @AppStorage("mac_workday_end_hour") private var workdayEndHour: Int = 18
    @AppStorage("mac_workday_interval_mins") private var workdayIntervalMins: Int = 60

    // Vault Security Storage
    @AppStorage("mac_vault_biometrics_enabled") private var isVaultSecurityEnabled: Bool = false

    // Telemetry & Privacy
    @AppStorage("mac_telemetry_opt_in") private var telemetryOptIn: Bool = true

    // Today Pillar Sub-modes Storage
    @AppStorage("mac_today_enable_plan") private var enableTodayPlan: Bool = true
    @AppStorage("mac_today_enable_list") private var enableTodayList: Bool = true
    @AppStorage("mac_today_enable_time") private var enableTodayTime: Bool = true

    // Local UI State
    @ObservedObject private var notificationManager = PlutoNotificationManager.shared
    @State private var showExportSuccess = false
    @State private var exportMessage = ""
    @State private var showKeynoteJourneyModal = false
    @State private var showingResetConfirmation = false
    @State private var showResetSuccess = false
    @State private var resetSuccessMessage = ""
    @State private var showingGhostResetConfirmation = false
    @State private var showGhostResetSuccess = false
    @State private var testNotificationFeedback: String? = nil

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

    // Tab Switcher
    enum SettingsTab: String, CaseIterable, Identifiable {
        case notifications = "Notifications & Wellness"
        case appearance   = "Appearance & Audio"
        case system       = "System & Security"
        case data         = "Data & Storage"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .notifications: return "bell.badge.fill"
            case .appearance:    return "paintpalette.fill"
            case .system:        return "lock.shield.fill"
            case .data:          return "externaldrive.fill"
            }
        }
    }

    @AppStorage("mac_settings_active_tab") private var selectedTab: SettingsTab = .notifications

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Header & Liquid Glass Tab Switcher
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Settings")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(DS.Color.textPrimary)

                        Text("System Preferences & Hardware Controls")
                            .font(.system(size: 12.5))
                            .foregroundStyle(DS.Color.textSecondary)
                    }

                    Spacer()

                    // Top Segmented Bar
                    PlutoGlassCluster(spacing: 2) {
                        ForEach(SettingsTab.allCases) { tab in
                            let isSelected = selectedTab == tab
                            Button {
                                withAnimation(PlutoSpring.snappy) {
                                    selectedTab = tab
                                }
                                Haptics.impact(.light)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                    Text(tab.rawValue)
                                        .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                                }
                                .foregroundStyle(isSelected ? Color.black : DS.Color.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background {
                                    if isSelected {
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color(white: 0.98), Color(white: 0.90)],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .overlay(Capsule().stroke(Color.white.opacity(0.9), lineWidth: 0.8))
                                            .shadow(color: Color.black.opacity(0.20), radius: 4, y: 1)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.bottom, 6)

                // Tab Content Switcher
                switch selectedTab {
                case .notifications:
                    VStack(spacing: 16) {
                        bentoTile(title: "Notifications & Workday Wellness", icon: "bell.badge.fill", accent: Color(red: 0.85, green: 0.40, blue: 0.40)) {
                            notificationsControlBlock
                        }
                    }

                case .appearance:
                    VStack(spacing: 16) {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                            bentoTile(title: "Executive Accent", icon: "paintpalette.fill", accent: Color(red: 0.95, green: 0.55, blue: 0.35)) {
                                appearanceControlBlock
                            }

                            bentoTile(title: "Sound & Acoustics", icon: "speaker.wave.3.fill", accent: accentColor) {
                                soundControlsBlock
                            }
                        }

                        bentoTile(title: "Today Pillar Sub-modes", icon: "calendar.day.timeline.left", accent: Color(red: 0.95, green: 0.77, blue: 0.25)) {
                            todaySubmodesControlBlock
                        }
                    }

                case .system:
                    VStack(spacing: 16) {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                            bentoTile(title: "Privacy & Biometric Vault", icon: "lock.shield.fill", accent: Color(red: 0.75, green: 0.55, blue: 0.95)) {
                                securityControlBlock
                            }

                            bentoTile(title: "General & Hotkeys", icon: "gearshape.fill", accent: Color(red: 0.35, green: 0.65, blue: 0.95)) {
                                generalControlBlock
                            }
                        }

                        bentoTile(title: "App Spotlight & Shortcuts Guide", icon: "sparkles", accent: Color(red: 0.95, green: 0.75, blue: 0.25)) {
                            studioNotesGuideBlock
                        }
                    }

                case .data:
                    VStack(spacing: 16) {
                        bentoTile(title: "Data Sovereignty & Local Storage", icon: "externaldrive.badge.icloud", accent: Color(red: 0.45, green: 0.85, blue: 0.55)) {
                            dataSyncControlBlock
                        }

                        bentoTile(title: "About PLUTO Sovereign OS", icon: "info.circle.fill", accent: Color(red: 0.80, green: 0.80, blue: 0.85)) {
                            aboutControlBlock
                        }

                        bentoTile(title: "Danger Zone · Factory Data Reset", icon: "trash.fill", accent: Color(red: 0.95, green: 0.35, blue: 0.35)) {
                            dangerZoneControlBlock
                        }
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(28)
            .frame(maxWidth: 960)
        }
        .background(.ultraThinMaterial)
        .background(DS.Theme.canvas)
        .confirmationDialog(
            "Reset Whole App Data?",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Everything (Clean Slate)", role: .destructive) {
                PlutoDataResetManager.resetAllAppData(context: modelContext)
                PlutoSoundEngine.shared.play(.deleteTrash)
                Haptics.notify(.success)
                resetSuccessMessage = "All App Data Has Been Reset to Clean Slate!"
                showResetSuccess = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently erase all tasks, work goals, journal notes, master bucket list items, and habit logs. This action cannot be undone.")
        }
        .confirmationDialog(
            "Reset Ghost Mode Operating System?",
            isPresented: $showingGhostResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Ghost Mode (Clean Slate)", role: .destructive) {
                Task {
                    _ = try? await GhostEngine.shared.resetAllGhostData()
                    await MainActor.run {
                        PlutoSoundEngine.shared.play(.deleteTrash)
                        Haptics.notify(.success)
                        showGhostResetSuccess = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently erase all active and archived Ghost seasons, daily ring check-in records, receipts, and custom protocol rules. Ghost Mode will return to an uninitiated covenant state.")
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
        .plutoGlass(.regular, in: RoundedRectangle(cornerRadius: 12))
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
        VStack(alignment: .leading, spacing: 16) {
            // Theme Mode Selector
            VStack(alignment: .leading, spacing: 6) {
                Text("Interface Appearance")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DS.Color.textPrimary)

                HStack(spacing: 8) {
                    themeModeButton(title: "Dark", icon: "moon.stars.fill", mode: "dark")
                    themeModeButton(title: "Light", icon: "sun.max.fill", mode: "light")
                    themeModeButton(title: "System", icon: "laptopcomputer", mode: "system")
                }
            }

            Divider().opacity(0.15)

            // Executive Accent Palette
            VStack(alignment: .leading, spacing: 6) {
                Text("Executive Accent Palette")
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
                                    Circle().stroke(Color.primary, lineWidth: selectedAccentIndex == idx ? 2 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider().opacity(0.15)

            Toggle(isOn: $enableHaptics) {
                Text("Force Touch Trackpad Haptics")
                    .font(.system(size: 12))
            }
            .toggleStyle(.switch)
            .tint(accentColor)
        }
    }

    private func themeModeButton(title: String, icon: String, mode: String) -> some View {
        let isSelected = appearanceMode == mode
        return Button {
            appearanceMode = mode
            PlutoDynamicAppIconManager.shared.updateDockIcon()
            PlutoSoundEngine.shared.play(.tabSwitch)
            Haptics.impact(.light)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(
                isSelected ? accentColor.opacity(0.18) : DS.Theme.card,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? accentColor : DS.Theme.border, lineWidth: 1)
            )
            .foregroundStyle(isSelected ? accentColor : DS.Theme.textSecondary)
        }
        .buttonStyle(.plain)
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

    // Today Sub-modes Control Block
    private var todaySubmodesControlBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Turn on or off operational sub-views in the Today pillar switcher. When turned off, they will immediately disappear from Today.")
                .font(.system(size: 11.5))
                .foregroundStyle(DS.Color.textSecondary)
                .lineSpacing(2)

            VStack(spacing: 12) {
                // 1. Plan Toggle
                Toggle(isOn: Binding(
                    get: { enableTodayPlan },
                    set: { newVal in
                        if !newVal && !enableTodayList && !enableTodayTime {
                            Haptics.notify(.warning)
                            return
                        }
                        enableTodayPlan = newVal
                        Haptics.impact(.light)
                    }
                )) {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar.day.timeline.left")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(DS.Theme.amber)
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Plan (Time-Blocked Day Planner)")
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundStyle(DS.Color.textPrimary)
                            Text("Vertical day agenda timeline, live time blocking, and task scheduling.")
                                .font(.system(size: 11))
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                }
                .toggleStyle(.switch)
                .tint(accentColor)

                Divider().opacity(0.12)

                // 2. List Toggle
                Toggle(isOn: Binding(
                    get: { enableTodayList },
                    set: { newVal in
                        if !newVal && !enableTodayPlan && !enableTodayTime {
                            Haptics.notify(.warning)
                            return
                        }
                        enableTodayList = newVal
                        Haptics.impact(.light)
                    }
                )) {
                    HStack(spacing: 10) {
                        Image(systemName: "checklist.checked")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(red: 0.35, green: 0.65, blue: 0.95))
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("List (Tasks & Queues)")
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundStyle(DS.Color.textPrimary)
                            Text("GTD-style inbox, priority queues, bento cards, and backlog trays.")
                                .font(.system(size: 11))
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                }
                .toggleStyle(.switch)
                .tint(accentColor)

                Divider().opacity(0.12)

                // 3. Time Toggle
                Toggle(isOn: Binding(
                    get: { enableTodayTime },
                    set: { newVal in
                        if !newVal && !enableTodayPlan && !enableTodayList {
                            Haptics.notify(.warning)
                            return
                        }
                        enableTodayTime = newVal
                        Haptics.impact(.light)
                    }
                )) {
                    HStack(spacing: 10) {
                        Image(systemName: "timer.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(red: 0.75, green: 0.55, blue: 0.95))
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Time (Focus Studio)")
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundStyle(DS.Color.textPrimary)
                            Text("Integrated Pomodoro timer, ambient flow mixer, and deep work tracking.")
                                .font(.system(size: 11))
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                }
                .toggleStyle(.switch)
                .tint(accentColor)
            }
        }
    }

    // 5. Notifications
    private var notificationsControlBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Toggle(isOn: Binding(
                    get: { masterNotificationsEnabled },
                    set: { newVal in
                        masterNotificationsEnabled = newVal
                        PlutoNotificationManager.shared.rescheduleAllFromAppStorage()
                        Haptics.impact(.light)
                    }
                )) {
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

                Spacer()

                Button {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape")
                        Text("macOS System Notifications ↗")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DS.Color.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DS.Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(DS.Color.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 20) {
                Toggle(isOn: Binding(
                    get: { eveningReflectionEnabled },
                    set: { newVal in
                        eveningReflectionEnabled = newVal
                        PlutoNotificationManager.shared.rescheduleAllFromAppStorage()
                        Haptics.impact(.light)
                    }
                )) {
                    Text("Evening Reflection (21:00)")
                        .font(.system(size: 12))
                }
                .toggleStyle(.switch)
                .tint(accentColor)

                Toggle(isOn: Binding(
                    get: { streakAlertEnabled },
                    set: { newVal in
                        streakAlertEnabled = newVal
                        PlutoNotificationManager.shared.rescheduleAllFromAppStorage()
                        Haptics.impact(.light)
                    }
                )) {
                    Text("Streak Protection Guard (22:00)")
                        .font(.system(size: 12))
                }
                .toggleStyle(.switch)
                .tint(accentColor)

                Toggle(isOn: Binding(
                    get: { weeklyDigestEnabled },
                    set: { newVal in
                        weeklyDigestEnabled = newVal
                        PlutoNotificationManager.shared.rescheduleAllFromAppStorage()
                        Haptics.impact(.light)
                    }
                )) {
                    Text("Sunday Digest")
                        .font(.system(size: 12))
                }
                .toggleStyle(.switch)
                .tint(accentColor)
            }

            Divider().opacity(0.15)

            // Workday Desk Bio-Breaks (Option B: Alternating 💧 Hydrate & 🚶 Stretch)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("💧 🚶 Workday Desk Bio-Breaks")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(DS.Color.textPrimary)
                            Text("Mon – Sat · 9 AM – 6 PM")
                                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.12))
                                .foregroundStyle(Color.blue)
                                .clipShape(Capsule())
                        }

                        Text("Alternates between \"Time to Hydrate\" and \"Stand & Stretch\" during office hours.")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Color.textSecondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { workdayWellnessEnabled },
                        set: { newVal in
                            workdayWellnessEnabled = newVal
                            PlutoNotificationManager.shared.scheduleWorkdayWellnessReminders(
                                enabled: newVal,
                                startHour: workdayStartHour,
                                endHour: workdayEndHour,
                                intervalMinutes: workdayIntervalMins
                            )
                            Haptics.impact(.light)
                        }
                    ))
                    .toggleStyle(.switch)
                    .tint(accentColor)
                }

                if workdayWellnessEnabled {
                    HStack(spacing: 12) {
                        Text("Interval Cadence:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DS.Color.textTertiary)

                        ForEach([45, 60, 90, 120], id: \.self) { mins in
                            let isSelected = workdayIntervalMins == mins
                            Button {
                                workdayIntervalMins = mins
                                PlutoNotificationManager.shared.scheduleWorkdayWellnessReminders(
                                    enabled: true,
                                    startHour: workdayStartHour,
                                    endHour: workdayEndHour,
                                    intervalMinutes: mins
                                )
                                Haptics.impact(.light)
                            } label: {
                                Text(mins >= 60 ? (mins == 60 ? "Every 1 hr" : "Every \(mins / 60) hrs") : "Every \(mins)m")
                                    .font(.system(size: 10.5, weight: isSelected ? .bold : .medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(isSelected ? accentColor.opacity(0.15) : DS.Color.surface)
                                    .foregroundStyle(isSelected ? accentColor : DS.Color.textSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(isSelected ? accentColor.opacity(0.4) : DS.Color.border, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(12)
            .background(DS.Color.background, in: RoundedRectangle(cornerRadius: 8))

            // Notification Permission Banner if not authorized
            if !notificationManager.isAuthorized {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(red: 0.96, green: 0.65, blue: 0.18))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("macOS Notifications Not Authorized")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DS.Color.textPrimary)
                        Text("Grant permission to receive workday desk bio-breaks, streak alerts, and focus completions.")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Color.textSecondary)
                    }

                    Spacer()

                    Button("Authorize Now") {
                        Task {
                            let granted = await PlutoNotificationManager.shared.requestAuthorization()
                            if !granted {
                                // If denied, open macOS notification settings directly
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            Haptics.impact(.medium)
                        }
                    }
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(accentColor)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(Color(red: 0.96, green: 0.65, blue: 0.18).opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.96, green: 0.65, blue: 0.18).opacity(0.3), lineWidth: 1))
            }

            HStack(spacing: 10) {
                Button {
                    Task {
                        let sent = await PlutoNotificationManager.shared.sendImmediateTestNotification(
                            title: "🔥 Focus Session Complete",
                            body: "25 minutes of Deep Work logged to Sovereign Vault.",
                            type: "focus"
                        )
                        await MainActor.run {
                            testNotificationFeedback = sent ? "Focus alert banner dispatched (1s)" : "Permission denied — authorize in macOS Settings"
                            PlutoSoundEngine.shared.play(.timerComplete)
                            Haptics.impact(.medium)
                        }
                    }
                } label: {
                    Label("Test Focus Alert", systemImage: "bell.badge")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(DS.Color.background)
                        .foregroundStyle(DS.Color.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(DS.Color.border, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        let sent = await PlutoNotificationManager.shared.sendImmediateTestNotification(
                            title: "💧 Time to Hydrate",
                            body: "Take a refreshing sip of water and reset your posture.",
                            type: "hydrate"
                        )
                        await MainActor.run {
                            testNotificationFeedback = sent ? "Hydrate prompt banner dispatched (1s)" : "Permission denied — authorize in macOS Settings"
                            PlutoSoundEngine.shared.play(.timerStart)
                            Haptics.impact(.medium)
                        }
                    }
                } label: {
                    Label("Test Hydrate Prompt", systemImage: "drop.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(DS.Color.background)
                        .foregroundStyle(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(DS.Color.border, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        let sent = await PlutoNotificationManager.shared.sendImmediateTestNotification(
                            title: "🚶 Stand & Stretch",
                            body: "Step away from your screen, roll your shoulders, and stretch.",
                            type: "stretch"
                        )
                        await MainActor.run {
                            testNotificationFeedback = sent ? "Stretch prompt banner dispatched (1s)" : "Permission denied — authorize in macOS Settings"
                            PlutoSoundEngine.shared.play(.timerStart)
                            Haptics.impact(.medium)
                        }
                    }
                } label: {
                    Label("Test Stretch Prompt", systemImage: "figure.walk")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(DS.Color.background)
                        .foregroundStyle(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(DS.Color.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            if let feedback = testNotificationFeedback {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.green)
                    Text(feedback)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.green)
                }
                .transition(.opacity)
            }
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
        VStack(alignment: .leading, spacing: 14) {
            // Whole App Reset
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
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(red: 0.95, green: 0.35, blue: 0.35).opacity(0.18))
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

            Divider().opacity(0.2)

            // Ghost Mode Specific Reset
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(red: 0.95, green: 0.65, blue: 0.18))
                    Text("Reset Ghost Mode Operating System")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DS.Color.textPrimary)
                }
                Text("Erase current and archived Ghost seasons, daily ring check-in records, receipts, and custom protocol rules. Returns Ghost Mode to an uninitiated covenant state.")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Color.textSecondary)
            }

            HStack(spacing: 12) {
                Button {
                    PlutoSoundEngine.shared.play(.tabSwitch)
                    Haptics.impact(.medium)
                    showingGhostResetConfirmation = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Reset Ghost Mode")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(red: 0.95, green: 0.65, blue: 0.18).opacity(0.18))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(red: 0.95, green: 0.65, blue: 0.18).opacity(0.5), lineWidth: 1)
                    )
                    .foregroundStyle(Color(red: 0.95, green: 0.65, blue: 0.18))
                }
                .buttonStyle(.plain)

                if showGhostResetSuccess {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.green)
                        Text("Ghost Mode Reset Complete")
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
