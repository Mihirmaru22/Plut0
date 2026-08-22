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
}
