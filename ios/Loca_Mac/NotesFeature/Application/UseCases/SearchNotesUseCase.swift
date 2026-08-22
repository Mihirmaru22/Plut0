import Foundation

/// Use case querying notes matching a text term across titles and plain text cache.
public struct SearchNotesUseCase: Sendable {
    private let repository: NotesRepository
    
    public init(repository: NotesRepository) {
        self.repository = repository
    }
    
    public func execute(term: String) async throws -> [NoteSummary] {
        try await repository.searchNotes(term: term)
    }
}
