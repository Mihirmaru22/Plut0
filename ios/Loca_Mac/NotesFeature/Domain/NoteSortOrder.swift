import Foundation

/// Defines sorting strategies for note queries.
public enum NoteSortOrder: String, Hashable, Codable, Sendable {
    case updatedAtDescending
    case createdAtDescending
    case titleAscending
    case manual
}
