//
//  PlutoQuickActionHUD.swift
//  PLUTO
//
//  Global Floating Quick-Log & Task HUD overlay.
//  Accessible system-wide via ⌃⌥P hotkey from any application.
//

import SwiftUI
import SwiftData
import WidgetKit

// MARK: - PlutoQuickActionHUD

struct PlutoQuickActionHUD: View {

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<HabitBoard> { $0.archivedAt == nil }, sort: \HabitBoard.createdAt)
    private var habits: [HabitBoard]

    @State private var taskText: String = ""
    @State private var selectedTab: HUDTab = .tasks
    @State private var showFeedback: String? = nil

    enum HUDTab: String, CaseIterable {
        case tasks = "Task & Focus"
        case habits = "Habit Check-In"
        case journal = "Quick Reflection"
    }

    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {

            // HUD Top Bar
            HStack(spacing: 8) {
                Image(systemName: "circle.grid.cross.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.accentColor)

                Text("Pluto Quick HUD")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(DS.Color.textPrimary)

                Spacer()

                // Keyboard indicator
                HStack(spacing: 4) {
                    Text("⌃⌥P")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.Color.textTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(DS.Color.surfaceRecessed, in: RoundedRectangle(cornerRadius: 3))

                    Text("esc to close")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DS.Color.textTertiary)
                }

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plutoGlassCircle)
            }
            .padding(.horizontal, DS.Space.lg)
            .padding(.vertical, 12)
            .background(DS.Color.surface.opacity(0.6))

            Divider().opacity(0.2)

            // Main Input Field
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.accentColor)

                TextField("Quickly add a task or type and press Return...", text: $taskText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DS.Color.textPrimary)
                    .onSubmit {
                        submitQuickTask()
                    }

                if !taskText.isEmpty {
                    Button {
                        submitQuickTask()
                    } label: {
                        Text("Add ↵")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(.plutoGlassProminent(tint: Color.accentColor))
                }
            }
            .padding(.horizontal, DS.Space.lg)
            .padding(.vertical, 14)
            .background(DS.Color.surfaceRecessed.opacity(0.6))

            Divider().opacity(0.2)

            // Quick Habit Check-ins
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("One-Tap Habit Logging")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DS.Color.textTertiary)

                    Spacer()

                    if let feedback = showFeedback {
                        Text(feedback)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(DS.Color.success)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, DS.Space.lg)
                .padding(.top, 10)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(habits.prefix(6)) { habit in
                            Button {
                                quickLogHabit(habit)
                            } label: {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(ColorPalette[habit.colorIndex])
                                        .frame(width: 6, height: 6)

                                    Text(habit.name)
                                        .font(.system(size: 12, weight: .semibold))

                                    if habit.currentStreak > 0 {
                                        Text("\(habit.currentStreak)d")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(DS.Color.streak)
                                    }
                                }
                            }
                            .buttonStyle(.plutoGlass)
                        }
                    }
                    .padding(.horizontal, DS.Space.lg)
                    .padding(.bottom, 12)
                }
            }

            Divider().opacity(0.2)

            // Bottom Quick Actions Dock
            HStack(spacing: 12) {
                Button {
                    NotificationCenter.default.post(
                        name: .locaDeepLink,
                        object: PlutoNotificationManager.DeepLinkPayload(section: .today, habitID: nil, taskID: nil, date: nil)
                    )
                    NSApp.activate(ignoringOtherApps: true)
                    onClose()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                        Text("Start 25m Focus")
                    }
                    .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plutoGlass)

                Spacer()

                Button {
                    NotificationCenter.default.post(
                        name: .locaDeepLink,
                        object: PlutoNotificationManager.DeepLinkPayload(section: .today, habitID: nil, taskID: nil, date: nil)
                    )
                    NSApp.activate(ignoringOtherApps: true)
                    onClose()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sun.max.fill")
                        Text("Open Today")
                    }
                    .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plutoGlass)
            }
            .padding(.horizontal, DS.Space.lg)
            .padding(.vertical, 10)
            .background(DS.Color.surface.opacity(0.6))
        }
        .frame(width: 480)
        .plutoGlass(.regular, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.40), radius: 24, x: 0, y: 12)
    }

    // MARK: - Actions

    private func submitQuickTask() {
        let trimmed = taskText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let item = TodoItem(
            title: trimmed,
            notes: nil,
            dueDate: Calendar.current.startOfDay(for: .now),
            startTime: nil,
            durationMinutes: 30
        )
        modelContext.insert(item)
        try? modelContext.save()

        taskText = ""
        showFeedback = "Task Added!"
        Haptics.impact(.rigid)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showFeedback = nil
            onClose()
        }
    }

    private func quickLogHabit(_ habit: HabitBoard) {
        do {
            try CheckInWriter.insert(
                value: habit.effectiveTarget,
                timestamp: .now,
                note: "Quick HUD Check-in",
                board: habit,
                context: modelContext
            )
            WidgetCenter.shared.reloadAllTimelines()
            showFeedback = "Logged \(habit.name)!"
            Haptics.impact(.rigid)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showFeedback = nil
            }
        } catch {
            print("Failed to quick-log habit: \(error)")
        }
    }
}
