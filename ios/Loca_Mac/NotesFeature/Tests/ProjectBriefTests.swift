#if canImport(Testing)
import Foundation
import Testing
import SQLite3

@Suite("Notes Feature - Project Brief Isolated Memory Tests")
struct ProjectBriefTests {
    
    @Test func testInMemoryProjectBriefCRUD() async throws {
        let repo = InMemoryProjectBriefRepository()
        let briefID = NoteID()
        
        // 1. Create empty brief
        try await repo.apply(.createNote(id: briefID, folderID: nil))
        let initial = try await repo.fetchDocument(id: briefID)
        #expect(initial != nil)
        #expect(initial?.id == briefID)
        
        // 2. Update brief content
        let blocks: [NoteBlock] = [
            .heading(HeadingBlock(text: "Project Pluto Specification", level: 1)),
            .paragraph(ParagraphBlock(text: "CRDT-backed sovereign brief engine."))
        ]
        let content = NoteContent(version: 1, blocks: blocks)
        try await repo.apply(.updateContent(briefID, content))
        
        let updated = try await repo.fetchDocument(id: briefID)
        #expect(updated?.content.blocks.count == 2)
        #expect(updated?.title == "Project Pluto Specification")
        #expect(updated?.preview == "CRDT-backed sovereign brief engine.")
        
        // 3. Search briefs
        let searchResults = try await repo.searchDocuments(term: "Pluto")
        #expect(searchResults.count == 1)
        #expect(searchResults.first?.id == briefID)
        
        // 4. Delete brief
        try await repo.apply(.delete(briefID))
        let deleted = try await repo.fetchDocument(id: briefID)
        #expect(deleted == nil)
    }
    
    @Test func testMemoryIsolationBetweenNotesAndBriefs() async throws {
        let notesRepo = InMemoryNotesRepository()
        let briefRepo = InMemoryProjectBriefRepository()
        
        let noteID = NoteID()
        let briefID = NoteID()
        
        // 1. Write note to notesRepo
        let noteContent = NoteContent(version: 1, blocks: [
            .paragraph(ParagraphBlock(text: "Secret Note Alpha"))
        ])
        try await notesRepo.apply(.createNote(id: noteID, folderID: nil))
        try await notesRepo.apply(.updateContent(noteID, noteContent))
        
        // 2. Write brief to briefRepo
        let briefContent = NoteContent(version: 1, blocks: [
            .paragraph(ParagraphBlock(text: "Confidential Project Brief Beta"))
        ])
        try await briefRepo.apply(.createNote(id: briefID, folderID: nil))
        try await briefRepo.apply(.updateContent(briefID, briefContent))
        
        // 3. Verify Notes Repository only contains Notes
        let notesSearchForNote = try await notesRepo.searchNotes(term: "Secret")
        #expect(notesSearchForNote.count == 1)
        #expect(notesSearchForNote.first?.id == noteID)
        
        let notesSearchForBrief = try await notesRepo.searchNotes(term: "Confidential")
        #expect(notesSearchForBrief.isEmpty)
        
        // 4. Verify Brief Repository only contains Briefs
        let briefSearchForBrief = try await briefRepo.searchDocuments(term: "Confidential")
        #expect(briefSearchForBrief.count == 1)
        #expect(briefSearchForBrief.first?.id == briefID)
        
        let briefSearchForNote = try await briefRepo.searchDocuments(term: "Secret")
        #expect(briefSearchForNote.isEmpty)
    }
    
    @Test func testSQLiteProjectBriefStorePersistence() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let dbURL = tempDir.appendingPathComponent("brief_test_\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: dbURL) }
        
        let database = try NotesDatabase(fileURL: dbURL)
        let store = LocalProjectBriefStore(database: database)
        let repo = LocalProjectBriefRepository(store: store)
        
        let briefID = NoteID()
        let content = NoteContent(version: 1, blocks: [
            .heading(HeadingBlock(text: "Design System Architecture", level: 1)),
            .checklistItem(ChecklistItemBlock(text: "Tokens defined", isChecked: true))
        ])
        
        // Create & Update
        try await repo.apply(.createNote(id: briefID, folderID: nil))
        try await repo.apply(.updateContent(briefID, content))
        
        // Fetch
        let fetched = try await repo.fetchDocument(id: briefID)
        #expect(fetched != nil)
        #expect(fetched?.content.blocks.count == 2)
        #expect(fetched?.title == "Design System Architecture")
        
        // Search
        let search = try await repo.searchDocuments(term: "Architecture")
        #expect(search.count == 1)
        #expect(search.first?.id == briefID)
    }
    
    @Test func testMigrationV3CreatesProjectBriefsTable() throws {
        var db: OpaquePointer?
        #expect(sqlite3_open(":memory:", &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        
        try NotesMigrations.runMigrations(on: db)
        let applied = try NotesMigrations.appliedVersions(on: db)
        #expect(applied.contains(1))
        #expect(applied.contains(3))
        
        // Verify table existence
        let checkSQL = "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='project_briefs';"
        var statement: OpaquePointer?
        #expect(sqlite3_prepare_v2(db, checkSQL, -1, &statement, nil) == SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        
        #expect(sqlite3_step(statement) == SQLITE_ROW)
        let tableCount = sqlite3_column_int(statement, 0)
        #expect(tableCount == 1)
    }
}
#endif
