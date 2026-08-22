#if canImport(Testing)
import Foundation
import Testing

@Suite("Notes Feature - SQLite Local Repository Tests")
struct RepositoryTests {
    
    private func makeTemporaryRepository() throws -> (LocalNotesRepository, URL) {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let dbURL = tempDir.appendingPathComponent("test_notes.sqlite")
        
        let db = try NotesDatabase(fileURL: dbURL)
        let store = LocalNotesStore(database: db)
        let eventBus = NotesEventBus()
        let repo = LocalNotesRepository(store: store, eventBus: eventBus)
        return (repo, tempDir)
    }
    
    @Test func testCreateAndFetchNote() async throws {
        let (repo, tempDir) = try makeTemporaryRepository()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let noteID = NoteID()
        try await repo.apply(.createNote(noteID: noteID, folderID: nil))
        
        let fetched = try await repo.fetchNote(id: noteID)
        #expect(fetched != nil)
        #expect(fetched?.id == noteID)
        #expect(fetched?.title == "")
        #expect(fetched?.isDeleted == false)
        #expect(fetched?.isPinned == false)
        
        let summaries = try await repo.fetchNotes(matching: .all)
        #expect(summaries.count == 1)
        #expect(summaries.first?.id == noteID)
    }
    
    @Test func testUpdateTitleAndContent() async throws {
        let (repo, tempDir) = try makeTemporaryRepository()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let noteID = NoteID()
        try await repo.apply(.createNote(noteID: noteID, folderID: nil))
        
        try await repo.apply(.setTitle(noteID: noteID, title: "Executive Plan"))
        
        let blockID = UUID()
        let blocks: [NoteBlock] = [
            .heading(HeadingBlock(text: "Goals", level: 1)),
            .checklistItem(ChecklistItemBlock(id: blockID, text: "Ship Phase 1 Engine", isChecked: false))
        ]
        let content = NoteContent(version: 1, blocks: blocks)
        try await repo.apply(.updateContent(noteID: noteID, content: content))
        
        let updated = try await repo.fetchNote(id: noteID)
        #expect(updated?.title == "Executive Plan")
        #expect(updated?.content.blocks.count == 2)
        #expect(updated?.plainTextCache.contains("Ship Phase 1 Engine") == true)
        
        // Toggle checklist item
        try await repo.apply(.toggleChecklistItem(noteID: noteID, blockID: blockID))
        let toggled = try await repo.fetchNote(id: noteID)
        if case .checklistItem(let item) = toggled?.content.blocks.last {
            #expect(item.isChecked == true)
        } else {
            Issue.record("Expected checklist item block")
        }
    }
    
    @Test func testPinningAndSorting() async throws {
        let (repo, tempDir) = try makeTemporaryRepository()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let note1 = NoteID()
        let note2 = NoteID()
        
        try await repo.apply(.createNote(noteID: note1, folderID: nil))
        try await repo.apply(.setTitle(noteID: note1, title: "Note One"))
        
        try await repo.apply(.createNote(noteID: note2, folderID: nil))
        try await repo.apply(.setTitle(noteID: note2, title: "Note Two"))
        
        // Pin Note 1
        try await repo.apply(.setPinned(noteID: note1, isPinned: true))
        
        let list = try await repo.fetchNotes(matching: .all)
        #expect(list.count == 2)
        #expect(list.first?.id == note1)
        #expect(list.first?.isPinned == true)
    }
    
    @Test func testFoldersAndMoves() async throws {
        let (repo, tempDir) = try makeTemporaryRepository()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let folderID = try await repo.createFolder(name: "Strategy", parentID: nil)
        let folders = try await repo.fetchFolders()
        #expect(folders.count == 1)
        #expect(folders.first?.name == "Strategy")
        
        let noteID = NoteID()
        try await repo.apply(.createNote(noteID: noteID, folderID: nil))
        
        try await repo.apply(.move(noteID: noteID, folderID: folderID))
        let moved = try await repo.fetchNote(id: noteID)
        #expect(moved?.folderID == folderID)
        
        let folderNotes = try await repo.fetchNotes(matching: NoteQuery(folderID: folderID))
        #expect(folderNotes.count == 1)
    }
    
    @Test func testTagAssociations() async throws {
        let (repo, tempDir) = try makeTemporaryRepository()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let tagID = try await repo.createTag(name: "Important")
        let noteID = NoteID()
        try await repo.apply(.createNote(noteID: noteID, folderID: nil))
        
        try await repo.addTag(tagID, to: noteID)
        let tags = try await repo.fetchTags(for: noteID)
        #expect(tags.count == 1)
        #expect(tags.first?.name == "Important")
        
        let taggedNotes = try await repo.fetchNotes(matching: NoteQuery(tagIDs: [tagID]))
        #expect(taggedNotes.count == 1)
        
        try await repo.removeTag(tagID, from: noteID)
        let emptyTags = try await repo.fetchTags(for: noteID)
        #expect(emptyTags.isEmpty)
    }
    
    @Test func testSoftDeleteRestoreAndPermanentPurge() async throws {
        let (repo, tempDir) = try makeTemporaryRepository()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let noteID = NoteID()
        try await repo.apply(.createNote(noteID: noteID, folderID: nil))
        
        // Soft delete
        try await repo.apply(.markDeleted(noteID: noteID))
        
        let activeNotes = try await repo.fetchNotes(matching: .all)
        #expect(activeNotes.isEmpty)
        
        let deletedNotes = try await repo.fetchNotes(matching: .recentlyDeleted)
        #expect(deletedNotes.count == 1)
        #expect(deletedNotes.first?.id == noteID)
        
        // Restore
        try await repo.apply(.restore(noteID: noteID))
        let restoredNotes = try await repo.fetchNotes(matching: .all)
        #expect(restoredNotes.count == 1)
        
        // Permanent Delete
        try await repo.apply(.permanentlyDelete(noteID: noteID))
        let purged = try await repo.fetchNote(id: noteID)
        #expect(purged == nil)
    }
    
    @Test func testSearchNotes() async throws {
        let (repo, tempDir) = try makeTemporaryRepository()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let noteID = NoteID()
        try await repo.apply(.createNote(noteID: noteID, folderID: nil))
        try await repo.apply(.setTitle(noteID: noteID, title: "Secret Roadmap"))
        
        let content = NoteContent(version: 1, blocks: [.paragraph(ParagraphBlock(text: "Launch date is October 2026"))])
        try await repo.apply(.updateContent(noteID: noteID, content: content))
        
        let titleSearch = try await repo.searchNotes(term: "Roadmap")
        #expect(titleSearch.count == 1)
        
        let bodySearch = try await repo.searchNotes(term: "October")
        #expect(bodySearch.count == 1)
        
        let missSearch = try await repo.searchNotes(term: "NonExistentTermXYZ")
        #expect(missSearch.isEmpty)
    }
    
    // MARK: - Fix 1 Tests: Search Wildcard Literal Matching
    
    @Test func testSearchWildcardLiteralMatching() async throws {
        let (repo, tempDir) = try makeTemporaryRepository()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let note1 = NoteID()
        let note2 = NoteID()
        let note3 = NoteID()
        
        try await repo.apply(.createNote(noteID: note1, folderID: nil))
        try await repo.apply(.setTitle(noteID: note1, title: "100% Complete Progress"))
        
        try await repo.apply(.createNote(noteID: note2, folderID: nil))
        try await repo.apply(.setTitle(noteID: note2, title: "100 Percent Complete Progress"))
        
        try await repo.apply(.createNote(noteID: note3, folderID: nil))
        try await repo.apply(.setTitle(noteID: note3, title: "project_alpha_spec"))
        
        // 1. Searching for literal '%' must ONLY match note1
        let percentSearch = try await repo.searchNotes(term: "%")
        #expect(percentSearch.count == 1)
        #expect(percentSearch.first?.id == note1)
        
        // 2. Searching for literal '_' must ONLY match note3
        let underscoreSearch = try await repo.searchNotes(term: "_")
        #expect(underscoreSearch.count == 1)
        #expect(underscoreSearch.first?.id == note3)
        
        // 3. Searching for combined wildcards '100%'
        let combinedSearch = try await repo.searchNotes(term: "100%")
        #expect(combinedSearch.count == 1)
        #expect(combinedSearch.first?.id == note1)
    }
    
    // MARK: - Fix 2 Tests: Batch Mutation Execution & Rollback
    
    @Test func testBatchMutationAtomicitySuccess() async throws {
        let (repo, tempDir) = try makeTemporaryRepository()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let note1 = NoteID()
        let note2 = NoteID()
        let folderID = try await repo.createFolder(name: "Engineering", parentID: nil)
        
        let mutations: [NoteMutation] = [
            .createNote(noteID: note1, folderID: nil),
            .createNote(noteID: note2, folderID: nil),
            .setTitle(noteID: note1, title: "Batch Note 1"),
            .setPinned(noteID: note1, isPinned: true),
            .move(noteID: note2, folderID: folderID)
        ]
        
        try await repo.apply(mutations: mutations)
        
        let fetched1 = try await repo.fetchNote(id: note1)
        #expect(fetched1?.title == "Batch Note 1")
        #expect(fetched1?.isPinned == true)
        
        let fetched2 = try await repo.fetchNote(id: note2)
        #expect(fetched2?.folderID == folderID)
        
        let allNotes = try await repo.fetchNotes(matching: .all)
        #expect(allNotes.count == 2)
    }
    
    @Test func testBatchMutationRollbackOnFailure() async throws {
        let (repo, tempDir) = try makeTemporaryRepository()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let noteValid = NoteID()
        let noteInvalid = NoteID() // Not created in DB
        
        let mutations: [NoteMutation] = [
            .createNote(noteID: noteValid, folderID: nil),
            .setTitle(noteID: noteValid, title: "Valid Title"),
            .setTitle(noteID: noteInvalid, title: "Will Fail") // This throws noteNotFound
        ]
        
        do {
            try await repo.apply(mutations: mutations)
            Issue.record("Expected batch apply to fail and throw NotesError.noteNotFound")
        } catch {
            // Assert error is noteNotFound
            if let notesError = error as? NotesError {
                #expect(notesError == .noteNotFound(noteInvalid))
            }
        }
        
        // Assert atomic rollback: noteValid must NOT exist in the database
        let fetched = try await repo.fetchNote(id: noteValid)
        #expect(fetched == nil)
        
        let allNotes = try await repo.fetchNotes(matching: .all)
        #expect(allNotes.isEmpty)
    }
    
    // MARK: - Fix 3 Tests: Schema Migration Version Tracking
    
    @Test func testSchemaMigrationVersionTracking() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let dbURL = tempDir.appendingPathComponent("migration_test.sqlite")
        let db = try NotesDatabase(fileURL: dbURL)
        
        // 1. Assert v1 migration is recorded in schema_migrations
        let applied = try db.read { pointer in
            try NotesMigrations.appliedVersions(on: pointer)
        }
        #expect(applied.contains(1))
        
        // 2. Run mock v2 migration
        try db.write { pointer in
            try NotesMigrations.runMigration(version: 2, on: pointer) { dbPointer in
                try NotesMigrations.execute(sql: "ALTER TABLE notes ADD COLUMN test_column TEXT DEFAULT '';", on: dbPointer)
            }
        }
        
        // 3. Assert v2 is now recorded
        let updatedVersions = try db.read { pointer in
            try NotesMigrations.appliedVersions(on: pointer)
        }
        #expect(updatedVersions.contains(1))
        #expect(updatedVersions.contains(2))
    }
}
#endif
