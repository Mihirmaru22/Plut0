import Foundation
import SwiftData
import SwiftUI

// MARK: - EmptyStateSeeder (First-Launch Guided Onboarding & Sample Data)

@MainActor
public final class EmptyStateSeeder {
    
    public static let shared = EmptyStateSeeder()
    private init() {}
    
    public func seedInitialDataIfNeeded(context: ModelContext) {
        let hasSeeded = UserDefaults.standard.bool(forKey: "has_seeded_initial_loca_workspace_v2")
        guard !hasSeeded else { return }
        
        // Seed Sample Work Project
        seedSampleProject(context: context)
        
        UserDefaults.standard.set(true, forKey: "has_seeded_initial_loca_workspace_v2")
        try? context.save()
    }
    
    private func seedSampleProject(context: ModelContext) {
        let briefText = """
# Project Goal & Overview

Build a focused, distraction-free environment to achieve peak productivity and calm consistency.

## Deliverables
- Clear task milestones
- Daily progress tracking
- Seamless reflection
"""
        let briefAttr = RichTextTypography.convertMarkdownToAttributedString(markdown: briefText)
        let project = WorkProject(
            title: "🚀 Launching My First Project",
            icon: "paperplane.fill",
            colorHex: "#8B5CF6",
            briefPlainText: briefText,
            briefRTFData: RichTextTypography.serializeToRTFD(attributedString: briefAttr),
            isPinned: true
        )
        context.insert(project)
        
        let sec1 = WorkSection(projectID: project.id, title: "Phase 1: Planning", sortOrder: 0)
        let sec2 = WorkSection(projectID: project.id, title: "Phase 2: Execution", sortOrder: 1)
        context.insert(sec1)
        context.insert(sec2)
        
        let t1 = TodoItem(title: "Define core project milestones", projectID: project.id, sectionID: sec1.id, completedAt: Date())
        let t2 = TodoItem(title: "Paste specification into project brief", projectID: project.id, sectionID: sec1.id, completedAt: Date())
        let t3 = TodoItem(title: "Check off your first task in execution", projectID: project.id, sectionID: sec2.id)
        
        context.insert(t1)
        context.insert(t2)
        context.insert(t3)
    }
}
