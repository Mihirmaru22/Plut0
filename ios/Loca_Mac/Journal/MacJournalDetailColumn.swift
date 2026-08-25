import SwiftUI

// MARK: - MacJournalDetailColumn

/// Detail column for the Journal section.
///
/// Supports:
/// - `Today's log`: Daylight Flow Routines & Sleep Tracker (`MacJournalCollect`)
/// - `Notes`: Full-Width 1:1 Apple Journal Canvas with Floating Capsule, Photos, Voice Memo Studio (`AppleJournalEditorCanvas`)
/// - `Analyse`: Monthly Consistency & Correlations (`MacJournalAnalyse`)
struct MacJournalDetailColumn: View {

    @Binding var selectedRow: JournalRow?
    @Binding var selectedNote: JournalNote?

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var showDatePicker = false

    var body: some View {
        VStack(spacing: 0) {
            if selectedRow != .notes {
                journalHeader
                Divider()
            }

            switch selectedRow ?? .todaysLog {
            case .notes:
                if let note = selectedNote {
                    AppleJournalEditorCanvas(note: note)
                } else {
                    ContentUnavailableView {
                        Label("No Entry Selected", systemImage: "square.and.pencil")
                    } description: {
                        Text("Choose an entry from the list or click New Entry.")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DS.Theme.sidebar)
                }
            case .analyse:
                MacJournalAnalyse(selectedDate: selectedDate)
            case .todaysLog:
                MacJournalCollect(selectedDate: selectedDate)
            }
        }
    }

    // MARK: - Header (Used for Today's log and Analyse)

    private var journalHeader: some View {
        HStack(alignment: .center, spacing: DS.Space.lg) {
            VStack(alignment: .leading, spacing: 4) {
                Text(headerTitle)
                    .font(DS.Text.title)
                    .fontWeight(.bold)
                    .foregroundStyle(DS.Color.textPrimary)

                if selectedRow != .analyse {
                    dateNavigationRow
                } else {
                    Text("Monthly Insights & Trends")
                        .font(DS.Text.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }

            Spacer(minLength: DS.Space.md)
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, DS.Space.md)
        .background(DS.Theme.sidebar)
    }

    // MARK: - Date Navigation Row

    private var dateNavigationRow: some View {
        HStack(spacing: 6) {
            // Previous day
            Button {
                withAnimation(DS.Motion.settle) {
                    if let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) {
                        selectedDate = Calendar.current.startOfDay(for: prev)
                    }
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.caption2.weight(.bold))
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
                    .foregroundStyle(DS.Color.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Previous day")

            // Date Picker trigger button
            Button {
                showDatePicker = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                    Text(dateFormattedLabel)
                        .font(DS.Text.caption)
                        .foregroundStyle(DS.Color.textPrimary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(DS.Color.surfaceRecessed, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showDatePicker) {
                JournalDatePickerPopover(selectedDate: $selectedDate)
            }
            .help("Choose a date")

            // Next day
            Button {
                withAnimation(DS.Motion.settle) {
                    if let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) {
                        selectedDate = Calendar.current.startOfDay(for: next)
                    }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
                    .foregroundStyle(DS.Color.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Next day")

            // "Jump to Today" shortcut when viewing historical/future date
            if !Calendar.current.isDateInToday(selectedDate) {
                Button {
                    withAnimation(DS.Motion.settle) {
                        selectedDate = Calendar.current.startOfDay(for: .now)
                    }
                } label: {
                    Text("Today")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .help("Jump to today")
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private var headerTitle: String {
        switch selectedRow {
        case .analyse:   return "Analyse"
        case .notes:     return "Notes"
        case .todaysLog: return "Today's log"
        default:         return "Journal"
        }
    }

    private var dateFormattedLabel: String {
        let cal = Calendar.current
        let f = DateFormatter()
        f.dateFormat = "EEEE · MMMM d"
        if cal.isDateInToday(selectedDate) {
            return "Today, \(f.string(from: selectedDate))"
        } else if cal.isDateInYesterday(selectedDate) {
            return "Yesterday, \(f.string(from: selectedDate))"
        } else {
            return f.string(from: selectedDate)
        }
    }
}

// MARK: - JournalDatePickerPopover

private struct JournalDatePickerPopover: View {

    @Binding var selectedDate: Date

    var body: some View {
        VStack(spacing: DS.Space.sm) {
            DatePicker(
                "Journal Date",
                selection: $selectedDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .labelsHidden()

            HStack {
                Button("Today") {
                    selectedDate = Calendar.current.startOfDay(for: .now)
                }
                .buttonStyle(.borderless)
                .font(DS.Text.caption)

                Spacer()

                Button("Yesterday") {
                    if let y = Calendar.current.date(byAdding: .day, value: -1, to: .now) {
                        selectedDate = Calendar.current.startOfDay(for: y)
                    }
                }
                .buttonStyle(.borderless)
                .font(DS.Text.caption)
            }
            .padding(.horizontal, 4)
        }
        .padding(DS.Space.md)
        .frame(width: 280)
    }
}
