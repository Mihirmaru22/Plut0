import SwiftUI

/// Main native macOS 2-Column user interface combining the Navigator (Left) and DocumentEditorView (Right).
public struct NotesCanvasView: View {
    
    @ObservedObject public var engine: NotesEngine
    
    @AppStorage("notes_last_opened_note_id") private var lastOpenedNoteIDString: String = ""
    
    // Navigator state
    @State private var isNavigatorVisible: Bool = true
    @State private var searchText: String = ""
    @State private var selectedFolderID: FolderID? = nil
    @State private var showingDeleted: Bool = false
    @State private var selectedNoteID: NoteID? = nil
    
    @State private var notes: [NoteSummary] = []
    @State private var folders: [Folder] = []
    
    // Active Editor metadata
    @State private var activeNoteIsPinned: Bool = false
    @State private var activeNoteFolderID: FolderID? = nil
    
    // Quick Switcher (Cmd+K)
    @State private var isQuickSwitcherPresented: Bool = false
    
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
                    onCreateNote: { createNewNote() },
                    onDeleteNote: deleteNote,
                    onTogglePinNote: togglePinNote,
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
        .overlay {
            if isQuickSwitcherPresented {
                QuickSwitcherView(
                    isPresented: $isQuickSwitcherPresented,
                    notes: notes,
                    onSelectNote: { id in
                        self.selectedNoteID = id
                    },
                    onCreateNoteWithTitle: { title in
                        createNewNote(withTitle: title)
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .background {
            Button("") {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isQuickSwitcherPresented.toggle()
                }
            }
            .keyboardShortcut("k", modifiers: .command)
            .opacity(0)
            .allowsHitTesting(false)
        }
        .task {
            await reloadFolders()
            NotesSpotlightIndexer.shared.startObserving(engine: engine)
        }
        .task(id: queryKey) {
            await observeNotesList()
        }
        .task(id: selectedNoteID) {
            if let id = selectedNoteID {
                lastOpenedNoteIDString = id.raw.uuidString
            }
            await loadSelectedNote()
        }
        .onAppear {
            if selectedNoteID == nil && !lastOpenedNoteIDString.isEmpty {
                if let uuid = UUID(uuidString: lastOpenedNoteIDString) {
                    selectedNoteID = NoteID(raw: uuid)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .plutoOpenNote)) { note in
            if let noteID = note.object as? NoteID {
                self.selectedNoteID = noteID
            }
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
        if let noteID = selectedNoteID {
            PlutoDocumentEditor(
                repository: engine.repository,
                documentID: noteID,
                memory: .notes,
                config: EditorChromeConfig(
                    dateHeader: false,
                    mediaBar: false,
                    wordCountFooter: true,
                    bookmarkButton: false,
                    doneButton: false,
                    aaPopover: true,
                    calmAtRest: true,
                    folderName: folderName(for: activeNoteFolderID),
                    isNavigatorVisible: isNavigatorVisible,
                    onToggleNavigator: { toggleNavigator() }
                ),
                onKeystrokeMutated: { doc in
                    handleLocalKeystroke(doc)
                }
            )
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
                Button("Create Note") {
                    createNewNote()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut("n", modifiers: .command)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Keystroke & Mutation Handlers
    
    private func handleLocalKeystroke(_ doc: CRDTDoc) {
        let serialized = CRDTTranslator.materializeContent(from: doc)
        let derivedTitle = NotePreviewGenerator.deriveTitle(from: serialized)
        let derivedPreview = NotePreviewGenerator.derivePreview(from: serialized)
        NotesSpotlightIndexer.shared.indexNote(id: doc.id, title: derivedTitle, preview: derivedPreview, content: serialized)
    }
    
    private func togglePinCurrentNote() {
        guard let noteID = selectedNoteID else { return }
        togglePinNote(noteID)
    }
    
    private func togglePinNote(_ noteID: NoteID) {
        let newPinned = !activeNoteIsPinned
        activeNoteIsPinned = newPinned
        Task {
            try? await engine.updateNote(id: noteID, isPinned: newPinned)
            await reloadNotes()
        }
    }
    
    // MARK: - CRUD Helpers
    
    private func createNewNote(withTitle title: String = "") {
        Task {
            do {
                let note = try await engine.createNote(title: title, folderID: selectedFolderID)
                if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let initialContent = NoteContent(version: 1, blocks: [.paragraph(ParagraphBlock(text: title))])
                    try await engine.updateContent(initialContent, for: note.id)
                }
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
                NotesSpotlightIndexer.shared.deindexNote(id: noteID)
                if selectedNoteID == noteID {
                    selectedNoteID = nil
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
                // Reversible: move notes in folder to all notes, delete folder
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
        guard let noteID = selectedNoteID else { return }
        if let initialNote = try? await engine.fetchNote(id: noteID) {
            self.activeNoteIsPinned = initialNote.isPinned
            self.activeNoteFolderID = initialNote.folderID
        }
    }
}
