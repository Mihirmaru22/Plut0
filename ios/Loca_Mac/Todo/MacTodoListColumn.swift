import SwiftUI
import SwiftData

// MARK: - ListDesignVariant

enum ListDesignVariant: String, CaseIterable, Identifiable {
    case list1 = "Linear Bento Cards"
    case list2 = "Compact Grouped Sections"
    case list3 = "Focus Horizon Cards"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .list1: return "square.grid.2x2"
        case .list2: return "list.bullet.indent"
        case .list3: return "rectangle.stack"
        }
    }
}

// MARK: - MacTodoListColumn (Task Inventory with Liquid Glass Layout Menu)

/// The "List" sub-pillar styled with Liquid Glass controls and spring vocabulary.
struct MacTodoListColumn: View {

    @Binding var selection: TodoItem?

    @Query(sort: [SortDescriptor(\TodoItem.createdAt)], animation: .default)
    private var allItems: [TodoItem]

    @AppStorage("mac_todo_list_layout_v2") private var selectedVariant: ListDesignVariant = .list1
    @State private var showCompleted = false
    @Namespace private var layoutPillNamespace
    @Namespace private var taskSelectionNamespace

    private var activeItems: [TodoItem] {
        allItems.filter { !$0.isArchived && $0.parentID == nil && $0.startTime == nil }
    }

    private var openItems: [TodoItem] {
        activeItems.filter { !$0.isCompleted }
    }

    private var doneItems: [TodoItem] {
        activeItems
            .filter { $0.isCompleted }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    var body: some View {
        VStack(spacing: 0) {

            // Top Header: Liquid Glass Task Counter & Layout Switcher
            topGlassHeader
                .padding(.horizontal, DS.Space.md)
                .padding(.vertical, 8)

            Divider()
                .opacity(0.12)

            // Quick Add Input with Glass Container
            MacTodoQuickAdd()
                .padding(.horizontal, DS.Space.md)
                .padding(.vertical, 8)

            Divider()
                .opacity(0.12)

            // Main List Content
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.md) {
                    switch selectedVariant {
                    case .list1:
                        List1BentoCardsView(
                            items: openItems,
                            doneItems: doneItems,
                            selection: $selection,
                            showCompleted: $showCompleted,
                            selectionNamespace: taskSelectionNamespace
                        )
                    case .list2:
                        List2GroupedSectionsView(
                            items: openItems,
                            doneItems: doneItems,
                            selection: $selection,
                            showCompleted: $showCompleted,
                            selectionNamespace: taskSelectionNamespace
                        )
                    case .list3:
                        List3FocusCardsView(
                            items: openItems,
                            doneItems: doneItems,
                            selection: $selection,
                            showCompleted: $showCompleted,
                            selectionNamespace: taskSelectionNamespace
                        )
                    }
                }
                .padding(.horizontal, DS.Space.md)
                .padding(.vertical, DS.Space.md)
            }
            .overlay {
                if activeItems.isEmpty {
                    ContentUnavailableView {
                        Label("No Tasks", systemImage: "checkmark.circle")
                    } description: {
                        Text("Type a task in the bar above and press Return.")
                    }
                }
            }
        }
        .onChange(of: selectedVariant) { _, newVar in
            PlutoTelemetryEngine.shared.trackLayoutChanged(section: "TodoList", newLayout: newVar.rawValue)
        }
    }

    // MARK: - Top Apple Liquid Glass Header

    private var topGlassHeader: some View {
        HStack(spacing: DS.Space.sm) {
            // Task count chip in glass capsule
            HStack(spacing: 5) {
                Circle()
                    .fill(DS.Theme.amber)
                    .frame(width: 5, height: 5)

                Text("\(openItems.count) tasks open")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .contentTransition(.numericText())

                if !doneItems.isEmpty {
                    Text("• \(doneItems.count) done")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(DS.Theme.textSecondary)
                        .contentTransition(.numericText())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .plutoGlass(.regular, in: Capsule())

            Spacer()

            // Liquid Glass Layout Switcher Capsule
            GlassEffectContainer(spacing: 2) {
                ForEach(ListDesignVariant.allCases) { variant in
                    let isSelected = selectedVariant == variant
                    Button {
                        withAnimation(PlutoSpring.snappy) {
                            selectedVariant = variant
                        }
                    } label: {
                        Image(systemName: variant.icon)
                            .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? Color.white : DS.Theme.textSecondary)
                            .symbolEffect(.bounce, value: isSelected)
                            .frame(width: 26, height: 22)
                            .contentShape(Capsule())
                            .background {
                                if isSelected {
                                    Capsule()
                                        .fill(DS.Theme.cardSelected)
                                        .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 0.8))
                                        .matchedGeometryEffect(id: "activeLayoutPill", in: layoutPillNamespace)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .help(variant.rawValue)
                }
            }
        }
    }
}

// MARK: - Design 1: List1BentoCardsView (Liquid Glass Bento Cards)

private struct List1BentoCardsView: View {

    @Environment(\.modelContext) private var modelContext
    let items: [TodoItem]
    let doneItems: [TodoItem]
    @Binding var selection: TodoItem?
    @Binding var showCompleted: Bool
    var selectionNamespace: Namespace.ID

    var body: some View {
        VStack(spacing: 7) {
            ForEach(items, id: \.id) { item in
                List1CardRow(
                    item: item,
                    isSelected: selection?.id == item.id,
                    selectionNamespace: selectionNamespace
                ) {
                    selection = item
                }
            }

            if !doneItems.isEmpty {
                completedSection
            }
        }
    }

    private var completedSection: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Button {
                    withAnimation(PlutoSpring.smooth) { showCompleted.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .rotationEffect(.degrees(showCompleted ? 90 : 0))
                            .animation(PlutoSpring.smooth, value: showCompleted)

                        Text(showCompleted ? "Hide completed" : "\(doneItems.count) completed tasks")
                            .font(.system(size: 11, weight: .medium))
                            .contentTransition(.numericText())
                    }
                    .foregroundStyle(DS.Theme.textTertiary)
                }
                .buttonStyle(.plain)

                Spacer()

                ClearCompletedGlassButton {
                    for item in doneItems {
                        item.archivedAt = Date()
                    }
                    try? modelContext.save()
                    PlutoSoundEngine.shared.play(.deleteTrash)
                    Haptics.impact(.medium)
                }
            }
            .padding(.vertical, 4)

            if showCompleted {
                ForEach(doneItems, id: \.id) { item in
                    List1CardRow(
                        item: item,
                        isSelected: selection?.id == item.id,
                        selectionNamespace: selectionNamespace
                    ) {
                        selection = item
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
                }
            }
        }
        .padding(.top, 6)
    }
}

// MARK: - Clear Completed Glass Button

private struct ClearCompletedGlassButton: View {
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "trash")
                    .font(.system(size: 9))
                Text("Clear Completed")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(Color.red.opacity(0.90))
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .plutoGlass(.tinted(.red), in: Capsule())
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(PlutoSpring.snappy, value: isPressed)
        }
        .buttonStyle(.plain)
        .help("Delete all completed tasks")
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - List1CardRow (Liquid Glass Card)

private struct List1CardRow: View {
    @Bindable var item: TodoItem
    let isSelected: Bool
    var selectionNamespace: Namespace.ID
    let onSelect: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\TodoItem.createdAt)]) private var allItems: [TodoItem]
    @State private var isHovered = false

    private var subtasks: [TodoItem] {
        allItems.filter { $0.parentID == item.id && !$0.isArchived }
    }
    private var completedSubtaskCount: Int { subtasks.filter(\.isCompleted).count }
    private var catColor: Color { item.categoryColor }

    var body: some View {
        HStack(spacing: 10) {

            // Checkbox with glass styling
            Button {
                withAnimation(PlutoSpring.bouncy) {
                    if item.isCompleted {
                        item.completedAt = nil
                    } else {
                        item.completedAt = Date()
                        PlutoSoundEngine.shared.play(.completePop)
                        PlutoTelemetryEngine.shared.trackTaskCompleted(task: item)
                    }
                    try? modelContext.save()
                }
                Haptics.notify(.success)
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(item.isCompleted ? DS.Theme.emerald : DS.Theme.border, lineWidth: 1.5)
                        .frame(width: 18, height: 18)

                    if item.isCompleted {
                        Circle()
                            .fill(DS.Theme.emerald)
                            .frame(width: 18, height: 18)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.black)
                    }
                }
                .plutoGlass(.regular, in: Circle())
                .symbolEffect(.bounce, value: item.isCompleted)
            }
            .buttonStyle(.plain)

            // Category Icon Bubble
            Image(systemName: item.iconName ?? "checklist")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(item.isCompleted ? DS.Theme.textTertiary : catColor)
                .frame(width: 22, height: 22)
                .background(catColor.opacity(0.12), in: Circle())

            // Title & Metadata
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title.isEmpty ? "Untitled Task" : item.title)
                    .font(.system(size: 12.5, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(item.isCompleted ? DS.Theme.textTertiary : DS.Theme.textPrimary)
                    .strikethrough(item.isCompleted, color: DS.Theme.textTertiary)
                    .animation(.easeInOut(duration: 0.15), value: item.isCompleted)
                    .lineLimit(1)

                // Metadata Pill Row
                if item.dueDate != nil || !subtasks.isEmpty || item.startTime != nil {
                    HStack(spacing: 6) {
                        if let due = item.dueDate {
                            HStack(spacing: 3) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 8))
                                Text(due, style: .date)
                            }
                            .font(.system(size: 9.5))
                            .foregroundStyle(isOverdue(due) && !item.isCompleted ? Color.red : DS.Theme.textTertiary)
                        }

                        if !subtasks.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 8))
                                Text("\(completedSubtaskCount)/\(subtasks.count)")
                            }
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(catColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(catColor.opacity(0.1), in: Capsule())
                        }
                    }
                }
            }

            Spacer()

            // Delete Trash Button on Hover
            if item.isCompleted || isHovered {
                Button {
                    item.archivedAt = Date()
                    try? modelContext.save()
                    PlutoSoundEngine.shared.play(.deleteTrash)
                    Haptics.impact(.light)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(item.isCompleted ? Color.red.opacity(0.8) : DS.Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Delete task")
                .transition(.scale.combined(with: .opacity))
            }

            // Priority Indicator Pill
            if item.priority > 0 {
                priorityPill(item.priority)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 10)
                    .fill(DS.Theme.cardSelected)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.35), lineWidth: 0.8))
                    .matchedGeometryEffect(id: "taskSelectionHighlight", in: selectionNamespace)
            } else if isHovered {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.05))
            }
        }
        .plutoGlass(isSelected ? .interactive : (isHovered ? .regular : .regular), in: RoundedRectangle(cornerRadius: 10))
        .offset(y: isHovered ? -1 : 0)
        .animation(PlutoSpring.snappy, value: isHovered)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    private func priorityPill(_ p: Int) -> some View {
        let (label, color) = priorityInfo(p)
        return Text(label)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 0.6))
    }

    private func priorityInfo(_ p: Int) -> (String, Color) {
        switch p {
        case 3: return ("High", Color.red)
        case 2: return ("Med", Color.orange)
        case 1: return ("Low", Color.green)
        default: return ("", Color.clear)
        }
    }

    private func isOverdue(_ date: Date) -> Bool {
        Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: .now)
    }
}

// MARK: - Design 2: List2GroupedSectionsView (Liquid Glass Grouped Sections)

private struct List2GroupedSectionsView: View {

    let items: [TodoItem]
    let doneItems: [TodoItem]
    @Binding var selection: TodoItem?
    @Binding var showCompleted: Bool
    var selectionNamespace: Namespace.ID

    private var highPriority: [TodoItem] { items.filter { $0.priority == 3 } }
    private var medPriority:  [TodoItem] { items.filter { $0.priority == 2 } }
    private var lowPriority:  [TodoItem] { items.filter { $0.priority <= 1 } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            if !highPriority.isEmpty {
                glassPriorityGroup(title: "HIGH PRIORITY", icon: "flame.fill", color: .red, tasks: highPriority)
            }

            if !medPriority.isEmpty {
                glassPriorityGroup(title: "MEDIUM PRIORITY", icon: "bolt.fill", color: .orange, tasks: medPriority)
            }

            if !lowPriority.isEmpty {
                glassPriorityGroup(title: "STANDARD & INBOX", icon: "tray.full.fill", color: DS.Theme.amber, tasks: lowPriority)
            }

            if !doneItems.isEmpty {
                Button {
                    withAnimation(PlutoSpring.smooth) { showCompleted.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .rotationEffect(.degrees(showCompleted ? 90 : 0))
                            .animation(PlutoSpring.smooth, value: showCompleted)

                        Text(showCompleted ? "Hide completed" : "\(doneItems.count) completed tasks")
                            .font(.system(size: 11, weight: .medium))
                            .contentTransition(.numericText())
                    }
                    .foregroundStyle(DS.Theme.textTertiary)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)

                if showCompleted {
                    VStack(spacing: 6) {
                        ForEach(doneItems, id: \.id) { item in
                            List1CardRow(
                                item: item,
                                isSelected: selection?.id == item.id,
                                selectionNamespace: selectionNamespace
                            ) {
                                selection = item
                            }
                        }
                    }
                }
            }
        }
    }

    private func glassPriorityGroup(title: String, icon: String, color: Color, tasks: [TodoItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color)

                Text(title)
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)

                Spacer()

                Text("\(tasks.count)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(color.opacity(0.12), in: Capsule())
            }
            .padding(.horizontal, 2)

            VStack(spacing: 6) {
                ForEach(tasks, id: \.id) { item in
                    List1CardRow(
                        item: item,
                        isSelected: selection?.id == item.id,
                        selectionNamespace: selectionNamespace
                    ) {
                        selection = item
                    }
                }
            }
        }
        .padding(10)
        .plutoGlass(.regular, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Design 3: List3FocusCardsView (Liquid Glass Focus Horizon Cards)

private struct List3FocusCardsView: View {

    let items: [TodoItem]
    let doneItems: [TodoItem]
    @Binding var selection: TodoItem?
    @Binding var showCompleted: Bool
    var selectionNamespace: Namespace.ID

    var body: some View {
        VStack(spacing: 8) {
            ForEach(items, id: \.id) { item in
                List1CardRow(
                    item: item,
                    isSelected: selection?.id == item.id,
                    selectionNamespace: selectionNamespace
                ) {
                    selection = item
                }
            }

            if !doneItems.isEmpty {
                Button {
                    withAnimation(PlutoSpring.smooth) { showCompleted.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .rotationEffect(.degrees(showCompleted ? 90 : 0))
                            .animation(PlutoSpring.smooth, value: showCompleted)

                        Text(showCompleted ? "Hide completed" : "\(doneItems.count) completed tasks")
                            .font(.system(size: 11, weight: .medium))
                            .contentTransition(.numericText())
                    }
                    .foregroundStyle(DS.Theme.textTertiary)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)

                if showCompleted {
                    VStack(spacing: 6) {
                        ForEach(doneItems, id: \.id) { item in
                            List1CardRow(
                                item: item,
                                isSelected: selection?.id == item.id,
                                selectionNamespace: selectionNamespace
                            ) {
                                selection = item
                            }
                        }
                    }
                }
            }
        }
    }
}
