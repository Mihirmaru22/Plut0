import SwiftUI

// MARK: - QuickSwitcherViewModel

/// State model and business logic for Quick Switcher (Cmd+K) search, index clamping, and keyboard navigation.
public final class QuickSwitcherViewModel: ObservableObject {
    @Published public var allNotes: [NoteSummary] = []
    
    @Published public var query: String = "" {
        didSet {
            selectedIndex = 0
            updateFilteredNotes()
        }
    }
    
    @Published public var results: [NoteSummary] = [] {
        didSet {
            clampIndex()
        }
    }
    
    @Published public var selectedIndex: Int = 0
    
    public init(notes: [NoteSummary] = []) {
        self.allNotes = notes
        self.results = notes.isEmpty ? [] : Array(notes.prefix(8))
        self.selectedIndex = 0
    }
    
    public func setNotes(_ notes: [NoteSummary]) {
        self.allNotes = notes
        updateFilteredNotes()
    }
    
    public func updateFilteredNotes() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            self.results = Array(allNotes.prefix(8))
        } else {
            self.results = allNotes.filter {
                $0.title.localizedCaseInsensitiveContains(trimmed) ||
                $0.preview.localizedCaseInsensitiveContains(trimmed)
            }
        }
    }
    
    public func clampIndex() {
        if results.isEmpty {
            selectedIndex = 0
        } else if selectedIndex >= results.count {
            selectedIndex = max(0, results.count - 1)
        } else if selectedIndex < 0 {
            selectedIndex = 0
        }
    }
    
    public func moveSelectionUp() {
        guard !results.isEmpty else {
            selectedIndex = 0
            return
        }
        selectedIndex = max(0, selectedIndex - 1)
    }
    
    public func moveSelectionDown() {
        guard !results.isEmpty else {
            selectedIndex = 0
            return
        }
        selectedIndex = min(results.count - 1, selectedIndex + 1)
    }
    
    @discardableResult
    public func activateSelected() -> NoteSummary? {
        clampIndex()
        guard !results.isEmpty, selectedIndex >= 0, selectedIndex < results.count else {
            return nil
        }
        return results[selectedIndex]
    }
}

// MARK: - QuickSwitcherView

/// Floating command palette (Cmd+K) providing ultra-fast note searching, keyboard navigation, and creation.
public struct QuickSwitcherView: View {
    
    @Binding public var isPresented: Bool
    public let notes: [NoteSummary]
    public let onSelectNote: (NoteID) -> Void
    public let onCreateNoteWithTitle: (String) -> Void
    
    @StateObject private var viewModel: QuickSwitcherViewModel
    @FocusState private var isFieldFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init(
        isPresented: Binding<Bool>,
        notes: [NoteSummary],
        onSelectNote: @escaping (NoteID) -> Void,
        onCreateNoteWithTitle: @escaping (String) -> Void
    ) {
        self._isPresented = isPresented
        self.notes = notes
        self.onSelectNote = onSelectNote
        self.onCreateNoteWithTitle = onCreateNoteWithTitle
        self._viewModel = StateObject(wrappedValue: QuickSwitcherViewModel(notes: notes))
    }
    
    @Namespace private var paletteSelectionNamespace

    public var body: some View {
        ZStack {
            // Dismiss background overlay
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            // Centered Floating Palette (Prominent Liquid Glass Panel)
            VStack(spacing: 0) {
                // Search Input Header
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(DS.Theme.amber)
                    
                    TextField("Search notes or type to create...", text: $viewModel.query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .focused($isFieldFocused)
                        .onSubmit {
                            commitSelection()
                        }
                    
                    if !viewModel.query.isEmpty {
                        Button {
                            viewModel.query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text("ESC")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .foregroundStyle(DS.Theme.textTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                
                Divider()
                    .opacity(0.12)
                
                // Search Results
                let results = viewModel.results
                if !results.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 3) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, note in
                                let isSelected = index == viewModel.selectedIndex
                                Button {
                                    viewModel.selectedIndex = index
                                    commitSelection()
                                } label: {
                                    HStack(spacing: 8) {
                                        if note.isPinned {
                                            Image(systemName: "pin.fill")
                                                .font(.system(size: 10))
                                                .foregroundStyle(DS.Theme.amber)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(note.title.isEmpty ? "New Note" : note.title)
                                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                                .foregroundStyle(isSelected ? Color.black.opacity(0.92) : Color.white)
                                                .lineLimit(1)
                                            
                                            if !note.preview.isEmpty {
                                                Text(note.preview)
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(isSelected ? Color.black.opacity(0.7) : Color.white.opacity(0.6))
                                                    .lineLimit(1)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        if isSelected {
                                            Image(systemName: "return")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(Color.black.opacity(0.85))
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background {
                                        if isSelected {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [Color(white: 0.98), Color(white: 0.90)],
                                                        startPoint: .top,
                                                        endPoint: .bottom
                                                     )
                                                )
                                                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.white.opacity(0.9), lineWidth: 1))
                                                .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
                                                .matchedGeometryEffect(id: "paletteSelectionPill", in: paletteSelectionNamespace)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 280)
                } else if !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Create New Note Affordance
                    Button {
                        commitSelection()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(DS.Theme.amber)
                            Text("Create note \"\(viewModel.query)\"")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "return")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(DS.Theme.amber)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .plutoGlass(.interactive, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                } else {
                    Text("No notes found")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(24)
                }
            }
            .frame(width: 520)
            .plutoGlass(.prominent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.black.opacity(0.35), radius: 28, x: 0, y: 14)
            .transition(.scale(scale: 0.96).combined(with: .opacity))
        }
        .onAppear {
            isFieldFocused = true
            viewModel.clampIndex()
        }
        .onExitCommand {
            isPresented = false
        }
        .onKeyPress(.upArrow) {
            viewModel.moveSelectionUp()
            return .handled
        }
        .onKeyPress(.downArrow) {
            viewModel.moveSelectionDown()
            return .handled
        }
        .onKeyPress(.return) {
            commitSelection()
            return .handled
        }
        .onChange(of: notes) { _, newNotes in
            viewModel.setNotes(newNotes)
        }
    }
    
    private func commitSelection() {
        if let selected = viewModel.activateSelected() {
            onSelectNote(selected.id)
            isPresented = false
        } else {
            let trimmed = viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                onCreateNoteWithTitle(trimmed)
                isPresented = false
            }
        }
    }
}
