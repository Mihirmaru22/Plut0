import Foundation
import AppKit

/// Supported rich-text block types for formatting controls and typography mapping.
public enum EditorBlockType: String, Equatable, CaseIterable, Sendable {
    case h1
    case h2
    case h3
    case checklist
    case bullet
    case paragraph
    
    public var rawBlockType: (type: String, attributes: [String: String]) {
        switch self {
        case .h1: return ("heading", ["level": "1"])
        case .h2: return ("heading", ["level": "2"])
        case .h3: return ("heading", ["level": "3"])
        case .checklist: return ("checklistItem", ["isChecked": "false"])
        case .bullet: return ("bullet", [:])
        case .paragraph: return ("paragraph", [:])
        }
    }
}

/// Equatable formatting state derived from CRDT document truth for stateful toolbar buttons.
public struct FormattingState: Equatable, Sendable {
    public var isBold: Bool
    public var isItalic: Bool
    public var isUnderline: Bool
    public var isStrikethrough: Bool
    public var blockType: EditorBlockType
    
    public init(
        isBold: Bool = false,
        isItalic: Bool = false,
        isUnderline: Bool = false,
        isStrikethrough: Bool = false,
        blockType: EditorBlockType = .paragraph
    ) {
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderline = isUnderline
        self.isStrikethrough = isStrikethrough
        self.blockType = blockType
    }
    
    public var activeBlockType: EditorBlockType {
        blockType
    }
}

/// Return-key split result containing block metadata and target cursor position.
public struct SplitResult: Sendable {
    public let newBlockID: UUID?
    public let newCursor: Int
    public let oldBlockType: String
    public let newBlockType: String
    
    public init(newBlockID: UUID?, newCursor: Int, oldBlockType: String, newBlockType: String) {
        self.newBlockID = newBlockID
        self.newCursor = newCursor
        self.oldBlockType = oldBlockType
        self.newBlockType = newBlockType
    }
}

/// Snapshot representation for bridge-owned Undo and Redo operations.
public struct AutoFormatRevertState: Sendable {
    public let blockID: UUID
    public let originalType: String
    public let originalAttributes: [String: String]
    public let prefix: String
    public let location: Int
    
    public init(blockID: UUID, originalType: String, originalAttributes: [String: String], prefix: String, location: Int) {
        self.blockID = blockID
        self.originalType = originalType
        self.originalAttributes = originalAttributes
        self.prefix = prefix
        self.location = location
    }
}

public struct UndoRecord: Sendable {
    public let operations: [CRDTOperation]
    public let selection: NSRange
    public let timestamp: Date
    public let isTyping: Bool
    public let blockID: UUID?
    
    public init(
        operations: [CRDTOperation] = [],
        selection: NSRange,
        timestamp: Date = Date(),
        isTyping: Bool = false,
        blockID: UUID? = nil
    ) {
        self.operations = operations
        self.selection = selection
        self.timestamp = timestamp
        self.isTyping = isTyping
        self.blockID = blockID
    }
}

/// Bidirectional bridging engine translating TextKit layout offsets and mouse events to granular CRDT operations.
public final class TextKitCRDTBridge: @unchecked Sendable {
    
    public var doc: CRDTDoc
    public let deviceID: String
    private let lock = NSLock()
    
    // Cached map of block ID to its global NSRange in the rendered attributed string
    public private(set) var blockRanges: [UUID: NSRange] = [:]
    
    // Single source of truth for cursor / selection position
    public private(set) var lastKnownSelection: NSRange = NSRange(location: 0, length: 0)
    
    // Sticky marks for empty selection typing with consecutive progression detection
    private var stickyMarks: Set<String> = []
    private var lastInsertionLocation: Int = -1
    private var lastInsertionTime: Date = Date.distantPast
    private var stickyArmTime: Date = Date.distantPast
    
    // Bridge-owned Undo / Redo History Stacks (Delta Operations — not snapshot overwrites)
    private var undoStack: [UndoRecord] = []
    private var redoStack: [UndoRecord] = []
    private var lastTypingTime: Date = Date.distantPast
    private var lastTypingBlockID: UUID? = nil
    // Auto-Format Revert Snapshot
    public private(set) var lastAutoFormatRevert: AutoFormatRevertState? = nil
    
    public func clearAutoFormatRevert() {
        lock.lock()
        defer { lock.unlock() }
        lastAutoFormatRevert = nil
    }
    
    public init(doc: CRDTDoc, deviceID: String = "local-device") {
        self.doc = doc
        self.deviceID = deviceID
    }
    
    // MARK: - Undo / Redo History Management (Delta-Based)
    
    private func recordUndo(operations: [CRDTOperation] = [], beforeSelection: NSRange, isTyping: Bool = false, blockID: UUID? = nil) {
        let now = Date()
        if isTyping,
           let lastBlock = lastTypingBlockID,
           lastBlock == blockID,
           now.timeIntervalSince(lastTypingTime) < 0.8,
           !undoStack.isEmpty,
           undoStack.last?.isTyping == true {
            lastTypingTime = now
            if var lastRecord = undoStack.popLast() {
                var updatedOps = lastRecord.operations
                updatedOps.append(contentsOf: operations)
                undoStack.append(UndoRecord(operations: updatedOps, selection: lastRecord.selection, timestamp: lastRecord.timestamp, isTyping: true, blockID: blockID))
            }
            return
        }
        
        let record = UndoRecord(operations: operations, selection: beforeSelection, timestamp: now, isTyping: isTyping, blockID: blockID)
        undoStack.append(record)
        redoStack.removeAll()
        
        lastTypingTime = now
        lastTypingBlockID = blockID
    }
    
    public func undo(currentSelection: NSRange) -> NSRange? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let record = undoStack.popLast() else { return nil }
        
        // Execute inverse operations on live doc (preserves concurrent remote edits)
        let inverseOps = record.operations.map { $0.inverse() }
        for op in inverseOps.reversed() {
            applyOperation(op)
        }
        
        let redoRecord = UndoRecord(
            operations: record.operations,
            selection: currentSelection,
            timestamp: Date(),
            isTyping: false,
            blockID: nil
        )
        redoStack.append(redoRecord)
        
        self.stickyMarks.removeAll()
        self.lastKnownSelection = record.selection
        return record.selection
    }
    
    public func redo(currentSelection: NSRange) -> NSRange? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let record = redoStack.popLast() else { return nil }
        
        // Execute forward operations on live doc
        for op in record.operations {
            applyOperation(op)
        }
        
        let undoRecord = UndoRecord(
            operations: record.operations,
            selection: currentSelection,
            timestamp: Date(),
            isTyping: false,
            blockID: nil
        )
        undoStack.append(undoRecord)
        
        self.stickyMarks.removeAll()
        self.lastKnownSelection = record.selection
        return record.selection
    }
    
    private func applyOperation(_ op: CRDTOperation) {
        switch op {
        case .insertText(let blockID, let position, let text, _):
            doc.insertText(text, at: position, in: blockID)
            
        case .deleteText(let blockID, let position, let length, _):
            doc.deleteText(at: position, length: length, in: blockID)
            
        case .createBlock(let block, let afterBlockID):
            if let idx = doc.blocks.firstIndex(where: { $0.id == block.id }) {
                doc.blocks[idx].isDeleted = false
            } else {
                doc.insertBlock(block, afterBlockID: afterBlockID)
            }
            
        case .removeBlock(let blockID, _):
            doc.removeBlock(blockID: blockID)
            
        case .updateBlockMetadata(let blockID, _, let newType, _, let newAttributes):
            if let idx = doc.blocks.firstIndex(where: { $0.id == blockID }) {
                doc.blocks[idx].type = newType
                doc.blocks[idx].attributes = newAttributes
                doc.blocks[idx].lastModified = Date().timeIntervalSince1970
                _ = doc.vectorClock.increment(for: deviceID)
            }
            
        case .splitBlock(let origID, _, let newID, _, _, let movedText):
            doc.deleteText(at: 0, length: movedText.count, in: newID)
            doc.removeBlock(blockID: newID)
            
        case .mergeBlocks(let firstID, let secondID, _, let secondOldBlock):
            if let idx = doc.blocks.firstIndex(where: { $0.id == secondID }) {
                doc.blocks[idx].isDeleted = false
            } else {
                doc.insertBlock(secondOldBlock, afterBlockID: firstID)
            }
            
        case .toggleChecklist(let blockID):
            doc.toggleChecklist(blockID: blockID)
        }
    }
    
    // MARK: - Direct Block & CRDT Convenience API
    
    @discardableResult
    public func createBlock(id: UUID = UUID(), type: String = "paragraph", text: String = "", attributes: [String: String] = [:]) -> UUID {
        lock.lock()
        defer { lock.unlock() }
        let newBlock = CRDTBlock(id: id, type: type, text: CRDTText(string: text, deviceID: deviceID), attributes: attributes, lastModified: Date().timeIntervalSince1970)
        doc.addBlock(newBlock)
        let op = CRDTOperation.createBlock(block: newBlock, afterBlockID: nil)
        recordUndo(operations: [op], beforeSelection: lastKnownSelection, isTyping: false)
        return id
    }
    
    public func insertText(_ text: String, atBlockID blockID: UUID, position: Int) {
        lock.lock()
        defer { lock.unlock() }
        let op = CRDTOperation.insertText(blockID: blockID, position: position, text: text, deviceID: deviceID)
        recordUndo(operations: [op], beforeSelection: lastKnownSelection, isTyping: true, blockID: blockID)
        doc.insertText(text, at: position, in: blockID)
    }
    
    public func deleteText(atBlockID blockID: UUID, position: Int, length: Int = 1) {
        lock.lock()
        defer { lock.unlock() }
        guard let b = doc.blocks.first(where: { $0.id == blockID }) else { return }
        let str = b.text.string
        let chars = Array(str)
        let deleted = (position < chars.count) ? String(chars[position..<min(position + length, chars.count)]) : ""
        let op = CRDTOperation.deleteText(blockID: blockID, position: position, length: length, deletedText: deleted)
        recordUndo(operations: [op], beforeSelection: lastKnownSelection, isTyping: false)
        doc.deleteText(at: position, length: length, in: blockID)
    }
    
    public func getBlock(id: UUID) -> CRDTBlock? {
        lock.lock()
        defer { lock.unlock() }
        return doc.blocks.first(where: { $0.id == id && !$0.isDeleted })
    }
    
    public func merge(from otherDoc: CRDTDoc) {
        lock.lock()
        defer { lock.unlock() }
        doc.merge(with: otherDoc)
    }
    
    public func adjustUndoStackAfterRemoteMerge(oldDoc: CRDTDoc, newDoc: CRDTDoc) {
        lock.lock()
        defer { lock.unlock() }
        
        var adjustedUndoStack: [UndoRecord] = []
        
        for record in undoStack {
            var validOperations: [CRDTOperation] = []
            
            for op in record.operations {
                switch op {
                case .insertText(let blockID, _, _, _):
                    if doc.blocks.contains(where: { $0.id == blockID && !$0.isDeleted }) {
                        validOperations.append(op)
                    }
                    
                case .deleteText(let blockID, _, _, _):
                    if doc.blocks.contains(where: { $0.id == blockID && !$0.isDeleted }) {
                        validOperations.append(op)
                    }
                    
                case .createBlock, .removeBlock:
                    validOperations.append(op)
                    
                case .updateBlockMetadata(let blockID, _, _, _, _):
                    if doc.blocks.contains(where: { $0.id == blockID && !$0.isDeleted }) {
                        validOperations.append(op)
                    }
                    
                case .splitBlock(let origID, _, _, _, _, _):
                    if doc.blocks.contains(where: { $0.id == origID && !$0.isDeleted }) {
                        validOperations.append(op)
                    }
                    
                case .mergeBlocks(let firstID, _, _, _):
                    if doc.blocks.contains(where: { $0.id == firstID && !$0.isDeleted }) {
                        validOperations.append(op)
                    }
                    
                case .toggleChecklist(let blockID):
                    if doc.blocks.contains(where: { $0.id == blockID && !$0.isDeleted }) {
                        validOperations.append(op)
                    }
                }
            }
            
            if !validOperations.isEmpty {
                adjustedUndoStack.append(
                    UndoRecord(
                        operations: validOperations,
                        selection: record.selection,
                        timestamp: record.timestamp,
                        isTyping: record.isTyping,
                        blockID: record.blockID
                    )
                )
            }
        }
        
        undoStack = adjustedUndoStack
    }
    
    public func clearUndoHistory() {
        lock.lock()
        defer { lock.unlock() }
        undoStack.removeAll()
        redoStack.removeAll()
        lastTypingBlockID = nil
    }
    
    // MARK: - Selection & Sticky Marks Tracking
    
    public func updateLastKnownSelection(_ range: NSRange) {
        lock.lock()
        defer { lock.unlock() }
        self.lastKnownSelection = range
    }
    
    public func setStickyMarks(_ marks: Set<String>) {
        lock.lock()
        defer { lock.unlock() }
        self.stickyMarks = marks
        self.lastInsertionLocation = lastKnownSelection.location
        self.stickyArmTime = Date()
    }
    
    public func getStickyMarks() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return stickyMarks
    }
    
    public func clearStickyMarks() {
        lock.lock()
        defer { lock.unlock() }
        self.stickyMarks.removeAll()
        self.lastInsertionLocation = -1
    }
    
    public func selectionDidChange(to range: NSRange) {
        lock.lock()
        defer { lock.unlock() }
        self.lastKnownSelection = range
        
        // Only clear sticky marks if cursor moved away AND not within focus-return window (0.25s)
        if range.location != lastInsertionLocation && Date().timeIntervalSince(stickyArmTime) > 0.25 {
            if !stickyMarks.isEmpty {
                stickyMarks.removeAll()
                lastInsertionLocation = -1
            }
        }
    }
    
    // MARK: - Block Range Resolution
    
    /// Resolves a global character index to an enclosing CRDT block and relative index within that block.
    public func resolveLocation(_ globalIndex: Int) -> (block: CRDTBlock, blockIndex: Int, relativeIndex: Int)? {
        lock.lock()
        defer { lock.unlock() }
        return resolveLocationInternal(globalIndex)
    }
    
    public func block(for blockID: UUID) -> CRDTBlock? {
        lock.lock()
        defer { lock.unlock() }
        return doc.blocks.first(where: { $0.id == blockID && !$0.isDeleted })
    }
    
    // MARK: - Keystroke to CRDT Translation
    
    /// Inserts text at a global character location with undo tracking.
    public func insertText(_ text: String, at globalLocation: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        let beforeSel = NSRange(location: globalLocation, length: 0)
        let target = resolveLocationInternal(globalLocation)
        let op: CRDTOperation
        if let t = target {
            op = .insertText(blockID: t.block.id, position: t.relativeIndex, text: text, deviceID: deviceID)
        } else {
            let newBlock = CRDTBlock(id: UUID(), type: "paragraph", text: CRDTText(string: text, deviceID: deviceID))
            op = .createBlock(block: newBlock, afterBlockID: nil)
        }
        recordUndo(operations: [op], beforeSelection: beforeSel, isTyping: true, blockID: target?.block.id)
        
        insertTextInternal(text, at: globalLocation)
    }
    
    private func insertTextInternal(_ text: String, at globalLocation: Int) {
        guard let target = resolveLocationInternal(globalLocation) else {
            let newBlock = CRDTBlock(id: UUID(), type: "paragraph", text: CRDTText(string: text, deviceID: deviceID))
            doc.addBlock(newBlock)
            return
        }
        
        if let idx = doc.blocks.firstIndex(where: { $0.id == target.block.id }) {
            doc.blocks[idx].adjustMarksForInsertion(at: target.relativeIndex, length: text.count)
        }
        doc.insertText(text, at: target.relativeIndex, in: target.block.id)
        
        // If sticky marks are active, apply them to the newly inserted range
        if !stickyMarks.isEmpty && !text.isEmpty {
            let range = NSRange(location: globalLocation, length: text.count)
            for mark in stickyMarks {
                applyInlineMarkInternal(type: mark, in: range)
            }
        }
        
        // Update tracking for consecutive detection
        lastInsertionLocation = globalLocation + text.count
        lastInsertionTime = Date()
    }
    
    /// Deletes text at a global character location.
    public func deleteText(at globalLocation: Int, length: Int = 1) {
        deleteRange(at: globalLocation, length: length)
    }
    
    /// Multi-block range deletion handling arbitrary selection spans (Cmd+A + Delete, Backspace, etc.).
    public func deleteRange(at globalLocation: Int, length: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        guard length > 0 else { return }
        let beforeSel = NSRange(location: globalLocation, length: length)
        
        var ops: [CRDTOperation] = []
        if let target = resolveLocationInternal(globalLocation) {
            let chars = Array(target.block.text.string)
            let delLen = min(length, max(0, chars.count - target.relativeIndex))
            if delLen > 0 {
                let delText = String(chars[target.relativeIndex..<(target.relativeIndex + delLen)])
                ops.append(.deleteText(blockID: target.block.id, position: target.relativeIndex, length: delLen, deletedText: delText))
            }
        }
        recordUndo(operations: ops, beforeSelection: beforeSel, isTyping: false)
        
        deleteRangeInternal(at: globalLocation, length: length)
    }
    
    private func deleteRangeInternal(at globalLocation: Int, length: Int) {
        guard length > 0 else { return }
        
        let activeBlocks = doc.blocks.filter { !$0.isDeleted }
        guard !activeBlocks.isEmpty else {
            ensureNonEmptyDocument()
            return
        }
        
        let startLocation = globalLocation
        let endLocation = globalLocation + length
        
        guard let startTarget = resolveLocationInternal(startLocation),
              let endTarget = resolveLocationInternal(endLocation) else {
            ensureNonEmptyDocument()
            return
        }
        
        if startTarget.block.id == endTarget.block.id {
            // Within single block
            let deleteLen = endTarget.relativeIndex - startTarget.relativeIndex
            if deleteLen > 0 {
                if startTarget.relativeIndex == 0 && deleteLen == 1 && startTarget.blockIndex > 0 {
                    mergeBlockWithPreceding(targetBlockIndex: startTarget.blockIndex)
                } else {
                    if let idx = doc.blocks.firstIndex(where: { $0.id == startTarget.block.id }) {
                        doc.blocks[idx].adjustMarksForDeletion(at: startTarget.relativeIndex, length: deleteLen)
                    }
                    doc.deleteText(at: startTarget.relativeIndex, length: deleteLen, in: startTarget.block.id)
                }
            }
        } else {
            // Cross-block deletion
            let startIdx = startTarget.blockIndex
            let endIdx = endTarget.blockIndex
            
            let startBlock = activeBlocks[startIdx]
            let endBlock = activeBlocks[endIdx]
            
            // 1. Truncate start block at startTarget.relativeIndex
            let startOrigLen = startBlock.text.string.count
            let startKeepLen = startTarget.relativeIndex
            if startKeepLen < startOrigLen {
                let delLen = startOrigLen - startKeepLen
                if let idx = doc.blocks.firstIndex(where: { $0.id == startBlock.id }) {
                    doc.blocks[idx].adjustMarksForDeletion(at: startKeepLen, length: delLen)
                }
                doc.deleteText(at: startKeepLen, length: delLen, in: startBlock.id)
            }
            
            // 2. Remove all middle blocks strictly between startIdx and endIdx
            if endIdx > startIdx + 1 {
                for i in (startIdx + 1)..<endIdx {
                    doc.removeBlock(blockID: activeBlocks[i].id)
                }
            }
            
            // 3. Splice end block tail onto start block
            let endTail = String(endBlock.text.string.dropFirst(endTarget.relativeIndex))
            if !endTail.isEmpty {
                let startOffset = startKeepLen
                if let idx = doc.blocks.firstIndex(where: { $0.id == startBlock.id }) {
                    for mark in endBlock.marks {
                        if mark.endIndex > endTarget.relativeIndex {
                            let adjStart = max(0, mark.startIndex - endTarget.relativeIndex) + startOffset
                            let adjEnd = (mark.endIndex - endTarget.relativeIndex) + startOffset
                            doc.blocks[idx].marks.append(CRDTTextMark(type: mark.type, startIndex: adjStart, endIndex: adjEnd))
                        }
                    }
                }
                doc.insertText(endTail, at: startKeepLen, in: startBlock.id)
            }
            
            // 4. Remove end block
            doc.removeBlock(blockID: endBlock.id)
        }
        
        let remaining = doc.blocks.filter { !$0.isDeleted }
        if remaining.isEmpty {
            ensureNonEmptyDocument()
        }
        
        lastInsertionLocation = globalLocation
    }
    
    private func ensureNonEmptyDocument() {
        for i in doc.blocks.indices {
            doc.blocks[i].isDeleted = true
        }
        let empty = CRDTBlock(id: UUID(), type: "paragraph", text: CRDTText(string: "", deviceID: deviceID))
        doc.addBlock(empty)
        lastInsertionLocation = 0
    }
    
    /// Structured multi-line paste inserting distinct blocks across newlines (Cmd+V).
    public func insertStructuredText(_ text: String, at globalLocation: Int, replacingLength: Int = 0) -> Int {
        lock.lock()
        defer { lock.unlock() }
        
        let beforeSel = NSRange(location: globalLocation, length: replacingLength)
        recordUndo(beforeSelection: beforeSel, isTyping: false)
        
        if replacingLength > 0 {
            deleteRangeInternal(at: globalLocation, length: replacingLength)
        }
        
        return insertStructuredTextInternal(text, at: globalLocation)
    }
    
    private func insertStructuredTextInternal(_ text: String, at globalLocation: Int) -> Int {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        guard !lines.isEmpty else { return globalLocation }
        
        if lines.count == 1 {
            insertTextInternal(lines[0], at: globalLocation)
            return globalLocation + lines[0].count
        }
        
        guard let target = resolveLocationInternal(globalLocation) else {
            var currentID: UUID? = nil
            var totalLen = 0
            for line in lines {
                let block = CRDTBlock(id: UUID(), type: "paragraph", text: CRDTText(string: line, deviceID: deviceID))
                doc.insertBlock(block, afterBlockID: currentID)
                currentID = block.id
                totalLen += line.count + 1
            }
            return max(0, totalLen - 1)
        }
        
        let currentString = target.block.text.string
        let textBefore = String(currentString.prefix(target.relativeIndex))
        let textAfter = String(currentString.dropFirst(target.relativeIndex))
        
        // 1. Truncate current block and append first line
        let firstLine = lines[0]
        let currentBlockNewText = textBefore + firstLine
        
        if let idx = doc.blocks.firstIndex(where: { $0.id == target.block.id }) {
            doc.blocks[idx].text = CRDTText(string: currentBlockNewText, deviceID: deviceID)
            doc.blocks[idx].lastModified = Date().timeIntervalSince1970
        }
        
        let subType = (target.block.type == "checklistItem" || target.block.type == "bullet") ? target.block.type : "paragraph"
        let subAttrs = (target.block.type == "checklistItem") ? ["isChecked": "false"] : [:]
        
        var prevBlockID = target.block.id
        var lastInsertedBlockID = target.block.id
        var lastLineLen = 0
        
        // 2. Insert intermediate lines as distinct CRDT blocks
        for (idx, line) in lines.dropFirst().enumerated() {
            let isLast = (idx == lines.count - 2)
            let blockContent = isLast ? (line + textAfter) : line
            lastLineLen = line.count
            
            let newBlockID = UUID()
            let newBlock = CRDTBlock(
                id: newBlockID,
                type: subType,
                text: CRDTText(string: blockContent, deviceID: deviceID),
                attributes: subAttrs,
                lastModified: Date().timeIntervalSince1970
            )
            doc.insertBlock(newBlock, afterBlockID: prevBlockID)
            prevBlockID = newBlockID
            lastInsertedBlockID = newBlockID
        }
        
        _ = doc.vectorClock.increment(for: deviceID)
        
        _ = renderAttributedString() // Refresh block ranges
        let lastBlockRange = blockRanges[lastInsertedBlockID] ?? NSRange(location: 0, length: 0)
        let newCursor = lastBlockRange.location + lastLineLen
        lastInsertionLocation = newCursor
        return newCursor
    }
    
    /// Splits the current block on Return keypress with Apple Notes semantics.
    @discardableResult
    public func splitBlock(at globalLocation: Int) -> SplitResult? {
        lock.lock()
        defer { lock.unlock() }
        
        let beforeSel = NSRange(location: globalLocation, length: 0)
        
        // Sticky marks must NOT leak across Enter / block splits
        self.stickyMarks.removeAll()
        
        guard let target = resolveLocationInternal(globalLocation) else { return nil }
        
        let oldType = target.block.type
        let currentString = target.block.text.string
        
        // Check for empty list item (Checklist, Bullet, Heading) -> Revert to paragraph (Exit list mode)
        if currentString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if oldType == "checklistItem" || oldType == "bullet" || oldType == "heading" {
                let op = CRDTOperation.updateBlockMetadata(blockID: target.block.id, oldType: oldType, newType: "paragraph", oldAttributes: target.block.attributes, newAttributes: [:])
                recordUndo(operations: [op], beforeSelection: beforeSel, isTyping: false)
                
                if let idx = doc.blocks.firstIndex(where: { $0.id == target.block.id }) {
                    doc.blocks[idx].type = "paragraph"
                    doc.blocks[idx].attributes = [:]
                    doc.blocks[idx].lastModified = Date().timeIntervalSince1970
                    _ = doc.vectorClock.increment(for: deviceID)
                }
                lastInsertionLocation = globalLocation
                return SplitResult(newBlockID: nil, newCursor: globalLocation, oldBlockType: oldType, newBlockType: "paragraph")
            }
        }
        
        // Non-empty or standard paragraph split:
        let textAfter = String(currentString.dropFirst(target.relativeIndex))
        var ops: [CRDTOperation] = []
        
        if target.relativeIndex < currentString.count {
            if let idx = doc.blocks.firstIndex(where: { $0.id == target.block.id }) {
                doc.blocks[idx].adjustMarksForDeletion(at: target.relativeIndex, length: currentString.count - target.relativeIndex)
            }
            ops.append(.deleteText(blockID: target.block.id, position: target.relativeIndex, length: textAfter.count, deletedText: textAfter))
            doc.deleteText(at: target.relativeIndex, length: currentString.count - target.relativeIndex, in: target.block.id)
        }
        
        let newBlockID = UUID()
        let newType: String
        let newAttributes: [String: String]
        
        if oldType == "checklistItem" {
            newType = "checklistItem"
            newAttributes = ["isChecked": "false"]
        } else if oldType == "bullet" {
            newType = "bullet"
            newAttributes = [:]
        } else {
            newType = "paragraph"
            newAttributes = [:]
        }
        
        let newBlock = CRDTBlock(
            id: newBlockID,
            type: newType,
            text: CRDTText(string: textAfter, deviceID: deviceID),
            attributes: newAttributes,
            lastModified: Date().timeIntervalSince1970
        )
        
        ops.append(.createBlock(block: newBlock, afterBlockID: target.block.id))
        recordUndo(operations: ops, beforeSelection: beforeSel, isTyping: false)
        
        doc.insertBlock(newBlock, afterBlockID: target.block.id)
        let newCursor = globalLocation + 1
        lastInsertionLocation = newCursor
        
        return SplitResult(newBlockID: newBlockID, newCursor: newCursor, oldBlockType: oldType, newBlockType: newType)
    }
    
    private func mergeBlockWithPreceding(targetBlockIndex: Int) {
        let active = doc.blocks.filter { !$0.isDeleted }
        guard targetBlockIndex > 0, targetBlockIndex < active.count else { return }
        
        let prevBlock = active[targetBlockIndex - 1]
        let currentBlock = active[targetBlockIndex]
        
        let currentText = currentBlock.text.string
        if !currentText.isEmpty {
            let offset = prevBlock.text.string.count
            if let prevIdx = doc.blocks.firstIndex(where: { $0.id == prevBlock.id }) {
                for mark in currentBlock.marks {
                    doc.blocks[prevIdx].marks.append(
                        CRDTTextMark(
                            type: mark.type,
                            startIndex: mark.startIndex + offset,
                            endIndex: mark.endIndex + offset
                        )
                    )
                }
            }
            doc.insertText(currentText, at: prevBlock.text.string.count, in: prevBlock.id)
        }
        
        doc.removeBlock(blockID: currentBlock.id)
    }
    
    // MARK: - Formatting & Inline Marks
    
    public func applyInlineMark(type: String, in globalRange: NSRange) {
        lock.lock()
        defer { lock.unlock() }
        recordUndo(beforeSelection: globalRange, isTyping: false)
        applyInlineMarkInternal(type: type, in: globalRange)
    }
    
    public func removeInlineMark(type: String, in globalRange: NSRange) {
        lock.lock()
        defer { lock.unlock() }
        recordUndo(beforeSelection: globalRange, isTyping: false)
        removeInlineMarkInternal(type: type, in: globalRange)
    }
    
    public func toggleInlineMark(type: String, in globalRange: NSRange) {
        lock.lock()
        defer { lock.unlock() }
        
        if globalRange.length > 0 {
            recordUndo(beforeSelection: globalRange, isTyping: false)
            let active = activeInlineMarksInternal(at: globalRange)
            if active.contains(type) {
                removeInlineMarkInternal(type: type, in: globalRange)
            } else {
                applyInlineMarkInternal(type: type, in: globalRange)
            }
        } else {
            // Empty selection: toggle sticky mark for subsequent typing
            if stickyMarks.contains(type) {
                stickyMarks.remove(type)
            } else {
                stickyMarks.insert(type)
            }
            lastInsertionLocation = globalRange.location
            stickyArmTime = Date()
        }
    }
    
    private func applyInlineMarkInternal(type: String, in globalRange: NSRange) {
        let activeBlocks = doc.blocks.filter { !$0.isDeleted }
        var runningOffset = 0
        
        for block in activeBlocks {
            let blockLen = block.text.string.count
            let blockRange = NSRange(location: runningOffset, length: blockLen)
            
            let intersection = NSIntersectionRange(globalRange, blockRange)
            if intersection.length > 0 {
                let startRel = intersection.location - runningOffset
                let endRel = startRel + intersection.length
                
                if let idx = doc.blocks.firstIndex(where: { $0.id == block.id }) {
                    doc.blocks[idx].applyMark(type: type, startIndex: startRel, endIndex: endRel)
                    _ = doc.vectorClock.increment(for: deviceID)
                }
            }
            runningOffset += blockLen + 1
        }
    }
    
    private func removeInlineMarkInternal(type: String, in globalRange: NSRange) {
        let activeBlocks = doc.blocks.filter { !$0.isDeleted }
        var runningOffset = 0
        
        for block in activeBlocks {
            let blockLen = block.text.string.count
            let blockRange = NSRange(location: runningOffset, length: blockLen)
            
            let intersection = NSIntersectionRange(globalRange, blockRange)
            if intersection.length > 0 {
                let startRel = intersection.location - runningOffset
                let endRel = startRel + intersection.length
                
                if let idx = doc.blocks.firstIndex(where: { $0.id == block.id }) {
                    doc.blocks[idx].removeMark(type: type, startIndex: startRel, endIndex: endRel)
                    _ = doc.vectorClock.increment(for: deviceID)
                }
            }
            runningOffset += blockLen + 1
        }
    }
    
    public func setBlockType(_ type: String, at globalLocation: Int, attributes: [String: String] = [:]) {
        lock.lock()
        defer { lock.unlock() }
        
        recordUndo(beforeSelection: NSRange(location: globalLocation, length: 0), isTyping: false)
        guard let target = resolveLocationInternal(globalLocation) else { return }
        if let idx = doc.blocks.firstIndex(where: { $0.id == target.block.id }) {
            doc.blocks[idx].type = type
            for (k, v) in attributes {
                doc.blocks[idx].attributes[k] = v
            }
            doc.blocks[idx].lastModified = Date().timeIntervalSince1970
            _ = doc.vectorClock.increment(for: deviceID)
        }
    }
    
    /// Converts current block to the requested block type, or reverts to .paragraph if already active.
    public func toggleBlockType(_ targetType: EditorBlockType, at globalLocation: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        recordUndo(beforeSelection: NSRange(location: globalLocation, length: 0), isTyping: false)
        guard let target = resolveLocationInternal(globalLocation) else { return }
        guard let idx = doc.blocks.firstIndex(where: { $0.id == target.block.id }) else { return }
        
        let currentBlock = doc.blocks[idx]
        let currentType = blockType(for: currentBlock)
        let (rawType, rawAttributes) = targetType.rawBlockType
        
        if currentType == targetType {
            doc.blocks[idx].type = "paragraph"
            doc.blocks[idx].attributes = [:]
        } else {
            doc.blocks[idx].type = rawType
            doc.blocks[idx].attributes = rawAttributes
        }
        
        doc.blocks[idx].lastModified = Date().timeIntervalSince1970
        _ = doc.vectorClock.increment(for: deviceID)
    }
    
    public func toggleChecklist(at globalLocation: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        recordUndo(beforeSelection: NSRange(location: globalLocation, length: 0), isTyping: false)
        guard let target = resolveLocationInternal(globalLocation) else { return }
        doc.toggleChecklist(blockID: target.block.id)
    }
    
    public func toggleChecklist(blockID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        
        recordUndo(beforeSelection: lastKnownSelection, isTyping: false)
        doc.toggleChecklist(blockID: blockID)
    }
    
    // MARK: - Formatting State Derivation (Source of Truth = CRDT)
    
    public func activeInlineMarks(at selection: NSRange) -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return activeInlineMarksInternal(at: selection)
    }
    
    public func blockType(at location: Int) -> EditorBlockType {
        lock.lock()
        defer { lock.unlock() }
        guard let target = resolveLocationInternal(location) else { return .paragraph }
        return blockType(for: target.block)
    }
    
    public func currentFormattingState(at selection: NSRange) -> FormattingState {
        lock.lock()
        defer { lock.unlock() }
        
        let marks = activeInlineMarksInternal(at: selection)
        let isBold = stickyMarks.contains("bold") || marks.contains("bold")
        let isItalic = stickyMarks.contains("italic") || marks.contains("italic")
        let isUnderline = stickyMarks.contains("underline") || marks.contains("underline")
        let isStrikethrough = stickyMarks.contains("strikethrough") || marks.contains("strikethrough")
        
        let bType: EditorBlockType
        if let target = resolveLocationInternal(selection.location) {
            bType = blockType(for: target.block)
        } else {
            bType = .paragraph
        }
        
        return FormattingState(
            isBold: isBold,
            isItalic: isItalic,
            isUnderline: isUnderline,
            isStrikethrough: isStrikethrough,
            blockType: bType
        )
    }
    
    private func blockType(for block: CRDTBlock) -> EditorBlockType {
        if block.type == "heading" {
            let level = block.attributes["level"] ?? "1"
            if level == "1" { return .h1 }
            if level == "2" { return .h2 }
            if level == "3" { return .h3 }
            return .h1
        } else if block.type == "checklistItem" {
            return .checklist
        } else if block.type == "bullet" {
            return .bullet
        } else {
            return .paragraph
        }
    }
    
    private func activeInlineMarksInternal(at selection: NSRange) -> Set<String> {
        let activeBlocks = doc.blocks.filter { !$0.isDeleted }
        guard !activeBlocks.isEmpty else { return [] }
        
        if selection.length == 0 {
            let checkPos = max(0, selection.location > 0 ? selection.location - 1 : 0)
            guard let target = resolveLocationInternal(checkPos) else { return [] }
            
            var result = Set<String>()
            for mark in target.block.marks {
                if target.relativeIndex >= mark.startIndex && target.relativeIndex < mark.endIndex {
                    result.insert(mark.type)
                }
            }
            return result
        } else {
            var boldCovered = true
            var italicCovered = true
            var foundAnyBlock = false
            
            var runningOffset = 0
            for block in activeBlocks {
                let blockLen = block.text.string.count
                let blockRange = NSRange(location: runningOffset, length: blockLen)
                let intersection = NSIntersectionRange(selection, blockRange)
                
                if intersection.length > 0 {
                    foundAnyBlock = true
                    let startRel = intersection.location - runningOffset
                    let endRel = startRel + intersection.length
                    
                    let hasBold = block.marks.contains { $0.type == "bold" && $0.startIndex <= startRel && $0.endIndex >= endRel }
                    if !hasBold { boldCovered = false }
                    
                    let hasItalic = block.marks.contains { $0.type == "italic" && $0.startIndex <= startRel && $0.endIndex >= endRel }
                    if !hasItalic { italicCovered = false }
                }
                runningOffset += blockLen + 1
            }
            
            guard foundAnyBlock else { return [] }
            var result = Set<String>()
            if boldCovered { result.insert("bold") }
            if italicCovered { result.insert("italic") }
            return result
        }
    }
    
    // MARK: - Attributed String Generation & Inline Mark Rendering
    
    public func renderAttributedString() -> NSAttributedString {
        lock.lock()
        defer { lock.unlock() }
        
        let result = NSMutableAttributedString()
        blockRanges.removeAll()
        
        let activeBlocks = doc.blocks.filter { !$0.isDeleted }
        if activeBlocks.isEmpty {
            let emptyAttrs = TextKit2BlockAttributes.attributes(for: "paragraph")
            return NSAttributedString(string: "", attributes: emptyAttrs)
        }
        
        for (index, block) in activeBlocks.enumerated() {
            let startLocation = result.length
            let blockAttrs = TextKit2BlockAttributes.attributes(for: block.type, attributes: block.attributes, isFirstBlock: index == 0)
            let blockText = block.text.string
            
            let mutableBlock = NSMutableAttributedString(string: blockText, attributes: blockAttrs)
            
            // Apply inline marks (Bold / Italic)
            for mark in block.marks {
                let clampedStart = max(0, min(mark.startIndex, blockText.count))
                let clampedEnd = max(clampedStart, min(mark.endIndex, blockText.count))
                let markRange = NSRange(location: clampedStart, length: clampedEnd - clampedStart)
                
                if markRange.length > 0 {
                    if mark.type == "bold" {
                        let baseFont = (blockAttrs[.font] as? NSFont) ?? NSFont.systemFont(ofSize: 14)
                        let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
                        mutableBlock.addAttribute(.font, value: boldFont, range: markRange)
                    } else if mark.type == "italic" {
                        let baseFont = (blockAttrs[.font] as? NSFont) ?? NSFont.systemFont(ofSize: 14)
                        let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
                        mutableBlock.addAttribute(.font, value: italicFont, range: markRange)
                    }
                }
            }
            
            result.append(mutableBlock)
            
            let endLocation = result.length
            blockRanges[block.id] = NSRange(location: startLocation, length: endLocation - startLocation)
            
            // Trailing newline between blocks
            if index < activeBlocks.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: blockAttrs))
            }
        }
        
        return result
    }
    
    // MARK: - Markdown Auto-Formatting & Backspace Revert
    
    public func convertMarkdownPrefix(at globalLocation: Int) -> (newCursor: Int, blockType: EditorBlockType)? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let target = resolveLocationInternal(globalLocation) else { return nil }
        let blockText = target.block.text.string
        let textBefore = String(blockText.prefix(target.relativeIndex))
        
        var matchType: (type: String, attrs: [String: String], prefix: String)? = nil
        
        if textBefore == "###" {
            matchType = ("heading", ["level": "3"], "###")
        } else if textBefore == "##" {
            matchType = ("heading", ["level": "2"], "##")
        } else if textBefore == "#" {
            matchType = ("heading", ["level": "1"], "#")
        } else if textBefore == "-" || textBefore == "*" {
            matchType = ("bullet", [:], textBefore)
        } else if textBefore == "1." {
            matchType = ("bullet", [:], "1.")
        } else if textBefore == "[]" || textBefore == "[ ]" {
            matchType = ("checklistItem", ["isChecked": "false"], textBefore)
        }
        
        guard let match = matchType else { return nil }
        
        recordUndo(beforeSelection: NSRange(location: globalLocation, length: 0), isTyping: false)
        
        let blockStartLocation = globalLocation - match.prefix.count
        
        lastAutoFormatRevert = AutoFormatRevertState(
            blockID: target.block.id,
            originalType: target.block.type,
            originalAttributes: target.block.attributes,
            prefix: match.prefix,
            location: blockStartLocation
        )
        
        doc.deleteText(at: 0, length: match.prefix.count, in: target.block.id)
        
        if let idx = doc.blocks.firstIndex(where: { $0.id == target.block.id }) {
            doc.blocks[idx].type = match.type
            doc.blocks[idx].attributes = match.attrs
        }
        
        let bType: EditorBlockType
        if match.type == "heading" {
            let lvl = match.attrs["level"] ?? "1"
            bType = (lvl == "1" ? .h1 : (lvl == "2" ? .h2 : .h3))
        } else if match.type == "checklistItem" {
            bType = .checklist
        } else if match.type == "bullet" {
            bType = .bullet
        } else {
            bType = .paragraph
        }
        
        return (newCursor: blockStartLocation, blockType: bType)
    }
    
    public func revertAutoFormat() -> (restoredCursor: Int, blockType: EditorBlockType)? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let revert = lastAutoFormatRevert else { return nil }
        guard let idx = doc.blocks.firstIndex(where: { $0.id == revert.blockID && !$0.isDeleted }) else {
            lastAutoFormatRevert = nil
            return nil
        }
        
        recordUndo(beforeSelection: NSRange(location: revert.location, length: 0), isTyping: false)
        
        doc.blocks[idx].type = revert.originalType
        doc.blocks[idx].attributes = revert.originalAttributes
        
        let restoredPrefix = revert.prefix + " "
        doc.insertText(restoredPrefix, at: 0, in: revert.blockID)
        
        let newCursor = revert.location + restoredPrefix.count
        lastAutoFormatRevert = nil
        
        let bType = blockType(for: doc.blocks[idx])
        return (restoredCursor: newCursor, blockType: bType)
    }
    
    // MARK: - List Indentation (Tab / Shift-Tab)
    
    public func indentBlock(at globalLocation: Int, direction: Int) -> (newLevel: Int, blockType: EditorBlockType)? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let target = resolveLocationInternal(globalLocation) else { return nil }
        guard target.block.type == "checklistItem" || target.block.type == "bullet" else { return nil }
        
        guard let idx = doc.blocks.firstIndex(where: { $0.id == target.block.id }) else { return nil }
        
        let currentLevel = Int(doc.blocks[idx].attributes["indentLevel", default: "0"]) ?? 0
        let newLevel = min(3, max(0, currentLevel + direction))
        
        guard newLevel != currentLevel else { return nil }
        
        recordUndo(beforeSelection: NSRange(location: globalLocation, length: 0), isTyping: false)
        doc.blocks[idx].attributes["indentLevel"] = "\(newLevel)"
        
        return (newLevel: newLevel, blockType: blockType(for: doc.blocks[idx]))
    }
    
    // MARK: - Rich Pasteboard Interop
    
    public func exportPlainText(for range: NSRange) -> String {
        lock.lock()
        defer { lock.unlock() }
        let full = renderAttributedStringInternal()
        let clamped = NSRange(location: max(0, min(range.location, full.length)), length: max(0, min(range.length, full.length - max(0, min(range.location, full.length)))))
        return (full.string as NSString).substring(with: clamped)
    }
    
    public func exportRTF(for range: NSRange) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        let full = renderAttributedStringInternal()
        let clamped = NSRange(location: max(0, min(range.location, full.length)), length: max(0, min(range.length, full.length - max(0, min(range.location, full.length)))))
        let sub = full.attributedSubstring(from: clamped)
        return try? sub.data(from: NSRange(location: 0, length: sub.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }
    
    public func exportHTML(for range: NSRange) -> String {
        lock.lock()
        defer { lock.unlock() }
        
        let activeBlocks = doc.blocks.filter { !$0.isDeleted }
        guard !activeBlocks.isEmpty else { return "" }
        
        var html = ""
        var runningOffset = 0
        
        for block in activeBlocks {
            let blockLen = block.text.string.count
            let blockRange = NSRange(location: runningOffset, length: blockLen)
            let intersection = NSIntersectionRange(blockRange, range)
            
            if intersection.length > 0 || (range.length == 0 && range.location >= runningOffset && range.location <= runningOffset + blockLen) {
                let startRel = max(0, intersection.location - runningOffset)
                let endRel = startRel + (range.length > 0 ? intersection.length : blockLen)
                let clampedStart = min(startRel, blockLen)
                let clampedEnd = min(max(clampedStart, endRel), blockLen)
                let rawSnippet = (block.text.string as NSString).substring(with: NSRange(location: clampedStart, length: clampedEnd - clampedStart))
                
                var formattedText = rawSnippet
                    .replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "<", with: "&lt;")
                    .replacingOccurrences(of: ">", with: "&gt;")
                
                if block.marks.contains(where: { $0.type == "bold" }) {
                    formattedText = "<strong>\(formattedText)</strong>"
                }
                if block.marks.contains(where: { $0.type == "italic" }) {
                    formattedText = "<em>\(formattedText)</em>"
                }
                
                switch block.type {
                case "heading":
                    let lvl = block.attributes["level", default: "1"]
                    html += "<h\(lvl)>\(formattedText)</h\(lvl)>\n"
                case "checklistItem":
                    let isChecked = block.attributes["isChecked"] == "true"
                    let checkedAttr = isChecked ? " checked" : ""
                    html += "<ul><li><input type=\"checkbox\"\(checkedAttr) disabled /> \(formattedText)</li></ul>\n"
                case "bullet":
                    html += "<ul><li>\(formattedText)</li></ul>\n"
                default:
                    html += "<p>\(formattedText)</p>\n"
                }
            }
            
            runningOffset += blockLen + 1
        }
        
        return html
    }
    
    public func writeToPasteboard(selection: NSRange) {
        let sel = selection.length > 0 ? selection : NSRange(location: 0, length: renderAttributedString().length)
        let text = exportPlainText(for: sel)
        let html = exportHTML(for: sel)
        let rtfData = exportRTF(for: sel)
        
        let pboard = NSPasteboard.general
        pboard.clearContents()
        
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        if !html.isEmpty {
            item.setString(html, forType: .html)
        }
        if let rtf = rtfData {
            item.setData(rtf, forType: .rtf)
        }
        pboard.writeObjects([item])
    }
    
    private func renderAttributedStringInternal() -> NSAttributedString {
        let result = NSMutableAttributedString()
        blockRanges.removeAll()
        
        let activeBlocks = doc.blocks.filter { !$0.isDeleted }
        if activeBlocks.isEmpty {
            let emptyAttrs = TextKit2BlockAttributes.attributes(for: "paragraph")
            return NSAttributedString(string: "", attributes: emptyAttrs)
        }
        
        for (index, block) in activeBlocks.enumerated() {
            let startLocation = result.length
            let blockAttrs = TextKit2BlockAttributes.attributes(for: block.type, attributes: block.attributes, isFirstBlock: index == 0)
            let blockText = block.text.string
            
            let mutableBlock = NSMutableAttributedString(string: blockText, attributes: blockAttrs)
            
            for mark in block.marks {
                let clampedStart = max(0, min(mark.startIndex, blockText.count))
                let clampedEnd = max(clampedStart, min(mark.endIndex, blockText.count))
                let markRange = NSRange(location: clampedStart, length: clampedEnd - clampedStart)
                
                if markRange.length > 0 {
                    if mark.type == "bold" {
                        let baseFont = (blockAttrs[.font] as? NSFont) ?? NSFont.systemFont(ofSize: 14)
                        let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
                        mutableBlock.addAttribute(.font, value: boldFont, range: markRange)
                    } else if mark.type == "italic" {
                        let baseFont = (blockAttrs[.font] as? NSFont) ?? NSFont.systemFont(ofSize: 14)
                        let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
                        mutableBlock.addAttribute(.font, value: italicFont, range: markRange)
                    }
                }
            }
            
            result.append(mutableBlock)
            let endLocation = result.length
            blockRanges[block.id] = NSRange(location: startLocation, length: endLocation - startLocation)
            
            if index < activeBlocks.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: blockAttrs))
            }
        }
        return result
    }
    
    private func resolveLocationInternal(_ globalIndex: Int) -> (block: CRDTBlock, blockIndex: Int, relativeIndex: Int)? {
        let activeBlocks = doc.blocks.filter { !$0.isDeleted }
        guard !activeBlocks.isEmpty else { return nil }
        
        var runningOffset = 0
        for (idx, block) in activeBlocks.enumerated() {
            let blockLen = block.text.string.count
            if globalIndex >= runningOffset && globalIndex <= runningOffset + blockLen {
                let relative = globalIndex - runningOffset
                return (block, idx, relative)
            }
            runningOffset += blockLen + 1
        }
        
        if let last = activeBlocks.last {
            return (last, activeBlocks.count - 1, last.text.string.count)
        }
        return nil
    }
}
