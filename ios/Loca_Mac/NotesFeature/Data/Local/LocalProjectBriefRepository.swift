import Foundation

/// Isolated DocumentCoreRepository implementation managing Project Briefs backed by SQLite `project_briefs`.
public final class LocalProjectBriefRepository: DocumentCoreRepository, @unchecked Sendable {
    
    private let store: LocalProjectBriefStore
    private let eventBus: NotesEventBus
    
    public init(store: LocalProjectBriefStore, eventBus: NotesEventBus = NotesEventBus()) {
        self.store = store
        self.eventBus = eventBus
    }
    
    public func fetchDocument(id: NoteID) async throws -> Note? {
        try await store.fetchBrief(id: id)
    }
    
    public func apply(_ mutation: NoteMutation) async throws {
        let event = try await store.apply(mutation)
        eventBus.publish(event)
    }
    
    public func apply(mutations: [NoteMutation]) async throws {
        let events = try await store.apply(mutations: mutations)
        for event in events {
            eventBus.publish(event)
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
        try await store.searchBriefs(term: term)
    }
}
