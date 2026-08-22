#if canImport(Testing)
import Foundation
import Testing

@Suite("Notes Feature - In-Memory Repository Behavioral Parity Tests")
struct InMemoryRepositoryTests {
    
    @Test func testInMemoryCreateUpdateAndSearch() async throws {
        let repo = InMemoryNotesRepository()
        
        let noteID = NoteID()
        try await repo.apply(.createNote(noteID: noteID, folderID: nil))
        try await repo.apply(.setTitle(noteID: noteID, title: "Memory Note"))
        
        let content = NoteContent(version: 1, blocks: [.paragraph(ParagraphBlock(text: "High speed test execution"))])
        try await repo.apply(.updateContent(noteID: noteID, content: content))
        
        let note = try await repo.fetchNote(id: noteID)
        #expect(note?.title == "Memory Note")
        #expect(note?.plainTextCache == "High speed test execution")
        
        let searchResults = try await repo.searchNotes(term: "High speed")
        #expect(searchResults.count == 1)
        #expect(searchResults.first?.id == noteID)
    }
    
    @Test func testInMemoryPinningAndFolders() async throws {
        let repo = InMemoryNotesRepository()
        
        let folderID = try await repo.createFolder(name: "Design", parentID: nil)
        let noteID = NoteID()
        try await repo.apply(.createNote(noteID: noteID, folderID: nil))
        try await repo.apply(.move(noteID: noteID, folderID: folderID))
        try await repo.apply(.setPinned(noteID: noteID, isPinned: true))
        
        let list = try await repo.fetchNotes(matching: NoteQuery(folderID: folderID))
        #expect(list.count == 1)
        #expect(list.first?.isPinned == true)
    }
    
    @Test func testInMemorySoftDeleteAndRestore() async throws {
        let repo = InMemoryNotesRepository()
        
        let noteID = NoteID()
        try await repo.apply(.createNote(noteID: noteID, folderID: nil))
        
        try await repo.apply(.markDeleted(noteID: noteID))
        let active = try await repo.fetchNotes(matching: .all)
        #expect(active.isEmpty)
        
        let deleted = try await repo.fetchNotes(matching: .recentlyDeleted)
        #expect(deleted.count == 1)
        
        try await repo.apply(.restore(noteID: noteID))
        let restored = try await repo.fetchNotes(matching: .all)
        #expect(restored.count == 1)
        
        try await repo.apply(.permanentlyDelete(noteID: noteID))
        let purged = try await repo.fetchNote(id: noteID)
        #expect(purged == nil)
    }
    
    @Test func testInMemoryBatchMutationAtomicityAndRollback() async throws {
        let repo = InMemoryNotesRepository()
        
        let note1 = NoteID()
        let note2 = NoteID()
        let noteInvalid = NoteID()
        
        // 1. Successful batch of 3 mutations
        let batch: [NoteMutation] = [
            .createNote(noteID: note1, folderID: nil),
            .createNote(noteID: note2, folderID: nil),
            .setTitle(noteID: note1, title: "Memory Batch 1")
        ]
        try await repo.apply(mutations: batch)
        
        let fetched1 = try await repo.fetchNote(id: note1)
        #expect(fetched1?.title == "Memory Batch 1")
        
        // 2. Failing batch containing invalid note ID -> should atomically roll back
        let failingBatch: [NoteMutation] = [
            .setTitle(noteID: note2, title: "Updated Note 2"),
            .setTitle(noteID: noteInvalid, title: "Will Fail")
        ]
        
        do {
            try await repo.apply(mutations: failingBatch)
            Issue.record("Expected batch to fail and throw")
        } catch {
            if let notesError = error as? NotesError {
                #expect(notesError == .noteNotFound(noteInvalid))
            }
        }
        
        // Assert note2 title was NOT mutated (rolled back)
        let fetched2 = try await repo.fetchNote(id: note2)
        #expect(fetched2?.title == "")
    }
}
#endif
