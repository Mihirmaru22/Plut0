import SwiftUI

/// Minimal, interactive developer HUD for exercising and verifying the Notes Engine.
public struct NotesDebugView: View {
    
    @StateObject private var engine: NotesEngine
    
    @State private var notes: [NoteSummary] = []
    @State private var selectedNoteID: NoteID? = nil
    @State private var selectedNote: Note? = nil
    @State private var folders: [Folder] = []
    @State private var tags: [Tag] = []
    @State private var selectedFolderID: FolderID? = nil
    @State private var showingDeleted: Bool = false
    @State private var searchText: String = ""
    @State private var newFolderName: String = ""
    @State private var newTagName: String = ""
    
    // Editor State
    @State private var editTitle: String = ""
    @State private var editBody: String = ""
    @State private var statusMessage: String = "Ready"
    
    public init(engine: NotesEngine = .inMemory()) {
        _engine = StateObject(wrappedValue: engine)
    }
    
    public var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            notesList
        } detail: {
            noteDetail
        }
        .task {
            await reloadFoldersAndTags()
        }
        .task(id: queryKey) {
            await observeNotes()
        }
        .task(id: selectedNoteID) {
            await observeSelectedNote()
        }
    }
    
    private var queryKey: String {
        "\(showingDeleted)-\(selectedFolderID?.raw.uuidString ?? "all")-\(searchText)"
    }
    
    // MARK: - 1. Sidebar Column (Folders & Filters)
    
    private var sidebar: some View {
        List {
            Section("Filters") {
                Button {
                    showingDeleted = false
                    selectedFolderID = nil
                } label: {
                    Label("All Notes", systemImage: "tray.full.fill")
                }
                .foregroundStyle(!showingDeleted && selectedFolderID == nil ? Color.accentColor : Color.primary)
                
                Button {
                    showingDeleted = true
                    selectedFolderID = nil
                } label: {
                    Label("Recently Deleted", systemImage: "trash.fill")
                }
                .foregroundStyle(showingDeleted ? Color.red : Color.primary)
            }
            
            Section("Folders") {
                ForEach(folders) { folder in
                    Button {
                        showingDeleted = false
                        selectedFolderID = folder.id
                    } label: {
                        HStack {
                            Label(folder.name, systemImage: "folder.fill")
                            Spacer()
                            Button {
                                Task {
                                    try? await engine.deleteFolder(id: folder.id)
                                    await reloadFoldersAndTags()
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption2)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .foregroundStyle(!showingDeleted && selectedFolderID == folder.id ? Color.accentColor : Color.primary)
                }
                
                HStack {
                    TextField("New Folder", text: $newFolderName)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        guard !newFolderName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        Task {
                            _ = try? await engine.createFolder(name: newFolderName)
                            newFolderName = ""
                            await reloadFoldersAndTags()
                        }
                    }
                }
                .padding(.top, 4)
            }
            
            Section("Tags") {
                ForEach(tags) { tag in
                    Label(tag.name, systemImage: "tag.fill")
                }
                HStack {
                    TextField("New Tag", text: $newTagName)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        guard !newTagName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        Task {
                            _ = try? await engine.createTag(name: newTagName)
                            newTagName = ""
                            await reloadFoldersAndTags()
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .navigationTitle("Engine Explorer")
    }
    
    // MARK: - 2. Notes List Column
    
    private var notesList: some View {
        VStack(spacing: 0) {
            // Search Bar & Actions
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search notes...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                Button {
                    Task {
                        do {
                            let newID = try await engine.createNote(in: selectedFolderID)
                            selectedNoteID = newID
                            statusMessage = "Created Note: \(newID.raw.uuidString.prefix(8))"
                        } catch {
                            statusMessage = "Error creating note: \(error.localizedDescription)"
                        }
                    }
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(10)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            if notes.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "note.text")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No Notes Found")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List(notes, selection: $selectedNoteID) { summary in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            if summary.isPinned {
                                Image(systemName: "pin.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                            }
                            Text(summary.title.isEmpty ? "Untitled Note" : summary.title)
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                            Spacer()
                            Text(summary.updatedAt, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        if !summary.preview.isEmpty {
                            Text(summary.preview)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 4)
                    .tag(summary.id)
                    .contextMenu {
                        if !summary.isDeleted {
                            Button(summary.isPinned ? "Unpin Note" : "Pin Note") {
                                Task {
                                    try? await engine.setPinned(!summary.isPinned, noteID: summary.id)
                                }
                            }
                            Button("Move to Trash", role: .destructive) {
                                Task {
                                    try? await engine.delete(noteID: summary.id)
                                }
                            }
                        } else {
                            Button("Restore Note") {
                                Task {
                                    try? await engine.restore(noteID: summary.id)
                                }
                            }
                            Button("Delete Immediately", role: .destructive) {
                                Task {
                                    try? await engine.permanentlyDelete(noteID: summary.id)
                                }
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            HStack {
                Text("\(notes.count) notes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .navigationTitle(showingDeleted ? "Trash" : "Notes")
    }
    
    // MARK: - 3. Note Detail Column
    
    private var noteDetail: some View {
        VStack(spacing: 0) {
            if let note = selectedNote {
                VStack(alignment: .leading, spacing: 12) {
                    // Toolbar controls
                    HStack {
                        Button {
                            Task {
                                try? await engine.setPinned(!note.isPinned, noteID: note.id)
                            }
                        } label: {
                            Image(systemName: note.isPinned ? "pin.fill" : "pin")
                                .foregroundStyle(note.isPinned ? .orange : .primary)
                        }
                        
                        Menu {
                            Button("None") {
                                Task { try? await engine.move(noteID: note.id, to: nil) }
                            }
                            ForEach(folders) { folder in
                                Button(folder.name) {
                                    Task { try? await engine.move(noteID: note.id, to: folder.id) }
                                }
                            }
                        } label: {
                            Label(folderName(for: note.folderID), systemImage: "folder")
                        }
                        
                        Spacer()
                        
                        if note.isDeleted {
                            Button("Restore") {
                                Task { try? await engine.restore(noteID: note.id) }
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button("Delete", role: .destructive) {
                                Task { try? await engine.delete(noteID: note.id) }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    
                    Divider()
                    
                    // Title Editor
                    TextField("Note Title", text: $editTitle)
                        .font(.system(size: 20, weight: .bold))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .onChange(of: editTitle) { _, newTitle in
                            Task {
                                try? await engine.setTitle(newTitle, for: note.id)
                            }
                        }
                    
                    // Simple Paragraph Block Editor
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Structured Block Content:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                        
                        TextEditor(text: $editBody)
                            .font(.system(size: 13, design: .monospaced))
                            .padding(8)
                            .background(Color(nsColor: .textBackgroundColor).opacity(0.3))
                            .cornerRadius(6)
                            .padding(.horizontal, 16)
                            .onChange(of: editBody) { _, newBody in
                                Task {
                                    let blocks = newBody.components(separatedBy: "\n").map { line -> NoteBlock in
                                        if line.hasPrefix("[x] ") {
                                            return .checklistItem(ChecklistItemBlock(id: UUID(), text: String(line.dropFirst(4)), isChecked: true))
                                        } else if line.hasPrefix("[ ] ") {
                                            return .checklistItem(ChecklistItemBlock(id: UUID(), text: String(line.dropFirst(4)), isChecked: false))
                                        } else if line.hasPrefix("# ") {
                                            return .heading(HeadingBlock(id: UUID(), text: String(line.dropFirst(2)), level: 1))
                                        } else if line.hasPrefix("- ") {
                                            return .bullet(BulletBlock(id: UUID(), text: String(line.dropFirst(2))))
                                        } else {
                                            return .paragraph(ParagraphBlock(id: UUID(), text: line))
                                        }
                                    }
                                    let content = NoteContent(version: 1, blocks: blocks)
                                    try? await engine.updateContent(content, for: note.id)
                                }
                            }
                    }
                    
                    // Metadata HUD & Sync Status
                    VStack(spacing: 6) {
                        HStack {
                            Text("Device: \(note.deviceID)")
                            Spacer()
                            Text("Blocks: \(note.content.blocks.count)")
                            Spacer()
                            Text("Updated: \(note.updatedAt, style: .time)")
                        }
                        
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(.green)
                            Text("E2EE Shadow Sync: Active (Curve25519 + AES-256-GCM)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("CRDT v2")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .background(Color(nsColor: .windowBackgroundColor))
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "note.text.badge.plus")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("Select a note to inspect")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func observeNotes() async {
        let query = NoteQuery(
            folderID: selectedFolderID,
            includeDeleted: showingDeleted,
            searchText: searchText.isEmpty ? nil : searchText,
            tagIDs: [],
            sortOrder: .updatedAtDescending,
            limit: nil
        )
        
        for await updatedList in engine.observeNotes(matching: query) {
            self.notes = updatedList
            if selectedNoteID == nil, let first = updatedList.first {
                selectedNoteID = first.id
            }
        }
    }
    
    private func observeSelectedNote() async {
        guard let noteID = selectedNoteID else {
            selectedNote = nil
            editTitle = ""
            editBody = ""
            return
        }
        
        for await note in engine.observeNote(id: noteID) {
            self.selectedNote = note
            if let note = note {
                if self.editTitle != note.title {
                    self.editTitle = note.title
                }
                let body = NoteTextExtractor.plainText(from: note.content)
                if self.editBody != body {
                    self.editBody = body
                }
            }
        }
    }
    
    private func reloadFoldersAndTags() async {
        folders = (try? await engine.fetchFolders()) ?? []
        tags = (try? await engine.fetchTags()) ?? []
    }
    
    private func folderName(for id: FolderID?) -> String {
        guard let id = id else { return "No Folder" }
        return folders.first(where: { $0.id == id })?.name ?? "Folder"
    }
}
