import SwiftUI
import SwiftData

// MARK: - WorkSubmode

enum WorkSubmode: String, CaseIterable, Identifiable {
    case projects = "Projects & Execution"
    case roadmap  = "Strategic Roadmap"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .projects: return "folder.fill"
        case .roadmap:  return "binoculars.fill"
        }
    }
}

// MARK: - MacWorkWorkspaceView (Unified Work Pillar Command Center)

struct MacWorkWorkspaceView: View {
    
    @Environment(\.modelContext) private var modelContext
    @AppStorage("mac_work_submode_v2") private var submodeString: String = "Projects & Execution"
    
    @Query(sort: [SortDescriptor(\WorkProject.createdAt, order: .reverse)])
    private var allProjects: [WorkProject]
    
    @State private var selectedProjectID: UUID? = nil
    @State private var isShowingCreateProjectModal: Bool = false
    @State private var newProjectTitle: String = ""
    @State private var newProjectIcon: String = "folder.fill"
    @State private var newProjectColorHex: String = "#3B82F6"
    @State private var projectSearchText: String = ""
    
    private var submode: Binding<WorkSubmode> {
        Binding(
            get: { WorkSubmode(rawValue: submodeString) ?? .projects },
            set: { submodeString = $0.rawValue }
        )
    }
    
    private var filteredProjects: [WorkProject] {
        let active = allProjects.filter { !$0.isArchived }
        if projectSearchText.isEmpty {
            return active
        }
        return active.filter { $0.title.localizedCaseInsensitiveContains(projectSearchText) }
    }
    
    private var selectedProject: WorkProject? {
        if let id = selectedProjectID {
            return allProjects.first { $0.id == id }
        }
        return filteredProjects.first
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Top Mode Switcher Bar (Clean Liquid Glass)
            HStack(spacing: 12) {
                PlutoGlassCluster(spacing: 3) {
                    ForEach(WorkSubmode.allCases) { mode in
                        let isSelected = submode.wrappedValue == mode
                        Button {
                            withAnimation(PlutoSpring.snappy) {
                                submode.wrappedValue = mode
                            }
                            Haptics.impact(.light)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                                    .symbolEffect(.bounce, value: isSelected)
                                Text(mode.rawValue)
                                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                            }
                        }
                        .buttonStyle(.plutoGlass(isProminent: isSelected, tint: isSelected ? Color.accentColor : nil))
                    }
                }
                
                Spacer()
                
                if submode.wrappedValue == .projects {
                    Button {
                        newProjectTitle = ""
                        isShowingCreateProjectModal = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                            Text("New Project")
                                .font(.system(size: 12, weight: .bold))
                        }
                    }
                    .buttonStyle(.plutoGlassProminent(tint: Color.accentColor))
                    .help("Create New Project (⌘⇧N)")
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.4).background(.ultraThinMaterial))
            
            Divider().opacity(0.25)
            
            // Main View Switcher
            if submode.wrappedValue == .projects {
                projectsSplitView
            } else {
                MacAuditView()
            }
        }
        .sheet(isPresented: $isShowingCreateProjectModal) {
            createProjectModal
        }
        .onAppear {
            if selectedProjectID == nil, let first = filteredProjects.first {
                selectedProjectID = first.id
            }
        }
    }
    
    // MARK: - Projects Split View
    
    private var projectsSplitView: some View {
        HSplitView {
            // Left Column: Projects Navigator
            VStack(spacing: 0) {
                // Search Bar
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.4))
                    
                    TextField("Search projects...", text: $projectSearchText)
                        .font(.system(size: 12))
                        .textFieldStyle(.plain)
                        .foregroundStyle(Color.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                .padding(10)
                
                Divider().opacity(0.15)
                
                // Projects List
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(filteredProjects) { project in
                            projectCardRow(project: project)
                        }
                    }
                    .padding(10)
                }
            }
            .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
            .background(Color(nsColor: NSColor(red: 0.10, green: 0.10, blue: 0.11, alpha: 1.0)))
            
            // Right Column: Active Project Detail Command Center
            Group {
                if let project = selectedProject {
                    MacProjectDetailView(project: project)
                } else {
                    ContentUnavailableView {
                        Label("No Project Selected", systemImage: "folder")
                    } description: {
                        Text("Create a project to start planning phases, pasting briefs, and managing tasks.")
                    } actions: {
                        Button("Create Project") {
                            isShowingCreateProjectModal = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Project Card Row
    
    private func projectCardRow(project: WorkProject) -> some View {
        let isSelected = selectedProject?.id == project.id
        
        return Button {
            selectedProjectID = project.id
            Haptics.impact(.light)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: project.colorHex).opacity(0.18))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: project.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: project.colorHex))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(project.title)
                            .font(.system(size: 12.5, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.85))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if project.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.orange)
                        }
                    }
                    
                    Text(project.briefPlainText.isEmpty ? "No brief" : project.briefPlainText)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? Color.white.opacity(0.12)
                    : Color.white.opacity(0.02),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.white.opacity(0.2) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Create Project Modal
    
    private var createProjectModal: some View {
        VStack(spacing: 16) {
            Text("Create New Project")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.white)
            
            TextField("Project Name (e.g. Mobile App Redesign)", text: $newProjectTitle)
                .textFieldStyle(.roundedBorder)
            
            HStack(spacing: 8) {
                Text("Theme Color:")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.7))
                
                let colors = ["#3B82F6", "#8B5CF6", "#10B981", "#F59E0B", "#EF4444", "#EC4899"]
                ForEach(colors, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: newProjectColorHex == hex ? 2 : 0)
                        )
                        .onTapGesture {
                            newProjectColorHex = hex
                        }
                }
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    isShowingCreateProjectModal = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Create Project") {
                    let title = newProjectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    let p = WorkProject(
                        title: title.isEmpty ? "New Project" : title,
                        icon: "folder.fill",
                        colorHex: newProjectColorHex
                    )
                    modelContext.insert(p)
                    try? modelContext.save()
                    selectedProjectID = p.id
                    isShowingCreateProjectModal = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360, height: 190)
        .background(Color.black.opacity(0.85).background(.ultraThinMaterial))
    }
}
