import Foundation

/// Application-level facade for Project Briefs providing isolated DocumentCoreRepository access.
public enum ProjectBriefEngine {
    
    public static func localDefault() throws -> LocalProjectBriefRepository {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let plutoDir = appSupport.appendingPathComponent("Pluto", isDirectory: true)
        try? FileManager.default.createDirectory(at: plutoDir, withIntermediateDirectories: true)
        let dbURL = plutoDir.appendingPathComponent("notes_v1.sqlite")
        
        let db = try NotesDatabase(fileURL: dbURL)
        let store = LocalProjectBriefStore(database: db)
        return LocalProjectBriefRepository(store: store)
    }
    
    public static func inMemory() -> InMemoryProjectBriefRepository {
        InMemoryProjectBriefRepository()
    }
    
    public static let shared: any DocumentCoreRepository = {
        do {
            return try localDefault()
        } catch {
            return inMemory()
        }
    }()
}
