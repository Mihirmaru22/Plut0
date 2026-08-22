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
    
    public var body: some View {
        ZStack {
            // Dismiss background overlay
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            // Centered Floating Palette
            VStack(spacing: 0) {
                // Search Input Header
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                    
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
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                
                Divider()
                
                // Search Results
                let results = filteredNotes
                if !results.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, note in
                                Button {
                                    onSelectNote(note.id)
                                    isPresented = false
                                } label: {
                                    HStack(spacing: 8) {
                                        if note.isPinned {
                                            Image(systemName: "pin.fill")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.orange)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(note.title.isEmpty ? "New Note" : note.title)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)
                                            
                                            if !note.preview.isEmpty {
                                                Text(note.preview)
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        if index == selectedIndex {
                                            Image(systemName: "return")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(index == selectedIndex ? Color.accentColor.opacity(0.15) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                                .foregroundStyle(Color.accentColor)
                            Text("Create note \"\(query)\"")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "return")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: Color.black.opacity(0.25), radius: 24, x: 0, y: 12)
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
