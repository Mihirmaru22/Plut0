import SwiftUI
import SwiftData

// MARK: - MacOnboardingView (First-Launch Welcome & Feature Tour - LOCA Version 3)

/// Interactive, minimalist executive onboarding and feature walkthrough for LOCA App Version 3.
/// Presented automatically upon first launch or manually replayed from Settings.
struct MacOnboardingView: View {

    @Binding var isPresented: Bool

    @AppStorage("has_completed_onboarding_v3") private var hasCompletedOnboarding: Bool = false
    @AppStorage("mac_time_ambient_sound_v2") private var selectedAmbientSound: String = "Lo-Fi Focus Chords"
    @AppStorage("mac_vault_biometrics_enabled") private var enableVaultSecurity: Bool = false
    @AppStorage("mac_selected_palette_idx") private var selectedPaletteIdx: Int = 0

    @ObservedObject private var notificationManager = PlutoNotificationManager.shared
    @ObservedObject private var calendarSync        = PlutoCalendarSync.shared
    @ObservedObject private var loginItemManager    = PlutoLoginItemManager.shared

    @State private var currentStep: Int = 0
    @State private var selectedFeatureTab: Int = 0
    @State private var isAccessibilityGranted: Bool = AXIsProcessTrusted()

    private let totalSteps: Int = 5

    var body: some View {
        ZStack {
            DS.Color.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Step Progress Indicator
                topStepBar
                    .padding(.horizontal, DS.Space.xl)
                    .padding(.top, DS.Space.lg)
                    .padding(.bottom, DS.Space.md)

                Divider()

                // Dynamic Step Content
                Group {
                    switch currentStep {
                    case 0:
                        welcomeStep
                    case 1:
                        featuresTourStep
                    case 2:
                        permissionsStep
                    case 3:
                        personalizationStep
                    case 4:
                        readyToLaunchStep
                    default:
                        welcomeStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                ))

                Divider()

                // Bottom Navigation Footer
                bottomNavigationFooter
                    .padding(.horizontal, DS.Space.xl)
                    .padding(.vertical, DS.Space.md)
                    .background(DS.Color.surface)
            }
        }
        .frame(width: 800, height: 600)
        .animation(.easeInOut(duration: 0.25), value: currentStep)
        .onAppear {
            isAccessibilityGranted = AXIsProcessTrusted()
            notificationManager.checkAuthorization()
            calendarSync.checkAuthorization()
            loginItemManager.refreshStatus()
        }
    }

    // MARK: - Top Step Bar

    private var topStepBar: some View {
        HStack(spacing: DS.Space.md) {
            HStack(spacing: 8) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DS.Color.textPrimary)

                Text("PLUTO APP VERSION 3.5")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DS.Color.textPrimary)
                    .tracking(0.8)
            }

            Spacer()

            // Step Indicator Dots
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { idx in
                    Capsule()
                        .fill(idx == currentStep ? DS.Color.textPrimary : DS.Color.surfaceRecessed)
                        .frame(width: idx == currentStep ? 24 : 8, height: 6)
                        .animation(.easeInOut(duration: 0.2), value: currentStep)
                }
            }
        }
    }

    // MARK: - Step 0: Welcome & Introduction

    private var welcomeStep: some View {
        VStack(spacing: DS.Space.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(DS.Color.surface)
                    .frame(width: 80, height: 80)
                    .overlay(Circle().stroke(DS.Color.border.opacity(0.4), lineWidth: 1))

                Image(systemName: "sparkles")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(DS.Color.textPrimary)
            }

            VStack(spacing: 6) {
                Text("Welcome to PLUTO Version 3.5")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(DS.Color.textPrimary)

                Text("The Apple Silicon & Local-First Executive Operating System for Habits, Focus & Life Mastery")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DS.Color.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // 3 Pillar Highlights
            HStack(spacing: DS.Space.md) {
                welcomeHighlightCard(
                    icon: "cpu.fill",
                    title: "Apple Neural Engine",
                    subtitle: "Zero-latency on-device cognitive clarity scoring, smart NLP task recognition, and 3-bullet Executive Briefs."
                )

                welcomeHighlightCard(
                    icon: "headphones",
                    title: "3D Spatial Audio",
                    subtitle: "Immersive HRTF binaural flow state engine (432Hz Alpha beat) with IOKit uninterrupted focus sleep prevention."
                )

                welcomeHighlightCard(
                    icon: "touchid",
                    title: "Touch ID Vault",
                    subtitle: "Secure Enclave biometric hardware encryption protecting your Private Journal reflections and Life Strategy."
                )
            }
            .padding(.horizontal, DS.Space.lg)
            .padding(.top, DS.Space.sm)

            Spacer()
        }
        .padding(.horizontal, DS.Space.xl)
    }

    private func welcomeHighlightCard(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(DS.Color.textPrimary)

            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DS.Color.textPrimary)

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(DS.Color.textSecondary)
                .lineSpacing(2)
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .stroke(DS.Color.border.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Step 1: Feature Explanation Tour

    private struct FeatureGuide: Identifiable {
        let id: Int
        let title: String
        let icon: String
        let subtitle: String
        let highlights: [String]
    }

    private let features: [FeatureGuide] = [
        FeatureGuide(
            id: 0,
            title: "Apple Neural Engine",
            icon: "cpu.fill",
            subtitle: "100% private, on-device intelligence powered by Apple Silicon.",
            highlights: [
                "Real-time semantic cognitive clarity index (-1.0 to +1.0) and habit correlation.",
                "Smart Task NLP: 'Gym tomorrow at 7am for 1h #health !!' detects dates, times & tags.",
                "3-bullet Executive Briefs summarizing weekly momentum, focus & calibrations."
            ]
        ),
        FeatureGuide(
            id: 1,
            title: "3D Spatial Audio & Flow",
            icon: "headphones",
            subtitle: "Procedural audio synthesizer with Apple Spatial Audio and sleep prevention.",
            highlights: [
                "AVAudioEnvironmentNode with HRTF 3D soundstage positioning.",
                "True 8Hz Alpha Wave flow state carrier (432Hz left / 440Hz right).",
                "IOKit sleep assertion: Mac never falls asleep during active Pomodoro deep work."
            ]
        ),
        FeatureGuide(
            id: 2,
            title: "Siri Voice & Spotlight",
            icon: "mic.fill",
            subtitle: "Hands-free voice control and system-wide macOS Spotlight ⌘Space search.",
            highlights: [
                "Siri Voice Shortcuts: 'Hey Siri, log Gym in PLUTO' and 'Start 25m Focus Sprint'.",
                "Smart Parameter Disambiguation natively prompting between matching habits.",
                "CoreSpotlight: search habits, tasks, goals & maxims directly in macOS Spotlight."
            ]
        ),
        FeatureGuide(
            id: 3,
            title: "Touch ID Vault & Security",
            icon: "touchid",
            subtitle: "Hardware-level Secure Enclave encryption for reflections and life plans.",
            highlights: [
                "Instant Touch ID / Apple Watch biometric unlocking for Private Journal & Life Suite.",
                "Configurable auto-lock inactivity timer (Immediately on sleep, 1m, 5m, 15m).",
                "Zero cloud trackers, zero telemetry: 100% local-first SwiftData storage."
            ]
        ),
        FeatureGuide(
            id: 4,
            title: "Day Planner & .ics Drops",
            icon: "calendar.badge.plus",
            subtitle: "Hourly time-blocking with direct Calendar .ics invite drag-and-drop.",
            highlights: [
                "Drag .ics files or meeting invites from Finder/Mail directly onto the timeline canvas.",
                "ProMotion 120Hz butter-smooth dragging, resizing, and 5-minute interval snapping.",
                "Morning Sprint, Afternoon Deep Work, and Evening Wind Down agenda streams."
            ]
        ),
        FeatureGuide(
            id: 5,
            title: "Interactive Desktop Widgets",
            icon: "rectangle.3.group.fill",
            subtitle: "macOS Sonoma & Sequoia interactive desktop wallpaper widgets.",
            highlights: [
                "Desktop Habit Matrix: 1-click habit check-in pills right on your wallpaper.",
                "Today Agenda Widget: active focus sprint window and upcoming scheduled tasks.",
                "Memento Mori 365/366 Day Matrix: tracking exact days done vs remaining in the current year."
            ]
        )
    ]

    private var featuresTourStep: some View {
        HStack(spacing: DS.Space.lg) {
            // Left Feature Selector Tabs
            VStack(spacing: 4) {
                ForEach(features) { feat in
                    let isSelected = selectedFeatureTab == feat.id
                    Button {
                        selectedFeatureTab = feat.id
                        Haptics.impact(.light)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: feat.icon)
                                .font(.system(size: 13))
                                .foregroundStyle(isSelected ? DS.Color.textPrimary : DS.Color.textSecondary)
                                .frame(width: 20)

                            Text(feat.title)
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? DS.Color.textPrimary : DS.Color.textSecondary)

                            Spacer()

                            if isSelected {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(DS.Color.textTertiary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            isSelected ? DS.Color.surfaceRecessed : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 230)
            .padding(.vertical, DS.Space.md)

            Divider()

            // Right Feature Details Card
            let active = features[selectedFeatureTab]
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                HStack(spacing: 10) {
                    Image(systemName: active.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(DS.Color.textPrimary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(active.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(DS.Color.textPrimary)

                        Text(active.subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: DS.Space.md) {
                    ForEach(active.highlights, id: \.self) { highlight in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(DS.Color.success)
                                .padding(.top, 1)

                            Text(highlight)
                                .font(.system(size: 12))
                                .foregroundStyle(DS.Color.textSecondary)
                                .lineSpacing(3)
                        }
                    }
                }

                Spacer()
            }
            .padding(DS.Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, DS.Space.xl)
    }

    // MARK: - Step 2: System Permissions & Integrations

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            // Header Row with Master "Grant All" Button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("System Access & Permissions")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(DS.Color.textPrimary)

                    Text("PLUTO uses native Apple frameworks for zero-latency local intelligence, background streaks & calendar sync.")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Color.textSecondary)
                }

                Spacer()

                Button {
                    requestAllPermissions()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("Grant All Permissions")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            Divider()

            // 4 Core Permission Cards Grid
            VStack(spacing: 8) {
                // 1. Notifications
                permissionCard(
                    icon: "bell.badge.fill",
                    color: Color.orange,
                    title: "Smart Habit & Streak Notifications",
                    description: "Streak break warnings (10 PM), habit check-in nudges, Pomodoro alerts, and evening reflection digests.",
                    isGranted: notificationManager.isAuthorized,
                    buttonTitle: "Enable Notifications",
                    action: {
                        Task {
                            _ = await notificationManager.requestAuthorization()
                            Haptics.impact(.rigid)
                        }
                    }
                )

                // 2. Calendar Sync
                permissionCard(
                    icon: "calendar",
                    color: Color.blue,
                    title: "Apple Calendar & Day Planner (EventKit)",
                    description: "Seamlessly overlay meetings and scheduled events onto your Day Planner time-blocking canvas.",
                    isGranted: calendarSync.isAuthorized,
                    buttonTitle: "Connect Calendar",
                    action: {
                        Task {
                            _ = await calendarSync.requestAuthorization()
                            Haptics.impact(.rigid)
                        }
                    }
                )

                // 3. Accessibility / Global Hotkey
                permissionCard(
                    icon: "command.square.fill",
                    color: Color.purple,
                    title: "Global Quick Action HUD (⌃⌥P)",
                    description: "Summon the fast habit/task HUD anywhere in macOS. Requires Accessibility permission in System Settings.",
                    isGranted: isAccessibilityGranted,
                    buttonTitle: "Grant Accessibility",
                    action: {
                        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                        _ = AXIsProcessTrustedWithOptions(options)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            isAccessibilityGranted = AXIsProcessTrusted()
                        }
                    }
                )

                // 4. Launch at Login
                permissionCard(
                    icon: "power",
                    color: Color.green,
                    title: "Launch at macOS Startup (SMAppService)",
                    description: "Keep PLUTO and your streak tracker ready in the background as soon as your Mac turns on.",
                    isGranted: loginItemManager.isEnabled,
                    buttonTitle: "Enable at Startup",
                    action: {
                        loginItemManager.setLaunchAtLogin(enabled: true)
                        Haptics.impact(.light)
                    }
                )
            }

            Spacer()
        }
        .padding(.horizontal, DS.Space.xl)
        .padding(.vertical, DS.Space.md)
    }

    private func permissionCard(
        icon: String,
        color: Color,
        title: String,
        description: String,
        isGranted: Bool,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DS.Color.textPrimary)

                Text(description)
                    .font(.system(size: 10))
                    .foregroundStyle(DS.Color.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            if isGranted {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Color.success)
                    Text("Granted")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DS.Color.success)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(DS.Color.success.opacity(0.12), in: Capsule())
            } else {
                Button(action: action) {
                    Text(buttonTitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DS.Color.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(DS.Color.surfaceRecessed, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(DS.Color.border.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isGranted ? DS.Color.success.opacity(0.3) : DS.Color.border.opacity(0.3), lineWidth: 1)
        )
    }

    private func requestAllPermissions() {
        Task {
            _ = await notificationManager.requestAuthorization()
            _ = await calendarSync.requestAuthorization()
            loginItemManager.setLaunchAtLogin(enabled: true)

            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            _ = AXIsProcessTrustedWithOptions(options)

            isAccessibilityGranted = AXIsProcessTrusted()
            Haptics.notify(.success)
        }
    }

    // MARK: - Step 3: Workspace Personalization

    private var personalizationStep: some View {
        VStack(alignment: .leading, spacing: DS.Space.lg) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Personalize Your V3.5 Workspace")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DS.Color.textPrimary)

                Text("Configure your preferred initial layouts and soundscapes. You can adjust these anytime in Settings.")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Color.textSecondary)
            }

            Divider()

            // Ambient Sound & Touch ID Preferences
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                Text("DEFAULT 3D SPATIAL FOCUS SOUND")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DS.Color.textTertiary)
                    .tracking(0.6)

                HStack(spacing: DS.Space.sm) {
                    ForEach(["Lo-Fi Focus Chords", "Deep Binaural (432Hz)", "Gentle Rain & Thunder"], id: \.self) { sound in
                        let isSelected = selectedAmbientSound == sound
                        Button {
                            selectedAmbientSound = sound
                            AmbientSoundEngine.shared.setSound(sound)
                            Haptics.impact(.light)
                        } label: {
                            Text(sound)
                                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? .white : DS.Color.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    isSelected ? Color.accentColor : DS.Color.surface,
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(DS.Color.border.opacity(0.4), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Touch ID Toggle Option
            Toggle(isOn: $enableVaultSecurity) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Touch ID Vault Lock")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DS.Color.textPrimary)
                    Text("Safeguard Private Journal reflections and Life Strategy behind biometric authentication.")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }
            .toggleStyle(.checkbox)
            .padding(.top, 4)

            Spacer()
        }
        .padding(.horizontal, DS.Space.xl)
        .padding(.vertical, DS.Space.md)
    }

    // MARK: - Step 3: Launch Ready

    private var readyToLaunchStep: some View {
        VStack(spacing: DS.Space.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(DS.Color.success.opacity(0.12))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(DS.Color.success)
            }

            VStack(spacing: 6) {
                Text("PLUTO Version 3.5 is Ready")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(DS.Color.textPrimary)

                Text("Your Apple Silicon super-app is configured and synchronized locally.")
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Color.textSecondary)
            }

            // Quick Reference Keybindings
            VStack(alignment: .leading, spacing: 8) {
                Text("QUICK EXECUTIVE SHORTCUTS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DS.Color.textTertiary)
                    .tracking(0.6)

                HStack(spacing: DS.Space.lg) {
                    shortcutBadge(keys: "⌘1–6", label: "Jump Pillars")
                    shortcutBadge(keys: "⌘N", label: "Quick Add")
                    shortcutBadge(keys: "⌘Space", label: "Spotlight")
                    shortcutBadge(keys: "⌘,", label: "Settings")
                }
            }
            .padding(DS.Space.md)
            .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.card).stroke(DS.Color.border.opacity(0.4), lineWidth: 1))

            Spacer()
        }
        .padding(.horizontal, DS.Space.xl)
    }

    private func shortcutBadge(keys: String, label: String) -> some View {
        HStack(spacing: 6) {
            Text(keys)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.Color.textPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(DS.Color.surfaceRecessed, in: RoundedRectangle(cornerRadius: 4))

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - Bottom Navigation Footer

    private var bottomNavigationFooter: some View {
        HStack {
            if currentStep > 0 {
                Button {
                    currentStep -= 1
                    Haptics.impact(.light)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Previous")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DS.Color.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(DS.Color.surfaceRecessed, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if currentStep < totalSteps - 1 {
                Button {
                    currentStep += 1
                    Haptics.impact(.light)
                } label: {
                    HStack(spacing: 6) {
                        Text(currentStep == 0 ? "Explore Features" : "Continue")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    hasCompletedOnboarding = true
                    isPresented = false
                    Haptics.impact(.rigid)
                } label: {
                    HStack(spacing: 6) {
                        Text("Enter PLUTO V3.5")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(DS.Color.success, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
