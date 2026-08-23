import Foundation

/// Test harness for orchestrating and verifying CRDT multi-peer concurrent operations, merges, and convergence.
public final class MultiPeerTestHarness {
    public struct Peer {
        public let deviceID: String
        public var bridge: TextKitCRDTBridge
        public var operations: [CRDTOperation] = []
        
        public init(deviceID: String, bridge: TextKitCRDTBridge) {
            self.deviceID = deviceID
            self.bridge = bridge
        }
    }
    
    public var peers: [Peer]
    
    public init(peerCount: Int, noteID: NoteID = NoteID()) {
        self.peers = (0..<peerCount).map { i in
            let devID = "device-\(i)"
            let doc = CRDTDoc(id: noteID, deviceID: devID)
            let bridge = TextKitCRDTBridge(doc: doc, deviceID: devID)
            return Peer(deviceID: devID, bridge: bridge)
        }
    }
    
    public func type(on peerIndex: Int, text: String, atBlockID blockID: UUID, position: Int) {
        peers[peerIndex].bridge.insertText(text, atBlockID: blockID, position: position)
    }
    
    public func mergeAll() {
        // Full mesh pairwise merge across all peers
        for _ in 0..<peers.count {
            for i in 0..<peers.count {
                for j in 0..<peers.count where i != j {
                    peers[i].bridge.merge(from: peers[j].bridge.doc)
                }
            }
        }
    }
    
    public func converge() -> Bool {
        guard let first = peers.first else { return true }
        let firstStrings = first.bridge.doc.blocks.filter { !$0.isDeleted }.map { $0.text.string }
        
        return peers.dropFirst().allSatisfy { peer in
            let peerStrings = peer.bridge.doc.blocks.filter { !$0.isDeleted }.map { $0.text.string }
            return peerStrings == firstStrings
        }
    }
    
    public func getDocumentStrings() -> [String] {
        peers.map { peer in
            peer.bridge.doc.blocks.filter { !$0.isDeleted }.map { $0.text.string }.joined(separator: "\n")
        }
    }
}
