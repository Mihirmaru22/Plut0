import Foundation

/// Document-level CRDT container managing metadata, block sequences, and vector clock versioning.
public struct CRDTDoc: Identifiable, Hashable, Codable, Sendable {
    public let id: NoteID
    public var metadata: [String: String]
    public var metadataTimestamps: [String: Double]
    public var blocks: [CRDTBlock]
    public var vectorClock: CRDTVectorClock
    public var deviceID: String
    public var localCounter: UInt64
    
    public init(
        id: NoteID = NoteID(),
        deviceID: String = "local-device",
        metadata: [String: String] = [:],
        metadataTimestamps: [String: Double] = [:],
        blocks: [CRDTBlock] = [],
        vectorClock: CRDTVectorClock = CRDTVectorClock(),
        localCounter: UInt64 = 0
    ) {
        self.id = id
        self.deviceID = deviceID
        self.metadata = metadata
        self.metadataTimestamps = metadataTimestamps
        self.blocks = blocks
        self.vectorClock = vectorClock
        self.localCounter = localCounter
    }
    
    // MARK: - Metadata Operations (LWW Register)
    
    public mutating func setMetadata(key: String, value: String, timestamp: Double = Date().timeIntervalSince1970) {
        let currentTs = metadataTimestamps[key, default: 0]
        if timestamp >= currentTs {
            metadata[key] = value
            metadataTimestamps[key] = timestamp
            _ = vectorClock.increment(for: deviceID)
        }
    }
    
    public var title: String {
        get { metadata["title", default: ""] }
        set { setMetadata(key: "title", value: newValue) }
    }
    
    public var isPinned: Bool {
        get { metadata["isPinned"] == "true" }
        set { setMetadata(key: "isPinned", value: newValue ? "true" : "false") }
    }
    
    public var isDeleted: Bool {
        get { metadata["isDeleted"] == "true" }
        set { setMetadata(key: "isDeleted", value: newValue ? "true" : "false") }
    }
    
    public var folderID: FolderID? {
        get { metadata["folderID"].flatMap { UUID(uuidString: $0) }.map { FolderID(raw: $0) } }
        set { setMetadata(key: "folderID", value: newValue?.raw.uuidString ?? "") }
    }
    
    // MARK: - Block Operations
    
    public mutating func addBlock(_ block: CRDTBlock) {
        var newBlock = block
        if let last = blocks.last {
            newBlock.sortKey = FractionalIndex.between(last.sortKey, nil)
        } else {
            newBlock.sortKey = FractionalIndex.initial
        }
        blocks.append(newBlock)
        _ = vectorClock.increment(for: deviceID)
    }
    
    public mutating func insertBlock(_ block: CRDTBlock, afterBlockID: UUID?) {
        var newBlock = block
        if let afterID = afterBlockID, let idx = blocks.firstIndex(where: { $0.id == afterID }) {
            let prevKey = blocks[idx].sortKey
            let nextKey = (idx + 1 < blocks.count) ? blocks[idx + 1].sortKey : nil
            newBlock.sortKey = FractionalIndex.between(prevKey, nextKey)
            blocks.insert(newBlock, at: idx + 1)
        } else if let first = blocks.first {
            newBlock.sortKey = FractionalIndex.between(nil, first.sortKey)
            blocks.insert(newBlock, at: 0)
        } else {
            newBlock.sortKey = FractionalIndex.initial
            blocks.append(newBlock)
        }
        _ = vectorClock.increment(for: deviceID)
    }
    
    public mutating func insertText(_ text: String, at charIndex: Int, in blockID: UUID) {
        guard let idx = blocks.firstIndex(where: { $0.id == blockID }) else { return }
        blocks[idx].text.insert(text, at: charIndex, deviceID: deviceID, counter: &localCounter)
        blocks[idx].lastModified = Date().timeIntervalSince1970
        _ = vectorClock.increment(for: deviceID)
    }
    
    public mutating func deleteText(at charIndex: Int, length: Int = 1, in blockID: UUID) {
        guard let idx = blocks.firstIndex(where: { $0.id == blockID }) else { return }
        blocks[idx].text.delete(at: charIndex, length: length)
        blocks[idx].lastModified = Date().timeIntervalSince1970
        _ = vectorClock.increment(for: deviceID)
    }
    
    public mutating func toggleChecklist(blockID: UUID) {
        guard let idx = blocks.firstIndex(where: { $0.id == blockID }) else { return }
        let current = blocks[idx].attributes["isChecked"] == "true"
        blocks[idx].attributes["isChecked"] = current ? "false" : "true"
        blocks[idx].lastModified = Date().timeIntervalSince1970
        _ = vectorClock.increment(for: deviceID)
    }
    
    public mutating func removeBlock(blockID: UUID) {
        guard let idx = blocks.firstIndex(where: { $0.id == blockID }) else { return }
        blocks[idx].isDeleted = true
        blocks[idx].lastModified = Date().timeIntervalSince1970
        _ = vectorClock.increment(for: deviceID)
    }
    
    // MARK: - CRDT Merge Engine
    
    public mutating func merge(with other: CRDTDoc) {
        guard self.id == other.id else { return }
        
        // 1. Merge Metadata with LWW
        for (key, otherValue) in other.metadata {
            let otherTs = other.metadataTimestamps[key, default: 0]
            let localTs = self.metadataTimestamps[key, default: 0]
            if otherTs > localTs || (otherTs == localTs && otherValue > (self.metadata[key] ?? "")) {
                self.metadata[key] = otherValue
                self.metadataTimestamps[key] = otherTs
            }
        }
        
        // 2. Merge Blocks (Union of Blocks + In-place block merge)
        var localBlockMap = [UUID: Int]()
        for (idx, b) in blocks.enumerated() {
            localBlockMap[b.id] = idx
        }
        
        for remoteBlock in other.blocks {
            if let localIdx = localBlockMap[remoteBlock.id] {
                blocks[localIdx].merge(with: remoteBlock)
            } else {
                // New block from remote
                blocks.append(remoteBlock)
                localBlockMap[remoteBlock.id] = blocks.count - 1
            }
        }
        
        // 3. Sort active blocks deterministically by sortKey then block ID
        blocks.sort {
            if $0.sortKey != $1.sortKey {
                return $0.sortKey < $1.sortKey
            }
            return $0.id.uuidString < $1.id.uuidString
        }
        
        // 4. Merge Vector Clocks
        self.vectorClock.merge(with: other.vectorClock)
        self.localCounter = max(self.localCounter, other.localCounter)
    }
}
