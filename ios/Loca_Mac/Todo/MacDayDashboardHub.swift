import SwiftUI
import SwiftData
import Combine

// MARK: - MacDayDashboardHub (Linear Precision Bento Dashboard Hub)

/// Shown in the right detail column of Plan mode when no specific task is selected.
/// Styled with Linear / Raycast precision bento tiles, machined borders, and vibrant KPI badges.
struct MacDayDashboardHub: View {

    @Binding var selectedItem: TodoItem?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\TodoItem.startTime)]) private var allItems: [TodoItem]
    @Query(filter: #Predicate<HabitBoard> { $0.archivedAt == nil }) private var allHabits: [HabitBoard]

    @State private var focusTimeRemaining: Int = 25 * 60
    @State private var isTimerRunning: Bool = false
    @State private var timerEndTimestamp: Date? = nil
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var today: Date { Calendar.current.startOfDay(for: .now) }

    private var activeTasks: [TodoItem] {
        allItems.filter { !$0.isArchived && $0.parentID == nil }
    }

    private var scheduledToday: [TodoItem] {
        activeTasks.filter {
            guard let s = $0.startTime else { return false }
            return Calendar.current.isDate(s, inSameDayAs: today)
        }
    }

    private var unscheduledTasks: [TodoItem] {
        activeTasks.filter { $0.startTime == nil && !$0.isCompleted }
    }

    private var completedToday: [TodoItem] {
        scheduledToday.filter(\.isCompleted)
    }

    private var totalPlannedMinutes: Int {
        scheduledToday.reduce(0) { total, item in
            let dur = item.durationMinutes > 0 ? item.durationMinutes : 30
            return total + dur
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.lg) {

                // 1. Hero Date & Architecture Bento
                heroDayBanner

                // 2. Metrics & Velocity KPI Row
                metricsKpiGrid

                // 3. Dual Hub: Unscheduled Backlog & Active Focus Sprint
                HStack(alignment: .top, spacing: DS.Space.md) {
                    unscheduledBacklogCard
                        .frame(maxWidth: .infinity)

                    focusSprintWidget
                        .frame(width: 270)
                }

                // 4. Today's Keystone Habits Strip
                todayHabitsStrip

                Spacer(minLength: DS.Space.xl)
            }
            .padding(DS.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Theme.canvas)
        .onReceive(timer) { _ in
            guard isTimerRunning, let end = timerEndTimestamp else { return }
            let remaining = Int(ceil(end.timeIntervalSinceNow))
            if remaining <= 0 {
                focusTimeRemaining = 0
                isTimerRunning = false
                timerEndTimestamp = nil
                Haptics.notify(.success)
            } else {
                focusTimeRemaining = remaining
            }
        }
    }

    // MARK: - 1. Hero Day Banner

    private var heroDayBanner: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle().fill(DS.Theme.emerald).frame(width: 6, height: 6)
                    Text("DAY ARCHITECTURE // ACTIVE SESSION")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.Theme.emerald)
                        .tracking(0.8)
                }

                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.white)

                Text("\"Action is the foundational key to all success.\"")
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundStyle(DS.Theme.textSecondary)
            }

            Spacer()

            // Quick New Block Button
            Button {
                createNewBlock()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Plan Block")
                        .font(.system(size: 11.5, weight: .bold))
                }
                .foregroundStyle(Color.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(DS.Theme.amber, in: RoundedRectangle(cornerRadius: 6))
                .shadow(color: DS.Theme.amber.opacity(0.35), radius: 6, x: 0, y: 1)
            }
            .buttonStyle(.plain)
        }
        .padding(DS.Space.lg)
        .machinedCard(cornerRadius: 10, accent: DS.Theme.amber)
    }

    // MARK: - 2. Metrics KPI Grid

    private var metricsKpiGrid: some View {
        HStack(spacing: DS.Space.md) {
            kpiCard(
                title: "PLANNED TIME",
                value: String(format: "%.1fh", Double(totalPlannedMinutes) / 60.0),
                subtitle: "\(scheduledToday.count) schedule blocks",
                icon: "clock.fill",
                accent: DS.Theme.cyan
            )

            kpiCard(
                title: "COMPLETION",
                value: "\(completedToday.count)/\(scheduledToday.count)",
                subtitle: scheduledToday.isEmpty ? "0% done" : "\(Int((Double(completedToday.count) / Double(scheduledToday.count)) * 100))% velocity",
                icon: "checkmark.circle.fill",
                accent: DS.Theme.emerald
            )

            kpiCard(
                title: "BACKLOG",
                value: "\(unscheduledTasks.count)",
                subtitle: "Unscheduled tasks",
                icon: "tray.full.fill",
                accent: DS.Theme.amber
            )
        }
    }

    private func kpiCard(title: String, value: String, subtitle: String, icon: String, accent: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(accent)
                .frame(width: 32, height: 32)
                .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.Theme.textTertiary)
                    .tracking(0.5)

                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)

                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(DS.Theme.textSecondary)
            }
            Spacer()
        }
        .padding(DS.Space.md)
        .machinedCard(cornerRadius: 8, accent: accent)
    }

    // MARK: - 3. Unscheduled Backlog Card

    private var unscheduledBacklogCard: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            HStack {
                Text("UNSCHEDULED BACKLOG")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.Theme.textTertiary)
                    .tracking(0.6)

                Spacer()

                Text("\(unscheduledTasks.count) tasks")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DS.Theme.textSecondary)
            }

            if unscheduledTasks.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(DS.Theme.emerald.opacity(0.8))
                    Text("All tasks scheduled or done!")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Space.xl)
            } else {
                VStack(spacing: 5) {
                    ForEach(unscheduledTasks.prefix(5)) { task in
                        Button {
                            selectedItem = task
                            Haptics.impact(.light)
                        } label: {
                            HStack(spacing: 8) {
                                Circle().stroke(Color.white.opacity(0.20), lineWidth: 1.2).frame(width: 10, height: 10)
                                Text(task.title.isEmpty ? "Untitled Task" : task.title)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.white.opacity(0.9))
                                    .lineLimit(1)
                                Spacer()
                                Text("Schedule →")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(DS.Theme.cyan)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6.5)
                            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(DS.Space.lg)
        .machinedCard(cornerRadius: 10)
    }

    // MARK: - 4. Active Focus Sprint Widget

    private var focusSprintWidget: some View {
        VStack(spacing: DS.Space.md) {
            HStack {
                Text("FOCUS SPRINT")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.Theme.textTertiary)
                    .tracking(0.6)
                Spacer()
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(DS.Theme.amber)
            }

            // Timer Clock Face
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 5)
                    .frame(width: 86, height: 86)

                Circle()
                    .trim(from: 0, to: Double(focusTimeRemaining) / (25 * 60))
                    .stroke(DS.Theme.amber, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 86, height: 86)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text(formattedTime(focusTimeRemaining))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white)
                    Text(isTimerRunning ? "FOCUSING" : "PAUSED")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.Theme.textTertiary)
                }
            }

            // Controls
            HStack(spacing: 10) {
                Button {
                    if isTimerRunning {
                        isTimerRunning = false
                        timerEndTimestamp = nil
                    } else {
                        isTimerRunning = true
                        timerEndTimestamp = Date().addingTimeInterval(Double(focusTimeRemaining))
                    }
                    Haptics.impact(.light)
                } label: {
                    Image(systemName: isTimerRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(width: 28, height: 28)
                        .background(DS.Theme.amber, in: Circle())
                }
                .buttonStyle(.plain)

                Button {
                    focusTimeRemaining = 25 * 60
                    isTimerRunning = false
                    timerEndTimestamp = nil
                    Haptics.impact(.light)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Theme.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DS.Space.lg)
        .machinedCard(cornerRadius: 10, accent: DS.Theme.amber)
    }

    // MARK: - 5. Today's Keystone Habits Strip

    private var todayHabitsStrip: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            HStack {
                Text("KEYSTONE HABITS")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.Theme.textTertiary)
                    .tracking(0.6)
                Spacer()
                Text("\(allHabits.count) active")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(DS.Theme.textSecondary)
            }

            if allHabits.isEmpty {
                Text("No habits configured yet.")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Theme.textTertiary)
            } else {
                HStack(spacing: 10) {
                    ForEach(allHabits.prefix(4)) { habit in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(ColorPalette[habit.colorIndex])
                                .frame(width: 8, height: 8)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(habit.name)
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundStyle(Color.white)
                                    .lineLimit(1)
                                Text("\(habit.currentStreak)d streak")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(DS.Theme.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(9)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.06), lineWidth: 1))
                    }
                }
            }
        }
        .padding(DS.Space.lg)
        .machinedCard(cornerRadius: 10)
    }

    // Helpers
    private func formattedTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func createNewBlock() {
        let now = Date.now
        let item = TodoItem(title: "New Block", startTime: now, durationMinutes: 30)
        modelContext.insert(item)
        try? modelContext.save()
        selectedItem = item
    }
}
