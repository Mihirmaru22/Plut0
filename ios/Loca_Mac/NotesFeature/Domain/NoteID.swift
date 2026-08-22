import Foundation

/// Strongly typed domain identifier for a Note entity.
public struct NoteID: Hashable, Codable, Sendable, Identifiable, CustomStringConvertible {
    public let raw: UUID
    
    public var id: UUID { raw }
    
    public var description: String { raw.uuidString }
    
    public init(raw: UUID = UUID()) {
        self.raw = raw
    }
    
    public init?(uuidString: String) {
        guard let uuid = UUID(uuidString: uuidString) else { return nil }
        self.raw = uuid
    }
}
