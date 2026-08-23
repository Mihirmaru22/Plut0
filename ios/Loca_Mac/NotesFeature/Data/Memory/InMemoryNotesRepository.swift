import Foundation

/// Fast in-memory repository implementation for unit testing, previews, and debug flows without disk I/O.
public final class InMemoryNotesRepository: NotesRepository, @unchecked Sendable {
    
    private let lock = NSLock()
    private var notes: [NoteID: Note] = [:]
    private var folders: [FolderID: Folder] = [:]
    private var tags: [TagID: Tag] = [:]
    private var noteTags: [NoteID: Set<TagID>] = [:]
    private let eventBus: NotesEventBus
    
    public init(eventBus: NotesEventBus = NotesEventBus()) {
        self.eventBus = eventBus
    }
    
    // MARK: - Fetch
    
    public func fetchNotes(matching query: NoteQuery) async throws -> [NoteSummary] {
        lock.lock()
        defer { lock.unlock() }
        
        var filtered = notes.values.filter { note in
            if query.includeDeleted {
                guard note.isDeleted else { return false }
            } else {
                guard !note.isDeleted else { return false }
            }
            
            if let folderID = query.folderID, note.folderID != folderID {
                return false
            }
            
            if let search = query.searchText, !search.trimmingCharacters(in: .whitespaces).isEmpty {
                let term = search.lowercased()
                let matchesTitle = note.title.lowercased().contains(term)
                let matchesBody = note.plainTextCache.lowercased().contains(term)
                if !matchesTitle && !matchesBody {
                    return false
                }
            }
            
            if !query.tagIDs.isEmpty {
                let assigned = noteTags[note.id] ?? []
                let hasAllTags = query.tagIDs.allSatisfy { assigned.contains($0) }
                if !hasAllTags {
                    return false
                }
            }
            
            return true
        }
        
        // Sorting: pinned first, then sort order
        filtered.sort { a, b in
            if a.isPinned != b.isPinned {
                return a.isPinned && !b.isPinned
            }
            switch query.sortOrder {
            case .updatedAtDescending:
                return a.updatedAt > b.updatedAt
            case .createdAtDescending:
                return a.createdAt > b.createdAt
            case .titleAscending:
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            case .manual:
                return a.sortKey < b.sortKey
            }
        }
        
        if let limit = query.limit, filtered.count > limit {
            filtered = Array(filtered.prefix(limit))
        }
        
        return filtered.map { note in
            NoteSummary(
                id: note.id,
                title: note.title,
                preview: note.preview,
                folderID: note.folderID,
                isPinned: note.isPinned,
                isLocked: note.isLocked,
                isDeleted: note.isDeleted,
                isPrivate: note.isPrivate,
                updatedAt: note.updatedAt
            )
        }
    }
    
    public func fetchNote(id: NoteID) async throws -> Note? {
        lock.lock()
        defer { lock.unlock() }
        return notes[id]
    }
    
    // MARK: - Observation
    
    public func observeNotes(matching query: NoteQuery) -> AsyncStream<[NoteSummary]> {
        AsyncStream { continuation in
            let task = Task {
                if let initial = try? await self.fetchNotes(matching: query) {
                    continuation.yield(initial)
                }
                for await _ in self.eventBus.events() {
                    guard !Task.isCancelled else { break }
                    if let updated = try? await self.fetchNotes(matching: query) {
                        continuation.yield(updated)
                    }
                }
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    public func observeNote(id: NoteID) -> AsyncStream<Note?> {
        AsyncStream { continuation in
            let task = Task {
                if let initial = try? await self.fetchNote(id: id) {
                    continuation.yield(initial)
                }
                for await event in self.eventBus.events() {
                    guard !Task.isCancelled else { break }
                    switch event {
                    case .noteUpdated(let targetID),
                         .notePinned(let targetID),
                         .noteMoved(let targetID),
                         .noteRestored(let targetID),
                         .tagsChanged(let targetID):
                        if targetID == id {
                            let note = try? await self.fetchNote(id: id)
                            continuation.yield(note)
                        }
                    case .noteDeleted(let targetID):
                        if targetID == id {
                            let note = try? await self.fetchNote(id: id)
                            continuation.yield(note)
                        }
                    case .notePermanentlyDeleted(let targetID):
                        if targetID == id {
                            continuation.yield(nil)
                        }
                    case .databaseReset:
                        let note = try? await self.fetchNote(id: id)
                        continuation.yield(note)
                    default:
                        break
                    }
                }
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    // MARK: - Mutations
    
    public func apply(_ mutation: NoteMutation) async throws {
        try await apply(mutations: [mutation])
    }
    
    public func apply(mutations: [NoteMutation]) async throws {
        guard !mutations.isEmpty else { return }
        var eventsToPublish: [NotesEvent] = []
        
        try lock.withLock {
            let snapshotNotes = notes
            let snapshotFolders = folders
            let snapshotTags = tags
            let snapshotNoteTags = noteTags
            
            do {
                for mutation in mutations {
                    let event = try applySingleMutation(mutation)
                    eventsToPublish.append(event)
                }
            } catch {
                notes = snapshotNotes
                folders = snapshotFolders
                tags = snapshotTags
                noteTags = snapshotNoteTags
                throw error
            }
        }
        
        for event in eventsToPublish {
            eventBus.publish(event)
        }
    }
    
    private func applySingleMutation(_ mutation: NoteMutation) throws -> NotesEvent {
        switch mutation {
        case .createNote(let noteID, let folderID):
            let now = Date()
            let content = NoteContent.empty
            let plainText = NoteTextExtractor.plainText(from: content)
            let preview = NotePreviewGenerator.preview(from: plainText)
            
            let note = Note(
                id: noteID,
                folderID: folderID,
                title: "",
                content: content,
                plainTextCache: plainText,
                preview: preview,
                isPinned: false,
                isLocked: false,
                isDeleted: false,
                isPrivate: false,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil,
                sortKey: String(format: "%014.3f", now.timeIntervalSince1970),
                schemaVersion: 1,
                clientUpdatedAt: now,
                deviceID: "in-memory-device"
            )
            notes[noteID] = note
            return .noteCreated(noteID)
            
        case .setTitle(let noteID, let title):
            guard var note = notes[noteID] else {
                throw NotesError.noteNotFound(noteID)
            }
            let now = Date()
            note.title = title
            note.updatedAt = now
            note.clientUpdatedAt = now
            notes[noteID] = note
            return .noteUpdated(noteID)
            
        case .updateContent(let noteID, let content):
            guard var note = notes[noteID] else {
                throw NotesError.noteNotFound(noteID)
            }
            let now = Date()
            let plainText = NoteTextExtractor.plainText(from: content)
            let derivedTitle = NotePreviewGenerator.deriveTitle(from: content)
            let preview = NotePreviewGenerator.derivePreview(from: content)
            
            note.title = derivedTitle
            note.content = content
            note.plainTextCache = plainText
            note.preview = preview
            note.updatedAt = now
            note.clientUpdatedAt = now
            notes[noteID] = note
            return .noteUpdated(noteID)
            
        case .move(let noteID, let folderID):
            guard var note = notes[noteID] else {
                throw NotesError.noteNotFound(noteID)
            }
            let now = Date()
            note.folderID = folderID
            note.updatedAt = now
            note.clientUpdatedAt = now
            notes[noteID] = note
            return .noteMoved(noteID)
            
        case .setPinned(let noteID, let isPinned):
            guard var note = notes[noteID] else {
                throw NotesError.noteNotFound(noteID)
            }
            let now = Date()
            note.isPinned = isPinned
            note.updatedAt = now
            note.clientUpdatedAt = now
            notes[noteID] = note
            return .notePinned(noteID)
            
        case .setLocked(let noteID, let isLocked):
            guard var note = notes[noteID] else {
                throw NotesError.noteNotFound(noteID)
            }
            let now = Date()
            note.isLocked = isLocked
            note.updatedAt = now
            note.clientUpdatedAt = now
            notes[noteID] = note
            return .noteUpdated(noteID)
            
        case .markDeleted(let noteID):
            guard var note = notes[noteID] else {
                throw NotesError.noteNotFound(noteID)
            }
            let now = Date()
            note.isDeleted = true
            note.deletedAt = now
            note.updatedAt = now
            note.clientUpdatedAt = now
            notes[noteID] = note
            return .noteDeleted(noteID)
            
        case .restore(let noteID):
            guard var note = notes[noteID] else {
                throw NotesError.noteNotFound(noteID)
            }
            let now = Date()
            note.isDeleted = false
            note.deletedAt = nil
            note.updatedAt = now
            note.clientUpdatedAt = now
            notes[noteID] = note
            return .noteRestored(noteID)
            
        case .permanentlyDelete(let noteID):
            notes.removeValue(forKey: noteID)
            noteTags.removeValue(forKey: noteID)
            return .notePermanentlyDeleted(noteID)
            
        case .toggleChecklistItem(let noteID, let blockID):
            guard var note = notes[noteID] else {
                throw NotesError.noteNotFound(noteID)
            }
            var mutatedBlocks = note.content.blocks
            var didMutate = false
            for (idx, block) in mutatedBlocks.enumerated() {
                if case .checklistItem(var item) = block, item.id == blockID {
                    item.isChecked.toggle()
                    mutatedBlocks[idx] = .checklistItem(item)
                    didMutate = true
                    break
                }
            }
            if didMutate {
                let now = Date()
                let newContent = NoteContent(version: note.content.version, blocks: mutatedBlocks)
                let plainText = NoteTextExtractor.plainText(from: newContent)
                let preview = NotePreviewGenerator.preview(from: plainText)
                
                note.content = newContent
                note.plainTextCache = plainText
                note.preview = preview
                note.updatedAt = now
                note.clientUpdatedAt = now
                notes[noteID] = note
            }
            return .noteUpdated(noteID)
            
        case .setPrivate(let noteID, let isPrivate):
            guard var note = notes[noteID] else {
                throw NotesError.noteNotFound(noteID)
            }
            let now = Date()
            note.isPrivate = isPrivate
            note.updatedAt = now
            note.clientUpdatedAt = now
            notes[noteID] = note
            return .noteUpdated(noteID)
            
        case .materializeFromSync(let noteID, let title, let content, let plainTextCache, let preview):
            let now = Date()
            if var note = notes[noteID] {
                note.title = title
                note.content = content
                note.plainTextCache = plainTextCache
                note.preview = preview
                note.updatedAt = now
                note.clientUpdatedAt = now
                notes[noteID] = note
                return .noteUpdated(noteID)
            } else {
                let note = Note(
                    id: noteID,
                    folderID: nil,
                    title: title,
                    content: content,
                    plainTextCache: plainTextCache,
                    preview: preview,
                    isPinned: false,
                    isLocked: false,
                    isDeleted: false,
                    isPrivate: false,
                    createdAt: now,
                    updatedAt: now,
                    deletedAt: nil,
                    sortKey: FractionalIndex.initial,
                    schemaVersion: 1,
                    clientUpdatedAt: now,
                    deviceID: "in-memory-sync"
                )
                notes[noteID] = note
                return .noteCreated(noteID)
            }
        }
    }
    
    // MARK: - Folders
    
    public func fetchFolders() async throws -> [Folder] {
        lock.lock()
        defer { lock.unlock() }
        return Array(folders.values).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    public func createFolder(name: String, parentID: FolderID?) async throws -> FolderID {
        let id = FolderID()
        let folder = Folder(id: id, name: name, parentID: parentID)
        lock.lock()
        folders[id] = folder
        lock.unlock()
        eventBus.publish(.folderCreated(id))
        return id
    }
    
    public func deleteFolder(id: FolderID) async throws {
        lock.lock()
        folders.removeValue(forKey: id)
        for (noteID, note) in notes where note.folderID == id {
            var updated = note
            updated.folderID = nil
            notes[noteID] = updated
        }
        lock.unlock()
        eventBus.publish(.folderDeleted(id))
    }
    
    // MARK: - Tags
    
    public func fetchTags() async throws -> [Tag] {
        lock.lock()
        defer { lock.unlock() }
        return Array(tags.values).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    public func createTag(name: String) async throws -> TagID {
        let id = TagID()
        let tag = Tag(id: id, name: name)
        lock.lock()
        tags[id] = tag
        lock.unlock()
        eventBus.publish(.tagCreated(id))
        return id
    }
    
    public func addTag(_ tagID: TagID, to noteID: NoteID) async throws {
        lock.lock()
        var current = noteTags[noteID] ?? Set<TagID>()
        current.insert(tagID)
        noteTags[noteID] = current
        lock.unlock()
        eventBus.publish(.tagsChanged(noteID))
    }
    
    public func removeTag(_ tagID: TagID, from noteID: NoteID) async throws {
        lock.lock()
        if var current = noteTags[noteID] {
            current.remove(tagID)
            noteTags[noteID] = current
        }
        lock.unlock()
        eventBus.publish(.tagsChanged(noteID))
    }
    
    public func fetchTags(for noteID: NoteID) async throws -> [Tag] {
        lock.lock()
        defer { lock.unlock() }
        let tagSet = noteTags[noteID] ?? []
        return tagSet.compactMap { tags[$0] }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    // MARK: - Search
    
    public func searchNotes(term: String) async throws -> [NoteSummary] {
        let query = NoteQuery(searchText: term)
        return try await fetchNotes(matching: query)
    }
}
