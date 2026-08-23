import Foundation
import SwiftData

// MARK: - WorkSection (@Model)

@Model
final class WorkSection {
    
    var id: UUID = UUID()
    var projectID: UUID = UUID()
    var title: String = "New Section"
    var sortOrder: Int = 0
    var isCollapsed: Bool = false
    var createdAt: Date = Date()
    
    init(
        id: UUID = UUID(),
        projectID: UUID,
        title: String = "New Section",
        sortOrder: Int = 0,
        isCollapsed: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.projectID = projectID
        self.title = title
        self.sortOrder = sortOrder
        self.isCollapsed = isCollapsed
        self.createdAt = createdAt
    }
    
    // MARK: - Cascade Archiving
    
    func archiveCascade(in context: ModelContext) {
        let secID = self.id
        if let tasks = try? context.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.sectionID == secID })) {
            for task in tasks {
                task.archiveCascade(in: context)
            }
        }
        context.delete(self)
    }
}
