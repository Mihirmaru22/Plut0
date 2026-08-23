import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - MacDayPlannerColumn  (T10 — Executive Agenda Day Planner)

struct MacDayPlannerColumn: View {

    @Binding var selection: TodoItem?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(sort: [SortDescriptor(\TodoItem.startTime)], animation: .default)
    private var allItems: [TodoItem]

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var isIcsDropTargeted: Bool = false

    // Drag-to-move state
    @State private var draggingID:        UUID?  = nil
    @State private var dragOriginalStart: Date?  = nil
    @State private var dragDeltaMinutes:  Int    = 0

    // Resize state
    @State private var resizingID:            UUID? = nil
    @State private var resizeOriginalMinutes: Int   = 0
    @State private var resizeDeltaMinutes:    Int   = 0

    // Ghost affordance
    @State private var hoverY: CGFloat? = nil

    @ObservedObject private var calendarSync = PlutoCalendarSync.shared
    @AppStorage("mac_calendar_sync_enabled") private var calendarSyncEnabled: Bool = true

    private let cal = Calendar.current

    // MARK: - Derived collections

    private var active: [TodoItem] {
        allItems.filter { !$0.isArchived && $0.parentID == nil }
    }

    private var scheduled: [TodoItem] {
        active
            .filter { item in
                guard let s = item.startTime else { return false }
                return cal.isDate(s, inSameDayAs: selectedDate)
            }
            .sorted { ($0.startTime ?? .distantPast) < ($1.startTime ?? .distantPast) }
    }

    private var unscheduled: [TodoItem] {
        active.filter { item in
            guard item.startTime == nil, let due = item.dueDate else { return false }
            return cal.isDate(due, inSameDayAs: selectedDate)
        }
    }

    private var weekDays: [Date] {
        guard let interval = cal.dateInterval(of: .weekOfYear, for: selectedDate) else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: interval.start) }
    }

    // MARK: - Timeline geometry

    private enum TM {
        static let ppm:        CGFloat = 1.0   // points per minute
        static let gutter:     CGFloat = 52    // hour-label column width
        static let blockInset: CGFloat = 4     // horizontal breathing room per block
        static let minHeight:  CGFloat = 34    // minimum block height
        static let bottomPad:  CGFloat = 48    // breathing room below last hour
        static let resizeZone: CGFloat = 14    // bottom pt that triggers resize
    }

    private var isToday: Bool {
        cal.isDateInToday(selectedDate)
    }

    private var isFuture: Bool {
        cal.startOfDay(for: selectedDate) > cal.startOfDay(for: .now)
    }

    private var standardDayStart: Date {
        cal.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDate) ?? selectedDate
    }

    private var railStart: Date {
        let earliest = scheduled.compactMap { $0.startTime }.min()

        if isToday {
            let now = Date.now
            // If planning early morning before 9:00 AM (e.g. 7am or 8am): Show full day from 9:00 AM (or earlier if tasks exist)
            if now < standardDayStart {
                if let e = earliest, e < standardDayStart { return floorHour(e) }
                return standardDayStart
            } else {
                // Day is in-progress (e.g. 11am, 2pm): Anchor timeline from current hour
                let currentHour = floorHour(now)
                if let e = earliest, e < currentHour { return floorHour(e) }
                return currentHour
            }
        } else {
            // Future or Past day: Show full day starting from 9:00 AM
            if let e = earliest, e < standardDayStart { return floorHour(e) }
            return standardDayStart
        }
    }

    private var railEnd: Date {
        let day22 = cal.date(bySettingHour: 22, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        let latest = scheduled.compactMap { $0.endTime }.max()
        if let l = latest, l > day22 { return ceilHour(l) }
        return day22
    }

    private var totalMinutes: CGFloat {
        CGFloat(max(60, cal.dateComponents([.minute], from: railStart, to: railEnd).minute ?? 840))
    }

    private var totalHeight: CGFloat { totalMinutes * TM.ppm + TM.bottomPad }

    private func yFor(_ date: Date) -> CGFloat {
        let m = CGFloat(cal.dateComponents([.minute], from: railStart, to: date).minute ?? 0)
        return m * TM.ppm
    }

    private func timeAt(_ y: CGFloat) -> Date {
        let minutes = Int(max(0, y / TM.ppm))
        return cal.date(byAdding: .minute, value: minutes, to: railStart) ?? railStart
    }

    private func snap5(_ date: Date) -> Date {
        var c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard let m = c.minute else { return date }
        c.minute = (m / 5) * 5; c.second = 0
        return cal.date(from: c) ?? date
    }

    private func floorHour(_ date: Date) -> Date {
        var c = cal.dateComponents([.year, .month, .day, .hour], from: date)
        c.minute = 0; c.second = 0
        return cal.date(from: c) ?? date
    }

    private func ceilHour(_ date: Date) -> Date {
        var c = cal.dateComponents([.year, .month, .day, .hour], from: date)
        c.hour = (c.hour ?? 0) + 1; c.minute = 0; c.second = 0
        return cal.date(from: c) ?? date
    }

    private var railHours: [Date] {
        var result: [Date] = []
        var cursor = floorHour(railStart)
        while cursor <= railEnd {
            result.append(cursor)
            cursor = cal.date(byAdding: .hour, value: 1, to: cursor) ?? cursor.addingTimeInterval(3600)
        }
        return result
    }

    // Effective start time of a block — accounts for live drag delta
    private func effectiveStart(_ item: TodoItem) -> Date {
        guard draggingID == item.id, let orig = dragOriginalStart else {
            return item.startTime ?? selectedDate
        }
        return cal.date(byAdding: .minute, value: dragDeltaMinutes, to: orig) ?? orig
    }

    private func blockHeight(_ item: TodoItem) -> CGFloat {
        var mins = item.durationMinutes
        if resizingID == item.id { mins = max(5, mins + resizeDeltaMinutes) }
        return max(TM.minHeight, CGFloat(mins) * TM.ppm)
    }

    // MARK: - Overlap layout

    struct LayoutBlock {
        let item: TodoItem
        let column: Int
        let totalColumns: Int
    }

    private var layoutBlocks: [LayoutBlock] {
        guard !scheduled.isEmpty else { return [] }

        // Greedy column assignment (interval graph coloring)
        var assignments: [UUID: Int] = [:]
        for item in scheduled {
            guard let start = item.startTime else { continue }
            let end = item.endTime ?? cal.date(byAdding: .minute, value: 1, to: start)!
            var occupied = Set<Int>()
            for other in scheduled where other.id != item.id {
                guard let oStart = other.startTime else { continue }
                let oEnd = other.endTime ?? cal.date(byAdding: .minute, value: 1, to: oStart)!
                if start < oEnd && end > oStart, let col = assignments[other.id] {
                    occupied.insert(col)
                }
            }
            var col = 0; while occupied.contains(col) { col += 1 }
            assignments[item.id] = col
        }

        return scheduled.compactMap { item in
            guard let start = item.startTime, let col = assignments[item.id] else { return nil }
            let end = item.endTime ?? cal.date(byAdding: .minute, value: 1, to: start)!
            var maxCol = col
            for other in scheduled where other.id != item.id {
                guard let oStart = other.startTime else { continue }
                let oEnd = other.endTime ?? cal.date(byAdding: .minute, value: 1, to: oStart)!
                if start < oEnd && end > oStart, let oCol = assignments[other.id] {
                    maxCol = max(maxCol, oCol)
                }
            }
            return LayoutBlock(item: item, column: col, totalColumns: maxCol + 1)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            weekStrip
            Divider()
            agendaStreamView
        }
        .onReceive(NotificationCenter.default.publisher(for: .locaShiftDay)) { note in
            if let delta = note.object as? Int { shiftDay(delta) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .locaJumpToToday)) { _ in
            withAnimation(reduceMotion ? nil : DS.Motion.settle) {
                selectedDate = cal.startOfDay(for: .now)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .locaNudgeBlock)) { note in
            guard let delta = note.object as? Int,
                  let item = selection, let start = item.startTime else { return }
            item.startTime = snap5(cal.date(byAdding: .minute, value: delta, to: start) ?? start)
            try? modelContext.save()
            if let newStart = item.startTime {
                PlutoTelemetryEngine.shared.trackTaskRescheduled(task: item, newStartTime: newStart)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .locaAddBlock)) { _ in
            addBlock()
        }
        .onAppear {
            calendarSync.fetchEvents(for: selectedDate)
        }
        .onChange(of: selectedDate) { _, newDate in
            calendarSync.fetchEvents(for: newDate)
        }
    }

    // MARK: - Header (Pattern A Date Switcher Pill)

    private var header: some View {
        HStack(spacing: DS.Space.sm) {
            // Segmented Date Switcher Pill
            HStack(spacing: 8) {
                Button { shiftDay(-1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DS.Theme.textSecondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Previous day  ←")

                Button {
                    if !cal.isDateInToday(selectedDate) {
                        withAnimation(.spring(response: 0.25)) {
                            selectedDate = cal.startOfDay(for: .now)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DS.Theme.amber)

                        Text(selectedDate, format: .dateTime.weekday(.wide).day().month(.wide))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DS.Theme.textPrimary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 4)
                }
                .buttonStyle(.plain)

                Button { shiftDay(1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DS.Theme.textSecondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Next day  →")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(DS.Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(DS.Theme.border, lineWidth: 1)
            )

            Spacer()

            Button(action: addBlock) {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                    Text("Block")
                        .font(.system(size: 11.5, weight: .bold))
                }
                .foregroundStyle(Color.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(DS.Theme.amber, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Add a time block  ⌘N")
        }
        .padding(.horizontal, DS.Space.md)
        .padding(.vertical, 8)
    }

    // MARK: - Week strip (Pattern C High-Contrast Day Tiles)

    private var weekStrip: some View {
        HStack(spacing: 6) {
            ForEach(weekDays, id: \.self) { dayCell($0) }
        }
        .padding(.horizontal, DS.Space.md)
        .padding(.bottom, 8)
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = cal.isDate(day, inSameDayAs: selectedDate)
        let isToday    = cal.isDateInToday(day)
        let count      = active.filter { $0.startTime.map { cal.isDate($0, inSameDayAs: day) } ?? false }.count

        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                selectedDate = cal.startOfDay(for: day)
            }
        } label: {
            VStack(spacing: 2) {
                Text(day, format: .dateTime.weekday(.abbreviated))
                    .font(.system(size: 9.5, weight: isSelected ? .bold : .medium, design: .monospaced))
                    .foregroundStyle(isSelected ? Color.black : (isToday ? DS.Theme.amber : DS.Theme.textTertiary))

                Text(day, format: .dateTime.day())
                    .font(.system(size: 13, weight: isSelected ? .black : .bold, design: .monospaced))
                    .foregroundStyle(isSelected ? Color.black : DS.Theme.textPrimary)

                // Task count pip
                Circle()
                    .fill(count > 0 ? (isSelected ? Color.black : DS.Theme.amber) : Color.clear)
                    .frame(width: 3.5, height: 3.5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? Color.white : DS.Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(isSelected ? Color.white : (isToday ? DS.Theme.amber.opacity(0.4) : DS.Theme.border), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Timeline shell

    private var timeline: some View {
        ScrollView {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    timelineCanvas(width: geo.size.width)
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let loc):
                                hoverY = loc.x > TM.gutter ? loc.y : nil
                            case .ended:
                                hoverY = nil
                            }
                        }
                }
                .frame(height: totalHeight)

                if !unscheduled.isEmpty {
                    unscheduledSection
                        .padding(.horizontal, DS.Space.md)
                }
            }
        }
        .scrollDisabled(draggingID != nil || resizingID != nil)
    }

    // MARK: - Timeline canvas

    @ViewBuilder
    private func timelineCanvas(width: CGFloat) -> some View {
        let blockAreaWidth = width - TM.gutter

        ZStack(alignment: .topLeading) {
            // Size anchor & canvas click surface
            Color.clear
                .frame(width: width, height: totalHeight)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    if let y = hoverY {
                        let snapped = snap5(timeAt(y))
                        addBlockAt(snapped)
                    }
                }

            // Hour rail: guide lines + labels
            ForEach(railHours, id: \.self) { hour in
                hourTick(hour, totalWidth: width)
            }

            // Synced Apple Calendar Events (EventKit)
            if calendarSyncEnabled && calendarSync.isAuthorized {
                ForEach(calendarSync.eventsForSelectedDate) { event in
                    syncedCalendarBlockView(event, blockAreaWidth: blockAreaWidth)
                }
            }

            // Scheduled blocks
            ForEach(layoutBlocks, id: \.item.id) { lb in
                plannerBlockView(lb, blockAreaWidth: blockAreaWidth)
            }

            // Floating time bubble during drag
            if let did = draggingID,
               let lb  = layoutBlocks.first(where: { $0.item.id == did }) {
                let colW  = blockAreaWidth / CGFloat(lb.totalColumns)
                let xPos  = TM.gutter + CGFloat(lb.column) * colW + colW + TM.blockInset
                let startY = yFor(effectiveStart(lb.item))

                Text(effectiveStart(lb.item), format: .dateTime.hour().minute())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor, in: Capsule())
                    .offset(x: min(xPos, width - 70), y: startY - 2)
                    .animation(nil, value: startY)
            }

            // Now line — today only, updates every minute
            if cal.isDateInToday(selectedDate) {
                TimelineView(.periodic(from: .now, by: 60)) { ctx in
                    nowLine(at: ctx.date, totalWidth: width)
                }
            }

            // Ghost affordance
            ghostAffordance(totalWidth: width, blockAreaWidth: blockAreaWidth)

            // Drop target indicator
            if isIcsDropTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    .frame(width: width - TM.gutter, height: totalHeight)
                    .offset(x: TM.gutter)
                    .overlay(
                        VStack(spacing: 4) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(Color.accentColor)
                            Text("Drop .ics Calendar Event onto Timeline")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.accentColor)
                        }
                        .padding(12)
                        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Color.border.opacity(0.6), lineWidth: 1))
                        .shadow(radius: 10)
                    )
            }
        }
        .onDrop(of: [.fileURL, .text], isTargeted: $isIcsDropTargeted) { providers, location in
            handleTimelineDrop(providers: providers, dropLocation: location)
        }
    }

    // MARK: - Hour tick

    @ViewBuilder
    private func hourTick(_ hour: Date, totalWidth: CGFloat) -> some View {
        let y = yFor(hour)

        // Guide line
        Rectangle()
            .fill(DS.Color.separator.opacity(0.25))
            .frame(width: totalWidth - TM.gutter, height: 0.5)
            .offset(x: TM.gutter, y: y)

        // Hour label (10pt rounded, right-aligned in gutter)
        Text(hour, format: .dateTime.hour())
            .font(.system(size: 10, design: .rounded))
            .foregroundStyle(DS.Color.textTertiary)
            .frame(width: TM.gutter - 8, alignment: .trailing)
            .offset(x: 0, y: y - 7)
    }

    // MARK: - Block view

    @ViewBuilder
    private func plannerBlockView(_ lb: LayoutBlock, blockAreaWidth: CGFloat) -> some View {
        let item    = lb.item
        let startY  = yFor(effectiveStart(item))
        let height  = blockHeight(item)
        let colW    = blockAreaWidth / CGFloat(lb.totalColumns)
        let xPos    = TM.gutter + CGFloat(lb.column) * colW + TM.blockInset
        let width   = colW - TM.blockInset * 2

        PlannerBlock(
            item:       item,
            height:     height,
            isSelected: selection?.id == item.id,
            isDragging: draggingID == item.id,
            isResizing: resizingID == item.id,
            reduceMotion: reduceMotion,
            onSelect:   {
                withAnimation(reduceMotion ? .linear(duration: 0.1) : DS.Motion.settle) {
                    selection = item
                }
            },
            onToggle:   { toggleComplete(item) },
            onDragChanged:  { delta in
                if draggingID == nil {
                    draggingID        = item.id
                    dragOriginalStart = item.startTime
                    dragDeltaMinutes  = 0
                }
                let raw = Int(delta / TM.ppm)
                dragDeltaMinutes = (raw / 5) * 5
            },
            onDragEnded: {
                if let orig = dragOriginalStart {
                    item.startTime = snap5(
                        cal.date(byAdding: .minute, value: dragDeltaMinutes, to: orig) ?? orig
                    )
                    if let startTime = item.startTime, let dueDate = item.dueDate {
                        // Keep dueDate in sync if it was on the original day
                        if cal.isDate(dueDate, inSameDayAs: selectedDate) {
                            item.dueDate = cal.startOfDay(for: startTime)
                        }
                    }
                    try? modelContext.save()
                    if let newStart = item.startTime {
                        PlutoTelemetryEngine.shared.trackTaskRescheduled(task: item, newStartTime: newStart)
                    }
                    Haptics.impact(.light)
                }
                draggingID = nil; dragOriginalStart = nil; dragDeltaMinutes = 0
            },
            onResizeChanged: { delta in
                if resizingID == nil {
                    resizingID            = item.id
                    resizeOriginalMinutes = item.durationMinutes
                }
                let raw = Int(delta / TM.ppm)
                resizeDeltaMinutes = (raw / 5) * 5
            },
            onResizeEnded: {
                if resizingID == item.id {
                    item.durationMinutes = max(5, resizeOriginalMinutes + resizeDeltaMinutes)
                    try? modelContext.save()
                    Haptics.impact(.light)
                }
                resizingID = nil; resizeDeltaMinutes = 0; resizeOriginalMinutes = 0
            }
        )
        .frame(width: width, height: height)
        .offset(x: xPos, y: startY)
        .animation(
            (draggingID == item.id || resizingID == item.id) ? .none :
                (reduceMotion ? .linear(duration: 0.1) : DS.Motion.fluid120Hz),
            value: startY
        )
        .animation(
            (resizingID == item.id) ? .none :
                (reduceMotion ? .linear(duration: 0.1) : DS.Motion.fluid120Hz),
            value: height
        )
        .zIndex(selection?.id == item.id || draggingID == item.id ? 10 : 1)
    }

    // MARK: - Now line

    @ViewBuilder
    private func nowLine(at now: Date, totalWidth: CGFloat) -> some View {
        let y = yFor(now)
        if y >= 0 && y <= totalHeight {
            // Leading dot
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .offset(x: TM.gutter - 4, y: y - 4)

            // Hairline
            Rectangle()
                .fill(Color.red.opacity(0.85))
                .frame(width: totalWidth - TM.gutter, height: 1.5)
                .offset(x: TM.gutter, y: y)
        }
    }

    // MARK: - Ghost affordance

    @ViewBuilder
    private func ghostAffordance(totalWidth: CGFloat, blockAreaWidth: CGFloat) -> some View {
        if let y = hoverY, draggingID == nil, resizingID == nil, !isOverBlock(y: y) {
            let snappedTime = snap5(timeAt(y))
            Button {
                addBlockAt(snappedTime)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                    Text(snappedTime, format: .dateTime.hour().minute())
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Color.accentColor.opacity(0.75))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.08), in: Capsule())
            }
            .buttonStyle(.plain)
            .offset(x: TM.gutter + TM.blockInset, y: y - 12)
            .animation(nil, value: y)  // no spring-follow on mouse position
        }
    }

    private func isOverBlock(y: CGFloat) -> Bool {
        layoutBlocks.contains { lb in
            guard let start = lb.item.startTime else { return false }
            let blockY = yFor(start)
            return y >= blockY && y <= blockY + blockHeight(lb.item)
        }
    }

    // MARK: - Unscheduled tray

    private var unscheduledSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Divider().padding(.top, DS.Space.md)
            Label("Unscheduled", systemImage: "tray")
                .font(DS.Text.caption)
                .foregroundStyle(DS.Color.textSecondary)
                .padding(.top, DS.Space.sm)
                .padding(.bottom, DS.Space.xs)

            ForEach(unscheduled, id: \.id) { item in
                HStack(spacing: DS.Space.sm) {
                    Button { toggleComplete(item) } label: {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.isCompleted ? Color.accentColor : DS.Color.textSecondary)
                    }
                    .buttonStyle(.plain)

                    Text(item.title)
                        .font(DS.Text.body)
                        .strikethrough(item.isCompleted, color: DS.Color.textTertiary)
                        .foregroundStyle(item.isCompleted ? DS.Color.textTertiary : DS.Color.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Button { schedule(item) } label: { Image(systemName: "clock.badge.plus") }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                        .help("Add to timeline")
                }
                .padding(.vertical, DS.Space.xs)
                .padding(.horizontal, DS.Space.sm)
                .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.control))
                .contentShape(Rectangle())
                .onTapGesture { selection = item }
            }
        }
    }

    // MARK: - Actions

    private func shiftDay(_ delta: Int) {
        if let d = cal.date(byAdding: .day, value: delta, to: selectedDate) {
            withAnimation(reduceMotion ? nil : DS.Motion.settle) { selectedDate = d }
        }
    }

    private func addBlock() { addBlockAt(defaultStart()) }

    private func addBlockAt(_ time: Date) {
        let item = TodoItem(
            title: "New block",
            dueDate: cal.startOfDay(for: selectedDate),
            startTime: time,
            durationMinutes: 30
        )
        modelContext.insert(item)
        try? modelContext.save()
        withAnimation(reduceMotion ? nil : DS.Motion.settle) { selection = item }
        Haptics.impact(.light)
    }

    private func schedule(_ item: TodoItem) {
        item.startTime = defaultStart()
        if item.durationMinutes == 0 { item.durationMinutes = 30 }
        try? modelContext.save()
        selection = item
        Haptics.impact(.light)
    }

    private func toggleComplete(_ item: TodoItem) {
        item.completedAt = item.isCompleted ? nil : Date()
        try? modelContext.save()
        Haptics.impact(.light)
    }

    private func defaultStart() -> Date {
        if let last = scheduled.last, let end = last.endTime {
            if isToday {
                return max(end, snap5(Date.now))
            }
            return end
        }

        if isToday {
            let now = Date.now
            if now < standardDayStart {
                // Planning at 7am or 8am before day starts: first task starts at 9:00 AM (full day visible)
                return standardDayStart
            } else {
                // Planning during the day (e.g. 2:15 PM): first task starts right now
                return snap5(now)
            }
        } else {
            // Planning for a future day: first task starts at standard 9:00 AM
            return standardDayStart
        }
    }
}

// MARK: - PlannerBlock

/// An interactive time block on the proportional timeline.
/// A single DragGesture on the whole block handles both move (top area) and resize
/// (bottom 14 pt), determined at gesture-start time.
private struct PlannerBlock: View {

    let item:          TodoItem
    let height:        CGFloat
    let isSelected:    Bool
    let isDragging:    Bool
    let isResizing:    Bool
    let reduceMotion:  Bool

    let onSelect:         () -> Void
    let onToggle:         () -> Void
    let onDragChanged:    (CGFloat) -> Void
    let onDragEnded:      () -> Void
    let onResizeChanged:  (CGFloat) -> Void
    let onResizeEnded:    () -> Void

    @State private var isHovered = false
    @State private var dragMode: BlockDragMode = .none

    private enum BlockDragMode { case none, move, resize }

    var body: some View {
        ZStack(alignment: .bottom) {
            blockBody

            // Resize affordance strip — visible when hovered or selected
            if (isHovered || isSelected) && height > 40 {
                Capsule()
                    .fill(Color.accentColor.opacity(isResizing ? 0.8 : 0.4))
                    .frame(width: 32, height: 3)
                    .padding(.bottom, 4)
            }
        }
        .help(tooltipText)
        .onHover { isHovered = $0 }
        .scaleEffect(isDragging && !reduceMotion ? 1.02 : 1.0)
        .shadow(
            color: isDragging ? Color.accentColor.opacity(0.3) : .clear,
            radius: isDragging ? 10 : 0, x: 0, y: 4
        )
        .animation(reduceMotion ? .linear(duration: 0.05) : .spring(response: 0.2, dampingFraction: 0.75),
                   value: isDragging)
    }

    private var tooltipText: String {
        let title = item.title.isEmpty ? "Untitled Task" : item.title
        guard let start = item.startTime else { return title }
        let startStr = start.formatted(date: .omitted, time: .shortened)
        let end = item.endTime ?? start.addingTimeInterval(Double(item.durationMinutes * 60))
        let endStr = end.formatted(date: .omitted, time: .shortened)
        return "\(title)\n\(startStr) – \(endStr) (\(item.durationMinutes) min)"
    }

    private var blockBody: some View {
        HStack(alignment: .top, spacing: DS.Space.sm) {
            // Icon bubble — compact at 28pt
            Image(systemName: item.iconName ?? "checkmark")
                .font(.system(size: 11, weight: .semibold))
                .todoBubble(diameter: 28, done: item.isCompleted)

            // Title + time/duration
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title.isEmpty ? "Untitled" : item.title)
                    .font(DS.Text.body)
                    .lineLimit(height < 52 ? 1 : 3)
                    .strikethrough(item.isCompleted, color: DS.Color.textTertiary)
                    .foregroundStyle(item.isCompleted ? DS.Color.textTertiary : DS.Color.textPrimary)

                if height > 44 {
                    if let start = item.startTime {
                        Text(start, format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute())
                            .font(DS.Text.footnote)
                            .foregroundStyle(DS.Color.textTertiary)
                    }
                }
            }

            Spacer(minLength: 0)

            // Completion button
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13))
                    .foregroundStyle(item.isCompleted ? Color.accentColor : DS.Color.textSecondary)
            }
            .buttonStyle(.plain)
            .help(item.isCompleted ? "Mark not done" : "Mark done")
        }
        .padding(.horizontal, DS.Space.sm)
        .padding(.top, DS.Space.xs)
        .padding(.bottom, DS.Space.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.control)
                .fill(blockFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.control)
                .stroke(isSelected ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .highPriorityGesture(
            DragGesture(minimumDistance: 3)
                .onChanged { v in
                    if dragMode == .none {
                        dragMode = v.startLocation.y > (height - TM.resizeZone) ? .resize : .move
                    }
                    switch dragMode {
                    case .move:   onDragChanged(v.translation.height)
                    case .resize: onResizeChanged(v.translation.height)
                    case .none:   break
                    }
                }
                .onEnded { _ in
                    switch dragMode {
                    case .move:   onDragEnded()
                    case .resize: onResizeEnded()
                    case .none:   break
                    }
                    dragMode = .none
                }
        )
    }

    private var blockFill: Color {
        if isSelected  { return Color.accentColor.opacity(0.13) }
        if isDragging  { return Color.accentColor.opacity(0.09) }
        if isHovered   { return DS.Color.textPrimary.opacity(0.04) }
        return DS.Color.surface
    }

    private enum TM {
        static let resizeZone: CGFloat = 14
    }
}

// MARK: - MacDayPlannerColumn (Layout 2: Bento Timeblock Matrix & Layout 3: Agenda Stream)

extension MacDayPlannerColumn {

    // MARK: - Layout 2: Bento Timeblock Matrix

    var bentoTimeblockMatrix: some View {
        ScrollView {
            VStack(spacing: DS.Space.sm) {
                ForEach(railHours, id: \.self) { hour in
                    let hourTasks = scheduled.filter { item in
                        guard let s = item.startTime else { return false }
                        return cal.component(.hour, from: s) == cal.component(.hour, from: hour)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(hour, format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(DS.Color.textTertiary)
                                .frame(width: 50, alignment: .leading)

                            Rectangle()
                                .fill(DS.Color.border.opacity(0.3))
                                .frame(height: 1)
                        }

                        if hourTasks.isEmpty {
                            Button {
                                createBlock(at: hour)
                            } label: {
                                HStack {
                                    Image(systemName: "plus")
                                        .font(.system(size: 9))
                                    Text("Free Time · Click to schedule")
                                        .font(.system(size: 10))
                                }
                                .foregroundStyle(DS.Color.textTertiary.opacity(0.6))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(DS.Color.surfaceRecessed.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 50)
                        } else {
                            VStack(spacing: 4) {
                                ForEach(hourTasks) { task in
                                    bentoTaskRow(task: task)
                                }
                            }
                            .padding(.leading, 50)
                        }
                    }
                }

                if !unscheduled.isEmpty {
                    unscheduledSection
                        .padding(.top, DS.Space.md)
                }
            }
            .padding(DS.Space.md)
        }
    }

    private func bentoTaskRow(task: TodoItem) -> some View {
        BentoPlannerTaskRow(task: task, isSelected: selection?.id == task.id) {
            selection = task
        }
    }

    var agendaStreamView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                // Live Day Arc Glass Metrics Banner
                liveDayArcHeader

                // Morning Bucket (Box 1)
                agendaPeriodSection(
                    title: "MORNING SPRINT",
                    timeRange: "07:00 – 12:00",
                    icon: "sunrise.fill",
                    color: DS.Color.streak,
                    tasks: scheduled.filter {
                        guard let s = $0.startTime else { return false }
                        let h = cal.component(.hour, from: s)
                        return h >= 7 && h < 12
                    }
                )

                // Afternoon Bucket (Middle Box / Box 2)
                agendaPeriodSection(
                    title: "AFTERNOON DEEP WORK",
                    timeRange: "12:00 – 17:00",
                    icon: "sun.max.fill",
                    color: DS.Color.active,
                    tasks: scheduled.filter {
                        guard let s = $0.startTime else { return false }
                        let h = cal.component(.hour, from: s)
                        return h >= 12 && h < 17
                    }
                )

                // Evening Bucket (Box 3)
                agendaPeriodSection(
                    title: "EVENING & WIND DOWN",
                    timeRange: "17:00 – 22:00",
                    icon: "moon.fill",
                    color: ColorPalette[3],
                    tasks: scheduled.filter {
                        guard let s = $0.startTime else { return false }
                        let h = cal.component(.hour, from: s)
                        return h >= 17 && h < 22
                    }
                )

                if !unscheduled.isEmpty {
                    Divider()
                        .padding(.vertical, DS.Space.xs)

                    unscheduledSection
                }
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, DS.Space.md)
        }
    }

    // MARK: - Live Day Arc Header Card

    private var liveDayArcHeader: some View {
        let totalMins = scheduled.reduce(0) { $0 + $1.durationMinutes }
        let doneCount = scheduled.filter { $0.isCompleted }.count
        let totalCount = scheduled.count

        return VStack(spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DS.Theme.amber)

                    Text("DAY HORIZON")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.Theme.textTertiary)
                        .tracking(1.0)
                }

                Spacer()

                HStack(spacing: 8) {
                    if totalMins > 0 {
                        Text("\(totalMins / 60)h \(totalMins % 60)m planned")
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(DS.Theme.textTertiary)
                    }

                    if totalCount > 0 {
                        Text("\(doneCount)/\(totalCount) Done")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(doneCount == totalCount ? DS.Theme.emerald : DS.Theme.amber)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                (doneCount == totalCount ? DS.Theme.emerald : DS.Theme.amber).opacity(0.12),
                                in: Capsule()
                            )
                    }
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DS.Theme.surface)
                        .frame(height: 3)

                    if totalCount > 0 {
                        let ratio = CGFloat(doneCount) / CGFloat(max(1, totalCount))
                        Capsule()
                            .fill(DS.Theme.amber)
                            .frame(width: max(6, geo.size.width * ratio), height: 3)
                    }
                }
            }
            .frame(height: 3)
        }
        .padding(.vertical, 4)
    }

    private func agendaPeriodSection(title: String, timeRange: String, icon: String, color: Color, tasks: [TodoItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color)

                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.Theme.textSecondary)
                    .tracking(0.8)

                Spacer()

                Text(timeRange)
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DS.Theme.textTertiary)
            }
            .padding(.top, 4)

            if tasks.isEmpty {
                HStack {
                    Image(systemName: "circle.dashed")
                        .font(.system(size: 9))
                        .foregroundStyle(DS.Theme.textTertiary.opacity(0.5))
                    Text("No blocks scheduled")
                        .font(.system(size: 10.5))
                        .foregroundStyle(DS.Theme.textTertiary.opacity(0.7))
                }
                .padding(.vertical, 4)
            } else {
                VStack(spacing: 4) {
                    ForEach(tasks) { task in
                        bentoTaskRow(task: task)
                    }
                }
            }

            Divider().opacity(0.08)
        }
    }

    private func createBlock(at hourDate: Date) {
        let start = hourDate
        let item = TodoItem(title: "New Block", startTime: start, durationMinutes: 30)
        modelContext.insert(item)
        try? modelContext.save()
        selection = item
    }

    // MARK: - Calendar .ics Drop Handler

    private func handleTimelineDrop(providers: [NSItemProvider], dropLocation: CGPoint) -> Bool {
        let snappedTime = snap5(timeAt(dropLocation.y))

        for provider in providers {
            // 1. Check for file URL (.ics)
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let fileURL = url, fileURL.pathExtension.lowercased() == "ics",
                          let data = try? String(contentsOf: fileURL) else { return }

                    let events = ICSParser.parseICS(content: data)
                    DispatchQueue.main.async {
                        self.insertParsedEvents(events, fallbackStart: snappedTime)
                    }
                }
                return true
            }

            // 2. Check for plain text iCal (.ics string)
            if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                _ = provider.loadObject(ofClass: String.self) { text, _ in
                    guard let content = text else { return }
                    if content.contains("BEGIN:VEVENT") {
                        let events = ICSParser.parseICS(content: content)
                        DispatchQueue.main.async {
                            self.insertParsedEvents(events, fallbackStart: snappedTime)
                        }
                    } else {
                        // Regular text drop -> create task with title
                        DispatchQueue.main.async {
                            let item = TodoItem(
                                title: content.trimmingCharacters(in: .whitespacesAndNewlines),
                                notes: nil,
                                dueDate: self.cal.startOfDay(for: snappedTime),
                                startTime: snappedTime,
                                durationMinutes: 30
                            )
                            self.modelContext.insert(item)
                            try? self.modelContext.save()
                            self.selection = item
                            Haptics.impact(.rigid)
                        }
                    }
                }
                return true
            }
        }
        return false
    }

    private func insertParsedEvents(_ events: [ICSParser.ParsedCalendarEvent], fallbackStart: Date) {
        guard !events.isEmpty else { return }
        for (idx, evt) in events.enumerated() {
            let start = evt.startDate ?? cal.date(byAdding: .minute, value: idx * evt.durationMinutes, to: fallbackStart) ?? fallbackStart
            let item = TodoItem(
                title: evt.title,
                notes: evt.notes,
                dueDate: cal.startOfDay(for: start),
                startTime: start,
                durationMinutes: evt.durationMinutes
            )
            modelContext.insert(item)
            selection = item
        }
        try? modelContext.save()
        Haptics.impact(.rigid)
    }

    // MARK: - Synced Apple Calendar Block View (EventKit)

    @ViewBuilder
    private func syncedCalendarBlockView(_ event: PlutoCalendarEvent, blockAreaWidth: CGFloat) -> some View {
        let startY = yFor(event.startDate)
        let height = max(TM.minHeight, CGFloat(event.durationMinutes) * TM.ppm)
        let xPos = TM.gutter + TM.blockInset
        let width = blockAreaWidth - TM.blockInset * 2

        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.calendarColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 9))
                        .foregroundStyle(event.calendarColor)

                    Text(event.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.Color.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text(event.calendarTitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(DS.Color.textTertiary)
                }

                HStack(spacing: 4) {
                    Text("\(event.startDate, format: .dateTime.hour().minute()) – \(event.endDate, format: .dateTime.hour().minute())")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(DS.Color.textSecondary)

                    if let loc = event.location, !loc.isEmpty {
                        Text("· \(loc)")
                            .font(.system(size: 9))
                            .foregroundStyle(DS.Color.textTertiary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        convertCalendarEventToTask(event)
                    } label: {
                        Text("+ Convert")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: 3))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(width: width, height: height, alignment: .topLeading)
        .background(
            event.calendarColor.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(event.calendarColor.opacity(0.35), lineWidth: 1)
        )
        .offset(x: xPos, y: startY)
    }

    private func convertCalendarEventToTask(_ event: PlutoCalendarEvent) {
        let item = TodoItem(
            title: event.title,
            notes: event.notes,
            dueDate: cal.startOfDay(for: event.startDate),
            startTime: event.startDate,
            durationMinutes: event.durationMinutes
        )
        modelContext.insert(item)
        try? modelContext.save()
        selection = item
        Haptics.impact(.rigid)
    }
}

// MARK: - BentoPlannerTaskRow (with High-Fidelity Glass Hover Physics)

private struct BentoPlannerTaskRow: View {
    @Bindable var task: TodoItem
    let isSelected: Bool
    let onSelect: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var isHovered: Bool = false

    private var catColor: Color { task.categoryColor }

    var body: some View {
        Button {
            onSelect()
            Haptics.impact(.light)
        } label: {
            HStack(spacing: 9) {
                // Category/Task Bubble Indicator
                Image(systemName: task.iconName ?? (task.isCompleted ? "checkmark.circle.fill" : "circle"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(task.isCompleted ? DS.Color.success : catColor)
                    .frame(width: 22, height: 22)
                    .background(task.isCompleted ? DS.Color.success.opacity(0.12) : catColor.opacity(0.12), in: Circle())
                    .scaleEffect(isHovered ? 1.08 : 1.0)
                    .animation(.spring(response: 0.2), value: isHovered)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title.isEmpty ? "Untitled Task" : task.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(task.isCompleted ? DS.Color.textTertiary : DS.Color.textPrimary)
                        .strikethrough(task.isCompleted, color: DS.Color.textTertiary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if let start = task.startTime, let end = task.endTime {
                            HStack(spacing: 3) {
                                Image(systemName: "clock")
                                    .font(.system(size: 8))
                                Text("\(start.formatted(.dateTime.hour().minute())) – \(end.formatted(.dateTime.hour().minute()))")
                                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            }
                            .foregroundStyle(DS.Color.textSecondary)
                        }

                        Text("•")
                            .font(.system(size: 7))
                            .foregroundStyle(DS.Color.textTertiary)

                        Text("\(task.durationMinutes)m")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(catColor)
                    }
                }

                Spacer()

                // Checkmark toggle button
                Button {
                    withAnimation(.spring(response: 0.25)) {
                        if task.isCompleted {
                            task.completedAt = nil
                        } else {
                            task.completedAt = Date()
                            PlutoSoundEngine.shared.play(.checkmark)
                        }
                        try? modelContext.save()
                    }
                    Haptics.impact(.light)
                } label: {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15))
                        .foregroundStyle(task.isCompleted ? DS.Color.success : DS.Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? DS.Theme.cardSelected : (isHovered ? DS.Theme.surface : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(isSelected ? DS.Theme.amber.opacity(0.4) : (isHovered ? DS.Theme.border : Color.clear), lineWidth: 1)
            )
            .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isHovered)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
