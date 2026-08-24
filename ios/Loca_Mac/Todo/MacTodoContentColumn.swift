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

    private var mode: Binding<TodoMode> {
        Binding(
            get: {
                let current = TodoMode(rawValue: modeString) ?? .plan
                if visibleModes.contains(current) {
                    return current
                }
                return visibleModes.first ?? .plan
            },
            set: { newMode in
                let newIndex = newMode.index
                transitionDirection = newIndex >= lastModeIndex ? .forward : .backward
                lastModeIndex = newIndex
                modeString = newMode.rawValue
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Linear Machined Segmented Control
            if visibleModes.count > 1 {
                linearPillarSwitcher
                    .padding(.horizontal, DS.Space.md)
                    .padding(.vertical, 8)

                Divider()
                    .opacity(0.12)
            }

            // Direction-Aware Viewport (Plan ↔ List ↔ Time)
            ZStack {
                if mode.wrappedValue == .plan {
                    MacDayPlannerColumn(selection: $selection)
                        .transition(contentTransition)
                } else if mode.wrappedValue == .list {
                    MacTodoListColumn(selection: $selection)
                        .transition(contentTransition)
                } else {
                    MacTimeView()
                        .transition(contentTransition)
                }
            }
            .clipped()
            .animation(
                reduceMotion ? .linear(duration: 0.12) : .spring(response: 0.28, dampingFraction: 0.82),
                value: mode.wrappedValue
            )
        }
        .navigationTitle("Today")
        .background(.ultraThinMaterial)
        .background(DS.Theme.surface)
        .onAppear {
            ensureValidMode()
            lastModeIndex = (TodoMode(rawValue: modeString) ?? .plan).index
        }
        .onChange(of: enablePlan) { _, _ in ensureValidMode() }
        .onChange(of: enableList) { _, _ in ensureValidMode() }
        .onChange(of: enableTime) { _, _ in ensureValidMode() }
    }

    private func ensureValidMode() {
        let current = TodoMode(rawValue: modeString) ?? .plan
        if !visibleModes.contains(current), let first = visibleModes.first {
            modeString = first.rawValue
        }
    }

    // MARK: - Spatial Content Transition

    private var contentTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        switch transitionDirection {
        case .forward:
            return .asymmetric(
                insertion: .offset(x: 20).combined(with: .opacity),
                removal: .offset(x: -20).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .offset(x: -20).combined(with: .opacity),
                removal: .offset(x: 20).combined(with: .opacity)
            )
        }
    }

    // MARK: - Apple HIG Liquid Glass Segmented Switcher

    private var linearPillarSwitcher: some View {
        HStack(spacing: 4) {
            ForEach(visibleModes) { m in
                let isSelected = mode.wrappedValue == m
                let isHovered = hoveredMode == m

                Button {
                    guard mode.wrappedValue != m else { return }
                    withAnimation(PlutoSpring.snappy) {
                        mode.wrappedValue = m
                    }
                    Haptics.impact(.light)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: m.icon)
                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                            .symbolEffect(.bounce, value: isSelected)

                        Text(m.rawValue)
                            .font(.system(size: 12, weight: isSelected ? .bold : .medium))

                        // Count Badges
                        if m == .plan && !scheduledItems.isEmpty {
                            Text("\(scheduledItems.count)")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(
                                    isSelected ? Color.black.opacity(0.12) : Color.white.opacity(0.06),
                                    in: Capsule()
                                )
                        } else if m == .list && !openItems.isEmpty {
                            Text("\(openItems.count)")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(
                                    isSelected ? Color.black.opacity(0.12) : Color.white.opacity(0.06),
                                    in: Capsule()
                                )
                        }
                    }
                    .foregroundStyle(isSelected ? Color.white : (isHovered ? Color.white.opacity(0.9) : DS.Theme.textSecondary))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5.5)
                    .background {
                        if isSelected {
                            LiquidGlassLensPill(namespace: pillarNamespace, id: "todayPillarSelectedPill")
                        } else if isHovered {
                            Capsule()
                                .fill(Color.white.opacity(0.04))
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    hoveredMode = hovering ? m : nil
                }
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(DS.Theme.card)
        )
        .overlay(
            Capsule()
                .stroke(DS.Theme.border, lineWidth: 1)
        )
    }
}
