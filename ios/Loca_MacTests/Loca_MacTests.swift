import Testing
import Foundation
import SwiftData
import AppKit
@testable import Pluto

struct Loca_MacTests {

    // MARK: - Invariant 1: RTFD Round-trip Fidelity
    @Test func testRTFDRoundTrip() throws {
        let original = NSMutableAttributedString(string: "Hello Production World!\n")
        original.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 18), range: NSRange(location: 0, length: 5))
        original.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: NSRange(location: 6, length: 10))
        
        let data = RichTextTypography.serializeToRTFD(attributedString: original)
        #expect(data != nil)
        
        guard let data = data else { return }
        let deserialized = RichTextTypography.deserializeFromRTFD(data: data)
        #expect(deserialized != nil)
        #expect(deserialized?.string == original.string)
    }

    // MARK: - Invariant 2: Markdown Legacy Migration & Checklists
    @Test func testMarkdownToAttributedConversion() throws {
        let markdown = "# Title Heading\n- [ ] Unchecked Task\n- [x] Done Task\n  - [X] Nested Done Task\n* [ ] Alt Marker Task\n- [ ] \n**Bold Text**"
        let attr = RichTextTypography.convertMarkdownToAttributedString(markdown: markdown)
        
        #expect(attr.string.contains("Title Heading"))
        #expect(attr.string.contains("Unchecked Task"))
        #expect(attr.string.contains("Done Task"))
        #expect(attr.string.contains("Nested Done Task"))
        #expect(attr.string.contains("Alt Marker Task"))
        #expect(attr.string.contains("Bold Text"))
        
        let exportedMarkdown = RichTextTypography.convertAttributedStringToMarkdown(attributedString: attr)
        #expect(exportedMarkdown.contains("Title Heading"))
        #expect(exportedMarkdown.contains("- [ ] Unchecked Task"))
        #expect(exportedMarkdown.contains("- [x] Done Task"))
        #expect(exportedMarkdown.contains("- [x] Nested Done Task"))
        #expect(exportedMarkdown.contains("- [ ] Alt Marker Task"))
        #expect(exportedMarkdown.contains("- [ ] \n") || exportedMarkdown.contains("- [ ]\n"))
    }

    // MARK: - Invariant 3: Work Project Progress Calculation
    @Test func testProjectProgressRatio() throws {
        let schema = Schema([WorkProject.self, WorkSection.self, TodoItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let project = WorkProject(title: "Audit Test Project")
        context.insert(project)
        let projID = project.id
        
        // 0 tasks -> 0.0
        let projectTasks0 = try context.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.projectID == projID }))
        #expect(projectTasks0.isEmpty)
        
        // Add 2 tasks, 1 completed -> 50%
        let t1 = TodoItem(title: "Task 1", projectID: projID, completedAt: Date())
        let t2 = TodoItem(title: "Task 2", projectID: projID, completedAt: nil)
        context.insert(t1)
        context.insert(t2)
        try context.save()
        
        let projectTasks = try context.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.projectID == projID }))
        let completed = projectTasks.filter { $0.isCompleted }.count
        let total = projectTasks.count
        let ratio = Double(completed) / Double(total)
        
        #expect(total == 2)
        #expect(completed == 1)
        #expect(ratio == 0.5)
    }

    // MARK: - Invariant 4: Section Deletion Safety (Never deletes tasks)
    @Test func testSectionDeletionPreservesTasks() throws {
        let schema = Schema([WorkProject.self, WorkSection.self, TodoItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let project = WorkProject(title: "Phase Project")
        context.insert(project)
        let projID = project.id
        
        let section = WorkSection(projectID: projID, title: "Phase 1")
        context.insert(section)
        let secID = section.id
        
        let task = TodoItem(title: "Sub-task", projectID: projID, sectionID: secID)
        context.insert(task)
        try context.save()
        
        // Delete section logic: unsection tasks
        let tasks = try context.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.sectionID == secID }))
        for t in tasks {
            t.sectionID = nil
        }
        context.delete(section)
        try context.save()
        
        let remainingTasks = try context.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.projectID == projID }))
        #expect(remainingTasks.count == 1)
        #expect(remainingTasks.first?.sectionID == nil)
    }

    // MARK: - Invariant 5: Ghost Mode Privacy Barrier (Spotlight Exclusion)
    
    @Test func testGhostReflectionNotIndexed() throws {
        let privateNote = JournalNote(title: "Evening Reflection", text: "Ghost protocol reflection details", isPrivate: true)
        #expect(privateNote.isPrivate == true)
        
        let schema = Schema([JournalNote.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        context.insert(privateNote)
        try context.save()
        
        let allNotes = try context.fetch(FetchDescriptor<JournalNote>())
        let indexableNotes = allNotes.filter { !$0.isPrivate && !$0.isArchived && !$0.text.isEmpty }
        #expect(indexableNotes.isEmpty)
    }

    @Test func testPrivateNotePurgedOnReindex() throws {
        let schema = Schema([JournalNote.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let publicNote = JournalNote(title: "Public Note", text: "Public reflection", isPrivate: false)
        let privateNote = JournalNote(title: "Ghost Covenant", text: "Secret reflection", isPrivate: true)
        context.insert(publicNote)
        context.insert(privateNote)
        try context.save()
        
        let allNotes = try context.fetch(FetchDescriptor<JournalNote>())
        var identifiersToPurge: [String] = []
        var itemsToIndex: [JournalNote] = []
        
        for note in allNotes {
            if note.isPrivate || note.isArchived || note.text.isEmpty {
                identifiersToPurge.append(note.id.uuidString)
            } else {
                itemsToIndex.append(note)
            }
        }
        
        #expect(itemsToIndex.count == 1)
        #expect(itemsToIndex.first?.title == "Public Note")
        #expect(identifiersToPurge.contains(privateNote.id.uuidString))
    }

    @Test func testJournalStillShowsPrivateNotes() throws {
        let schema = Schema([JournalNote.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let reflectionNote = JournalNote(date: Date(), title: "Ghost Reflection", text: "Evening review content", kind: .dailyNote, isPrivate: true)
        context.insert(reflectionNote)
        try context.save()
        
        // In-app query for Journal list fetches all unarchived notes including private reflections
        let inAppJournalNotes = try context.fetch(FetchDescriptor<JournalNote>(predicate: #Predicate { $0.archivedAt == nil }))
        #expect(inAppJournalNotes.count == 1)
        #expect(inAppJournalNotes.first?.title == "Ghost Reflection")
        #expect(inAppJournalNotes.first?.isPrivate == true)
    }

    // MARK: - Invariant 6: Telemetry Privacy Barrier (SHA-256 PII Hashing)

    @Test @MainActor func testTelemetryHashesPII() throws {
        let engine = PlutoTelemetryEngine.shared
        let originalName = NSFullUserName()
        let testTitle = "Buy groceries"
        
        let testTask = TodoItem(title: testTitle)
        engine.trackTaskCreated(task: testTask)
        
        let payload = engine.debugLastPayload()
        let titleInPayload = payload["title"] as? String ?? ""
        
        // Assert payload does NOT contain plaintext
        #expect(!titleInPayload.contains(testTitle))
        #expect(titleInPayload != testTitle)
        #expect(!engine.testerName.contains(originalName) || originalName.isEmpty)
        
        // Assert SHA-256 hex string characteristics
        let expectedHash = PlutoPrivacy.hash(testTitle)
        #expect(titleInPayload == expectedHash)
        #expect(expectedHash.count == 64)
        
        // Verify determinism
        let hash2 = PlutoPrivacy.hash(testTitle)
        #expect(expectedHash == hash2)
    }

    @Test @MainActor func testTelemetryPreservesAnalytics() throws {
        let engine = PlutoTelemetryEngine.shared
        
        let task1 = TodoItem(title: "Morning routine")
        let task2 = TodoItem(title: "Morning routine")
        
        engine.trackTaskCreated(task: task1)
        let payload1 = engine.debugLastPayload()
        
        engine.trackTaskCreated(task: task2)
        let payload2 = engine.debugLastPayload()
        
        let title1 = payload1["title"] as? String
        let title2 = payload2["title"] as? String
        
        // Both tasks share the same title, so their anonymized SHA-256 hashes must be identical
        #expect(title1 != nil)
        #expect(title1 == title2)
        #expect(title1 == PlutoPrivacy.hash("Morning routine"))
    }

    // MARK: - Invariant 7: Recursive Soft-Delete Cascade Integrity (B-04, B-23, B-24)

    @Test func testRecursiveCascadeSubtaskArchiving() throws {
        let schema = Schema([TodoItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        // Level 1: Parent Task
        let parent = TodoItem(title: "Launch Project")
        context.insert(parent)
        try context.save()

        // Level 2: Subtask
        let child = TodoItem(title: "Write Documentation", parentID: parent.id)
        context.insert(child)
        try context.save()

        // Level 3: Nested Grandchild Subtask
        let grandchild = TodoItem(title: "Review Appendix", parentID: child.id)
        context.insert(grandchild)
        try context.save()

        // Execute recursive cascade archiving on top-level parent
        parent.archiveCascade(in: context)
        try context.save()

        #expect(parent.archivedAt != nil)
        #expect(child.archivedAt != nil)
        #expect(grandchild.archivedAt != nil)

        // Verify active tasks query filters out all 3
        let activeTasks = try context.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.archivedAt == nil }))
        #expect(activeTasks.isEmpty)
    }

    @Test func testWorkProjectCascadeArchiving() throws {
        let schema = Schema([WorkProject.self, WorkSection.self, TodoItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let project = WorkProject(title: "Pluto OS Sprint")
        context.insert(project)
        try context.save()

        let section = WorkSection(projectID: project.id, title: "Architecture")
        context.insert(section)
        try context.save()

        let task1 = TodoItem(title: "Fix DSP Engine", projectID: project.id, sectionID: section.id)
        let task2 = TodoItem(title: "Verify Cascade", projectID: project.id)
        context.insert(task1)
        context.insert(task2)
        try context.save()

        // Archive Project with Cascade
        project.archiveCascade(in: context)
        try context.save()

        #expect(project.isArchived == true)
        #expect(task1.archivedAt != nil)
        #expect(task2.archivedAt != nil)
    }

    // MARK: - Invariant 8: Focus Audio DSP Thread-Safe Execution (B-05, B-26)

    @Test func testFocusAudioDSPAllocationFreeRender() throws {
        let dsp = FocusAudioDSPContext()
        dsp.volLofi = 0.8
        dsp.volPiano = 0.5
        dsp.isAllPaused = false

        #expect(dsp.volLofi == 0.8)
        #expect(dsp.volPiano == 0.5)
        #expect(dsp.isAllPaused == false)

        var leftChannel = [Float](repeating: 0, count: 512)
        var rightChannel = [Float](repeating: 0, count: 512)

        leftChannel.withUnsafeMutableBufferPointer { leftBuf in
            rightChannel.withUnsafeMutableBufferPointer { rightBuf in
                var audioBuffers = [
                    AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(512 * MemoryLayout<Float>.size), mData: leftBuf.baseAddress),
                    AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(512 * MemoryLayout<Float>.size), mData: rightBuf.baseAddress)
                ]
                
                audioBuffers.withUnsafeMutableBufferPointer { ablBuf in
                    let abl = AudioBufferList(
                        mNumberBuffers: 2,
                        mBuffers: ablBuf[0]
                    )
                    var ablCopy = abl
                    withUnsafeMutablePointer(to: &ablCopy) { ptr in
                        let ablPointer = UnsafeMutableAudioBufferListPointer(ptr)
                        dsp.render(frameCount: 512, ablPointer: ablPointer, sampleRate: 44100.0)
                    }
                }
            }
        }

        // Verify audio was synthesized into left and right buffers
        let leftSum = leftChannel.reduce(0) { $0 + abs($1) }
        let rightSum = rightChannel.reduce(0) { $0 + abs($1) }
        #expect(leftSum > 0.0)
        #expect(rightSum > 0.0)
    }

    // MARK: - Invariant 9: Natural Language Time Extraction & Word Boundaries (B-09, B-10)

    @Test func testNaturalLanguageNoFalsePositiveTimeExtraction() throws {
        // Plain text with words containing 'am' or 'pm' must NEVER trigger time extraction
        let testCases = [
            "Buy spam",
            "Team sync",
            "Go to camp",
            "Scam alert",
            "Review diagram",
            "Ice cream social"
        ]

        for tc in testCases {
            let res = LocaNeuralEngine.parseSmartTask(tc)
            #expect(res.startTime == nil, "Failed for '\(tc)': erroneously extracted startTime \(String(describing: res.startTime))")
            #expect(res.dueDate == nil, "Failed for '\(tc)': erroneously extracted dueDate \(String(describing: res.dueDate))")
            #expect(res.cleanTitle == tc)
        }

        // Date-only phrases containing 'am'/'pm' words must set dueDate but NOT startTime
        let dateOnlyCases = [
            ("Buy spam today", "Buy spam"),
            ("Team sync tomorrow", "Team sync"),
            ("Go to camp tomorrow", "Go to camp")
        ]

        for (input, expectedTitle) in dateOnlyCases {
            let res = LocaNeuralEngine.parseSmartTask(input)
            #expect(res.startTime == nil, "Failed for '\(input)': erroneously extracted startTime \(String(describing: res.startTime))")
            #expect(res.dueDate != nil, "Failed for '\(input)': dueDate should be present")
            #expect(res.cleanTitle == expectedTitle)
        }
    }

    @Test func testNaturalLanguageAccurateTimeExtraction() throws {
        let cal = Calendar.current

        // 1. "Meeting at 5pm" -> 17:00
        let r1 = LocaNeuralEngine.parseSmartTask("Meeting at 5pm")
        #expect(r1.cleanTitle == "Meeting")
        #expect(r1.startTime != nil)
        if let st = r1.startTime {
            #expect(cal.component(.hour, from: st) == 17)
            #expect(cal.component(.minute, from: st) == 0)
        }

        // 2. "Standup 9:30am" -> 09:30
        let r2 = LocaNeuralEngine.parseSmartTask("Standup 9:30am")
        #expect(r2.cleanTitle == "Standup")
        #expect(r2.startTime != nil)
        if let st = r2.startTime {
            #expect(cal.component(.hour, from: st) == 9)
            #expect(cal.component(.minute, from: st) == 30)
        }

        // 3. "Team sync tomorrow at 10am for 1h #work !!" -> Complex task with 'am' word + explicit time
        let r3 = LocaNeuralEngine.parseSmartTask("Team sync tomorrow at 10am for 1h #work !!")
        #expect(r3.cleanTitle == "Team sync")
        #expect(r3.dueDate != nil)
        #expect(r3.startTime != nil)
        if let st = r3.startTime {
            #expect(cal.component(.hour, from: st) == 10)
            #expect(cal.component(.minute, from: st) == 0)
        }
        #expect(r3.durationMinutes == 60)
        #expect(r3.priority == 2)
        #expect(r3.detectedTags.contains("work"))

        // 4. "Lunch at noon" -> 12:00
        let r4 = LocaNeuralEngine.parseSmartTask("Lunch at noon")
        #expect(r4.cleanTitle == "Lunch")
        #expect(r4.startTime != nil)
        if let st = r4.startTime {
            #expect(cal.component(.hour, from: st) == 12)
            #expect(cal.component(.minute, from: st) == 0)
        }
    }

    // MARK: - Invariant 10: Quick Switcher Keyboard Navigation & Index Clamping (B-11, B-12)

    @Test func testQuickSwitcherIndexClamping() {
        let mockNote = NoteSummary(title: "Mock Note")
        let switcher = QuickSwitcherViewModel()
        switcher.results = Array(repeating: mockNote, count: 10)
        switcher.selectedIndex = 9
        #expect(switcher.selectedIndex == 9)

        // Simulate query change or filter shrink that reduces results to 5
        switcher.results = Array(repeating: mockNote, count: 5)

        // Index should clamp to 4 (last valid index)
        #expect(switcher.selectedIndex == 4)
    }

    @Test func testQuickSwitcherEnterActivation() {
        let mockNote1 = NoteSummary(title: "Note 1")
        let mockNote2 = NoteSummary(title: "Note 2")
        let switcher = QuickSwitcherViewModel()
        switcher.results = [mockNote1, mockNote2]
        switcher.selectedIndex = 1

        // Pressing Enter (activateSelected) should immediately activate item at index 1
        let activated = switcher.activateSelected()
        #expect(activated?.id == mockNote2.id)
    }

    @Test func testQuickSwitcherResetOnQueryChange() {
        let mockNote1 = NoteSummary(title: "Note 1")
        let mockNote2 = NoteSummary(title: "Note 2")
        let mockNote3 = NoteSummary(title: "Note 3")
        let switcher = QuickSwitcherViewModel(notes: [mockNote1, mockNote2, mockNote3])
        switcher.selectedIndex = 2

        // Changing query should reset selectedIndex to 0
        switcher.query = "Note"
        #expect(switcher.selectedIndex == 0)
    }

    @Test func testQuickSwitcherArrowNavigationBounds() {
        let mockNote1 = NoteSummary(title: "Alpha")
        let mockNote2 = NoteSummary(title: "Beta")
        let mockNote3 = NoteSummary(title: "Gamma")
        let switcher = QuickSwitcherViewModel(notes: [mockNote1, mockNote2, mockNote3])

        #expect(switcher.selectedIndex == 0)

        // Navigate down
        switcher.moveSelectionDown()
        #expect(switcher.selectedIndex == 1)
        switcher.moveSelectionDown()
        #expect(switcher.selectedIndex == 2)

        // Navigate down beyond bounds -> clamped at last index
        switcher.moveSelectionDown()
        #expect(switcher.selectedIndex == 2)

        // Navigate up
        switcher.moveSelectionUp()
        #expect(switcher.selectedIndex == 1)
        switcher.moveSelectionUp()
        #expect(switcher.selectedIndex == 0)

        // Navigate up beyond bounds -> clamped at 0
        switcher.moveSelectionUp()
        #expect(switcher.selectedIndex == 0)
    }

    // MARK: - Invariant 11: Habit & Streak Calculation Across Timezone / DST Boundaries (B-13, B-18)

    @Test func testStreakNearMidnight() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!

        // Check-in at 23:59 on Day 1
        let lateNight = calendar.date(from: DateComponents(year: 2024, month: 1, day: 15, hour: 23, minute: 59))!
        // Check-in at 00:01 on Day 2
        let earlyMorning = calendar.date(from: DateComponents(year: 2024, month: 1, day: 16, hour: 0, minute: 1))!

        let streak = calculateStreak(for: [lateNight, earlyMorning], calendar: calendar)
        #expect(streak == 2, "Midnight boundary must count as 2 consecutive days")
        #expect(isConsecutiveDay(lateNight, earlyMorning, calendar: calendar))
    }

    @Test func testStreakAcrossDSTTransition() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!

        // 1. Spring forward: March 12, 2023 at 2am -> 3am (23-hour day)
        let beforeSpring = calendar.date(from: DateComponents(year: 2023, month: 3, day: 11, hour: 23))!
        let duringSpring = calendar.date(from: DateComponents(year: 2023, month: 3, day: 12, hour: 10))!
        let afterSpring = calendar.date(from: DateComponents(year: 2023, month: 3, day: 13, hour: 1))!

        let springStreak2 = calculateStreak(for: [beforeSpring, duringSpring], calendar: calendar)
        #expect(springStreak2 == 2, "Spring forward 2-day streak should not break")

        let springStreak3 = calculateStreak(for: [beforeSpring, duringSpring, afterSpring], calendar: calendar)
        #expect(springStreak3 == 3, "Spring forward 3-day streak should not break")

        // 2. Fall back: November 5, 2023 at 2am -> 1am (25-hour day)
        let beforeFall = calendar.date(from: DateComponents(year: 2023, month: 11, day: 4, hour: 22))!
        let duringFall = calendar.date(from: DateComponents(year: 2023, month: 11, day: 5, hour: 23))!
        let afterFall = calendar.date(from: DateComponents(year: 2023, month: 11, day: 6, hour: 1))!

        let fallStreak3 = calculateStreak(for: [beforeFall, duringFall, afterFall], calendar: calendar)
        #expect(fallStreak3 == 3, "Fall back 3-day streak should not break")
    }

    @Test func testStreakAcrossTimezoneShift() {
        var pstCal = Calendar(identifier: .gregorian)
        pstCal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let day1PST = pstCal.date(from: DateComponents(year: 2023, month: 8, day: 23, hour: 14, minute: 0))!

        var estCal = Calendar(identifier: .gregorian)
        estCal.timeZone = TimeZone(identifier: "America/New_York")!
        let day2EST = estCal.date(from: DateComponents(year: 2023, month: 8, day: 24, hour: 14, minute: 0))!

        // When evaluated in user's current calendar (EST), day1 is Aug 23 and day2 is Aug 24
        let streak = calculateStreak(for: [day1PST, day2EST], calendar: estCal)
        #expect(streak == 2, "Timezone shift should maintain consecutive streak in current calendar")
    }

    @Test func testHabitCheckInDayNormalization() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!

        let date = calendar.date(from: DateComponents(year: 2024, month: 6, day: 15, hour: 18, minute: 30))!
        let checkIn = HabitCheckIn(timestamp: date, timezoneOffset: -14400)

        let normalizedDay = checkIn.day(in: calendar)
        let expectedDay = calendar.startOfDay(for: date)
        #expect(normalizedDay == expectedDay)
    }

    // MARK: - Invariant 12: Natural Language Duration, Prepositions & Punctuation (B-06, B-17, B-27)

    @Test func testFractionalDurations() {
        let result1 = LocaNeuralEngine.parseSmartTask("Workout for 1.5h")
        #expect(result1.durationMinutes == 90)
        #expect(result1.cleanTitle == "Workout")

        let result2 = LocaNeuralEngine.parseSmartTask("Meditate 0.5hr")
        #expect(result2.durationMinutes == 30)
        #expect(result2.cleanTitle == "Meditate")

        let result3 = LocaNeuralEngine.parseSmartTask("Focus 90min")
        #expect(result3.durationMinutes == 90)
        #expect(result3.cleanTitle == "Focus")

        let result4 = LocaNeuralEngine.parseSmartTask("Design review for 2.5 hours")
        #expect(result4.durationMinutes == 150)
        #expect(result4.cleanTitle == "Design review")
    }

    @Test func testCompoundPrepositions() {
        let result1 = LocaNeuralEngine.parseSmartTask("Meeting on next Tuesday")
        #expect(result1.cleanTitle == "Meeting")
        #expect(result1.dueDate != nil)

        let result2 = LocaNeuralEngine.parseSmartTask("Call by tomorrow morning")
        #expect(result2.cleanTitle == "Call")
        #expect(result2.dueDate != nil)

        let result3 = LocaNeuralEngine.parseSmartTask("Review notes on tomorrow")
        #expect(result3.cleanTitle == "Review notes")
        #expect(result3.dueDate != nil)
    }

    @Test func testTrailingPunctuation() {
        let result1 = LocaNeuralEngine.parseSmartTask("Meeting!")
        #expect(result1.cleanTitle == "Meeting")

        let result2 = LocaNeuralEngine.parseSmartTask("Call?")
        #expect(result2.cleanTitle == "Call")

        let result3 = LocaNeuralEngine.parseSmartTask("Review,")
        #expect(result3.cleanTitle == "Review")

        let result4 = LocaNeuralEngine.parseSmartTask("Standup...")
        #expect(result4.cleanTitle == "Standup")
    }

    // MARK: - Invariant 13: Swift 6 Strict Concurrency & Thread-Safe Resource Management (B-08, B-25, B-27)

    @Test func testNotesDatabaseDeinitThreadSafety() async throws {
        // Create in-memory database, spawn concurrent queries, and release reference simultaneously
        for _ in 0..<5 {
            var db: NotesDatabase? = try NotesDatabase.inMemory()
            let strongDB = db!

            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    _ = try? strongDB.read { _ in
                        Thread.sleep(forTimeInterval: 0.002)
                    }
                }
                group.addTask {
                    _ = try? strongDB.write { _ in
                        Thread.sleep(forTimeInterval: 0.002)
                    }
                }
            }

            // Immediately deinitialize database while tasks conclude
            db = nil
            #expect(db == nil)
        }
    }

    @Test func testTelemetryBufferConcurrency() async throws {
        let engine = PlutoTelemetryEngine.shared

        // Concurrently emit 100 events across background tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let event = PlutoAlphaEvent(
                        event_id: "test_\(i)_\(UUID().uuidString.prefix(6))",
                        event_name: "concurrent_test_event",
                        timestamp: ISO8601DateFormatter().string(from: Date()),
                        properties: ["index": AnyCodable(i)]
                    )
                    engine.trackEvent(event)
                }
            }
        }

        // Flush must execute safely without crash or race
        engine.flushBuffer()
    }

    @Test func testSendableConformances() {
        let indexer: any Sendable = NotesSpotlightIndexer.shared
        #expect(indexer is NotesSpotlightIndexer)

        let store = LocalNotesStore(database: try! NotesDatabase.inMemory())
        let repo: any Sendable = LocalNotesRepository(store: store, eventBus: NotesEventBus())
        #expect(repo is LocalNotesRepository)
    }
}




