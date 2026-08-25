import SwiftUI
import SwiftData

// MARK: - FocusRoomActivePanel

enum FocusRoomActivePanel {
    case none
    case background
    case sound
    case quote
    case stats
}

// MARK: - FocusRoomView (Pluto Fullscreen StudyStream Study Mode)

struct FocusRoomView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @StateObject private var timerVM = FocusTimerViewModel()
    @StateObject private var soundVM = FocusSoundViewModel()

    // Active Navigation / Panels State
    @State private var activePanel: FocusRoomActivePanel = .none
    @State private var showGoalsPanel: Bool = true
    @State private var showQuoteCard: Bool = true
    @State private var showTimerModal: Bool = false
    @State private var showNavDrawer: Bool = false
    @State private var hoveredCapsuleMode: String? = nil
    @Namespace private var glassPillNamespace
    @Namespace private var pomodoroModeNamespace
    @AppStorage("mac_today_submode") private var todaySubmode: String = "Plan"
    @State private var isFullscreen: Bool = false

    // Persistent Background State (Persists across App Restarts & Tab Switches)
    @AppStorage("focus_room_selected_preset_id") private var selectedPresetID: String = "nat_1"
    @AppStorage("focus_room_youtube_video_id") private var storedYoutubeVideoID: String = ""
    @State private var currentSession: FocusSession? = nil

    private var youtubeVideoIDBinding: Binding<String?> {
        Binding(
            get: { storedYoutubeVideoID.isEmpty ? nil : storedYoutubeVideoID },
            set: { storedYoutubeVideoID = $0 ?? "" }
        )
    }

    // Queries for Telemetry & Badges
    @Query private var allGoals: [FocusGoal]
    @Query(sort: [SortDescriptor(\TodoItem.createdAt)])
    private var allTodoItems: [TodoItem]

    private var openGoalsCount: Int { allGoals.filter { !$0.isCompleted }.count }
    private var totalGoalsCount: Int { allGoals.count }
    private var openTodoCount: Int { allTodoItems.filter { !$0.isArchived && $0.parentID == nil && !$0.isCompleted }.count }
    private var scheduledTodoCount: Int { allTodoItems.filter { !$0.isArchived && $0.parentID == nil && $0.startTime != nil }.count }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {

                // ===================================================================
                // LAYER 1: FULLSCREEN BACKGROUND (Strictly Clipped to Window Frame)
                // ===================================================================
                fullscreenBackground(size: geo.size)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea(.all)
                    .zIndex(0)

                // ===================================================================
                // LAYER 3: FLOATING PANELS OVERLAY
                // ===================================================================
                HStack(alignment: .top, spacing: 0) {

                    // Left Column: Timer Card + Session Goals Panel stacked vertically
                    VStack(alignment: .leading, spacing: 12) {
                        if showTimerModal {
                            bigTimerModal
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .move(edge: .top).combined(with: .opacity)
                                ))
                        }

                        if showGoalsPanel {
                            FocusGoalsPanel(isPresented: $showGoalsPanel)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .leading).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        }

                        Spacer()
                    }
                    .padding(.leading, 20)
                    .padding(.top, 76)

                    Spacer()

                    // Right Column: Active Tool Panels + Persistent Quote Card
                    VStack(alignment: .trailing, spacing: 12) {
                        switch activePanel {
                        case .background:
                            BackgroundPickerPanel(
                                isPresented: Binding(
                                    get: { activePanel == .background },
                                    set: { if !$0 { activePanel = .none } }
                                ),
                                selectedPresetID: $selectedPresetID,
                                youtubeVideoID: youtubeVideoIDBinding,
                                youtubeVolume: $soundVM.youtubeVolume
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))

                        case .sound:
                            SoundMixerPanel(
                                soundVM: soundVM,
                                isPresented: Binding(
                                    get: { activePanel == .sound },
                                    set: { if !$0 { activePanel = .none } }
                                )
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))

                        case .stats:
                            StudyStatsPanel(
                                isPresented: Binding(
                                    get: { activePanel == .stats },
                                    set: { if !$0 { activePanel = .none } }
                                )
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))

                        case .none, .quote:
                            EmptyView()
                        }

                        // Persistent Quote Card (always stays visible on screen unless closed)
                        if showQuoteCard {
                            QuotePanel(isPresented: $showQuoteCard)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                ))
                        }

                        Spacer()
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 76)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .zIndex(50)

                // ===================================================================
                // LAYER 2: FLOATING TOP BAR (Pinned to Top-Center & Edges)
                // ===================================================================
                topFloatingBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .frame(width: geo.size.width)
                    .zIndex(100)

                // ===================================================================
                // LAYER 4: BOTTOM KEYBOARD SHORTCUT HUD
                // ===================================================================
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        shortcutBadge(key: "Space", label: timerVM.isRunning ? "Pause" : "Resume")
                        shortcutBadge(key: "⌘T", label: "Timer")
                        shortcutBadge(key: "⌘B", label: "Sidebar")
                        shortcutBadge(key: "⌘F", label: "Fullscreen")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .background(Color.black.opacity(0.65), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                    .padding(.bottom, 16)
                }
                .frame(width: geo.size.width)
                .zIndex(70)

                // ===================================================================
                // LAYER 5: LIQUID GLASS FLYOUT NAVIGATION DRAWER (Burger Menu Overlay)
                // ===================================================================
                liquidGlassNavDrawer(size: geo.size)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showNavDrawer)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: activePanel)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showGoalsPanel)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showQuoteCard)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showTimerModal)
        .onAppear {
            DispatchQueue.main.async {
                startSession()
                // Prefetch nature preset wallpapers in background
                let presetURLs = BackgroundPickerPanel.presets.prefix(8).map { $0.fullImageURL }
                FocusWallpaperManager.shared.prefetch(urls: presetURLs)
            }
        }
        .onDisappear {
            DispatchQueue.main.async {
                endSession()
            }
        }
    }

    // MARK: - Layer 1: Fullscreen Background (Constrained to Window Bounds)

    @ViewBuilder
    private func fullscreenBackground(size: CGSize) -> some View {
        if !storedYoutubeVideoID.isEmpty {
            YouTubeWebView(videoID: storedYoutubeVideoID, volume: soundVM.youtubeVolume)
                .frame(width: size.width, height: size.height)
                .clipped()
        } else if let preset = BackgroundPickerPanel.presets.first(where: { $0.id == selectedPresetID }) {
            ZStack {
                // High-Speed Cached Wallpaper with 0ms RAM/Disk hit and zero lag
                FocusCachedImageView(
                    urlString: preset.fullImageURL,
                    fallbackColors: preset.fallbackColors
                )
                .frame(width: size.width, height: size.height)
                .clipped()

                // Subtle Atmospheric Tint for Translucent Card Readability
                Color.black.opacity(0.20)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        } else {
            presetGradientBackground(presetID: selectedPresetID)
                .frame(width: size.width, height: size.height)
                .clipped()
        }
    }

    private func presetGradientBackground(presetID: String) -> some View {
        ZStack {
            switch presetID {
            case "city_1":
                LinearGradient(
                    colors: [Color(red: 0.15, green: 0.25, blue: 0.45), Color(red: 0.05, green: 0.10, blue: 0.20)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case "anime_1":
                LinearGradient(
                    colors: [Color(red: 0.55, green: 0.35, blue: 0.55), Color(red: 0.15, green: 0.15, blue: 0.30)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            case "lib_1":
                LinearGradient(
                    colors: [Color(red: 0.25, green: 0.18, blue: 0.12), Color(red: 0.08, green: 0.05, blue: 0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            default:
                LinearGradient(
                    colors: [Color(red: 0.12, green: 0.18, blue: 0.28), Color(red: 0.04, green: 0.06, blue: 0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            // Atmospheric Ambient Overlay
            RadialGradient(
                colors: [Color.blue.opacity(0.15), Color.clear],
                center: .center,
                startRadius: 100,
                endRadius: 600
            )
        }
    }

    // MARK: - Layer 2: Floating Top Bar

    private var topFloatingBar: some View {
        HStack {

            // Top-Left: Burger / Sidebar Menu Button + Personal Timer Pill + Session Goals Pill
            HStack(spacing: 8) {
                // 0. Burger / Sidebar Toggle Button (matching macOS Sidebar toggle)
                Button {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                        showNavDrawer.toggle()
                    }
                    PlutoSoundEngine.shared.play(.tabSwitch)
                    Haptics.impact(.light)
                } label: {
                    Image(systemName: "sidebar.leading")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 32, height: 32)
                        .background(
                            ZStack {
                                Circle()
                                    .fill(showNavDrawer ? Color.white.opacity(0.28) : Color.black.opacity(0.65))
                                    .background(.ultraThinMaterial, in: Circle())
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(showNavDrawer ? 0.50 : 0.22),
                                                Color.white.opacity(0.06)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 0.8
                                    )
                            }
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 1.5)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("b", modifiers: .command)
                .help("Toggle Navigation Sidebar (⌘B)")

                // 1. Pomodoro Focus Pill
                Button {
                    showTimerModal.toggle()
                    PlutoSoundEngine.shared.play(.tabSwitch)
                    Haptics.impact(.light)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: timerVM.mode.icon)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(timerVM.mode.themeColor)

                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 4) {
                                Text(timerVM.mode.rawValue)
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.7))

                                if timerVM.mode == .focus {
                                    Text("• R\(timerVM.completedRounds % timerVM.totalRoundsTarget + 1)/\(timerVM.totalRoundsTarget)")
                                        .font(.system(size: 7.5, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }

                            Text(timerVM.formattedTime)
                                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .contentTransition(.numericText())
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .plutoGlass(.regular, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .help("Toggle Pomodoro Timer (⌘T)")

                // 2. Session Goals Pill (Toggles Goals Panel)
                Button {
                    showGoalsPanel.toggle()
                    PlutoSoundEngine.shared.play(.tabSwitch)
                    Haptics.impact(.light)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "target")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))

                        VStack(alignment: .leading, spacing: 0) {
                            Text("Session goals")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white.opacity(0.6))
                            Text("\(totalGoalsCount - openGoalsCount)/\(totalGoalsCount)")
                                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(
                    PlutoGlassButtonStyle(
                        shape: RoundedRectangle(cornerRadius: 10, style: .continuous),
                        tint: showGoalsPanel ? Color.blue : nil,
                        isProminent: showGoalsPanel
                    )
                )
            }

            Spacer()

            // Top-Center: Apple Liquid Glass Segmented Switcher [ Plan | List | Time ]
            PlutoGlassSegmentedPicker(
                selection: $todaySubmode,
                items: ["Plan", "List", "Time"],
                namespace: glassPillNamespace
            ) { m, isSelected in
                HStack(spacing: 5) {
                    Image(systemName: m == "Plan" ? "calendar.day.timeline.left" : (m == "List" ? "checklist.checked" : "timer.circle.fill"))
                        .font(.system(size: 10.5, weight: isSelected ? .bold : .semibold))
                        .symbolEffect(.bounce, value: isSelected)

                    Text(m)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))

                    if m == "Plan" && scheduledTodoCount > 0 {
                        Text("\(scheduledTodoCount)")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.60))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.white.opacity(0.22) : Color.white.opacity(0.08))
                            )
                    } else if m == "List" && openTodoCount > 0 {
                        Text("\(openTodoCount)")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.60))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.white.opacity(0.22) : Color.white.opacity(0.08))
                            )
                    }
                }
                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.65))
            }
            .keyboardShortcut(KeyEquivalent(Character(todaySubmode == "Plan" ? "1" : (todaySubmode == "List" ? "2" : "3"))), modifiers: .command)

            Spacer()

            // Top-Right: 5 Control Icon Buttons (Background, Sound, Quote, Stats, Fullscreen/Exit)
            HStack(spacing: 8) {
                topIconButton(icon: "photo.on.rectangle.angled", panel: .background)
                topIconButton(icon: "music.note", panel: .sound)
                
                // Quote Button (toggles persistent quote card on screen)
                Button {
                    withAnimation(.spring(response: 0.35)) {
                        showQuoteCard.toggle()
                    }
                    PlutoSoundEngine.shared.play(.tabSwitch)
                    Haptics.impact(.light)
                } label: {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(
                    PlutoGlassButtonStyle(
                        shape: RoundedRectangle(cornerRadius: 10, style: .continuous),
                        tint: showQuoteCard ? Color.blue : nil,
                        isProminent: showQuoteCard
                    )
                )
                .help("Toggle Motivational Quote")

                topIconButton(icon: "chart.bar.fill", panel: .stats)

                // Fullscreen / Exit Button
                Button {
                    #if os(macOS)
                    DispatchQueue.main.async {
                        if let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first {
                            window.toggleFullScreen(nil)
                        }
                    }
                    #else
                    dismiss()
                    #endif
                    Haptics.impact(.medium)
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(
                    PlutoGlassButtonStyle(
                        shape: RoundedRectangle(cornerRadius: 10, style: .continuous),
                        tint: nil,
                        isProminent: false
                    )
                )
                .help("Toggle Fullscreen")
            }
        }
    }

    private func topIconButton(icon: String, panel: FocusRoomActivePanel) -> some View {
        let isActive = activePanel == panel
        return Button {
            withAnimation(.spring(response: 0.35)) {
                if activePanel == panel {
                    activePanel = .none
                } else {
                    activePanel = panel
                }
            }
            PlutoSoundEngine.shared.play(.tabSwitch)
            Haptics.impact(.light)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 16, height: 16)
        }
        .buttonStyle(
            PlutoGlassButtonStyle(
                shape: RoundedRectangle(cornerRadius: 10, style: .continuous),
                tint: isActive ? Color.blue : nil,
                isProminent: isActive
            )
        )
    }

    // MARK: - Big Pomodoro Modal Popup

    private var bigTimerModal: some View {
        VStack(spacing: 14) {
            // Top Header: Title + Mute + Close
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(timerVM.mode.themeColor)
                    Text("Flow Studio")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    Text("\(timerVM.completedRounds) completed")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                }

                Spacer()

                Button {
                    timerVM.isMuted.toggle()
                    Haptics.impact(.light)
                } label: {
                    Image(systemName: timerVM.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plutoGlassCircle)
                .help(timerVM.isMuted ? "Unmute Bell" : "Mute Bell")

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showTimerModal = false
                    }
                    Haptics.impact(.light)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plutoGlassCircle)
            }

            // Mode Segmented Control: [ Focus | Short Break | Long Break ]
            PlutoGlassSegmentedPicker(
                selection: Binding(
                    get: { timerVM.mode },
                    set: { timerVM.setMode($0) }
                ),
                items: PomodoroMode.allCases,
                namespace: pomodoroModeNamespace
            ) { m, isSelected in
                HStack(spacing: 4) {
                    Image(systemName: m.icon)
                        .font(.system(size: 9.5, weight: .bold))
                        .symbolEffect(.bounce, value: isSelected)
                    Text(m.rawValue)
                        .font(.system(size: 10.5, weight: isSelected ? .bold : .medium))
                }
                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.65))
            }

            // Big Countdown Time Display with Quick Adjust
            VStack(spacing: 6) {
                HStack(alignment: .center) {
                    // -5m Button
                    Button {
                        timerVM.adjustDuration(deltaMinutes: -5)
                    } label: {
                        Text("-5m")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Decrease 5 minutes")

                    Spacer()

                    Text(timerVM.formattedTime)
                        .font(.system(size: 38, weight: .heavy, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Spacer()

                    // +5m Button
                    Button {
                        timerVM.adjustDuration(deltaMinutes: 5)
                    } label: {
                        Text("+5m")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .plutoGlass(.regular, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Increase 5 minutes")
                }

                // Subtle animated progress line
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 4)

                        Capsule()
                            .fill(timerVM.mode.themeColor)
                            .frame(width: max(4, geo.size.width * CGFloat(timerVM.progress)), height: 4)
                            .animation(.linear(duration: 0.5), value: timerVM.progress)
                    }
                }
                .frame(height: 4)
            }

            // Rounds Indicator Dots
            HStack {
                HStack(spacing: 5) {
                    ForEach(0..<timerVM.totalRoundsTarget, id: \.self) { round in
                        let isDone = round < (timerVM.completedRounds % timerVM.totalRoundsTarget)
                        Circle()
                            .fill(isDone ? timerVM.mode.themeColor : Color.white.opacity(0.18))
                            .frame(width: 7, height: 7)
                    }
                }

                Spacer()

                Text("Round \(timerVM.completedRounds % timerVM.totalRoundsTarget + 1) of \(timerVM.totalRoundsTarget)")
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Divider().opacity(0.2)

            // Primary Actions: Reset, Play/Pause, Skip Next
            HStack(spacing: 12) {
                Button {
                    timerVM.resetTimer()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help("Reset Session")

                Button {
                    timerVM.togglePlayPause()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: timerVM.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text(timerVM.isRunning ? "PAUSE" : "START")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(timerVM.mode.themeColor, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button {
                    timerVM.skipNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help("Skip to Next Phase")
            }
        }
        .padding(16)
        .frame(width: 310)
        .background(DS.Theme.sidebar)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.16), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 10)
    }

    // MARK: - Session Persistence

    private func startSession() {
        let session = FocusSession(
            startTime: Date(),
            sessionTag: "Study Stream",
            backgroundCategory: selectedPresetID
        )
        modelContext.insert(session)
        try? modelContext.save()
        currentSession = session
    }

    private func endSession() {
        guard let session = currentSession else { return }
        let duration = timerVM.secondsElapsed
        if duration < 15 {
            modelContext.delete(session)
            try? modelContext.save()
            currentSession = nil
            return
        }
        session.endTime = Date()
        session.durationSeconds = duration
        try? modelContext.save()
        currentSession = nil

        let minutes = duration / 60
        if minutes > 0 {
            Task {
                _ = try? await GhostEngine.shared.recordVerifiedSilenceMinutes(minutes)
            }
        }
    }

    private func shortcutBadge(key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                .foregroundStyle(Color.white.opacity(0.85))
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.65))
        }
    }

    // MARK: - Layer 5: Liquid Glass Flyout Navigation Drawer (Burger Menu)

    @ViewBuilder
    private func liquidGlassNavDrawer(size: CGSize) -> some View {
        if showNavDrawer {
            ZStack(alignment: .leading) {
                // Dimmed Backdrop Overlay (tap outside to dismiss)
                Color.black.opacity(0.45)
                    .background(DS.Theme.sidebar)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                            showNavDrawer = false
                        }
                    }

                // Slide-in Frosted Glass Drawer
                VStack(alignment: .leading, spacing: 0) {
                    // Drawer Header
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.accentColor)

                            Text("Pluto Studio")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.white)
                        }

                        Spacer()

                        Button {
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                                showNavDrawer = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.escape, modifiers: [])
                        .help("Close Menu (Esc)")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                    Divider().opacity(0.3)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {

                            // SECTION 1: TODAY PILLARS (Plan ⌘1, List ⌘2, Time ⌘3)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Today Pillars")
                                    .font(.system(size: 10.5, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.45))
                                    .padding(.horizontal, 12)

                                drawerNavButton(
                                    title: "Plan",
                                    subtitle: "Day Timeline & Schedule",
                                    icon: "calendar.day.timeline.left",
                                    badge: "⌘1",
                                    count: scheduledTodoCount,
                                    isActive: todaySubmode == "Plan"
                                ) {
                                    withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                                        showNavDrawer = false
                                        todaySubmode = "Plan"
                                    }
                                    NotificationCenter.default.post(name: .locaJumpToSection, object: MacSection.today)
                                    PlutoSoundEngine.shared.play(.tabSwitch)
                                    Haptics.impact(.light)
                                }

                                drawerNavButton(
                                    title: "List",
                                    subtitle: "GTD Tasks & Queues",
                                    icon: "checklist.checked",
                                    badge: "⌘2",
                                    count: openTodoCount,
                                    isActive: todaySubmode == "List"
                                ) {
                                    withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                                        showNavDrawer = false
                                        todaySubmode = "List"
                                    }
                                    NotificationCenter.default.post(name: .locaJumpToSection, object: MacSection.today)
                                    PlutoSoundEngine.shared.play(.tabSwitch)
                                    Haptics.impact(.light)
                                }

                                drawerNavButton(
                                    title: "Time",
                                    subtitle: "Focus Room (Active)",
                                    icon: "timer.circle.fill",
                                    badge: "⌘3",
                                    count: nil,
                                    isActive: todaySubmode == "Time"
                                ) {
                                    withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                                        showNavDrawer = false
                                    }
                                }
                            }

                            Divider().opacity(0.2)

                            // SECTION 2: WORKSPACE PILLARS
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Workspace")
                                    .font(.system(size: 10.5, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.45))
                                    .padding(.horizontal, 12)

                                drawerSectionButton(title: "Studio", subtitle: "Notes & Projects", icon: "sparkles.rectangle.stack.fill", section: .studio)
                                drawerSectionButton(title: "Life", subtitle: "Mountain & Trek Atlas", icon: "mountain.2.fill", section: .life)
                                drawerSectionButton(title: "Settings", subtitle: "Preferences & Backup", icon: "gearshape.fill", section: .settings)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 14)
                    }

                    Spacer()

                    // Quick Return to Day Planner Action
                    Button {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                            showNavDrawer = false
                            todaySubmode = "Plan"
                        }
                        NotificationCenter.default.post(name: .locaJumpToSection, object: MacSection.today)
                        PlutoSoundEngine.shared.play(.tabSwitch)
                        Haptics.impact(.medium)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left.circle.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("Return to Day Planner")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.85), Color.blue.opacity(0.70)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.3), lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(14)
                }
                .frame(width: 275)
                .frame(maxHeight: .infinity)
                .background(DS.Theme.sidebar)
                .overlay(
                    Rectangle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.25), Color.white.opacity(0.04)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.8
                        ),
                    alignment: .trailing
                )
                .shadow(color: Color.black.opacity(0.55), radius: 24, x: 8, y: 0)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
            .zIndex(250)
        }
    }

    private func drawerNavButton(
        title: String,
        subtitle: String,
        icon: String,
        badge: String,
        count: Int?,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: isActive ? .bold : .medium))
                    .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.75))
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12.5, weight: isActive ? .bold : .semibold))
                        .foregroundStyle(Color.white)

                    Text(subtitle)
                        .font(.system(size: 9.5))
                        .foregroundStyle(Color.white.opacity(0.55))
                }

                Spacer()

                if let c = count, c > 0 {
                    Text("\(c)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.75))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.white.opacity(isActive ? 0.22 : 0.10), in: Capsule())
                }

                Text(badge)
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.50))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(isActive ? 0.20 : 0.08), in: RoundedRectangle(cornerRadius: 4))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                isActive ? Color.white.opacity(0.14) : Color.white.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 9)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(
                        isActive ? Color.white.opacity(0.35) : Color.white.opacity(0.06),
                        lineWidth: 0.8
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func drawerSectionButton(
        title: String,
        subtitle: String,
        icon: String,
        section: MacSection
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                showNavDrawer = false
            }
            NotificationCenter.default.post(name: .locaJumpToSection, object: section)
            PlutoSoundEngine.shared.play(.tabSwitch)
            Haptics.impact(.light)
        } label: {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white)

                    Text(subtitle)
                        .font(.system(size: 9.5))
                        .foregroundStyle(Color.white.opacity(0.50))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.6)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
