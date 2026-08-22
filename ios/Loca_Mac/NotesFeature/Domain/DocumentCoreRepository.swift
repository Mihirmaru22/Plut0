import Foundation

/// Minimal core document repository protocol shared by Notes and Project Briefs.
public protocol DocumentCoreRepository: Sendable {
    func fetchDocument(id: NoteID) async throws -> Note?
    func apply(_ mutation: NoteMutation) async throws
    func apply(mutations: [NoteMutation]) async throws
    func observeDocument(id: NoteID) -> AsyncStream<Note?>
    func searchDocuments(term: String) async throws -> [NoteSummary]
}
