import SwiftUI
import SwiftData

// MARK: - HorizonCategory

enum HorizonCategory: String, CaseIterable, Identifiable, Codable {
    case all     = "All Horizons"
    case quarter = "This Quarter (Q3)"
    case year    = "This Year (2026)"
    case vision  = "3-Year Vision"
    case bucket  = "Lifetime Bucket List"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all:     return "line.3.horizontal.decrease.circle"
        case .quarter: return "clock.badge.checkmark"
        case .year:    return "calendar"
        case .vision:  return "binoculars.fill"
        case .bucket:  return "trophy.fill"
        }
    }
}

// MARK: - MacAuditView (Work Strategic Roadmap & Deliverables Studio)

/// Dedicated Strategic Milestone Roadmap Studio for macOS following PLUTO's sleek, unified minimalist design.
struct MacAuditView: View {

    @AppStorage("mac_audit_selected_horizon") var selectedHorizon: HorizonCategory = .all
    @AppStorage("mac_selected_accent_index") private var selectedAccentIndex: Int = 0

    struct MilestoneCheckpoint: Identifiable, Equatable, Codable {
        let id: String
        var title: String
        var isDone: Bool
    }

    struct DetailedGoalItem: Identifiable, Equatable, Codable {
        let id: String
        var title: String
        var customTag: String // Freeform custom project or domain tag
        var horizon: HorizonCategory
        var progress: Double // 0.0 to 1.0
        var targetDate: String
        var engineHabit: String
        var checkpoints: [MilestoneCheckpoint]
    }

    @State private var goals: [DetailedGoalItem] = []

    private func loadGoals() {
        if let data = UserDefaults.standard.data(forKey: "pluto_work_goals_v1"),
           let decoded = try? JSONDecoder().decode([DetailedGoalItem].self, from: data) {
            goals = decoded
        } else {
            goals = []
        }
    }

    private func saveGoals() {
        if let encoded = try? JSONEncoder().encode(goals) {
            UserDefaults.standard.set(encoded, forKey: "pluto_work_goals_v1")
        }
    }

    // New Goal Creator State
    @State private var showingAddGoalSheet = false
    @State private var newGoalTitle = ""
    @State private var newGoalCustomTag = "ENGINEERING"
    @State private var newGoalHorizon: HorizonCategory = .quarter
    @State private var newGoalTargetDate = "October 2026"
    @State private var newGoalEngineHabit = "Deep Work Focus · 90 min"

    // Inline Card Point Addition State
    @State private var addingPointGoalId: String? = nil
    @State private var inlinePointText: String = ""

    // Inline Title Editing State
    @State private var editingTitleGoalId: String? = nil
    @State private var editedTitleText: String = ""

    private var accentColor: Color {
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
        if selectedAccentIndex >= 0 && selectedAccentIndex < palette.count {
            return palette[selectedAccentIndex]
        }
        return palette[0]
    }

    private var filteredGoals: [DetailedGoalItem] {
        if selectedHorizon == .all {
            return goals
        }
        return goals.filter { $0.horizon == selectedHorizon }
    }

    var body: some View {
        VStack(spacing: 0) {

            // Top Bar: Clean Horizon Dropdown Filter + New Goal Button
            HStack(spacing: 12) {
                Menu {
                    ForEach(HorizonCategory.allCases) { horizon in
                        Button {
                            selectedHorizon = horizon
                            PlutoSoundEngine.shared.play(.tabSwitch)
                            Haptics.impact(.light)
                        } label: {
                            HStack {
                                Image(systemName: horizon.icon)
                                Text(horizon.rawValue)
                                if selectedHorizon == horizon {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: selectedHorizon.icon)
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Color.textSecondary)

                        Text(selectedHorizon.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DS.Color.textPrimary)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(DS.Color.textTertiary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(DS.Color.border.opacity(0.4), lineWidth: 1)
                    )
                }
                .menuStyle(.borderlessButton)
                .help("Filter by Horizon")

                Spacer()

                // + New Goal Action Button
                Button {
                    newGoalTitle = ""
                    newGoalCustomTag = "ENGINEERING"
                    newGoalHorizon = selectedHorizon == .all ? .quarter : selectedHorizon
                    showingAddGoalSheet = true
                    PlutoSoundEngine.shared.play(.tabSwitch)
                    Haptics.impact(.light)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("New Goal")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(DS.Color.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(DS.Color.surfaceRecessed, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(DS.Color.border.opacity(0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DS.Space.xl)
            .padding(.vertical, DS.Space.md)
            .background(DS.Color.background)

            Divider()

            // Main Scrollable Body
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.lg) {
                    if filteredGoals.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "flag.badge.ellipsis")
                                .font(.system(size: 28))
                                .foregroundStyle(accentColor.opacity(0.8))
                            Text("No Strategic Goals in \(selectedHorizon.rawValue)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(DS.Color.textPrimary)
                            Text("Define your key deliverables, checkpoints, and execution habits to track forward momentum.")
                                .font(DS.Text.caption)
                                .foregroundStyle(DS.Color.textTertiary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 380)

                            Button {
                                newGoalTitle = ""
                                newGoalCustomTag = "WORK"
                                newGoalHorizon = selectedHorizon == .all ? .quarter : selectedHorizon
                                showingAddGoalSheet = true
                                PlutoSoundEngine.shared.play(.tabSwitch)
                                Haptics.impact(.light)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10, weight: .bold))
                                    Text("Define First Objective")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(accentColor, in: RoundedRectangle(cornerRadius: 6))
                                .foregroundStyle(.black)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(DS.Space.xxl)
                        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card).stroke(DS.Color.border.opacity(0.4), lineWidth: 1))
                    } else {
                        VStack(spacing: DS.Space.lg) {
                            ForEach(filteredGoals) { goal in
                                minimalistGoalCard(goal)
                            }
                        }
                    }

                    Spacer(minLength: DS.Space.xxxl)
                }
                .padding(.horizontal, DS.Space.xl)
                .padding(.vertical, DS.Space.lg)
                .frame(maxWidth: 1000, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Color.background)
        .onAppear {
            loadGoals()
        }
        .onReceive(NotificationCenter.default.publisher(for: .plutoDataDidReset)) { _ in
            loadGoals()
        }
        .sheet(isPresented: $showingAddGoalSheet) {
            newGoalStudioModal
        }
    }

    // MARK: - New Goal Modal (Spacious Executive Custom Creator)

    private var newGoalStudioModal: some View {
        VStack(alignment: .leading, spacing: 18) {

            // Modal Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("New Work Objective")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(DS.Color.textPrimary)
                    Text("Define your strategic deliverable and execution habit.")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Color.textSecondary)
                }
                Spacer()
                Button {
                    PlutoSoundEngine.shared.play(.tabSwitch)
                    showingAddGoalSheet = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(DS.Color.textTertiary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // 1. Goal Title Field
            VStack(alignment: .leading, spacing: 6) {
                Text("Strategic Objective Title")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DS.Color.textTertiary)

                TextField("e.g. Ship PLUTO Version 5.0 Release", text: $newGoalTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .textFieldStyle(.roundedBorder)
            }

            // 2. Custom Project / Domain Tag Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Custom Work Category / Project Tag")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DS.Color.textTertiary)

                TextField("Type any custom tag (e.g. ENGINEERING, PRODUCT, CLIENT ALPHA)", text: $newGoalCustomTag)
                    .font(.system(size: 13, weight: .medium))
                    .textFieldStyle(.roundedBorder)

                // Quick Suggestion Chips
                HStack(spacing: 6) {
                    Text("Quick tags:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DS.Color.textTertiary)

                    let presets = ["ENGINEERING", "PRODUCT", "REVENUE", "DESIGN", "OPERATIONS", "CLIENT"]
                    ForEach(presets, id: \.self) { preset in
                        Button {
                            newGoalCustomTag = preset
                            PlutoSoundEngine.shared.play(.checkmark)
                            Haptics.impact(.light)
                        } label: {
                            Text(preset)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(newGoalCustomTag == preset ? accentColor.opacity(0.2) : DS.Color.surfaceRecessed)
                                .foregroundStyle(newGoalCustomTag == preset ? accentColor : DS.Color.textSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(newGoalCustomTag == preset ? accentColor : DS.Color.border.opacity(0.4), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 3. Horizon Timeframe Selector (Standardized 28pt Chips)
            VStack(alignment: .leading, spacing: 8) {
                Text("Horizon Timeframe")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DS.Color.textTertiary)

                HStack(spacing: 6) {
                    ForEach(HorizonCategory.allCases.filter { $0 != .all }) { h in
                        let isSelected = newGoalHorizon == h
                        Button {
                            newGoalHorizon = h
                            PlutoSoundEngine.shared.play(.tabSwitch)
                            Haptics.impact(.light)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: h.icon)
                                    .font(.system(size: 10))
                                Text(h.rawValue)
                                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                            }
                            .foregroundStyle(isSelected ? Color.white : DS.Color.textSecondary)
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .background(
                                isSelected
                                    ? LinearGradient(colors: [accentColor.opacity(0.35), accentColor.opacity(0.2)], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: [DS.Color.surfaceRecessed], startPoint: .top, endPoint: .bottom),
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isSelected ? accentColor : DS.Color.border.opacity(0.4), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 4. Target Deadline & Execution Habit
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Target Deadline")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DS.Color.textTertiary)
                    TextField("e.g. October 2026", text: $newGoalTargetDate)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Execution Habit")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DS.Color.textTertiary)
                    TextField("e.g. Deep Work 90m", text: $newGoalEngineHabit)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Divider()

            // Footer Actions
            HStack {
                Button("Cancel") {
                    showingAddGoalSheet = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.Color.textSecondary)

                Spacer()

                Button {
                    createGoalFromModal()
                } label: {
                    Text("Create Work Goal")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(accentColor, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(newGoalTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(24)
        .frame(width: 580)
        .background(DS.Color.surface)
    }

    private func createGoalFromModal() {
        let trimmedTitle = newGoalTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let tag = newGoalCustomTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "WORK" : newGoalCustomTag.uppercased()

        let newGoal = DetailedGoalItem(
            id: UUID().uuidString,
            title: trimmedTitle,
            customTag: tag,
            horizon: newGoalHorizon,
            progress: 0.0,
            targetDate: newGoalTargetDate,
            engineHabit: newGoalEngineHabit,
            checkpoints: [
                MilestoneCheckpoint(id: UUID().uuidString, title: "Kickoff & architecture design", isDone: false),
                MilestoneCheckpoint(id: UUID().uuidString, title: "Core implementation sprint", isDone: false),
                MilestoneCheckpoint(id: UUID().uuidString, title: "Final testing & production deploy", isDone: false)
            ]
        )

        goals.insert(newGoal, at: 0)
        saveGoals()
        showingAddGoalSheet = false
        PlutoSoundEngine.shared.play(.checkmark)
        Haptics.impact(.rigid)
    }

    // MARK: - Minimalist Goal Card View (Clean Uniform Neutral Styling)

    private func minimalistGoalCard(_ goal: DetailedGoalItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header Row: Custom Tag / Horizon + Title + Steppers + Trash
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "briefcase.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(accentColor)

                        Text(goal.customTag.uppercased())
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(accentColor.opacity(0.15))
                            .foregroundStyle(accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        Text("· \(goal.horizon.rawValue)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(DS.Color.textTertiary)
                    }

                    // Editable Title
                    if editingTitleGoalId == goal.id {
                        HStack {
                            TextField("Goal title…", text: $editedTitleText)
                                .font(.system(size: 15, weight: .bold))
                                .textFieldStyle(.plain)
                                .onSubmit {
                                    if let idx = goals.firstIndex(where: { $0.id == goal.id }) {
                                        goals[idx].title = editedTitleText
                                    }
                                    editingTitleGoalId = nil
                                }

                            Button("Done") {
                                if let idx = goals.firstIndex(where: { $0.id == goal.id }) {
                                    goals[idx].title = editedTitleText
                                }
                                editingTitleGoalId = nil
                            }
                            .font(.system(size: 11, weight: .bold))
                            .buttonStyle(.plain)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Text(goal.title)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(DS.Color.textPrimary)

                            Button {
                                editedTitleText = goal.title
                                editingTitleGoalId = goal.id
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 10))
                                    .foregroundStyle(DS.Color.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer()

                // Progress Badge & Steppers
                HStack(spacing: 6) {
                    Button {
                        if let idx = goals.firstIndex(where: { $0.id == goal.id }) {
                            goals[idx].progress = max(0.0, goals[idx].progress - 0.05)
                            saveGoals()
                            PlutoSoundEngine.shared.play(.checkmark)
                            Haptics.impact(.light)
                        }
                    } label: {
                        Text("–")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DS.Color.textSecondary)
                            .frame(width: 22, height: 22)
                            .background(DS.Color.surfaceRecessed, in: RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)

                    Text("\(Int(goal.progress * 100))%")
                        .font(.system(size: 13, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(DS.Color.textPrimary)
                        .frame(width: 40)

                    Button {
                        if let idx = goals.firstIndex(where: { $0.id == goal.id }) {
                            goals[idx].progress = min(1.0, goals[idx].progress + 0.05)
                            saveGoals()
                            if goals[idx].progress >= 1.0 {
                                PlutoSoundEngine.shared.play(.summitPassport)
                            } else {
                                PlutoSoundEngine.shared.play(.checkmark)
                            }
                            Haptics.impact(.light)
                        }
                    } label: {
                        Text("+")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DS.Color.textSecondary)
                            .frame(width: 22, height: 22)
                            .background(DS.Color.surfaceRecessed, in: RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)

                    // Delete Goal Button
                    Button {
                        if let idx = goals.firstIndex(where: { $0.id == goal.id }) {
                            goals.remove(at: idx)
                            saveGoals()
                            PlutoSoundEngine.shared.play(.deleteTrash)
                            Haptics.impact(.light)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Color.textTertiary)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .help("Delete Goal")
                }
            }

            // Clean Crisp Progress Bar
            GeometryReader { p in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DS.Color.surfaceRecessed)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(accentColor)
                        .frame(width: max(0, p.size.width * CGFloat(goal.progress)), height: 4)
                }
            }
            .frame(height: 4)

            // Milestone Stages & Checkpoints Box
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Milestone Stages & Checkpoints:")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DS.Color.textTertiary)

                    Spacer()

                    let doneCount = goal.checkpoints.filter { $0.isDone }.count
                    Text("\(doneCount) of \(goal.checkpoints.count) complete")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(DS.Color.textTertiary)
                }

                // Checkpoint Items List
                VStack(spacing: 2) {
                    ForEach(goal.checkpoints) { cp in
                        HStack(spacing: 8) {
                            // Checkbox Toggle
                            Button {
                                toggleCheckpoint(goalId: goal.id, checkpointId: cp.id)
                            } label: {
                                Image(systemName: cp.isDone ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 13))
                                    .foregroundStyle(cp.isDone ? accentColor : DS.Color.textTertiary)
                            }
                            .buttonStyle(.plain)

                            // Checkpoint Title Text
                            Text(cp.title)
                                .font(.system(size: 12))
                                .foregroundStyle(cp.isDone ? DS.Color.textTertiary : DS.Color.textPrimary)
                                .strikethrough(cp.isDone)

                            Spacer()

                            // Delete Checkpoint Button
                            Button {
                                deleteCheckpoint(goalId: goal.id, checkpointId: cp.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(DS.Color.textTertiary.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }

                // + Inline Add Point Row
                if addingPointGoalId == goal.id {
                    HStack(spacing: 6) {
                        Image(systemName: "circle.dashed")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Color.textTertiary)

                        TextField("Type milestone checkpoint and press Enter…", text: $inlinePointText)
                            .font(.system(size: 12))
                            .textFieldStyle(.plain)
                            .onSubmit {
                                saveInlinePoint(goalId: goal.id)
                            }

                        Button("Add") {
                            saveInlinePoint(goalId: goal.id)
                        }
                        .font(.system(size: 10, weight: .bold))
                        .buttonStyle(.plain)

                        Button("Cancel") {
                            addingPointGoalId = nil
                            inlinePointText = ""
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(DS.Color.textTertiary)
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                } else {
                    Button {
                        addingPointGoalId = goal.id
                        inlinePointText = ""
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 9, weight: .bold))
                            Text("Add milestone point…")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(DS.Color.textSecondary)
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(DS.Color.surfaceRecessed.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))

            Divider()

            // Footer: Target Date & Engine Habit
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.Color.textTertiary)
                    Text("Target: \(goal.targetDate)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.Color.textSecondary)
                }

                Spacer()

                // Engine Habit Badge
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(accentColor)

                    Text("Engine Habit: \(goal.engineHabit)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.Color.textPrimary)
                }
            }
        }
        .padding(DS.Space.lg)
        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .stroke(DS.Color.border.opacity(0.4), lineWidth: 1)
        )
    }

    private func toggleCheckpoint(goalId: String, checkpointId: String) {
        if let gIdx = goals.firstIndex(where: { $0.id == goalId }),
           let cIdx = goals[gIdx].checkpoints.firstIndex(where: { $0.id == checkpointId }) {
            goals[gIdx].checkpoints[cIdx].isDone.toggle()
            recalculateProgress(goalIdx: gIdx)
            saveGoals()
            PlutoSoundEngine.shared.play(.checkmark)
            Haptics.impact(.rigid)
        }
    }

    private func deleteCheckpoint(goalId: String, checkpointId: String) {
        if let gIdx = goals.firstIndex(where: { $0.id == goalId }) {
            goals[gIdx].checkpoints.removeAll { $0.id == checkpointId }
            recalculateProgress(goalIdx: gIdx)
            saveGoals()
            PlutoSoundEngine.shared.play(.deleteTrash)
            Haptics.impact(.light)
        }
    }

    private func saveInlinePoint(goalId: String) {
        let trimmed = inlinePointText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            addingPointGoalId = nil
            return
        }

        if let gIdx = goals.firstIndex(where: { $0.id == goalId }) {
            let newCP = MilestoneCheckpoint(id: UUID().uuidString, title: trimmed, isDone: false)
            goals[gIdx].checkpoints.append(newCP)
            recalculateProgress(goalIdx: gIdx)
            saveGoals()
            inlinePointText = ""
            PlutoSoundEngine.shared.play(.checkmark)
            Haptics.impact(.light)
        }
    }

    private func recalculateProgress(goalIdx: Int) {
        guard goalIdx >= 0 && goalIdx < goals.count else { return }
        let total = goals[goalIdx].checkpoints.count
        guard total > 0 else {
            goals[goalIdx].progress = 0
            return
        }
        let done = goals[goalIdx].checkpoints.filter { $0.isDone }.count
        goals[goalIdx].progress = Double(done) / Double(total)
    }
}
