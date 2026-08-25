import SwiftUI
import CoreLocation
import AVFoundation

/// Isolated memory domain specifying the storage and synchronization namespace.
public enum MemoryKind: String, Sendable {
    case notes = "Notes"
    case brief = "Project Brief"
    case journal = "Journal"
}

/// Dynamic chrome configuration controlling the visual presentation and accessories of PlutoDocumentEditor.
public struct EditorChromeConfig: Sendable {
    public var dateHeader: Bool
    public var mediaBar: Bool
    public var wordCountFooter: Bool
    public var bookmarkButton: Bool
    public var doneButton: Bool
    public var aaPopover: Bool
    public var calmAtRest: Bool
    public var folderName: String?
    public var isNavigatorVisible: Bool
    public var onToggleNavigator: (@Sendable () -> Void)?
    
    public init(
        dateHeader: Bool = false,
        mediaBar: Bool = false,
        wordCountFooter: Bool = true,
        bookmarkButton: Bool = false,
        doneButton: Bool = false,
        aaPopover: Bool = true,
        calmAtRest: Bool = true,
        folderName: String? = nil,
        isNavigatorVisible: Bool = true,
        onToggleNavigator: (@Sendable () -> Void)? = nil
    ) {
        self.dateHeader = dateHeader
        self.mediaBar = mediaBar
        self.wordCountFooter = wordCountFooter
        self.bookmarkButton = bookmarkButton
        self.doneButton = doneButton
        self.aaPopover = aaPopover
        self.calmAtRest = calmAtRest
        self.folderName = folderName
        self.isNavigatorVisible = isNavigatorVisible
        self.onToggleNavigator = onToggleNavigator
    }
    
    public static let notesDefault = EditorChromeConfig(
        dateHeader: false,
        mediaBar: false,
        wordCountFooter: true,
        bookmarkButton: false,
        doneButton: false,
        aaPopover: true,
        calmAtRest: true
    )
    
    public static let briefDefault = EditorChromeConfig(
        dateHeader: false,
        mediaBar: false,
        wordCountFooter: true,
        bookmarkButton: false,
        doneButton: false,
        aaPopover: true,
        calmAtRest: true
    )
    
    public static let journalDefault = EditorChromeConfig(
        dateHeader: true,
        mediaBar: true,
        wordCountFooter: true,
        bookmarkButton: true,
        doneButton: true,
        aaPopover: true,
        calmAtRest: false
    )
}

/// Unified document editor presentation engine shared across Notes, Project Briefs, and Journal.
/// One supreme presentation engine backed by three mathematically isolated memories.
public struct PlutoDocumentEditor: View {
    
    public let repository: any DocumentCoreRepository
    public let documentID: NoteID
    public let memory: MemoryKind
    public let config: EditorChromeConfig
    public var onKeystrokeMutated: (@Sendable (CRDTDoc) -> Void)?
    
    @Binding public var entryDate: Date
    @Binding public var isBookmarked: Bool
    
    private let autosave = AutosaveCoordinator()
    
    @State private var editorState: EditorBridgeState? = nil
    @State private var lastLocalContentHash: Int = 0
    @State private var isHeaderHovered: Bool = false
    @State private var isFooterHovered: Bool = false
    @State private var showFormattingPopover: Bool = false
    @State private var showDatePopover: Bool = false
    @State private var showSavedToast: Bool = false
    @State private var caretMemory: [UUID: NSRange] = [:]
    
    private static let headerDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, d MMM 'at' h:mm a"
        return f
    }()
    
    public init(
        repository: any DocumentCoreRepository,
        documentID: NoteID,
        memory: MemoryKind = .notes,
        config: EditorChromeConfig = .notesDefault,
        entryDate: Binding<Date> = .constant(Date()),
        isBookmarked: Binding<Bool> = .constant(false),
        onKeystrokeMutated: (@Sendable (CRDTDoc) -> Void)? = nil
    ) {
        self.repository = repository
        self.documentID = documentID
        self.memory = memory
        self.config = config
        self._entryDate = entryDate
        self._isBookmarked = isBookmarked
        self.onKeystrokeMutated = onKeystrokeMutated
    }
    
    private var liveWords: Int {
        guard let state = editorState else { return 0 }
        let text = state.bridge.doc.blocks
            .filter { !$0.isDeleted }
            .map { $0.text.string }
            .joined(separator: " ")
        return text.split { $0.isWhitespace || $0.isNewline }.count
    }
    
    private var liveReadTime: Int {
        max(1, Int(ceil(Double(liveWords) / 200.0)))
    }
    
    public var body: some View {
        Group {
            if let state = editorState {
                VStack(spacing: 0) {
                    // Top Chrome Strip (Header / Media Capsule / Aa Popover)
                    let shouldShowHeader = !config.calmAtRest || state.isFocused || isHeaderHovered || state.currentSelection.length > 0 || showFormattingPopover || showDatePopover
                    
                    if shouldShowHeader {
                        HStack(spacing: 12) {
                            // Left: Date Picker or Navigator Toggle
                            if config.dateHeader {
                                Button {
                                    showDatePopover = true
                                } label: {
                                    HStack(spacing: 5) {
                                        Text(Self.headerDateFormatter.string(from: entryDate))
                                            .font(.system(size: 12.5, weight: .bold))
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 8.5, weight: .bold))
                                            .foregroundStyle(DS.Color.textTertiary)
                                    }
                                }
                                .buttonStyle(.plutoGlass)
                                .popover(isPresented: $showDatePopover) {
                                    VStack(spacing: 10) {
                                        DatePicker("Entry Date & Time", selection: $entryDate, displayedComponents: [.date, .hourAndMinute])
                                            .datePickerStyle(.graphical)
                                            .labelsHidden()
                                        HStack {
                                            Button("Set to Now") {
                                                entryDate = Date()
                                                showDatePopover = false
                                            }
                                            .buttonStyle(.plutoGlass)
                                            .font(.caption)
                                            Spacer()
                                            Button("Done") { showDatePopover = false }
                                                .buttonStyle(.plutoGlassProminent(tint: Color.accentColor))
                                                .controlSize(.small)
                                        }
                                    }
                                    .padding(12)
                                }
                            } else if let onToggle = config.onToggleNavigator, !config.isNavigatorVisible {
                                Button(action: onToggle) {
                                    Image(systemName: "line.3.horizontal")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .buttonStyle(.plutoGlassCircle)
                                .help("Show Sidebar (⌘⌥S)")
                            }
                            
                            if let folder = config.folderName {
                                Text(folder)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.secondary.opacity(0.12), in: Capsule())
                            }
                            
                            Spacer()
                            
                            // Center: Floating Media Capsule
                            if config.mediaBar {
                                PlutoGlassCluster(spacing: 4) {
                                    toolbarCapsuleItem(icon: "text.alignleft", label: "Text Mode", isActive: true) {}
                                    toolbarCapsuleItem(icon: "photo", label: "Photos", isActive: false) {}
                                    toolbarCapsuleItem(icon: "location.north.line.fill", label: "Location", isActive: false) {}
                                    toolbarCapsuleItem(icon: "waveform", label: "Voice Studio", isActive: false) {}
                                }
                                
                                Spacer()
                            }
                            
                            // Right Actions (Aa Typography + Bookmark + Done)
                            HStack(spacing: 8) {
                                if config.aaPopover {
                                    Button {
                                        showFormattingPopover.toggle()
                                    } label: {
                                        HStack(spacing: 3) {
                                            Text("Aa").font(.system(size: 12.5, weight: .bold))
                                            Image(systemName: "pencil.and.outline").font(.system(size: 9.5))
                                        }
                                    }
                                    .buttonStyle(.plutoGlass)
                                    .popover(isPresented: $showFormattingPopover) {
                                        PlutoTypographyPopover(state: state)
                                    }
                                }
                                
                                if config.bookmarkButton {
                                    Button {
                                        isBookmarked.toggle()
                                        Haptics.impact(.light)
                                    } label: {
                                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                                            .font(.system(size: 12))
                                            .foregroundStyle(isBookmarked ? Color.yellow : Color.white.opacity(0.85))
                                    }
                                    .buttonStyle(.plutoGlassCircle(tint: isBookmarked ? Color.yellow.opacity(0.25) : nil))
                                }
                                
                                if config.doneButton {
                                    Button {
                                        showSavedToast = true
                                        Haptics.impact(.rigid)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            showSavedToast = false
                                        }
                                    } label: {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                    .buttonStyle(PlutoGlassButtonStyle(shape: Circle(), tint: Color(red: 0.38, green: 0.45, blue: 0.98), isProminent: true))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(DS.Theme.sidebar)
                        .onHover { isHeaderHovered = $0 }
                        .transition(.move(edge: .top).combined(with: .opacity))
                        
                        Divider().allowsHitTesting(false)
                    }
                    
                    // Main Writing Surface
                    TextKit2EditorRepresentable(
                        state: state,
                        onKeystroke: handleLocalKeystroke,
                        onSelectionChanged: { newSel in
                            caretMemory[documentID.raw] = newSel
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Bottom Status Bar (Word Count & Reading Time)
                    let shouldShowFooter = config.wordCountFooter && (!config.calmAtRest || state.isFocused || isFooterHovered)
                    if shouldShowFooter {
                        HStack {
                            Text("\(liveWords) words • \(liveReadTime) min read")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(DS.Color.textTertiary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 6)
                        .background(DS.Theme.sidebar)
                        .onHover { isFooterHovered = $0 }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .background(DS.Theme.sidebar)
                .animation(.easeInOut(duration: 0.15), value: state.isFocused)
                .animation(.easeInOut(duration: 0.15), value: isHeaderHovered)
                .animation(.easeInOut(duration: 0.15), value: isFooterHovered)
                .overlay(alignment: .bottomTrailing) {
                    if showSavedToast {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Saved")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.85), in: Capsule())
                        .padding(20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: documentID) {
            await loadDocument()
        }
    }
    
    private func toolbarCapsuleItem(icon: String, label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11.5, weight: isActive ? .bold : .medium))
                .frame(width: 14, height: 14)
        }
        .buttonStyle(
            PlutoGlassButtonStyle(
                shape: RoundedRectangle(cornerRadius: 6, style: .continuous),
                tint: isActive ? Color.accentColor : nil,
                isProminent: isActive
            )
        )
        .help(label)
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
