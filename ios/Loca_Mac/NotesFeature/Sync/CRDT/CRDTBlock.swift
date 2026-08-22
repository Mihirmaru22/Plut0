import Foundation

/// Inline character-level formatting span for rich text CRDT representation.
public struct CRDTTextMark: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var type: String // "bold", "italic", "strikethrough"
    public var startIndex: Int
    public var endIndex: Int
    
    public init(id: UUID = UUID(), type: String, startIndex: Int, endIndex: Int) {
        self.id = id
        self.type = type
        self.startIndex = startIndex
        self.endIndex = endIndex
    }
}

/// CRDT-backed representation of a NoteBlock supporting character-level text merges, LWW attributes, and inline text marks.
public struct CRDTBlock: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var type: String // "paragraph", "heading", "checklistItem", "bullet", "divider"
    public var text: CRDTText
    public var attributes: [String: String]
    public var marks: [CRDTTextMark]
    public var lastModified: Double
    public var isDeleted: Bool
    public var sortKey: String
    
    public init(
        id: UUID = UUID(),
        type: String = "paragraph",
        text: CRDTText = CRDTText(),
        attributes: [String: String] = [:],
        marks: [CRDTTextMark] = [],
        lastModified: Double = Date().timeIntervalSince1970,
        isDeleted: Bool = false,
        sortKey: String = FractionalIndex.initial
    ) {
        self.id = id
        self.type = type
        self.text = text
        self.attributes = attributes
        self.marks = marks
        self.lastModified = lastModified
        self.isDeleted = isDeleted
        self.sortKey = sortKey
    }
    
    // MARK: - Inline Formatting Marks
    
    public mutating func applyMark(type: String, startIndex: Int, endIndex: Int) {
        guard startIndex < endIndex else { return }
        
        // If identical mark exists, remove it (toggle off)
        if let existingIdx = marks.firstIndex(where: { $0.type == type && $0.startIndex == startIndex && $0.endIndex == endIndex }) {
            marks.remove(at: existingIdx)
        } else {
            marks.append(CRDTTextMark(type: type, startIndex: startIndex, endIndex: endIndex))
        }
        lastModified = Date().timeIntervalSince1970
    }
    
    public mutating func removeMark(type: String, startIndex: Int, endIndex: Int) {
        guard startIndex < endIndex else { return }
        var updated: [CRDTTextMark] = []
        for mark in marks {
            if mark.type != type {
                updated.append(mark)
                continue
            }
            if mark.endIndex <= startIndex || mark.startIndex >= endIndex {
                updated.append(mark)
            } else {
                if mark.startIndex < startIndex {
                    updated.append(CRDTTextMark(type: type, startIndex: mark.startIndex, endIndex: startIndex))
                }
                if mark.endIndex > endIndex {
                    updated.append(CRDTTextMark(type: type, startIndex: endIndex, endIndex: mark.endIndex))
                }
            }
        }
        marks = updated
        lastModified = Date().timeIntervalSince1970
    }
    
    public mutating func adjustMarksForInsertion(at index: Int, length: Int) {
        for i in 0..<marks.count {
            if index < marks[i].startIndex {
                marks[i].startIndex += length
                marks[i].endIndex += length
            } else if index <= marks[i].endIndex {
                marks[i].endIndex += length
            }
        }
    }
    
    public mutating func adjustMarksForDeletion(at index: Int, length: Int) {
        var updated: [CRDTTextMark] = []
        for var mark in marks {
            if index + length <= mark.startIndex {
                mark.startIndex -= length
                mark.endIndex -= length
                updated.append(mark)
            } else if index >= mark.endIndex {
                updated.append(mark)
            } else {
                let overlapStart = max(index, mark.startIndex)
                let overlapEnd = min(index + length, mark.endIndex)
                let overlapLen = overlapEnd - overlapStart
                mark.endIndex -= overlapLen
                if mark.startIndex < mark.endIndex {
                    updated.append(mark)
                }
            }
        }
        marks = updated
    }
    
    // MARK: - CRDT Merge
    
    /// Merges another block state into this block using CRDT rules.
    public mutating func merge(with other: CRDTBlock) {
        guard self.id == other.id else { return }
        
        // 1. Merge text via RGA
        self.text.merge(with: other.text)
        
        // 2. LWW attribute & type resolution
        if other.lastModified > self.lastModified {
            self.type = other.type
            for (key, val) in other.attributes {
                self.attributes[key] = val
            }
            self.lastModified = other.lastModified
        }
        
        // 3. Merge inline marks
        for remoteMark in other.marks {
            if !marks.contains(where: { $0.type == remoteMark.type && $0.startIndex == remoteMark.startIndex && $0.endIndex == remoteMark.endIndex }) {
                marks.append(remoteMark)
            }
        }
        
        // 4. Tombstone preservation
        if other.isDeleted {
            self.isDeleted = true
        }
    }
}
