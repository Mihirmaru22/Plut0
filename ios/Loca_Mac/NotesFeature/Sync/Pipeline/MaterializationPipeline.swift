import Foundation

/// Pipeline that takes a CRDTDoc (Source of Truth), materializes it into domain structures, and delegates persistence via NotesRepository.
public final class MaterializationPipeline: Sendable {
    
    private let repository: any NotesRepository
    
    public init(repository: any NotesRepository) {
        self.repository = repository
    }
    
    @discardableResult
    public func materialize(doc: CRDTDoc) async throws -> Note {
        let content = CRDTTranslator.materializeContent(from: doc)
        let plainText = NoteTextExtractor.plainText(from: content)
        let preview = NotePreviewGenerator.preview(from: plainText)
        
        let mutation = NoteMutation.materializeFromSync(
            noteID: doc.id,
            title: doc.title,
            content: content,
            plainTextCache: plainText,
            preview: preview
        )
        
        try await repository.apply(mutation)
        
        let materializedNote = try await repository.fetchNote(id: doc.id)
        return materializedNote ?? Note(
            id: doc.id,
            folderID: doc.folderID,
            title: doc.title,
            content: content,
            plainTextCache: plainText,
            preview: preview,
            isPinned: doc.isPinned,
            isLocked: false,
            isDeleted: doc.isDeleted,
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: doc.isDeleted ? Date() : nil,
            sortKey: FractionalIndex.initial,
            schemaVersion: 1,
            clientUpdatedAt: Date(),
            deviceID: doc.deviceID
        )
    }
}
