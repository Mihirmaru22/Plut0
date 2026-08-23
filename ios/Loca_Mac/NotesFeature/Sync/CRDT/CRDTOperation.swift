import Foundation

/// Granular CRDT operations enabling reversible, delta-based Undo/Redo without destroying concurrent remote edits.
public enum CRDTOperation: Sendable, Codable {
    case insertText(blockID: UUID, position: Int, text: String, deviceID: String)
    case deleteText(blockID: UUID, position: Int, length: Int, deletedText: String)
    case createBlock(block: CRDTBlock, afterBlockID: UUID?)
    case removeBlock(blockID: UUID, oldBlock: CRDTBlock)
    case updateBlockMetadata(blockID: UUID, oldType: String, newType: String, oldAttributes: [String: String], newAttributes: [String: String])
    case splitBlock(originalBlockID: UUID, splitPosition: Int, newBlockID: UUID, newBlockType: String, newBlockAttributes: [String: String], movedText: String)
    case mergeBlocks(firstBlockID: UUID, secondBlockID: UUID, movedText: String, secondOldBlock: CRDTBlock)
    case toggleChecklist(blockID: UUID)
    
    /// Computes the exact inverse operation against current document state.
    public func inverse() -> CRDTOperation {
        switch self {
        case .insertText(let blockID, let position, let text, _):
            return .deleteText(blockID: blockID, position: position, length: text.count, deletedText: text)
            
        case .deleteText(let blockID, let position, _, let deletedText):
            return .insertText(blockID: blockID, position: position, text: deletedText, deviceID: "local-undo")
            
        case .createBlock(let block, _):
            return .removeBlock(blockID: block.id, oldBlock: block)
            
        case .removeBlock(_, let oldBlock):
            return .createBlock(block: oldBlock, afterBlockID: nil)
            
        case .updateBlockMetadata(let blockID, let oldType, let newType, let oldAttributes, let newAttributes):
            return .updateBlockMetadata(blockID: blockID, oldType: newType, newType: oldType, oldAttributes: newAttributes, newAttributes: oldAttributes)
            
        case .splitBlock(let origID, let splitPos, let newID, _, _, let movedText):
            return .deleteText(blockID: newID, position: 0, length: movedText.count, deletedText: movedText)
            
        case .mergeBlocks(let firstID, let secondID, let movedText, let secondOldBlock):
            return .createBlock(block: secondOldBlock, afterBlockID: firstID)
            
        case .toggleChecklist(let blockID):
            return .toggleChecklist(blockID: blockID)
        }
    }
}
