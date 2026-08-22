import SwiftUI
import SwiftData
import AppKit

// MARK: - ProjectViewMode

enum ProjectViewMode: String, CaseIterable, Identifiable {
    case split = "Split View"
    case brief = "Project Brief"
    case tasks = "Tasks & Phases"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .split: return "rectangle.split.2x1"
        case .brief: return "doc.text"
        case .tasks: return "checklist"
        }
    }
}

// MARK: - MacProjectDetailView (Solid PM Command Center)

struct MacProjectDetailView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Bindable var project: WorkProject
    
    @Query private var allSections: [WorkSection]
    @Query(filter: #Predicate<TodoItem> { $0.archivedAt == nil }) private var allTasks: [TodoItem]
    
    @AppStorage("mac_project_view_mode_v2") private var viewModeString: String = "Split View"
    
    @State private var localBriefAttr: NSAttributedString = NSAttributedString()
    @State private var localBriefPlain: String = ""
    @State private var saveWorkItem: DispatchWorkItem? = nil
    
    @State private var isShowingNewSectionModal: Bool = false
    @State private var newSectionTitle: String = ""
    @State private var newTaskTitle: String = ""
    @State private var activeSectionForNewTask: UUID? = nil
    @State private var selectedTaskForDetail: TodoItem? = nil
    @State private var isShowingColorPicker: Bool = false
    
    private var viewMode: Binding<ProjectViewMode> {
        Binding(
            get: { ProjectViewMode(rawValue: viewModeString) ?? .split },
            set: { viewModeString = $0.rawValue }
        )
    }
    
    // Filtered Project Sections
    private var projectSections: [WorkSection] {
        allSections.filter { $0.projectID == project.id }.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    // Filtered Project Tasks
    private var projectTasks: [TodoItem] {
        allTasks.filter { $0.projectID == project.id }
    }
    
    // Progress calculation
    private var completedTasksCount: Int {
        projectTasks.filter { $0.isCompleted }.count
    }
    
    private var totalTasksCount: Int {
        projectTasks.count
    }
    
    private var progressRatio: Double {
        guard totalTasksCount > 0 else { return 0 }
        return Double(completedTasksCount) / Double(totalTasksCount)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // 1. TOP HERO COMMAND BAR
            projectHeroHeader
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color(nsColor: NSColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1.0)))
            
            Divider().opacity(0.25)
            
            // 2. MAIN WORKSPACE VIEWPORT ACCORDING TO VIEW MODE
            ZStack {
                switch viewMode.wrappedValue {
                case .split:
                    splitStudioLayout
                case .brief:
                    briefDocumentOnlyLayout
                case .tasks:
                    tasksPipelineOnlyLayout
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: NSColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1.0)))
        .onAppear {
            loadBrief()
        }
        .onChange(of: project.id) { _, _ in
            loadBrief()
        }
        .sheet(isPresented: $isShowingNewSectionModal) {
            newSectionModal
        }
        .sheet(item: $selectedTaskForDetail) { task in
            taskDetailSheet(task: task)
        }
    }
    
    // MARK: - Project Hero Header
    
    private var projectHeroHeader: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                
                // Icon & Color Badge
                Menu {
                    let colors = ["#3B82F6", "#8B5CF6", "#10B981", "#F59E0B", "#EF4444", "#EC4899", "#6366F1", "#14B8A6"]
                    ForEach(colors, id: \.self) { hex in
                        Button {
                            project.colorHex = hex
                            project.updatedAt = Date()
                            try? modelContext.save()
                        } label: {
                            Label(hex, systemImage: "circle.fill")
                        }
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(Color(hex: project.colorHex).opacity(0.2))
                            .frame(width: 38, height: 38)
                        
                        Image(systemName: project.icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color(hex: project.colorHex))
                    }
                }
                .buttonStyle(.plain)
                .help("Change Project Color")
                
                // Title Field
                VStack(alignment: .leading, spacing: 2) {
                    TextField("Project Title", text: $project.title)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Color.white)
                        .textFieldStyle(.plain)
                    
                    HStack(spacing: 8) {
                        Text("Created \(formatDate(project.createdAt))")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Color.white.opacity(0.4))
                        
                        Text("•")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Color.white.opacity(0.3))
                        
                        Text("\(completedTasksCount)/\(totalTasksCount) done (\(Int(progressRatio * 100))%)")
                            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color(hex: project.colorHex))
                    }
                }
                
                Spacer()
                
                // View Mode Pill Switcher (Split, Brief, Tasks)
                HStack(spacing: 3) {
                    ForEach(ProjectViewMode.allCases) { mode in
                        let isSelected = viewMode.wrappedValue == mode
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewMode.wrappedValue = mode
                            }
                            Haptics.impact(.light)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                Text(mode.rawValue)
                                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                            }
                            .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.6))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                isSelected
                                    ? Color(hex: project.colorHex).opacity(0.85)
                                    : Color.white.opacity(0.04),
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                
                // Export Brief
                Menu {
                    Button {
                        exportBriefPDF()
                    } label: {
                        Label("Export Brief as PDF", systemImage: "arrow.down.doc")
                    }
                    
                    Button {
                        exportBriefMarkdown()
                    } label: {
                        Label("Export Brief as Markdown", systemImage: "doc.text")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.05), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Export Specification")
                
                // Pin Project
                Button {
                    project.isPinned.toggle()
                    project.updatedAt = Date()
                    try? modelContext.save()
                } label: {
                    Image(systemName: project.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 12))
                        .foregroundStyle(project.isPinned ? Color.orange : Color.white.opacity(0.5))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.05), in: Circle())
                }
                .buttonStyle(.plain)
                .help(project.isPinned ? "Unpin Project" : "Pin Project")
                
                // Archive
                Button {
                    project.isArchived.toggle()
                    project.updatedAt = Date()
                    try? modelContext.save()
                } label: {
                    Image(systemName: project.isArchived ? "tray.and.arrow.up.fill" : "archivebox")
                        .font(.system(size: 12))
                        .foregroundStyle(project.isArchived ? Color.accentColor : Color.white.opacity(0.5))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.05), in: Circle())
                }
                .buttonStyle(.plain)
                .help(project.isArchived ? "Restore Project" : "Archive Project")
            }
            
            // Thin Progress Line
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: project.colorHex))
                        .frame(width: geo.size.width * CGFloat(progressRatio), height: 4)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: progressRatio)
                }
            }
            .frame(height: 4)
        }
    }
    
    // MARK: - 🔀 Split Studio Layout (Side-by-Side: Brief on Left, Tasks on Right)
    
    private var splitStudioLayout: some View {
        HSplitView {
            // Left Pane: Full-Height Project Brief Document
            VStack(alignment: .leading, spacing: 0) {
                briefPaneHeader
                Divider().opacity(0.2)
                briefEditorSurface
            }
            .frame(minWidth: 340, idealWidth: 460, maxWidth: .infinity, maxHeight: .infinity)
            
            // Right Pane: Full-Height Tasks & Milestones Pipeline
            VStack(alignment: .leading, spacing: 0) {
                tasksPaneHeader
                Divider().opacity(0.2)
                tasksScrollView
            }
            .frame(minWidth: 320, idealWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: NSColor(red: 0.09, green: 0.09, blue: 0.10, alpha: 1.0)))
        }
    }
    
    // MARK: - 📄 Brief Document Only Layout
    
    private var briefDocumentOnlyLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            briefPaneHeader
            Divider().opacity(0.2)
            briefEditorSurface
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 📋 Tasks Pipeline Only Layout
    
    private var tasksPipelineOnlyLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            tasksPaneHeader
            Divider().opacity(0.2)
            tasksScrollView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Brief Pane Components
    
    private var briefPaneHeader: some View {
        HStack {
            Label("PROJECT SPECIFICATION & BRIEF", systemImage: "doc.text")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.7))
            
            Spacer()
            
            let words = localBriefPlain.split { $0.isWhitespace }.count
            Text("\(words) words")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.35))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.02))
    }
    
    private var briefEditorSurface: some View {
        PlutoDocumentEditor(
            repository: ProjectBriefEngine.shared,
            documentID: NoteID(raw: project.id),
            memory: .brief,
            config: .briefDefault
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Tasks Pane Components
    
    private var tasksPaneHeader: some View {
        HStack {
            Label("EXECUTION PIPELINE", systemImage: "checklist")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.7))
            
            Spacer()
            
            Button {
                newSectionTitle = ""
                isShowingNewSectionModal = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                    Text("Add Phase")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color(hex: project.colorHex))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: project.colorHex).opacity(0.15), in: RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .help("Add Milestone Phase")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.02))
    }
    
    private var tasksScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                
                // 1. Defined Project Phases / Sections
                ForEach(projectSections) { section in
                    sectionCard(section: section)
                }
                
                // 2. Unsectioned / General Tasks
                let unsectionedTasks = projectTasks.filter { $0.sectionID == nil }
                if !unsectionedTasks.isEmpty || projectSections.isEmpty {
                    unsectionedCard(tasks: unsectionedTasks)
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - Section Card
    
    private func sectionCard(section: WorkSection) -> some View {
        let tasks = projectTasks.filter { $0.sectionID == section.id }
        let completed = tasks.filter { $0.isCompleted }.count
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        section.isCollapsed.toggle()
                        try? modelContext.save()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: section.isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.5))
                        
                        Text(section.title)
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                }
                .buttonStyle(.plain)
                
                Text("(\(completed)/\(tasks.count))")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.4))
                
                Spacer()
                
                // Delete Section (preserves tasks)
                Button {
                    for t in tasks {
                        t.sectionID = nil
                    }
                    modelContext.delete(section)
                    try? modelContext.save()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
                .buttonStyle(.plain)
                .help("Delete phase (tasks will be unsectioned)")
            }
            
            if !section.isCollapsed {
                VStack(spacing: 4) {
                    ForEach(tasks) { task in
                        taskRow(task: task)
                    }
                    
                    quickAddTaskRow(sectionID: section.id)
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
    
    // MARK: - Unsectioned Tasks Card
    
    private func unsectionedCard(tasks: [TodoItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(projectSections.isEmpty ? "All Tasks" : "General Tasks")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.85))
                
                Text("(\(tasks.filter { $0.isCompleted }.count)/\(tasks.count))")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.4))
                
                Spacer()
            }
            
            VStack(spacing: 4) {
                ForEach(tasks) { task in
                    taskRow(task: task)
                }
                
                quickAddTaskRow(sectionID: nil)
            }
            .padding(.top, 2)
        }
        .padding(12)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
    
    // MARK: - Task Row
    
    private func taskRow(task: TodoItem) -> some View {
        HStack(spacing: 10) {
            Button {
                if task.isCompleted {
                    task.completedAt = nil
                } else {
                    task.completedAt = Date()
                }
                project.updatedAt = Date()
                try? modelContext.save()
                Haptics.impact(.light)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(task.isCompleted ? Color(hex: project.colorHex) : Color.white.opacity(0.35))
            }
            .buttonStyle(.plain)
            
            Text(task.title)
                .font(.system(size: 12.5))
                .foregroundStyle(task.isCompleted ? Color.white.opacity(0.4) : Color.white)
                .strikethrough(task.isCompleted, color: Color.white.opacity(0.4))
            
            Spacer()
            
            if task.priority > 0 {
                Text("P\(task.priority)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.orange)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.12), in: Capsule())
            }
            
            // Detail Inspection Button
            Button {
                selectedTaskForDetail = task
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
            .buttonStyle(.plain)
            .help("Task Details")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 6))
    }
    
    // MARK: - Quick Add Task Row
    
    private func quickAddTaskRow(sectionID: UUID?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle")
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.3))
            
            TextField("Add task...", text: Binding(
                get: { activeSectionForNewTask == sectionID ? newTaskTitle : "" },
                set: { val in
                    activeSectionForNewTask = sectionID
                    newTaskTitle = val
                }
            ), onCommit: {
                createTask(sectionID: sectionID)
            })
            .font(.system(size: 12))
            .textFieldStyle(.plain)
            .foregroundStyle(Color.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.01), in: RoundedRectangle(cornerRadius: 6))
    }
    
    private func createTask(sectionID: UUID?) {
        guard !newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let item = TodoItem(
            title: newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            projectID: project.id,
            sectionID: sectionID
        )
        modelContext.insert(item)
        project.updatedAt = Date()
        try? modelContext.save()
        newTaskTitle = ""
        activeSectionForNewTask = nil
    }
    
    // MARK: - Modals & Detail Sheets
    
    private var newSectionModal: some View {
        VStack(spacing: 16) {
            Text("Create Phase / Section")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.white)
            
            TextField("Section Name (e.g. Phase 1: Planning)", text: $newSectionTitle)
                .textFieldStyle(.roundedBorder)
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    isShowingNewSectionModal = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Create Phase") {
                    let order = projectSections.count
                    let s = WorkSection(projectID: project.id, title: newSectionTitle.isEmpty ? "New Phase" : newSectionTitle, sortOrder: order)
                    modelContext.insert(s)
                    try? modelContext.save()
                    isShowingNewSectionModal = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 320, height: 160)
        .background(Color.black.opacity(0.85).background(.ultraThinMaterial))
    }
    
    private func taskDetailSheet(task: TodoItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Task Inspector")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white)
                Spacer()
                Button("Done") {
                    selectedTaskForDetail = nil
                }
                .buttonStyle(.borderedProminent)
            }
            
            TextField("Task Title", text: Binding(
                get: { task.title },
                set: { val in
                    task.title = val
                    try? modelContext.save()
                }
            ))
            .font(.system(size: 13.5, weight: .semibold))
            .textFieldStyle(.roundedBorder)
            
            HStack {
                Text("Phase:")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.6))
                
                Picker("Phase", selection: Binding(
                    get: { task.sectionID },
                    set: { newSec in
                        task.sectionID = newSec
                        try? modelContext.save()
                    }
                )) {
                    Text("General (No Phase)").tag(nil as UUID?)
                    ForEach(projectSections) { sec in
                        Text(sec.title).tag(sec.id as UUID?)
                    }
                }
                .labelsHidden()
            }
            
            Text("Notes & Implementation Details")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.6))
            
            TextEditor(text: Binding(
                get: { task.notes ?? "" },
                set: { val in
                    task.notes = val
                    try? modelContext.save()
                }
            ))
            .font(.system(size: 12))
            .padding(8)
            .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
            .frame(height: 120)
        }
        .padding(20)
        .frame(width: 420, height: 320)
        .background(Color.black.opacity(0.85).background(.ultraThinMaterial))
    }
    
    // MARK: - Brief Auto-Save & Sync
    
    private func handleBriefChange(updatedAttr: NSAttributedString, updatedPlain: String) {
        localBriefAttr = updatedAttr
        localBriefPlain = updatedPlain
        project.briefPlainText = updatedPlain
        project.briefRTFData = RichTextTypography.serializeToRTFD(attributedString: updatedAttr)
        
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak modelContext] in
            project.updatedAt = Date()
            try? modelContext?.save()
        }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }
    
    private func loadBrief() {
        if let data = project.briefRTFData, let attr = RichTextTypography.deserializeFromRTFD(data: data) {
            localBriefAttr = attr
            localBriefPlain = attr.string
        } else if !project.briefPlainText.isEmpty {
            let attr = RichTextTypography.convertMarkdownToAttributedString(markdown: project.briefPlainText)
            localBriefAttr = attr
            localBriefPlain = project.briefPlainText
        } else {
            localBriefAttr = NSAttributedString(string: "")
            localBriefPlain = ""
        }
    }
    
    private func exportBriefPDF() {
        DocumentExportService.shared.exportPDF(title: project.title, attributedText: localBriefAttr)
    }
    
    private func exportBriefMarkdown() {
        DocumentExportService.shared.exportMarkdown(title: project.title, attributedText: localBriefAttr)
    }
    
    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df.string(from: date)
    }
}
