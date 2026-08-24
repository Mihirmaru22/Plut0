import SwiftUI
import SwiftData

// MARK: - TodoMode (sub-pillar toggle)

/// The three sub-pillars of the Today section:
/// - **plan**: time-blocked day planner on a vertical timeline (`MacDayPlannerColumn`)
/// - **list**: GTD-style task queues and bento cards (`MacTodoListColumn`)
/// - **time**: Focus timer and flow studio (`MacTimeView`)
enum TodoMode: String, CaseIterable, Identifiable {
    case plan = "Plan"
    case list = "List"
    case time = "Time"

    var id: String { rawValue }

    var index: Int {
        switch self {
        case .plan: return 0
        case .list: return 1
        case .time: return 2
        }
    }

    var icon: String {
        switch self {
        case .plan: return "calendar.day.timeline.left"
        case .list: return "checklist.checked"
        case .time: return "timer.circle.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .plan: return "Day Planner"
        case .list: return "Tasks & Queues"
        case .time: return "Focus Studio"
        }
    }
}

// MARK: - Transition Direction

private enum TransitionDirection {
    case forward
    case backward
}

// MARK: - MacTodoContentColumn

/// Middle column of the Mac layout for the Today (Todo) section.
/// Styled with Linear precision dark obsidian theme and smooth direction-aware transitions.
struct MacTodoContentColumn: View {

    @Binding var selection: TodoItem?
    @AppStorage("mac_today_submode") private var modeString: String = "Plan"
    @AppStorage("mac_today_enable_plan") private var enablePlan: Bool = true
    @AppStorage("mac_today_enable_list") private var enableList: Bool = true
    @AppStorage("mac_today_enable_time") private var enableTime: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: [SortDescriptor(\TodoItem.createdAt)], animation: .default)
    private var allItems: [TodoItem]

    @State private var activeMode: TodoMode = .plan
    @State private var transitionDirection: TransitionDirection = .forward
    @State private var lastModeIndex: Int = 0
    @State private var hoveredMode: TodoMode? = nil
    @Namespace private var pillarNamespace

    private var visibleModes: [TodoMode] {
        var modes: [TodoMode] = []
        if enablePlan { modes.append(.plan) }
        if enableList { modes.append(.list) }
        if enableTime { modes.append(.time) }
        return modes.isEmpty ? [.plan] : modes
    }

    private var openItems: [TodoItem] {
        allItems.filter { !$0.isArchived && $0.parentID == nil && !$0.isCompleted }
    }

    private var scheduledItems: [TodoItem] {
        allItems.filter { !$0.isArchived && $0.parentID == nil && $0.startTime != nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            // macOS HIG Liquid Glass Tabbed Switcher
            if visibleModes.count > 1 {
                linearPillarSwitcher
                    .padding(.horizontal, DS.Space.md)
                    .padding(.vertical, 8)

                Divider()
                    .opacity(0.12)
            }

            // Direction-Aware Inset Viewport Pane (Plan ↔ List ↔ Time)
            ZStack {
                if activeMode == .plan {
                    MacDayPlannerColumn(selection: $selection)
                        .transition(contentTransition)
                } else if activeMode == .list {
                    MacTodoListColumn(selection: $selection)
                        .transition(contentTransition)
                } else {
                    MacTimeView()
                        .transition(contentTransition)
                }
            }
            .clipped()
            .animation(
                reduceMotion ? .linear(duration: 0.12) : PlutoSpring.snappy,
                value: activeMode
            )
        }
        .navigationTitle("Today")
        // Navigation owns the structural material; interactive task controls
        // use native Liquid Glass individually rather than stacking a legacy
        // simulated blur underneath the entire workspace.
        .background(Color.clear)
        .onAppear {
            let initial = TodoMode(rawValue: modeString) ?? .plan
            activeMode = visibleModes.contains(initial) ? initial : (visibleModes.first ?? .plan)
            lastModeIndex = activeMode.index
        }
        .onChange(of: enablePlan) { _, _ in ensureValidMode() }
        .onChange(of: enableList) { _, _ in ensureValidMode() }
        .onChange(of: enableTime) { _, _ in ensureValidMode() }
        .onChange(of: modeString) { _, newString in
            if let target = TodoMode(rawValue: newString), target != activeMode {
                withAnimation(PlutoSpring.snappy) {
                    activeMode = target
                }
            }
        }
    }

    private func ensureValidMode() {
        if !visibleModes.contains(activeMode), let first = visibleModes.first {
            selectMode(first)
        }
    }

    private func selectMode(_ newMode: TodoMode) {
        guard activeMode != newMode else { return }
        let newIndex = newMode.index
        transitionDirection = newIndex >= lastModeIndex ? .forward : .backward
        lastModeIndex = newIndex
        withAnimation(PlutoSpring.snappy) {
            activeMode = newMode
        }
        modeString = newMode.rawValue
        Haptics.selection()
    }

    // MARK: - Spatial Content Transition

    private var contentTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        switch transitionDirection {
        case .forward:
            return .asymmetric(
                insertion: .offset(x: 18).combined(with: .opacity),
                removal: .offset(x: -18).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .offset(x: -18).combined(with: .opacity),
                removal: .offset(x: 18).combined(with: .opacity)
            )
        }
    }

    // MARK: - Apple HIG Liquid Glass Segmented Switcher
    
    private var linearPillarSwitcher: some View {
        PlutoGlassSegmentedPicker(
            selection: Binding(
                get: { activeMode },
                set: { selectMode($0) }
            ),
            items: visibleModes,
            namespace: pillarNamespace
        ) { mode, isSelected in
            HStack(spacing: 5) {
                Image(systemName: mode.icon)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .symbolEffect(.bounce, value: isSelected)
                Text(mode.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                // Count Badges
                if mode == .plan && !scheduledItems.isEmpty {
                    Text("\(scheduledItems.count)")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.08), in: Capsule())
                } else if mode == .list && !openItems.isEmpty {
                    Text("\(openItems.count)")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.08), in: Capsule())
                }
            }
            .foregroundStyle(isSelected ? Color.white : (hoveredMode == mode ? Color.white.opacity(0.9) : Color.white.opacity(0.55)))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5.5)
            .contentShape(Capsule())
            .help(tabTooltip(for: mode))
            .onHover { hovering in
                hoveredMode = hovering ? mode : nil
            }
        }
    }

    private func tabTooltip(for mode: TodoMode) -> String {
        switch mode {
        case .plan: return "Day Planner — Visual timeline & time-blocking schedule (⌘1)"
        case .list: return "Task Queues — Prioritized GTD lists and inbox (⌘2)"
        case .time: return "Focus Studio — Flow timer, stopwatch, and sound mixer (⌘3)"
        }
    }
}
