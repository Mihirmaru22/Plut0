import SwiftUI

/// Column 1 of the 2-Column interface containing pinned search, folders navigation, and reactive note list.
public struct NotesNavigatorView: View {
    
    @Binding public var searchText: String
    @Binding public var selectedFolderID: FolderID?
    @Binding public var showingDeleted: Bool
    @Binding public var selectedNoteID: NoteID?
    
    public let notes: [NoteSummary]
    public let folders: [Folder]
    public let onCreateNote: () -> Void
    public let onDeleteNote: (NoteID) -> Void
    public let onTogglePinNote: (NoteID) -> Void
    public let onCreateFolder: (String) -> Void
    public let onDeleteFolder: (FolderID) -> Void
    public let onToggleCollapse: (() -> Void)?
    
    @State private var newFolderName: String = ""
    @State private var isAddingFolder: Bool = false
    
    public init(
        searchText: Binding<String>,
        selectedFolderID: Binding<FolderID?>,
        showingDeleted: Binding<Bool>,
        selectedNoteID: Binding<NoteID?>,
        notes: [NoteSummary],
        folders: [Folder],
        onCreateNote: @escaping () -> Void,
        onDeleteNote: @escaping (NoteID) -> Void,
        onTogglePinNote: @escaping (NoteID) -> Void = { _ in },
        onCreateFolderWithName: @escaping (String) -> Void = { _ in },
        onDeleteFolder: @escaping (FolderID) -> Void = { _ in },
        onToggleCollapse: (() -> Void)? = nil
    ) {
        self._searchText = searchText
        self._selectedFolderID = selectedFolderID
        self._showingDeleted = showingDeleted
        self._selectedNoteID = selectedNoteID
        self.notes = notes
        self.folders = folders
        self.onCreateNote = onCreateNote
        self.onDeleteNote = onDeleteNote
        self.onTogglePinNote = onTogglePinNote
        self.onCreateFolder = onCreateFolderWithName
        self.onDeleteFolder = onDeleteFolder
        self.onToggleCollapse = onToggleCollapse
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Pinned Search Bar & Burger Toggle
            HStack(spacing: 8) {
                if let toggle = onToggleCollapse {
                    Button(action: toggle) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 26, height: 26)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help("Hide Notes List (⌘⌥S)")
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    TextField("Search notes...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            
            Divider()
            
            // Sidebar List (Folders + Notes)
            List {
                // Section 1: System Views
                Section("Smart Views") {
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
                
                // Section 2: Folders
                Section {
                    ForEach(folders) { folder in
                        Button {
                            showingDeleted = false
                            selectedFolderID = folder.id
                        } label: {
                            HStack {
                                Label(folder.name, systemImage: "folder.fill")
                                Spacer()
                                Button {
                                    onDeleteFolder(folder.id)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .foregroundStyle(!showingDeleted && selectedFolderID == folder.id ? Color.accentColor : Color.primary)
                    }
                    
                    if isAddingFolder {
                        HStack {
                            TextField("Folder name", text: $newFolderName)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11))
                            Button("Add") {
                                if !newFolderName.trimmingCharacters(in: .whitespaces).isEmpty {
                                    onCreateFolder(newFolderName)
                                    newFolderName = ""
                                    isAddingFolder = false
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    } else {
                        Button {
                            isAddingFolder = true
                        } label: {
                            Label("New Folder", systemImage: "plus")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Folders")
                }
                
                // Section 3: Notes List
                Section("Notes") {
                    if notes.isEmpty {
                        Text(showingDeleted ? "Trash is empty" : "No notes")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(notes) { note in
                            Button {
                                selectedNoteID = note.id
                            } label: {
                                NoteSummaryRowView(summary: note, isSelected: selectedNoteID == note.id)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(note.isPinned ? "Unpin Note" : "Pin Note") {
                                    onTogglePinNote(note.id)
                                }
                                Button("Delete Note", role: .destructive) {
                                    onDeleteNote(note.id)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            
            Divider()
            
            // Bottom Action Bar (Quiet, no counters)
            HStack {
                Spacer()
                Button(action: onCreateNote) {
                    Label("New Note", systemImage: "square.and.pencil")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut("n", modifiers: .command)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(DS.Theme.sidebar)
        }
    }
}
