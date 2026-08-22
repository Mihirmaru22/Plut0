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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: [SortDescriptor(\TodoItem.createdAt)], animation: .default)
    private var allItems: [TodoItem]

    @State private var transitionDirection: TransitionDirection = .forward
    @State private var lastModeIndex: Int = 0
    @State private var hoveredMode: TodoMode? = nil

    private var openItems: [TodoItem] {
        allItems.filter { !$0.isArchived && $0.parentID == nil && !$0.isCompleted }
    }

    private var scheduledItems: [TodoItem] {
        allItems.filter { !$0.isArchived && $0.parentID == nil && $0.startTime != nil }
    }

    private var mode: Binding<TodoMode> {
        Binding(
            get: { TodoMode(rawValue: modeString) ?? .plan },
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
            linearPillarSwitcher
                .padding(.horizontal, DS.Space.md)
                .padding(.vertical, 8)

            Divider()
                .opacity(0.12)

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
        .background(DS.Theme.surface)
        .onAppear {
            lastModeIndex = (TodoMode(rawValue: modeString) ?? .plan).index
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

    // MARK: - Linear Machined Segmented Switcher

    private var linearPillarSwitcher: some View {
        HStack(spacing: 3) {
            ForEach(TodoMode.allCases) { m in
                let isSelected = mode.wrappedValue == m
                let isHovered = hoveredMode == m

                Button {
                    guard mode.wrappedValue != m else { return }
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.80)) {
                        mode.wrappedValue = m
                    }
                    Haptics.impact(.light)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: m.icon)
                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? DS.Theme.amber : (isHovered ? Color.white : DS.Theme.textSecondary))

                        Text(m.rawValue)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? Color.white : (isHovered ? Color.white : DS.Theme.textSecondary))

                        // Count Badges
                        if m == .plan && !scheduledItems.isEmpty {
                            Text("\(scheduledItems.count)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(isSelected ? DS.Theme.amber : DS.Theme.textTertiary)
                                .padding(.horizontal, 4.5)
                                .padding(.vertical, 1)
                                .background(
                                    isSelected ? DS.Theme.amber.opacity(0.15) : Color.white.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 3)
                                )
                        } else if m == .list && !openItems.isEmpty {
                            Text("\(openItems.count)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(isSelected ? DS.Theme.amber : DS.Theme.textTertiary)
                                .padding(.horizontal, 4.5)
                                .padding(.vertical, 1)
                                .background(
                                    isSelected ? DS.Theme.amber.opacity(0.15) : Color.white.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 3)
                                )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5.5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                isSelected
                                    ? DS.Theme.cardSelected
                                    : (isHovered ? Color.white.opacity(0.05) : Color.clear)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(
                                isSelected ? Color.white.opacity(0.14) : Color.clear,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    hoveredMode = hovering ? m : nil
                }
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DS.Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DS.Theme.border, lineWidth: 1)
        )
    }
}
