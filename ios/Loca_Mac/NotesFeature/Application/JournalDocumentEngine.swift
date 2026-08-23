import Foundation

/// Fast in-memory DocumentCoreRepository implementation providing isolated storage for Journal reflections.
public final class InMemoryJournalDocumentRepository: DocumentCoreRepository, @unchecked Sendable {
    
    private var entries: [NoteID: Note] = [:]
    private let lock = NSLock()
    private let eventBus = NotesEventBus()
    
    public init(initialEntries: [Note] = []) {
        for e in initialEntries {
            self.entries[e.id] = e
        }
    }
    
    public func fetchDocument(id: NoteID) async throws -> Note? {
        lock.lock()
        defer { lock.unlock() }
        return entries[id]
    }
    
    public func apply(_ mutation: NoteMutation) async throws {
        lock.lock()
        defer { lock.unlock() }
        
        switch mutation {
        case .createNote(let id, _):
            let note = Note(id: id, title: "")
            entries[id] = note
            eventBus.publish(.noteCreated(id))
            
        case .updateContent(let id, let content):
            let now = Date()
            let plainText = NoteTextExtractor.plainText(from: content)
            let preview = NotePreviewGenerator.derivePreview(from: content)
            let title = NotePreviewGenerator.deriveTitle(from: content)
            
            var note = entries[id] ?? Note(id: id, title: title)
            note.title = title
            note.content = content
            note.plainTextCache = plainText
            note.preview = preview
            note.updatedAt = now
            note.clientUpdatedAt = now
            entries[id] = note
            eventBus.publish(.noteUpdated(id))
            
        case .markDeleted(let id), .permanentlyDelete(let id):
            entries.removeValue(forKey: id)
            eventBus.publish(.noteDeleted(id))
            
        case .setPrivate(let id, let isPrivate):
            if var note = entries[id] {
                note.isPrivate = isPrivate
                entries[id] = note
            }
            eventBus.publish(.noteUpdated(id))
            
        default:
            eventBus.publish(.noteUpdated(mutation.noteID))
        }
    }
    
    public func apply(mutations: [NoteMutation]) async throws {
        for mutation in mutations {
            try await apply(mutation)
        }
    }
    
    public func observeDocument(id: NoteID) -> AsyncStream<Note?> {
        AsyncStream { continuation in
            let task = Task {
                let initial = try? await self.fetchDocument(id: id)
                continuation.yield(initial)
                
                for await event in self.eventBus.events() {
                    guard !Task.isCancelled else { break }
                    switch event {
                    case .noteUpdated(let eventID) where eventID == id:
                        let updated = try? await self.fetchDocument(id: id)
                        continuation.yield(updated)
                    case .noteDeleted(let eventID) where eventID == id:
                        continuation.yield(nil)
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
    
    public func searchDocuments(term: String) async throws -> [NoteSummary] {
        lock.lock()
        defer { lock.unlock() }
        let lower = term.lowercased()
        return entries.values
            .filter { $0.plainTextCache.localizedCaseInsensitiveContains(lower) || $0.preview.localizedCaseInsensitiveContains(lower) }
            .map { NotesMappers.noteSummary(from: $0) }
    }
}

public enum JournalDocumentEngine {
    public static let shared: any DocumentCoreRepository = InMemoryJournalDocumentRepository()
}
