import SwiftUI

/// Main native macOS 2-Column user interface combining the Navigator (Left) and TextKit 2 Editor Canvas (Right).
public struct NotesCanvasView: View {
    
    @ObservedObject public var engine: NotesEngine
    private let autosave = AutosaveCoordinator()
    
    // Navigator state
    @State private var isNavigatorVisible: Bool = true
    @State private var searchText: String = ""
    @State private var selectedFolderID: FolderID? = nil
    @State private var showingDeleted: Bool = false
    @State private var selectedNoteID: NoteID? = nil
    
    @State private var notes: [NoteSummary] = []
    @State private var folders: [Folder] = []
    
    // Active Editor state
    @State private var activeNoteTitle: String = ""
    @State private var activeNoteIsPinned: Bool = false
    @State private var activeNoteFolderID: FolderID? = nil
    @State private var editorState: EditorBridgeState? = nil
    @State private var lastLocalContentHash: Int = 0
    
    public init(engine: NotesEngine = NotesEngine.shared) {
        self.engine = engine
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            // Column 1: Navigator (Middle Menu)
            if isNavigatorVisible {
                NotesNavigatorView(
                    searchText: $searchText,
                    selectedFolderID: $selectedFolderID,
                    showingDeleted: $showingDeleted,
                    selectedNoteID: $selectedNoteID,
                    notes: notes,
                    folders: folders,
                    onCreateNote: createNewNote,
                    onDeleteNote: deleteNote,
                    onCreateFolderWithName: createFolder,
                    onDeleteFolder: deleteFolder,
                    onToggleCollapse: toggleNavigator
                )
                .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                
                // 1px Machined Boundary Divider
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.3))
                    .frame(width: 1)
                    .allowsHitTesting(false)
            }
            
            // Column 2: Editor Canvas (Right)
            editorColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            await reloadFolders()
        }
        .task(id: queryKey) {
            await observeNotesList()
        }
        .task(id: selectedNoteID) {
            await loadSelectedNote()
        }
    }
    
    private func toggleNavigator() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isNavigatorVisible.toggle()
        }
    }
    
    private var queryKey: String {
        "\(showingDeleted)-\(selectedFolderID?.raw.uuidString ?? "all")-\(searchText)"
    }
    
    // MARK: - Column 2: Editor Canvas
    
    @ViewBuilder
    private var editorColumn: some View {
        if let state = editorState, selectedNoteID != nil {
            VStack(spacing: 0) {
                // Header with Burger Sidebar Toggle
                NoteCanvasHeaderView(
                    title: $activeNoteTitle,
                    folderName: folderName(for: activeNoteFolderID),
                    isPinned: activeNoteIsPinned,
                    isNavigatorVisible: isNavigatorVisible,
                    onToggleNavigator: toggleNavigator,
                    onTogglePin: togglePinCurrentNote,
                    onTitleChanged: handleTitleChanged
                )
                
                Divider()
                    .allowsHitTesting(false)
                
                // Formatting Toolbar Strip
                HStack {
                    Spacer()
                    NotesFormattingToolbar(
                        state: state.formattingState,
                        onToggleBold: {
                            state.toggleBold()
                            handleLocalKeystroke(state.bridge.doc)
                        },
                        onToggleItalic: {
                            state.toggleItalic()
                            handleLocalKeystroke(state.bridge.doc)
                        },
                        onToggleBlockType: { blockType in
                            state.toggleBlockType(blockType)
                            handleLocalKeystroke(state.bridge.doc)
                        }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.35))
                
                Divider()
                    .allowsHitTesting(false)
                
                // Editor Body
                TextKit2EditorRepresentable(
                    state: state,
                    onKeystroke: handleLocalKeystroke,
                    onSelectionChanged: { _ in }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(nsColor: .textBackgroundColor))
        } else {
            emptyCanvasPlaceholder
        }
    }
    
    private var emptyCanvasPlaceholder: some View {
        VStack(spacing: 0) {
            if !isNavigatorVisible {
                HStack {
                    Button(action: toggleNavigator) {
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 13, weight: .medium))
                            Text("Show Notes List")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help("Show Notes List (⌘⌥S)")
                    
                    Spacer()
                }
                .padding(16)
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Image(systemName: "note.text")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                Text("No Note Selected")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                Button("Create New Note", action: createNewNote)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Keystroke & Mutation Handlers
    
    private func handleLocalKeystroke(_ doc: CRDTDoc) {
        let serialized = CRDTTranslator.materializeContent(from: doc)
        self.lastLocalContentHash = serialized.hashValue
        autosave.scheduleAutosave(noteID: doc.id, title: activeNoteTitle, content: serialized, engine: engine)
    }
    
    private func handleTitleChanged(_ newTitle: String) {
        guard let noteID = selectedNoteID else { return }
        if let state = editorState {
            state.bridge.doc.title = newTitle
            let serialized = CRDTTranslator.materializeContent(from: state.bridge.doc)
            self.lastLocalContentHash = serialized.hashValue
            autosave.scheduleAutosave(noteID: noteID, title: newTitle, content: serialized, engine: engine)
        } else {
            Task {
                try? await engine.updateNote(id: noteID, title: newTitle)
            }
        }
    }
    
    private func togglePinCurrentNote() {
        guard let noteID = selectedNoteID else { return }
        let newPinned = !activeNoteIsPinned
        activeNoteIsPinned = newPinned
        if let state = editorState {
            state.bridge.doc.isPinned = newPinned
            let serialized = CRDTTranslator.materializeContent(from: state.bridge.doc)
            self.lastLocalContentHash = serialized.hashValue
            autosave.scheduleAutosave(noteID: noteID, title: activeNoteTitle, isPinned: newPinned, content: serialized, engine: engine)
        }
    }
    
    // MARK: - CRUD Helpers
    
    private func createNewNote() {
        Task {
            do {
                let note = try await engine.createNote(title: "New Note", folderID: selectedFolderID)
                self.selectedNoteID = note.id
                await reloadNotes()
            } catch {
                // handled gracefully
            }
        }
    }
    
    private func deleteNote(_ noteID: NoteID) {
        Task {
            do {
                try await engine.deleteNote(id: noteID)
                if selectedNoteID == noteID {
                    selectedNoteID = nil
                    editorState = nil
                }
                await reloadNotes()
            } catch {
                // handled gracefully
            }
        }
    }
    
    private func createFolder(name: String) {
        Task {
            do {
                _ = try await engine.createFolder(name: name)
                await reloadFolders()
            } catch {
                // handled gracefully
            }
        }
    }
    
    private func deleteFolder(_ folderID: FolderID) {
        Task {
            do {
                try await engine.deleteFolder(id: folderID)
                if selectedFolderID == folderID {
                    selectedFolderID = nil
                }
                await reloadFolders()
                await reloadNotes()
            } catch {
                // handled gracefully
            }
        }
    }
    
    // MARK: - Data Loaders
    
    private func folderName(for id: FolderID?) -> String? {
        guard let id = id else { return nil }
        return folders.first(where: { $0.id == id })?.name
    }
    
    private func reloadFolders() async {
        do {
            self.folders = try await engine.fetchFolders()
        } catch {
            self.folders = []
        }
    }
    
    private func reloadNotes() async {
        do {
            let fetched = try await engine.fetchNotes(folderID: selectedFolderID, includeDeleted: showingDeleted)
            if !searchText.isEmpty {
                self.notes = fetched.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.preview.localizedCaseInsensitiveContains(searchText) }
            } else {
                self.notes = fetched
            }
        } catch {
            self.notes = []
        }
    }
    
    private func observeNotesList() async {
        for await notesList in engine.observeNotes(folderID: selectedFolderID, includeDeleted: showingDeleted) {
            if !searchText.isEmpty {
                self.notes = notesList.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.preview.localizedCaseInsensitiveContains(searchText) }
            } else {
                self.notes = notesList
            }
            
            // Auto-select first note if none selected
            if self.selectedNoteID == nil, let first = self.notes.first {
                self.selectedNoteID = first.id
            }
        }
    }
    
    private func loadSelectedNote() async {
        guard let noteID = selectedNoteID else {
            editorState = nil
            return
        }
        
        // Immediate synchronous fetch for instant transition
        if let initialNote = try? await engine.fetchNote(id: noteID) {
            self.activeNoteTitle = initialNote.title
            self.activeNoteIsPinned = initialNote.isPinned
            self.activeNoteFolderID = initialNote.folderID
            
            let doc = CRDTTranslator.crdtDoc(from: initialNote)
            let bridge = TextKitCRDTBridge(doc: doc)
            self.editorState = EditorBridgeState(bridge: bridge)
        }
        
        for await note in engine.observeNote(id: noteID) {
            guard let note = note else { continue }
            self.activeNoteTitle = note.title
            self.activeNoteIsPinned = note.isPinned
            self.activeNoteFolderID = note.folderID
            
            // Kill autosave self-echo
            if note.content.hashValue == self.lastLocalContentHash {
                continue
            }
            
            let doc = CRDTTranslator.crdtDoc(from: note)
            if let existingState = self.editorState, existingState.bridge.doc.id == doc.id {
                let currentCRDTContent = CRDTTranslator.materializeContent(from: existingState.bridge.doc)
                if currentCRDTContent == note.content {
                    continue
                }
                existingState.updateDocFromRemote(doc)
            } else {
                let bridge = TextKitCRDTBridge(doc: doc)
                self.editorState = EditorBridgeState(bridge: bridge)
            }
        }
    }
}
