import SwiftUI

/// Floating command palette (Cmd+K) providing ultra-fast note searching, keyboard navigation, and creation.
public struct QuickSwitcherView: View {
    
    @Binding public var isPresented: Bool
    public let notes: [NoteSummary]
    public let onSelectNote: (NoteID) -> Void
    public let onCreateNoteWithTitle: (String) -> Void
    
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
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
    }
    
    private var filteredNotes: [NoteSummary] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return Array(notes.prefix(8))
        }
        return notes.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed) ||
            $0.preview.localizedCaseInsensitiveContains(trimmed)
        }
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
                    
                    TextField("Search notes or type to create...", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .focused($isFieldFocused)
                        .onSubmit {
                            commitSelection()
                        }
                    
                    if !query.isEmpty {
                        Button {
                            query = ""
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
                let results = filteredNotes
                if !results.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 3) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, note in
                                let isSelected = index == selectedIndex
                                Button {
                                    onSelectNote(note.id)
                                    isPresented = false
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
                } else if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Create New Note Affordance
                    Button {
                        onCreateNoteWithTitle(query)
                        isPresented = false
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(DS.Theme.amber)
                            Text("Create note \"\(query)\"")
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
            selectedIndex = 0
        }
        .onExitCommand {
            isPresented = false
        }
        .onChange(of: query) { _, _ in
            selectedIndex = 0
        }
    }
    
    private func commitSelection() {
        let results = filteredNotes
        if selectedIndex >= 0 && selectedIndex < results.count {
            onSelectNote(results[selectedIndex].id)
            isPresented = false
        } else if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            onCreateNoteWithTitle(query)
            isPresented = false
        }
    }
}
