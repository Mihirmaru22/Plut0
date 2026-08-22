import Foundation

/// Atom ID uniquely identifying a character insertion in the RGA CRDT text buffer.
public struct CRDTAtomID: Hashable, Codable, Sendable, Comparable {
    public let deviceID: String
    public let counter: UInt64
    public let timestamp: Double
    
    public init(deviceID: String, counter: UInt64, timestamp: Double = Date().timeIntervalSince1970) {
        self.deviceID = deviceID
        self.counter = counter
        self.timestamp = timestamp
    }
    
    public static func < (lhs: CRDTAtomID, rhs: CRDTAtomID) -> Bool {
        if lhs.timestamp != rhs.timestamp {
            return lhs.timestamp < rhs.timestamp
        }
        if lhs.counter != rhs.counter {
            return lhs.counter < rhs.counter
        }
        return lhs.deviceID < rhs.deviceID
    }
}

/// Character atom inside the RGA CRDT text buffer.
public struct CRDTAtom: Hashable, Codable, Sendable {
    public let id: CRDTAtomID
    public let originID: CRDTAtomID?
    public let value: String
    public var isDeleted: Bool
    
    public init(id: CRDTAtomID, originID: CRDTAtomID?, value: String, isDeleted: Bool = false) {
        self.id = id
        self.originID = originID
        self.value = value
        self.isDeleted = isDeleted
    }
}

/// Replicated Growable Array (RGA) CRDT for collaborative, conflict-free character-level text editing.
public struct CRDTText: Hashable, Codable, Sendable {
    public private(set) var atoms: [CRDTAtom]
    
    public init(atoms: [CRDTAtom] = []) {
        self.atoms = atoms
    }
    
    public init(string: String, deviceID: String = "local", startCounter: UInt64 = 0) {
        var atoms: [CRDTAtom] = []
        var prevID: CRDTAtomID? = nil
        var counter = startCounter
        let now = Date().timeIntervalSince1970
        
        for char in string {
            counter += 1
            let id = CRDTAtomID(deviceID: deviceID, counter: counter, timestamp: now)
            let atom = CRDTAtom(id: id, originID: prevID, value: String(char), isDeleted: false)
            atoms.append(atom)
            prevID = id
        }
        self.atoms = atoms
    }
    
    /// Returns the plain string rendered from all active (non-tombstone) character atoms.
    public var string: String {
        atoms.filter { !$0.isDeleted }.map { $0.value }.joined()
    }
    
    /// Inserts a string at a visible character index.
    public mutating func insert(_ text: String, at index: Int, deviceID: String, counter: inout UInt64) {
        guard !text.isEmpty else { return }
        
        let visible = visibleAtoms()
        let originID: CRDTAtomID?
        let targetIndexInAtoms: Int
        
        if index <= 0 {
            originID = nil
            targetIndexInAtoms = 0
        } else if index >= visible.count {
            originID = visible.last?.id
            targetIndexInAtoms = atoms.count
        } else {
            let prevAtom = visible[index - 1]
            originID = prevAtom.id
            if let idx = atoms.firstIndex(where: { $0.id == prevAtom.id }) {
                targetIndexInAtoms = idx + 1
            } else {
                targetIndexInAtoms = atoms.count
            }
        }
        
        var newAtoms: [CRDTAtom] = []
        var currentOrigin = originID
        let now = Date().timeIntervalSince1970
        
        for char in text {
            counter += 1
            let atomID = CRDTAtomID(deviceID: deviceID, counter: counter, timestamp: now)
            let atom = CRDTAtom(id: atomID, originID: currentOrigin, value: String(char), isDeleted: false)
            newAtoms.append(atom)
            currentOrigin = atomID
        }
        
        atoms.insert(contentsOf: newAtoms, at: min(targetIndexInAtoms, atoms.count))
    }
    
    /// Deletes characters in a visible index range (marks atoms as tombstones).
    public mutating func delete(at index: Int, length: Int = 1) {
        let visible = visibleAtoms()
        guard index >= 0, index < visible.count, length > 0 else { return }
        
        let endIndex = min(index + length, visible.count)
        let toDeleteIDs = Set(visible[index..<endIndex].map { $0.id })
        
        for i in 0..<atoms.count {
            if toDeleteIDs.contains(atoms[i].id) {
                atoms[i].isDeleted = true
            }
        }
    }
    
    /// Merges remote CRDTText atoms deterministically.
    public mutating func merge(with other: CRDTText) {
        var existingMap = [CRDTAtomID: Int]()
        for (idx, atom) in atoms.enumerated() {
            existingMap[atom.id] = idx
        }
        
        for remoteAtom in other.atoms {
            if let localIdx = existingMap[remoteAtom.id] {
                // If either has deleted, tombstone wins
                if remoteAtom.isDeleted {
                    atoms[localIdx].isDeleted = true
                }
            } else {
                // Insert new atom at deterministic position based on originID & tie-breaking
                insertRemoteAtom(remoteAtom)
                existingMap.removeAll()
                for (idx, atom) in atoms.enumerated() {
                    existingMap[atom.id] = idx
                }
            }
        }
    }
    
    private mutating func insertRemoteAtom(_ atom: CRDTAtom) {
        var insertPos = 0
        if let origin = atom.originID {
            if let originIdx = atoms.firstIndex(where: { $0.id == origin }) {
                insertPos = originIdx + 1
            } else {
                insertPos = atoms.count
            }
        }
        
        // Advance past any other atoms sharing the same origin if they have greater precedence
        while insertPos < atoms.count {
            let next = atoms[insertPos]
            if next.originID == atom.originID {
                if atom.id < next.id {
                    insertPos += 1
                } else {
                    break
                }
            } else {
                break
            }
        }
        
        atoms.insert(atom, at: min(insertPos, atoms.count))
    }
    
    private func visibleAtoms() -> [CRDTAtom] {
        atoms.filter { !$0.isDeleted }
    }
}
