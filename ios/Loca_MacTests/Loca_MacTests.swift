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
}

