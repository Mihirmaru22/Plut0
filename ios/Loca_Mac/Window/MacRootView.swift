import SwiftUI
import SwiftData
import CoreSpotlight

enum MacSection: String, CaseIterable, Identifiable {
    case today = "Today"
    case notes = "Notes"
    case studio = "Studio"
    case life = "Life"
    case ghost = "Ghost Mode"
    case settings = "Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .today: "sun.max.fill"
        case .notes: "square.and.pencil"
        case .studio: "sparkles.rectangle.stack.fill"
        case .life: "mountain.2.fill"
        case .ghost: "flame.fill"
        case .settings: "gearshape.fill"
        }
    }
}

/// A macOS 27-native workspace: system navigation and toolbars adopt Liquid
/// Glass automatically, while the small set of custom action controls uses the
/// SwiftUI Liquid Glass APIs explicitly.
struct MacRootView: View {
    @State private var selectedSection: MacSection? = .today
    @State private var selectedTodo: TodoItem?
    @State private var selectedJournalNote: JournalNote?
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var vaultManager = LocaVaultAuthManager.shared

    @Query(filter: #Predicate<HabitBoard> { $0.archivedAt == nil }, sort: \HabitBoard.createdAt)
    private var activeHabits: [HabitBoard]

    @AppStorage("mac_notifications_master_enabled") private var masterNotificationsEnabled = true
    @AppStorage("mac_evening_reflection_enabled") private var eveningReflectionEnabled = true
    @AppStorage("mac_evening_reflection_time") private var eveningReflectionTime = "21:00"
    @AppStorage("mac_streak_alert_enabled") private var streakAlertEnabled = true
    @AppStorage("mac_streak_alert_time") private var streakAlertTime = "22:00"
    @AppStorage("mac_weekly_digest_enabled") private var weeklyDigestEnabled = true
    @AppStorage("mac_default_habit_reminder_time") private var defaultHabitTime = "09:00"
    @AppStorage("mac_today_submode") private var todaySubmode = "Plan"

    var body: some View {
        NavigationSplitView {
            List(MacSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    Label(section.rawValue, systemImage: section.systemImage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
            .navigationTitle("Pluto")
        } detail: {
            sectionContent
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Quick actions", systemImage: "circle.grid.2x2.fill") {
                    NotificationCenter.default.post(name: .locaFocusQuickAdd, object: nil)
                }
                .accessibilityLabel("Show quick actions")

                Button("New task", systemImage: "plus") {
                    NotificationCenter.default.post(name: .locaAddBlock, object: nil)
                }
                .accessibilityLabel("New task")
            }
        }
        .onAppear(perform: startFoundationServices)
        .onContinueUserActivity(CSSearchableItemActionType, perform: routeSearchActivity)
        .onOpenURL(perform: routeURL)
        .onReceive(NotificationCenter.default.publisher(for: .locaJumpToSection)) {
            selectedSection = $0.object as? MacSection
        }
        .onReceive(NotificationCenter.default.publisher(for: .locaJumpToToday)) { _ in
            selectedSection = .today
        }
        .onReceive(NotificationCenter.default.publisher(for: .locaLockVault)) { _ in
            vaultManager.lockAll()
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection ?? .today {
        case .today:
            if todaySubmode == "Time" {
                FocusRoomView()
            } else {
                HStack(spacing: 0) {
                    MacTodoContentColumn(selection: $selectedTodo)
                    MacTodoDetailColumn(item: $selectedTodo)
                }
            }
        case .notes:
            HStack(spacing: 0) {
                AppleJournalEntriesList(selectedNote: $selectedJournalNote)
                if let note = selectedJournalNote {
                    AppleJournalEditorCanvas(note: note)
                } else {
                    ContentUnavailableView("No Note Selected", systemImage: "note.text")
                }
            }
        case .studio:
            MacStudioWorkspaceView()
        case .life:
            MacLifeView()
        case .ghost:
            GhostPillarView()
        case .settings:
            // Keep the complete settings feature available. Its presentation is
            // glass-backed, but none of its preference, privacy, data, or
            // notification workflows are replaced by a reduced settings screen.
            MacSettingsView()
        }
    }

    private func startFoundationServices() {
        LocaSpotlightIndexer.shared.indexAll(context: modelContext)
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

    private func routeSearchActivity(_ userActivity: NSUserActivity) {
        guard let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }
        if let identifier = UUID(uuidString: identifier),
           let note = try? modelContext.fetch(FetchDescriptor<JournalNote>(predicate: #Predicate { $0.id == identifier })).first {
            selectedJournalNote = note
            selectedSection = .notes
        } else if let (type, _) = LocaSpotlightIndexer.ItemType.parseIdentifier(identifier) {
            selectedSection = switch type {
            case .habit, .task: .today
            case .journal: .notes
            case .principle, .bucket: .life
            case .goal: .studio
            }
        }
    }

    private func routeURL(_ url: URL) {
        guard (url.scheme == "pluto" || url.scheme == "loca"),
              url.host == "note" || url.host == "notes",
              let identifier = UUID(uuidString: url.lastPathComponent),
              let note = try? modelContext.fetch(FetchDescriptor<JournalNote>(predicate: #Predicate { $0.id == identifier })).first else { return }
        selectedJournalNote = note
        selectedSection = .notes
    }
}

// MARK: - Liquid Glass feature surfaces

/// Shared presentation shell for the first Liquid Glass pass across every
/// feature. It exposes live persisted data and command hooks without mounting
/// any of the retired feature interfaces.
private struct MacLiquidGlassFeatureView: View {
    let section: MacSection
    @Environment(\.modelContext) private var modelContext
    @Namespace private var namespace

    @Query(filter: #Predicate<TodoItem> { $0.archivedAt == nil }, sort: \TodoItem.createdAt, order: .reverse)
    private var todos: [TodoItem]
    @Query(filter: #Predicate<JournalNote> { $0.archivedAt == nil }, sort: \JournalNote.date, order: .reverse)
    private var notes: [JournalNote]
    @Query(filter: #Predicate<HabitBoard> { $0.archivedAt == nil }, sort: \HabitBoard.createdAt)
    private var habits: [HabitBoard]
    @Query(filter: #Predicate<WorkProject> { $0.isArchived == false }, sort: \WorkProject.updatedAt, order: .reverse)
    private var projects: [WorkProject]

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                VStack(alignment: .leading, spacing: 22) {
                    Label(section.rawValue, systemImage: section.systemImage)
                        .font(.largeTitle.weight(.bold))

                    sectionBody
                }
            }
            .padding(32)
            .frame(maxWidth: 860, alignment: .leading)
        }
        .navigationTitle(section.rawValue)
    }

    @ViewBuilder
    private var sectionBody: some View {
        switch section {
        case .today:
            featureHeader("Tasks that need your attention", actionTitle: "New task", actionSymbol: "plus") {
                NotificationCenter.default.post(name: .locaAddBlock, object: nil)
            }
            ForEach(todos.prefix(8), id: \.id) { item in
                Button {
                    item.completedAt = item.completedAt == nil ? Date() : nil
                    try? modelContext.save()
                } label: {
                    Label(item.title.isEmpty ? "Untitled task" : item.title, systemImage: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                .glassEffectID(item.id, in: namespace)
            }
        case .notes:
            featureHeader("Recent notes", actionTitle: "New note", actionSymbol: "square.and.pencil") {
                let note = JournalNote(title: "Untitled Note")
                modelContext.insert(note)
                try? modelContext.save()
            }
            ForEach(notes.prefix(8), id: \.id) { note in
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.title.isEmpty ? "Untitled note" : note.title).font(.headline)
                    Text(note.text.isEmpty ? "No text" : note.text).lineLimit(2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
            }
        case .studio:
            featureHeader("Projects", actionTitle: "New project", actionSymbol: "plus") {
                modelContext.insert(WorkProject(title: "Untitled Project"))
                try? modelContext.save()
            }
            ForEach(projects.prefix(8), id: \.id) { project in
                Label(project.title, systemImage: project.icon)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
            }
        case .life:
            featureHeader("Your personal record", actionTitle: "Open Life", actionSymbol: "arrow.right") {
                NotificationCenter.default.post(name: .locaJumpToSection, object: MacSection.life)
            }
            metric("Active habits", value: "\(habits.count)", symbol: "circle.grid.3x3.fill")
            metric("Journal entries", value: "\(notes.count)", symbol: "book.closed.fill")
        case .ghost:
            featureHeader("Ghost Mode", actionTitle: "Start protocol", actionSymbol: "flame.fill") {
                NotificationCenter.default.post(name: .locaJumpToSection, object: MacSection.ghost)
            }
            metric("Active commitments", value: "\(habits.count)", symbol: "checkmark.seal.fill")
            Text("Your existing Ghost Mode data and rules remain intact while its full editor is rebuilt in Liquid Glass.")
                .foregroundStyle(.secondary)
                .padding(16)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
        case .settings:
            EmptyView()
        }
    }

    private func featureHeader(_ subtitle: String, actionTitle: String, actionSymbol: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(subtitle).font(.title3).foregroundStyle(.secondary)
            Spacer()
            Button(action: action) { Label(actionTitle, systemImage: actionSymbol) }
                .buttonStyle(.glassProminent)
        }
    }

    private func metric(_ title: String, value: String, symbol: String) -> some View {
        Label { Text("\(title): \(value)") } icon: { Image(systemName: symbol) }
            .font(.headline)
            .padding(18)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}

// MARK: - Liquid Glass settings

/// Settings for the new presentation layer. Apple exposes semantic glass
/// variants, rather than an arbitrary blur or opacity amount, so the control
/// intentionally offers only the real system-backed choices.
private struct MacLiquidGlassSettingsView: View {
    @AppStorage("mac_glass_variant") private var glassVariant = GlassVariant.regular.rawValue
    @AppStorage("mac_appearance_mode") private var appearanceMode = "system"

    @Namespace private var namespace

    private var selectedVariant: GlassVariant {
        GlassVariant(rawValue: glassVariant) ?? .regular
    }

    private var glass: Glass {
        selectedVariant == .clear ? .clear : .regular
    }

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 20) {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Appearance", systemImage: "circle.lefthalf.filled")
                            .font(.largeTitle.weight(.bold))
                        Text("Choose the system-supported presentation of Pluto’s custom glass controls.")
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Liquid Glass")
                            .font(.headline)
                        Picker("Liquid Glass", selection: $glassVariant) {
                            ForEach(GlassVariant.allCases) { variant in
                                Text(variant.title).tag(variant.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityHint("Regular is the default system glass. Clear is intended for rich backgrounds.")
                        Text(selectedVariant.detail)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .glassEffect(glass, in: .rect(cornerRadius: 24))
                    .glassEffectID("glass-preference", in: namespace)
                    .glassEffectTransition(.matchedGeometry)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Color appearance")
                            .font(.headline)
                        Picker("Color appearance", selection: $appearanceMode) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(20)
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
                    .glassEffectID("color-preference", in: namespace)

                    Text("Liquid Glass automatically adapts to Reduce Transparency, Increase Contrast, and the system appearance settings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(32)
            .frame(maxWidth: 680, alignment: .leading)
        }
        .navigationTitle("Settings")
    }

    private enum GlassVariant: String, CaseIterable, Identifiable {
        case regular
        case clear

        var id: String { rawValue }
        var title: String { rawValue.capitalized }
        var detail: String {
            switch self {
            case .regular: "The default Liquid Glass material for controls and navigation."
            case .clear: "Use over visually rich backgrounds where more background detail should show through."
            }
        }
    }
}
