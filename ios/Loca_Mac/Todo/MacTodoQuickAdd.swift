import SwiftUI
import SwiftData
import Foundation

// MARK: - MacTodoQuickAdd   (T1 + T11 — natural-language quick-add bar)

/// Single text field pinned at the top of the List sub-pillar.
///
/// As the user types, `TodoNLParser` parses the raw string and shows
/// live token chips (date, time, duration, priority) below the field.
/// Pressing Return creates the task; Escape clears the field.
///
/// Examples (from T11 spec):
///   "Gym tomorrow at 7am for 1h !!" → title=Gym, date=tomorrow, start=07:00, duration=60, priority=2
///   "Call dentist tonight"          → title=Call dentist, date=today, start=19:00
///   "Buy milk"                      → title=Buy milk, no tokens
struct MacTodoQuickAdd: View {

    @Environment(\.modelContext) private var modelContext
    @State private var text: String = ""
    @FocusState private var focused: Bool

    private var preview: LocaNeuralEngine.SmartTaskResult { LocaNeuralEngine.parseSmartTask(text) }

    private var hasTokens: Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return preview.dueDate != nil
            || preview.startTime != nil
            || preview.durationMinutes > 0
            || preview.priority > 0
            || !preview.detectedTags.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Liquid Glass Input Row
            HStack(spacing: DS.Space.sm) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(focused ? DS.Theme.amber : DS.Theme.textTertiary)
                    .font(.system(size: 15))
                    .rotationEffect(.degrees(focused ? 90 : 0))
                    .animation(PlutoSpring.smooth, value: focused)

                TextField("Add a task (e.g. Design review tomorrow at 10am for 1h #work !!)…", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .regular))
                    .focused($focused)
                    .onSubmit(submit)
                    .onExitCommand { text = ""; focused = false }

                if !text.isEmpty {
                    Button {
                        submit()
                    } label: {
                        HStack(spacing: 3) {
                            Text("Add")
                                .font(.system(size: 11, weight: .bold))
                            Image(systemName: "return")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(DS.Theme.amber, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .plutoGlass(focused ? .interactive : .regular, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(focused ? DS.Theme.amber.opacity(0.6) : Color.clear, lineWidth: 1)
            )
            .onTapGesture { focused = true }

            // Live token preview in frosted glass chips
            if hasTokens {
                HStack(spacing: 6) {
                    if let date = preview.dueDate {
                        TokenChip(icon: "calendar", label: relativeDateLabel(date), color: .accentColor)
                    }
                    if let time = preview.startTime {
                        TokenChip(icon: "clock.fill", label: time.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute()), color: .teal)
                    }
                    if preview.durationMinutes > 0 {
                        TokenChip(icon: "timer", label: durationLabel(preview.durationMinutes), color: .orange)
                    }
                    if preview.priority > 0 {
                        TokenChip(icon: "flag.fill", label: priorityLabel(preview.priority), color: priorityColor(preview.priority))
                    }
                    ForEach(preview.detectedTags, id: \.self) { tag in
                        TokenChip(icon: "tag.fill", label: tag, color: Color(red: 0.68, green: 0.45, blue: 0.98))
                    }
                    Spacer()
                }
                .padding(.horizontal, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: hasTokens)
        .onReceive(NotificationCenter.default.publisher(for: .locaFocusQuickAdd)) { _ in
            focused = true
        }
    }

    // MARK: - Submit

    private func submit() {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        let r = LocaNeuralEngine.parseSmartTask(raw)
        let item = TodoItem(
            title:           r.cleanTitle,
            dueDate:         r.dueDate,
            priority:        r.priority,
            startTime:       r.startTime,
            durationMinutes: r.durationMinutes,
            category:        r.detectedTags.first
        )
        modelContext.insert(item)
        try? modelContext.save()
        PlutoTelemetryEngine.shared.trackTaskCreated(task: item)
        text = ""
    }

    // MARK: - Chip label helpers

    private func relativeDateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInTomorrow(date)  { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.wide))
    }

    private func durationLabel(_ minutes: Int) -> String {
        let h = minutes / 60; let m = minutes % 60
        if h == 0   { return "\(m)m" }
        if m == 0   { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    private func priorityLabel(_ p: Int) -> String {
        switch p { case 1: "Low"; case 2: "Medium"; default: "High" }
    }

    private func priorityColor(_ p: Int) -> Color {
        switch p { case 1: .green; case 2: .orange; default: .red }
    }
}

// MARK: - TokenChip

private struct TokenChip: View {
    let icon:  String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(label)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 0.8))
    }
}

// MARK: - TodoNLParser

/// Extracts structured fields from a natural-language task string.
///
/// Parse order: priority → duration → time → date.
/// The title is whatever text remains after stripping matched tokens.
///
/// Supported patterns (case-insensitive):
/// - Date:     "today", "tonight", "tomorrow", weekday, "next [weekday]"
/// - Time:     "9am", "1pm", "9:30", "9:30am", "noon", "midnight", "tonight" (→ 19:00)
/// - Duration: "45m", "1h", "1.5h", "90min", "for 30m"
/// - Priority: "!" (low), "!!" (medium), "!!!" (high) — standalone word
enum TodoNLParser {

    struct ParseResult {
        var title:           String = ""
        var dueDate:         Date?  = nil
        var startTime:       Date?  = nil
        var durationMinutes: Int    = 0
        var priority:        Int    = 0
    }

    static func parse(_ raw: String) -> ParseResult {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ParseResult(title: raw) }

        var words = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        var removeIdx = IndexSet()
        var result = ParseResult()

        // 1. Priority  — standalone "!", "!!", "!!!"
        for (i, w) in words.enumerated() {
            if w.allSatisfy({ $0 == "!" }) && !w.isEmpty && w.count <= 3 {
                result.priority = w.count
                removeIdx.insert(i)
                break
            }
        }

        // 2. Duration  — "for <N>[m/h]" then bare "<N>[m/h]"
        var foundDuration = false
        for (i, w) in words.enumerated() where !removeIdx.contains(i) {
            if w.lowercased() == "for", i + 1 < words.count, !removeIdx.contains(i + 1),
               let mins = parseDuration(words[i + 1]) {
                result.durationMinutes = mins
                removeIdx.insert(i); removeIdx.insert(i + 1)
                foundDuration = true; break
            }
        }
        if !foundDuration {
            for (i, w) in words.enumerated() where !removeIdx.contains(i) {
                if let mins = parseDuration(w) {
                    result.durationMinutes = mins
                    removeIdx.insert(i); break
                }
            }
        }

        // 3. Time  — "9am", "1pm", "9:30", "noon", "midnight"
        //    "tonight" is handled in the date section (sets time=19:00 + date=today)
        for (i, w) in words.enumerated() where !removeIdx.contains(i) {
            if let t = parseTime(w, today: .now) {
                result.startTime = t
                removeIdx.insert(i)
                // Remove a preceding "at" preposition
                if i > 0, words[i - 1].lowercased() == "at", !removeIdx.contains(i - 1) {
                    removeIdx.insert(i - 1)
                }
                break
            }
        }

        // 4. Date  — today/tonight/tomorrow/weekday/"next weekday"
        let lower = trimmed.lowercased()
        let cal   = Calendar.current
        let today = cal.startOfDay(for: .now)

        // "tonight" → date=today, time=19:00 if no explicit time yet
        if let idx = indexOfWord("tonight", in: words, excluding: removeIdx) {
            result.dueDate = today
            if result.startTime == nil {
                result.startTime = dateWith(hour: 19, minute: 0, from: .now)
            }
            removeIdx.insert(idx)
        }
        // "today"
        else if let idx = indexOfWord("today", in: words, excluding: removeIdx) {
            result.dueDate = today
            removeIdx.insert(idx)
        }
        // "tomorrow"
        else if let idx = indexOfWord("tomorrow", in: words, excluding: removeIdx) {
            result.dueDate = cal.date(byAdding: .day, value: 1, to: today)
            removeIdx.insert(idx)
        }
        // "next [weekday]"
        else if let range = lower.range(of: #"next\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)"#,
                                         options: .regularExpression) {
            let matched   = String(lower[range])
            let parts     = matched.components(separatedBy: .whitespaces)
            let dayName   = parts.last ?? ""
            result.dueDate = nextOccurrence(of: dayName, minDaysAhead: 1)
            // Remove both words
            for (i, w) in words.enumerated() where !removeIdx.contains(i) {
                if parts.contains(w.lowercased()) { removeIdx.insert(i) }
            }
        }
        // bare weekday name
        else {
            for (i, w) in words.enumerated() where !removeIdx.contains(i) {
                if weekdays.contains(w.lowercased()),
                   let d = nextOccurrence(of: w.lowercased(), minDaysAhead: 0) {
                    result.dueDate = d; removeIdx.insert(i); break
                }
            }
        }

        // If startTime is set but no explicit date → default to today
        if result.startTime != nil && result.dueDate == nil {
            result.dueDate = today
        }

        // Align startTime's date component with dueDate
        if let t = result.startTime, let due = result.dueDate {
            var c = cal.dateComponents([.hour, .minute, .second], from: t)
            c.year  = cal.component(.year,  from: due)
            c.month = cal.component(.month, from: due)
            c.day   = cal.component(.day,   from: due)
            result.startTime = cal.date(from: c)
        }

        // Build title from remaining words
        let cleaned = words
            .enumerated()
            .filter { !removeIdx.contains($0.offset) }
            .map { $0.element }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        result.title = cleaned.isEmpty ? trimmed : cleaned
        return result
    }

    // MARK: - Private helpers

    private static let weekdays = ["monday","tuesday","wednesday","thursday","friday","saturday","sunday"]

    private static func indexOfWord(_ target: String, in words: [String], excluding: IndexSet) -> Int? {
        words.enumerated().first(where: { !excluding.contains($0.offset) && $0.element.lowercased() == target })?.offset
    }

    /// Parses duration words: "30m", "1h", "1.5h", "45min", "2hours", etc.
    private static func parseDuration(_ word: String) -> Int? {
        let s = word.lowercased()
        for suffix in ["hours", "hour", "hrs", "hr", "h"] {
            if s.hasSuffix(suffix) {
                let n = String(s.dropLast(suffix.count))
                if let d = Double(n), d > 0 { return Int((d * 60).rounded()) }
            }
        }
        for suffix in ["minutes", "minute", "mins", "min", "m"] {
            if s.hasSuffix(suffix) {
                let n = String(s.dropLast(suffix.count))
                if let i = Int(n), i > 0 { return i }
            }
        }
        return nil
    }

    /// Parses time words: "9am", "1pm", "9:30", "9:30am", "noon", "midnight".
    /// Returns nil for bare numbers without am/pm/colon (e.g. "9" alone).
    private static func parseTime(_ word: String, today: Date) -> Date? {
        let s = word.lowercased()
        switch s {
        case "noon":     return dateWith(hour: 12, minute: 0, from: today)
        case "midnight": return dateWith(hour: 0,  minute: 0, from: today)
        default: break
        }

        var str = s
        var pm: Bool? = nil
        if str.hasSuffix("pm") { pm = true;  str = String(str.dropLast(2)) }
        else if str.hasSuffix("am") { pm = false; str = String(str.dropLast(2)) }

        let parts = str.split(separator: ":").compactMap { Int($0) }
        guard let rawHour = parts.first, !parts.isEmpty else { return nil }
        // Bare number without am/pm or colon is not a time
        if pm == nil && parts.count < 2 { return nil }

        let minute = parts.count > 1 ? parts[1] : 0
        var hour   = rawHour
        if let isPM = pm {
            if isPM  && hour < 12 { hour += 12 }
            if !isPM && hour == 12 { hour  = 0 }
        }
        guard hour >= 0 && hour < 24, minute >= 0 && minute < 60 else { return nil }
        return dateWith(hour: hour, minute: minute, from: today)
    }

    private static func dateWith(hour: Int, minute: Int, from base: Date) -> Date? {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: base)
        c.hour = hour; c.minute = minute; c.second = 0
        return Calendar.current.date(from: c)
    }

    private static func nextOccurrence(of dayName: String, minDaysAhead: Int) -> Date? {
        let map: [String: Int] = ["sunday":1,"monday":2,"tuesday":3,"wednesday":4,
                                   "thursday":5,"friday":6,"saturday":7]
        guard let target = map[dayName] else { return nil }
        let cal    = Calendar.current
        let today  = cal.startOfDay(for: .now)
        let todayW = cal.component(.weekday, from: today)
        var delta  = target - todayW
        if delta <= minDaysAhead { delta += 7 }
        return cal.date(byAdding: .day, value: delta, to: today)
    }
}
