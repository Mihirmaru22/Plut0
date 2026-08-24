import SwiftUI
import SwiftData

// MARK: - JournalRow

/// The sub-category modes shown in the Journal middle column.
enum JournalRow: String, CaseIterable, Identifiable {
    case todaysLog = "Today's Log"
    case notes     = "Notes"
    case analyse   = "Analyse"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .todaysLog: return "book.pages"
        case .notes:     return "square.and.pencil"
        case .analyse:   return "chart.xyaxis.line"
        }
    }
}

// MARK: - MacJournalContentColumn

/// Middle column for the Journal section with sub-category segmented picker
/// and unified 3-pane NavigationSplitView flow.
struct MacJournalContentColumn: View {

    @Binding var selectedRow: JournalRow?
    @Binding var selectedNote: JournalNote?

    @Query(filter: #Predicate<HabitBoard> { $0.habitKindRaw == 1 },
           sort: \HabitBoard.createdAt)
    private var habitCandidates: [HabitBoard]

    @Query(sort: [SortDescriptor(\JournalNote.date, order: .reverse)])
    private var allJournalNotes: [JournalNote]

    @Namespace private var journalPickerNamespace
    
    private var dailyRoutines: [HabitBoard] {
        habitCandidates.filter { $0.archivedAt == nil }
    }

    private var todayPendingDailyCount: Int {
        let cal = Calendar.current
        return dailyRoutines.filter { habit in
            let logs = habit.activeLogs.filter { cal.isDateInToday($0.timestamp) }
            return logs.reduce(0.0) { $0 + $1.value } < habit.effectiveTarget
        }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top Sub-Category Segmented Switcher (Matching Today Plan/List)
            PlutoGlassSegmentedPicker(
                selection: Binding(
                    get: { selectedRow ?? .todaysLog },
                    set: { selectedRow = $0 }
                ),
                items: JournalRow.allCases,
                namespace: journalPickerNamespace
            ) { row, isSelected in
                HStack(spacing: 5) {
                    Image(systemName: row.icon)
                        .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                        .symbolEffect(.bounce, value: isSelected)
                    Text(row.rawValue)
                        .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                }
                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.60))
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, DS.Space.sm)

            Divider()

            // Dynamic Content Based on Selected Sub-Category
            switch selectedRow ?? .todaysLog {
            case .notes:
                AppleJournalEntriesList(selectedNote: $selectedNote)
            case .todaysLog:
                JournalRoutinesMiddleList(routines: dailyRoutines)
            case .analyse:
                JournalAnalyseMiddleList()
            }
        }
        .navigationTitle("Journal")
    }
}

// MARK: - JournalRoutinesMiddleList (Middle column for Today's log)

private struct JournalRoutinesMiddleList: View {
    let routines: [HabitBoard]
    @Environment(\.modelContext) private var modelContext
    @State private var newRoutineName = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(routines.count) Daylight Flow Routines")
                    .font(DS.Text.caption)
                    .foregroundStyle(DS.Color.textTertiary)
                Spacer()
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(routines, id: \.id) { routine in
                        let isDone = isRoutineDoneToday(routine)
                        HStack(spacing: 10) {
                            Circle()
                                .fill(ColorPalette[routine.colorIndex])
                                .frame(width: 6, height: 6)

                            Text(routine.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(isDone ? DS.Color.textSecondary : DS.Color.textPrimary)

                            Spacer()

                            if routine.currentStreak > 0 {
                                Text("🔥 \(routine.currentStreak)d")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.orange)
                            }

                            // Check Circle
                            ZStack {
                                Circle()
                                    .stroke(ColorPalette[routine.colorIndex].opacity(0.3), lineWidth: 2)
                                    .frame(width: 20, height: 20)
                                if isDone {
                                    Circle()
                                        .fill(ColorPalette[routine.colorIndex])
                                        .frame(width: 14, height: 14)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .contentShape(Circle())
                            .highPriorityGesture(TapGesture().onEnded {
                                toggleRoutine(routine)
                            })
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: 8))
                    }

                    // Quick Add Field
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(DS.Color.textTertiary)

                        TextField("Add flow routine…", text: $newRoutineName)
                            .font(.system(size: 12))
                            .textFieldStyle(.plain)
                            .focused($isInputFocused)
                            .onSubmit {
                                addRoutine()
                            }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(DS.Color.surfaceRecessed, in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(10)
            }
        }
    }

    private func isRoutineDoneToday(_ routine: HabitBoard) -> Bool {
        let cal = Calendar.current
        let logs = (routine.logs ?? []).filter { $0.archivedAt == nil && cal.isDateInToday($0.timestamp) }
        return logs.reduce(0.0) { $0 + $1.value } >= routine.effectiveTarget
    }

    private func toggleRoutine(_ routine: HabitBoard) {
        do {
            try CheckInWriter.toggleBinary(board: routine, context: modelContext)
            PlutoTelemetryEngine.shared.trackHabitCheckIn(board: routine, value: routine.effectiveTarget, isDone: isRoutineDoneToday(routine))
            Haptics.impact(.rigid)
        } catch {}
    }

    private func addRoutine() {
        let trimmed = newRoutineName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let routine = HabitBoard(name: trimmed)
        routine.habitKind = .daily
        modelContext.insert(routine)
        try? modelContext.save()
        newRoutineName = ""
        isInputFocused = false
        Haptics.impact(.light)
    }
}

// MARK: - JournalAnalyseMiddleList (Middle column for Analyse)

private struct JournalAnalyseMiddleList: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Horizon Insights")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DS.Color.textPrimary)

            Text("Review your daylight routine completion pacing, sleep quality scores, and habit correlations across the last 30 days.")
                .font(DS.Text.caption)
                .foregroundStyle(DS.Color.textSecondary)
                .lineSpacing(3)

            Spacer()
        }
        .padding(14)
    }
}
