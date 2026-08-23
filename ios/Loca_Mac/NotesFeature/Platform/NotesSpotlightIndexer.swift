import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

extension Notification.Name {
    public static let plutoOpenNote = Notification.Name("plutoOpenNote")
}

/// Automatically donates and indexes rich notes into native macOS Spotlight (`CSSearchableIndex`).
/// Enables direct search from anywhere in macOS (`⌘Space`) with instant deep linking (`pluto://note/{uuid}`).
public final class NotesSpotlightIndexer: Sendable {
    
    public static let shared = NotesSpotlightIndexer()
    public let domainIdentifier = "com.mihirmaru.pluto.notes"
    
    private init() {}
    
    /// Indexes an individual note into macOS Core Spotlight.
    public func indexNote(id: NoteID, title: String, preview: String, content: NoteContent? = nil, isPrivate: Bool = false) {
        guard !isPrivate else {
            deindexNote(id: id)
            return
        }
        
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        attributeSet.title = title.isEmpty ? "New Note" : title
        attributeSet.contentDescription = preview
        
        var keywords = [title, "note", "pluto"]
        if let blocks = content?.blocks {
            for block in blocks.prefix(5) {
                keywords.append(contentsOf: block.text.components(separatedBy: .whitespacesAndNewlines))
            }
        }
        attributeSet.keywords = keywords.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        let item = CSSearchableItem(
            uniqueIdentifier: id.raw.uuidString,
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )
        
        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error = error {
                _ = error
            }
        }
    }
    
    /// Removes a deleted or private note from macOS Core Spotlight.
    public func deindexNote(id: NoteID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [id.raw.uuidString]) { _ in }
    }
    
    /// Batch indexes an array of note summaries, purging private notes.
    public func batchIndex(summaries: [NoteSummary]) {
        let nonPrivate = summaries.filter { !$0.isPrivate && !$0.isDeleted }
        let toPurge = summaries.filter { $0.isPrivate || $0.isDeleted }.map { $0.id.raw.uuidString }
        
        if !toPurge.isEmpty {
            CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: toPurge) { _ in }
        }
        
        let items: [CSSearchableItem] = nonPrivate.map { summary in
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.title = summary.title.isEmpty ? "New Note" : summary.title
            attributeSet.contentDescription = summary.preview
            attributeSet.keywords = [summary.title, "note", "pluto"]
            
            return CSSearchableItem(
                uniqueIdentifier: summary.id.raw.uuidString,
                domainIdentifier: domainIdentifier,
                attributeSet: attributeSet
            )
        }
        
        if !items.isEmpty {
            CSSearchableIndex.default().indexSearchableItems(items) { _ in }
        }
    }
    
    /// Starts real-time observation of the Notes engine to sync all changes to Spotlight.
    public func startObserving(engine: NotesEngine) {
        Task { @MainActor in
            for await notesList in engine.observeNotes() {
                self.batchIndex(summaries: notesList)
            }
        }
    }
}
