import Foundation

/// Binary serialization and delta envelope for CRDT document states.
public struct CRDTSnapshot: Hashable, Codable, Sendable {
    public let noteID: NoteID
    public let docData: Data
    public let vectorClock: CRDTVectorClock
    public let timestamp: Double
    
    public init(doc: CRDTDoc) throws {
        self.noteID = doc.id
        self.docData = try JSONEncoder().encode(doc)
        self.vectorClock = doc.vectorClock
        self.timestamp = Date().timeIntervalSince1970
    }
    
    public func decodeDoc() throws -> CRDTDoc {
        try JSONDecoder().decode(CRDTDoc.self, from: docData)
    }
}
