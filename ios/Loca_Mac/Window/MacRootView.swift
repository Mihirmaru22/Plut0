import SwiftUI
import SwiftData
import CoreSpotlight

// MARK: - MacSection

/// Top-level navigation sections shown in the Mac sidebar.
enum MacSection: String, CaseIterable, Identifiable {
    case today    = "Today"
    case notes    = "Notes"
    case studio   = "Studio"
    case life     = "Life"
    case ghost    = "Ghost Mode"
    case settings = "Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .today:    "sun.max.fill"
        case .notes:    "note.text"
        case .studio:   "sparkles.rectangle.stack.fill"
        case .life:     "mountain.2.fill"
        case .ghost:    "sparkles"
        case .settings: "gearshape"
        }
    }
}

// MARK: - MacRootView

/// Multi-pane root for the macOS app.
struct MacRootView: View {

    @State private var selectedSection:     MacSection?      = .today
    @State private var selectedHabit:       HabitBoard?      = nil
    @State private var selectedTodo:        TodoItem?        = nil
    @State private var selectedJournalNote: JournalNote?     = nil
    @State private var columnVisibility:    NavigationSplitViewVisibility = .all
    @AppStorage("has_completed_onboarding_v3") private var hasCompletedOnboarding: Bool = false
    @State private var showOnboarding:      Bool             = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject private var vaultManager = LocaVaultAuthManager.shared

    @Query(filter: #Predicate<HabitBoard> { $0.archivedAt == nil }, sort: \HabitBoard.createdAt)
    private var activeHabits: [HabitBoard]

    @AppStorage("mac_notifications_master_enabled") private var masterNotificationsEnabled: Bool = true
    @AppStorage("mac_evening_reflection_enabled") private var eveningReflectionEnabled: Bool = true
    @AppStorage("mac_evening_reflection_time") private var eveningReflectionTime: String = "21:00"
    @AppStorage("mac_streak_alert_enabled") private var streakAlertEnabled: Bool = true
    @AppStorage("mac_streak_alert_time") private var streakAlertTime: String = "22:00"
    @AppStorage("mac_weekly_digest_enabled") private var weeklyDigestEnabled: Bool = true
    @AppStorage("mac_default_habit_reminder_time") private var defaultHabitTime: String = "09:00"
    @AppStorage("mac_today_submode") private var todaySubmode: String = "Plan"

    var body: some View {
        splitView
        .sheet(isPresented: $showOnboarding) {
            MacOnboardingView(isPresented: $showOnboarding)
                .frame(minWidth: 720, minHeight: 520)
        }
        .onAppear {
            if !hasCompletedOnboarding {
                showOnboarding = true
            }

            LocaSpotlightIndexer.shared.indexAll(context: modelContext)

            // Auto-sync Apple Native Notifications (A1-A8)
            PlutoNotificationManager.shared.syncAll(
                habits: activeHabits,
                masterEnabled: masterNotificationsEnabled,
                eveningReflectionEnabled: eveningReflectionEnabled,
                eveningReflectionTime: eveningReflectionTime,
                streakAlertEnabled: streakAlertEnabled,
                streakAlertTime: streakAlertTime,
                weeklyDigestEnabled: weeklyDigestEnabled,
                defaultHabitTime: defaultHabitTime
            )
        }
        .onContinueUserActivity(CSSearchableItemActionType) { userActivity in
            if let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                if let uuid = UUID(uuidString: identifier) {
                    selectedSection = .notes
                    if let note = try? modelContext.fetch(FetchDescriptor<JournalNote>(predicate: #Predicate { $0.id == uuid })).first {
                        selectedJournalNote = note
                    }
                } else if let (type, id) = LocaSpotlightIndexer.ItemType.parseIdentifier(identifier) {
                    switch type {
                    case .habit, .task:
                        selectedSection = .today
                    case .journal:
                        selectedSection = .notes
                        if let uuid = UUID(uuidString: id),
                           let note = try? modelContext.fetch(FetchDescriptor<JournalNote>(predicate: #Predicate { $0.id == uuid })).first {
                            selectedJournalNote = note
                        }
                    case .principle, .bucket:
                        selectedSection = .life
                    case .goal:
                        selectedSection = .studio
                    }
                }
            }
        }
        .onOpenURL { url in
            if (url.scheme == "pluto" || url.scheme == "loca") && (url.host == "note" || url.host == "notes") {
                let idString = url.lastPathComponent
                if let uuid = UUID(uuidString: idString) {
                    selectedSection = .notes
                    if let note = try? modelContext.fetch(FetchDescriptor<JournalNote>(predicate: #Predicate { $0.id == uuid })).first {
                        selectedJournalNote = note
                    }
                }
            }
        }
        .onChange(of: selectedSection) { _, _ in
            selectedHabit      = nil
            selectedTodo       = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .locaJumpToSection)) { note in
            if let section = note.object as? MacSection {
                selectedSection = section
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .locaShowOnboarding)) { _ in
            showOnboarding = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .locaLockVault)) { _ in
            vaultManager.lockAll()
        }
    }

    // MARK: - Root View Shell (Sidebar Material Flush + Opaque Content Plane)

    @ViewBuilder
    private var splitView: some View {
        HStack(spacing: 0) {
            // 1. Sidebar (Translucent UltraThinMaterial, Flush to Window Edges)
            MacSidebarView(selection: $selectedSection)
                .frame(width: DS.Mac.sidebarIdealWidth)

            // 2. Trailing 1px Boundary Divider
            Rectangle()
                .fill(DS.Theme.border)
                .frame(width: 1)
                .ignoresSafeArea()

            // 3. Opaque Content Plane (Solid #161618 Obsidian, covering under titlebar)
            contentPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DS.Theme.canvas)
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var contentPane: some View {
        switch selectedSection {
        case .today:
            if todaySubmode == "Time" {
                FocusRoomView()
                    .transition(.opacity)
            } else {
                HStack(spacing: 0) {
                    MacTodoContentColumn(selection: $selectedTodo)
                        .frame(minWidth: DS.Mac.contentMinWidth, idealWidth: DS.Mac.contentIdealWidth, maxWidth: DS.Mac.contentMaxWidth)

                    Rectangle()
                        .fill(DS.Theme.border)
                        .frame(width: 1)
                        .ignoresSafeArea()

                    MacTodoDetailColumn(item: $selectedTodo)
                        .frame(minWidth: DS.Mac.detailMinWidth, maxWidth: .infinity)
                }
            }

        case .notes:
            HStack(spacing: 0) {
                AppleJournalEntriesList(selectedNote: $selectedJournalNote)
                    .frame(minWidth: 280, idealWidth: 320, maxWidth: 360)

                Rectangle()
                    .fill(DS.Theme.border)
                    .frame(width: 1)
                    .ignoresSafeArea()

                if let note = selectedJournalNote {
                    AppleJournalEditorCanvas(note: note)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView {
                        Label("No Note Selected", systemImage: "note.text")
                    } description: {
                        Text("Choose a note from the list or click New Entry (⌘N) to start writing.")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DS.Theme.canvas)
                }
            }

        case .studio:
            MacStudioWorkspaceView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .life:
            MacLifeView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .ghost:
            GhostPillarView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .settings, .none:
            MacSettingsView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - MacDetailPlaceholder (Contextual Action & Guidance Hub)

struct MacDetailPlaceholder: View {

    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<HabitBoard> { $0.archivedAt == nil })
    private var habits: [HabitBoard]

    @Query(filter: #Predicate<TodoItem> { $0.archivedAt == nil && $0.completedAt == nil })
    private var openTodos: [TodoItem]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color(red: 0.95, green: 0.77, blue: 0.25))

                    Text("Executive Workspace")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.white)

                    Text("Select a task or habit from the middle column to inspect details, or use the quick actions below.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }
                .padding(.top, 24)

                // Quick Status Bento Grid
                HStack(spacing: 12) {
                    statusCard(icon: "checkmark.circle.fill", count: "\(openTodos.count)", label: "Open Tasks", tint: Color(red: 0.35, green: 0.65, blue: 0.95))
                    statusCard(icon: "flame.fill", count: "\(habits.count)", label: "Active Habits", tint: Color(red: 0.95, green: 0.55, blue: 0.35))
                }
                .frame(maxWidth: 420)

                // Guided Actions
                VStack(spacing: 8) {
                    Text("SHORTCUTS & COMMANDS")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(Color.white.opacity(0.45))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    guidedActionRow(icon: "plus.circle", title: "New Task / Block", shortcut: "⌘N")
                    guidedActionRow(icon: "calendar.day.timeline.left", title: "Day Planner Timeline", shortcut: "⌘1")
                    guidedActionRow(icon: "note.text", title: "Notes", shortcut: "⌘2")
                    guidedActionRow(icon: "sparkles.rectangle.stack.fill", title: "Studio Projects & Goals", shortcut: "⌘3")
                    guidedActionRow(icon: "mountain.2.fill", title: "Trek & Travel Atlas", shortcut: "⌘4")
                    guidedActionRow(icon: "gearshape", title: "Settings & Preferences", shortcut: "⌘,")
                }
                .padding(16)
                .frame(maxWidth: 420)
                .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: NSColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1.0)))
    }

    private func statusCard(icon: String, count: String, label: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(count)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)

                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
            }

            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }

    private func guidedActionRow(icon: String, title: String, shortcut: String, action: (() -> Void)? = nil) -> some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))

                Spacer()

                Text(shortcut)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
