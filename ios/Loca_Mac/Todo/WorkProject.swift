import Foundation
import SwiftData

// MARK: - WorkProject (@Model)

@Model
final class WorkProject {
    
    // MARK: Identity & Ordering
    
    var id: UUID = UUID()
    var title: String = "Untitled Project"
    var icon: String = "folder"
    var colorHex: String = "#3B82F6"
    var sortOrder: Int = 0
    
    // MARK: Project Brief (Rich Text Spec/Scope)
    
    var briefPlainText: String = ""
    var briefRTFData: Data? = nil
    
    // MARK: Metadata & Lifecycle
    
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var targetDate: Date? = nil
    
    var isPinned: Bool = false
    var isArchived: Bool = false
    
    init(
        id: UUID = UUID(),
        title: String = "Untitled Project",
        icon: String = "folder",
        colorHex: String = "#3B82F6",
        sortOrder: Int = 0,
        briefPlainText: String = "",
        briefRTFData: Data? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        targetDate: Date? = nil,
        isPinned: Bool = false,
        isArchived: Bool = false
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.briefPlainText = briefPlainText
        self.briefRTFData = briefRTFData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.targetDate = targetDate
        self.isPinned = isPinned
        self.isArchived = isArchived
    }
    
    // MARK: - Cascade Archiving
    
    func archiveCascade(in context: ModelContext) {
        self.isArchived = true
        self.updatedAt = Date()
        let projID = self.id
        
        // 1. Cascade archive child sections
        if let sections = try? context.fetch(FetchDescriptor<WorkSection>(predicate: #Predicate { $0.projectID == projID })) {
            for section in sections {
                section.archiveCascade(in: context)
            }
        }
        
        // 2. Cascade archive child tasks
        if let tasks = try? context.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.projectID == projID })) {
            for task in tasks {
                task.archiveCascade(in: context)
            }
        }
    }
}
