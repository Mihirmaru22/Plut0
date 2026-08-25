import SwiftUI

/// Configuration properties customizing the chrome and behaviors of DocumentEditorView.
public struct EditorConfig: Sendable {
    public var showPin: Bool
    public var showFolderPill: Bool
    public var showMoveToFolder: Bool
    public var markdownMagic: Bool
    public var wordCount: Bool
    public var folderName: String?
    public var isNavigatorVisible: Bool
    public var onToggleNavigator: (@Sendable () -> Void)?
    
    public init(
        showPin: Bool = false,
        showFolderPill: Bool = false,
        showMoveToFolder: Bool = false,
        markdownMagic: Bool = true,
        wordCount: Bool = false,
        folderName: String? = nil,
        isNavigatorVisible: Bool = true,
        onToggleNavigator: (@Sendable () -> Void)? = nil
    ) {
        self.showPin = showPin
        self.showFolderPill = showFolderPill
        self.showMoveToFolder = showMoveToFolder
        self.markdownMagic = markdownMagic
        self.wordCount = wordCount
        self.folderName = folderName
        self.isNavigatorVisible = isNavigatorVisible
        self.onToggleNavigator = onToggleNavigator
    }
    
    public static let notesDefault = EditorConfig(showPin: true, showFolderPill: true, showMoveToFolder: true, markdownMagic: true, wordCount: false)
    public static let projectBrief = EditorConfig(showPin: false, showFolderPill: false, showMoveToFolder: false, markdownMagic: true, wordCount: true)
}

/// Universal, storage-agnostic native document editor engine shared by Notes and Studio Project Briefs.
public struct DocumentEditorView: View {
    
    public let repository: any DocumentCoreRepository
    public let documentID: NoteID
    public let config: EditorConfig
    public var onKeystrokeMutated: (@Sendable (CRDTDoc) -> Void)?
    
    private let autosave = AutosaveCoordinator()
    
    @State private var editorState: EditorBridgeState? = nil
    @State private var lastLocalContentHash: Int = 0
    @State private var isToolbarHovered: Bool = false
    @State private var caretMemory: [UUID: NSRange] = [:]
    
    public init(
        repository: any DocumentCoreRepository,
        documentID: NoteID,
        config: EditorConfig = .notesDefault,
        onKeystrokeMutated: (@Sendable (CRDTDoc) -> Void)? = nil
    ) {
        self.repository = repository
        self.documentID = documentID
        self.config = config
        self.onKeystrokeMutated = onKeystrokeMutated
    }
    
    private var liveWordCount: Int {
        guard let state = editorState else { return 0 }
        let text = state.bridge.doc.blocks
            .filter { !$0.isDeleted }
            .map { $0.text.string }
            .joined(separator: " ")
        return text.split { $0.isWhitespace || $0.isNewline }.count
    }
    
    public var body: some View {
        Group {
            if let state = editorState {
                VStack(spacing: 0) {
                    // Optional Header (Navigator burger toggle or folder chip)
                    if (!config.isNavigatorVisible || config.folderName != nil) && (config.showFolderPill || config.onToggleNavigator != nil) {
                        NoteCanvasHeaderView(
                            folderName: config.folderName,
                            isNavigatorVisible: config.isNavigatorVisible,
                            onToggleNavigator: { config.onToggleNavigator?() }
                        )
                    }
                    
                    // Contextual Formatting Toolbar Strip (fades/rises on focus or hover)
                    let isToolbarVisible = state.isFocused || isToolbarHovered || state.currentSelection.length > 0
                    if isToolbarVisible {
                        HStack(spacing: 12) {
                            if config.wordCount {
                                Text("\(liveWordCount) words")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 8)
                            }
                            
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
                        .background(DS.Theme.sidebar)
                        .onHover { isToolbarHovered = $0 }
                        .transition(.move(edge: .top).combined(with: .opacity))
                        
                        Divider()
                            .allowsHitTesting(false)
                    }
                    
                    // Calm Writing Surface
                    TextKit2EditorRepresentable(
                        state: state,
                        onKeystroke: handleLocalKeystroke,
                        onSelectionChanged: { newSel in
                            caretMemory[documentID.raw] = newSel
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(DS.Theme.sidebar)
                .animation(.easeInOut(duration: 0.15), value: state.isFocused)
                .animation(.easeInOut(duration: 0.15), value: isToolbarHovered)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: documentID) {
            await loadDocument()
        }
    }
    
    private func handleLocalKeystroke(_ doc: CRDTDoc) {
        let serialized = CRDTTranslator.materializeContent(from: doc)
        self.lastLocalContentHash = serialized.hashValue
        onKeystrokeMutated?(doc)
        
        Task {
            await autosave.scheduleAutosave(noteID: doc.id, content: serialized, repository: repository)
        }
    }
    
    private func loadDocument() async {
        if let initialNote = try? await repository.fetchDocument(id: documentID) {
            let doc = CRDTTranslator.crdtDoc(from: initialNote)
            let bridge = TextKitCRDTBridge(doc: doc)
            let state = EditorBridgeState(bridge: bridge)
            if let savedCaret = caretMemory[documentID.raw] {
                state.updateSelection(savedCaret)
            }
            self.editorState = state
        } else {
            let emptyDoc = CRDTDoc(id: documentID)
            let bridge = TextKitCRDTBridge(doc: emptyDoc)
            let state = EditorBridgeState(bridge: bridge)
            self.editorState = state
        }
        
        for await note in repository.observeDocument(id: documentID) {
            guard let note = note else { continue }
            if note.content.hashValue == self.lastLocalContentHash {
                continue
            }
            
            let doc = CRDTTranslator.crdtDoc(from: note)
            if let existingState = self.editorState, existingState.bridge.doc.id == doc.id {
                let currentCRDT = CRDTTranslator.materializeContent(from: existingState.bridge.doc)
                if currentCRDT == note.content {
                    continue
                }
                existingState.updateDocFromRemote(doc)
            } else {
                let bridge = TextKitCRDTBridge(doc: doc)
                let state = EditorBridgeState(bridge: bridge)
                if let savedCaret = caretMemory[documentID.raw] {
                    state.updateSelection(savedCaret)
                }
                self.editorState = state
            }
        }
    }
}
