import SwiftUI
import SwiftData

// MARK: - MacTodoDetailColumn   (T9 — calm document panel)

struct MacTodoDetailColumn: View {

    @Binding var item: TodoItem?

    var body: some View {
        if let currentItem = item {
            MacTodoEditor(item: currentItem)
                .id(currentItem.id)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal:   .opacity.combined(with: .move(edge: .leading))
                ))
                .animation(DS.Motion.settle, value: currentItem.id)
        } else {
            MacDayDashboardHub(selectedItem: $item)
        }
    }
}

// MARK: - MacTodoEditor

private struct MacTodoEditor: View {

    @Bindable var item: TodoItem
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\TodoItem.createdAt)]) private var allItems: [TodoItem]

    @State private var showDeleteConfirm = false
    @State private var showIconPicker    = false
    @State private var showStartPicker   = false
    @State private var showDatePicker    = false
    @State private var activeBlockID: UUID? = nil

    private var subtasks: [TodoItem] {
        allItems.filter { $0.parentID == item.id && !$0.isArchived }
    }
    private var completedSubtaskCount: Int { subtasks.filter(\.isCompleted).count }
    private var subtaskProgress: Double {
        subtasks.isEmpty ? 0 : Double(completedSubtaskCount) / Double(subtasks.count)
    }
    /// List task = no scheduled time; plan task = has startTime (no priority shown).
    private var isListTask: Bool { item.startTime == nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: Hero — icon bubble + display-font title + quick actions
                HStack(alignment: .center, spacing: DS.Space.md) {
                    Button { showIconPicker.toggle() } label: {
                        Image(systemName: item.iconName ?? "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(item.isCompleted ? DS.Theme.emerald : DS.Theme.amber)
                            .frame(width: 38, height: 38)
                            .background(
                                (item.isCompleted ? DS.Theme.emerald : DS.Theme.amber).opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke((item.isCompleted ? DS.Theme.emerald : DS.Theme.amber).opacity(0.25), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Change icon")
                    .popover(isPresented: $showIconPicker, arrowEdge: .bottom) {
                        IconPickerPopover(
                            selected: Binding(
                                get: { item.iconName },
                                set: { item.iconName = $0; showIconPicker = false; autosave() }
                            )
                        )
                    }

                    TextField("Task title", text: $item.title, axis: .vertical)
                        .font(.system(size: 24, weight: .bold))
                        .tracking(-0.4)
                        .textFieldStyle(.plain)
                        .foregroundStyle(item.isCompleted ? DS.Theme.textTertiary : DS.Theme.textPrimary)
                        .strikethrough(item.isCompleted, color: DS.Theme.textTertiary)
                        .onChange(of: item.title) { _, _ in autosave() }

                    Spacer()

                    // Complete Toggle
                    Button(action: toggleComplete) {
                        HStack(spacing: 5) {
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 14, weight: .bold))
                            Text(item.isCompleted ? "Done" : "Mark Done")
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                        .foregroundStyle(item.isCompleted ? DS.Theme.emerald : DS.Theme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            item.isCompleted ? DS.Theme.emerald.opacity(0.12) : Color.white.opacity(0.05),
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(item.isCompleted ? DS.Theme.emerald.opacity(0.30) : Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help(item.isCompleted ? "Mark not done" : "Mark done")

                    // Priority Flag Menu
                    if isListTask {
                        Menu {
                            Button("None")   { item.priority = 0; autosave() }
                            Divider()
                            Button("Low")    { item.priority = 1; autosave() }
                            Button("Medium") { item.priority = 2; autosave() }
                            Button("High")   { item.priority = 3; autosave() }
                        } label: {
                            Image(systemName: item.priority > 0 ? "flag.fill" : "flag")
                                .font(.system(size: 13))
                                .foregroundStyle(item.priority > 0 ? DS.Theme.amber : DS.Theme.textTertiary)
                                .frame(width: 28, height: 28)
                                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                        }
                        .menuStyle(.borderlessButton)
                        .help(item.priority > 0 ? "Priority: \(priorityLabel(item.priority))" : "Set priority")
                    }

                    // Archive (Delete)
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundStyle(DS.Theme.textTertiary)
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .help("Archive this task")
                }
                .padding(.top, DS.Space.xl)
                .padding(.bottom, DS.Space.md)

                // MARK: Chip row — date · time · flag
                chipRow
                    .padding(.bottom, DS.Space.xl)

                // MARK: Schedule card
                scheduleCard
                    .padding(.bottom, DS.Space.md)

                // MARK: Note
                noteSection
                    .padding(.bottom, DS.Space.xxxl)
            }
            .padding(.horizontal, DS.Space.xl)
        }
        .background(DS.Theme.canvas)
        .confirmationDialog(
            "Delete \"\(item.title)\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: archiveItem)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The task will be removed. This can't be undone from the app.")
        }
    }

    // MARK: Chip row

    @ViewBuilder
    private var chipRow: some View {
        HStack(spacing: DS.Space.sm) {
            if item.startTime != nil {
                // Plan task — combined date · time chip
                let dateText = (item.dueDate ?? item.startTime ?? Date())
                    .formatted(.dateTime.month(.abbreviated).day())
                let timeText = (item.startTime ?? Date())
                    .formatted(.dateTime.hour().minute())
                removableChip(icon: "calendar", text: "\(dateText) · \(timeText)") {
                    item.dueDate  = nil
                    item.startTime = nil
                    item.durationMinutes = 0
                    autosave()
                }
            } else {
                // List task — tappable date chip: add / modify / remove
                dateChipButton
            }

            // Flag chip — list tasks only, visible when priority is set
            if isListTask && item.priority > 0 {
                removableChip(icon: "flag.fill",
                              text: priorityLabel(item.priority),
                              tint: .orange) {
                    item.priority = 0
                    autosave()
                }
            }

            Spacer()
        }
    }

    /// List-task date affordance: a filled chip when a date is set, a dashed
    /// "+ Date" pill when not. Tapping either opens a graphical `DatePicker`
    /// popover to add, change, or (via the destructive button) remove the date.
    @ViewBuilder
    private var dateChipButton: some View {
        Button { showDatePicker.toggle() } label: {
            if let due = item.dueDate {
                HStack(spacing: DS.Space.xs) {
                    Image(systemName: "calendar").font(.caption2)
                    Text(due.formatted(.dateTime.month(.abbreviated).day()))
                        .font(DS.Text.caption)
                }
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.12), in: Capsule())
            } else {
                HStack(spacing: DS.Space.xs) {
                    Image(systemName: "plus").font(.caption2)
                    Text("Date").font(DS.Text.caption)
                }
                .foregroundStyle(DS.Color.textTertiary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .overlay(
                    Capsule()
                        .stroke(
                            DS.Color.textTertiary.opacity(0.45),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 2])
                        )
                )
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showDatePicker, arrowEdge: .bottom) {
            VStack(spacing: 0) {
                DatePicker(
                    "Due",
                    selection: Binding(
                        get: { item.dueDate ?? Calendar.current.startOfDay(for: .now) },
                        set: { item.dueDate = $0; autosave() }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(DS.Space.md)

                if item.dueDate != nil {
                    Divider()
                    Button(role: .destructive) {
                        item.dueDate = nil
                        autosave()
                        showDatePicker = false
                    } label: {
                        Label("Remove Date", systemImage: "calendar.badge.minus")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, DS.Space.sm)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
            }
            .frame(width: 300)
        }
    }

    // MARK: Schedule card

    @ViewBuilder
    private var scheduleCard: some View {
        GroupedCard(label: "SCHEDULE ON TIMELINE") {
            // On-timeline toggle
            HStack {
                Text("On timeline")
                    .font(DS.Text.body)
                    .foregroundStyle(DS.Color.textPrimary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { item.startTime != nil },
                    set: { on in
                        if on {
                            item.startTime = defaultStart()
                            if item.durationMinutes == 0 { item.durationMinutes = 30 }
                        } else {
                            item.startTime = nil
                            item.durationMinutes = 0
                        }
                        autosave()
                    }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
            }

            if item.startTime != nil {
                Divider()

                // Start — tapping opens a compact date+time popover
                HStack {
                    Text("Start")
                        .font(DS.Text.body)
                        .foregroundStyle(DS.Color.textPrimary)
                    Spacer()
                    Button { showStartPicker.toggle() } label: {
                        Text(
                            (item.startTime ?? defaultStart())
                                .formatted(.dateTime.weekday(.abbreviated)
                                    .month(.abbreviated).day()
                                    .hour().minute())
                        )
                        .font(DS.Text.body)
                        .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showStartPicker, arrowEdge: .trailing) {
                        VStack(spacing: 0) {
                            DatePicker(
                                "Start",
                                selection: Binding(
                                    get: { item.startTime ?? defaultStart() },
                                    set: { item.startTime = $0; autosave() }
                                ),
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                            .padding(DS.Space.md)
                        }
                        .frame(width: 320)
                    }
                }

                Divider()

                // Duration — custom − / + stepper
                HStack {
                    Text("Duration")
                        .font(DS.Text.body)
                        .foregroundStyle(DS.Color.textPrimary)
                    Spacer()
                    DurationStepper(
                        minutes: Binding(
                            get: { item.durationMinutes },
                            set: { item.durationMinutes = max(0, $0); autosave() }
                        )
                    )
                }
            }
        }
    }

    // MARK: Subtasks card

    @ViewBuilder
    private var subtasksCard: some View {
        let cardLabel = subtasks.isEmpty
            ? "SUBTASKS"
            : "SUBTASKS · \(completedSubtaskCount) OF \(subtasks.count)"

        GroupedCard(label: cardLabel) {
            ForEach(Array(subtasks.enumerated()), id: \.element.id) { idx, sub in
                if idx > 0 { Divider() }
                SubtaskRow(sub: sub) { deleteSubtask(sub) }
            }

            if !subtasks.isEmpty { Divider() }

            // Dashed add-subtask row
            Button(action: addSubtask) {
                HStack(spacing: DS.Space.sm) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(DS.Color.textTertiary)
                    Text("Add subtask")
                        .font(DS.Text.body)
                        .foregroundStyle(DS.Color.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, DS.Space.xs)
            }
            .buttonStyle(.plain)
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            detLabel("NOTE")
            MacBlockEditor(item: item, activeBlockID: $activeBlockID, allItems: allItems, onSave: autosave)
                .id(item.id)
        }
    }

    // MARK: - Actions

    private func addSubtask() {
        let sub = TodoItem(parentID: item.id)
        modelContext.insert(sub)
        autosave()
        Haptics.impact(.light)
    }

    private func deleteSubtask(_ sub: TodoItem) {
        sub.archivedAt = Date()
        autosave()
    }

    private func toggleComplete() {
        item.completedAt = item.isCompleted ? nil : Date()
        autosave()
        Haptics.impact(.light)
    }

    private func archiveItem() {
        item.archiveCascade(in: modelContext)
        autosave()
    }

    private func autosave() {
        try? modelContext.save()
    }

    private func defaultStart() -> Date {
        let cal = Calendar.current
        let day = item.dueDate ?? Date()
        return cal.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
    }

    // MARK: Helpers

    @ViewBuilder
    private func removableChip(
        icon: String,
        text: String,
        tint: Color = .accentColor,
        onRemove: @escaping () -> Void
    ) -> some View {
        HStack(spacing: DS.Space.xs) {
            Image(systemName: icon).font(.caption2)
            Text(text).font(DS.Text.caption)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12), in: Capsule())
    }

    private func detLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(DS.Color.textTertiary)
    }

    private func priorityLabel(_ p: Int) -> String {
        switch p {
        case 1: return "Low"
        case 2: return "Medium"
        case 3: return "High"
        default: return "None"
        }
    }
}

// MARK: - GroupedCard

private struct GroupedCard<Content: View>: View {

    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(DS.Color.textTertiary)

            VStack(alignment: .leading, spacing: DS.Space.sm) {
                content()
            }
            .padding(DS.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))
        }
    }
}

// MARK: - DurationStepper

private struct DurationStepper: View {

    @Binding var minutes: Int

    var body: some View {
        HStack(spacing: DS.Space.sm) {
            Button {
                withAnimation(DS.Motion.confirm) { minutes = max(0, minutes - 15) }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .background(DS.Color.surface, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(minutes <= 0)

            Text(minutes == 0 ? "None" : durationText)
                .font(DS.Text.body)
                .monospacedDigit()
                .frame(minWidth: 52, alignment: .center)
                .foregroundStyle(minutes == 0 ? DS.Color.textTertiary : DS.Color.textSecondary)

            Button {
                withAnimation(DS.Motion.confirm) { minutes += 15 }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .background(DS.Color.surface, in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var durationText: String {
        let h = minutes / 60, m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
}

// MARK: - SubtaskRow

private struct SubtaskRow: View {

    @Bindable var sub: TodoItem
    @Environment(\.modelContext) private var modelContext
    @State private var isHovered = false
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: DS.Space.sm) {
            Button {
                sub.completedAt = sub.isCompleted ? nil : Date()
                try? modelContext.save()
                Haptics.impact(.light)
            } label: {
                Image(systemName: sub.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(sub.isCompleted ? Color.accentColor : DS.Color.textSecondary)
            }
            .buttonStyle(.plain)

            TextField("Subtask", text: $sub.title)
                .font(DS.Text.body)
                .textFieldStyle(.plain)
                .strikethrough(sub.isCompleted, color: DS.Color.textTertiary)
                .foregroundStyle(sub.isCompleted ? DS.Color.textTertiary : DS.Color.textPrimary)
                .onChange(of: sub.title) { _, _ in try? modelContext.save() }

            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(DS.Color.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Remove subtask")
                .transition(.opacity)
            }
        }
        .padding(.vertical, DS.Space.xs)
        .onHover { isHovered = $0 }
        .animation(DS.Motion.confirm, value: isHovered)
    }
}
