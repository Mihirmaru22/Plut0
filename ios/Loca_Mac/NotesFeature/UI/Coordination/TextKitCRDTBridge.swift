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
    public var blockType: EditorBlockType
    
    public init(isBold: Bool = false, isItalic: Bool = false, blockType: EditorBlockType = .paragraph) {
        self.isBold = isBold
        self.isItalic = isItalic
        self.blockType = blockType
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
public struct UndoRecord: Sendable {
    public let doc: CRDTDoc
    public let selection: NSRange
    public let timestamp: Date
    public let isTyping: Bool
    public let blockID: UUID?
    
    public init(doc: CRDTDoc, selection: NSRange, timestamp: Date = Date(), isTyping: Bool = false, blockID: UUID? = nil) {
        self.doc = doc
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
    
    // Bridge-owned Undo / Redo History Stacks
    private var undoStack: [UndoRecord] = []
    private var redoStack: [UndoRecord] = []
    private var lastTypingTime: Date = Date.distantPast
    private var lastTypingBlockID: UUID? = nil
    
    public init(doc: CRDTDoc, deviceID: String = "local-device") {
        self.doc = doc
        self.deviceID = deviceID
    }
    
    // MARK: - Undo / Redo History Management
    
    private func recordUndo(beforeSelection: NSRange, isTyping: Bool = false, blockID: UUID? = nil) {
        let now = Date()
        if isTyping,
           let lastBlock = lastTypingBlockID,
           lastBlock == blockID,
           now.timeIntervalSince(lastTypingTime) < 0.8,
           !undoStack.isEmpty,
           undoStack.last?.isTyping == true {
            lastTypingTime = now
            return
        }
        
        let record = UndoRecord(doc: self.doc, selection: beforeSelection, timestamp: now, isTyping: isTyping, blockID: blockID)
        undoStack.append(record)
        redoStack.removeAll()
        
        lastTypingTime = now
        lastTypingBlockID = blockID
    }
    
    public func undo(currentSelection: NSRange) -> NSRange? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let record = undoStack.popLast() else { return nil }
        
        let redoRecord = UndoRecord(doc: self.doc, selection: currentSelection, timestamp: Date(), isTyping: false, blockID: nil)
        redoStack.append(redoRecord)
        
        self.doc = record.doc
        self.stickyMarks.removeAll()
        self.lastKnownSelection = record.selection
        return record.selection
    }
    
    public func redo(currentSelection: NSRange) -> NSRange? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let record = redoStack.popLast() else { return nil }
        
        let undoRecord = UndoRecord(doc: self.doc, selection: currentSelection, timestamp: Date(), isTyping: false, blockID: nil)
        undoStack.append(undoRecord)
        
        self.doc = record.doc
        self.stickyMarks.removeAll()
        self.lastKnownSelection = record.selection
        return record.selection
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
        recordUndo(beforeSelection: beforeSel, isTyping: true, blockID: target?.block.id)
        
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
        recordUndo(beforeSelection: beforeSel, isTyping: false)
        
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
        recordUndo(beforeSelection: beforeSel, isTyping: false)
        
        // Sticky marks must NOT leak across Enter / block splits
        self.stickyMarks.removeAll()
        
        guard let target = resolveLocationInternal(globalLocation) else { return nil }
        
        let oldType = target.block.type
        let currentString = target.block.text.string
        
        // Check for empty list item (Checklist, Bullet, Heading) -> Revert to paragraph (Exit list mode)
        if currentString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if oldType == "checklistItem" || oldType == "bullet" || oldType == "heading" {
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
        
        if target.relativeIndex < currentString.count {
            if let idx = doc.blocks.firstIndex(where: { $0.id == target.block.id }) {
                doc.blocks[idx].adjustMarksForDeletion(at: target.relativeIndex, length: currentString.count - target.relativeIndex)
            }
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
        
        let bType: EditorBlockType
        if let target = resolveLocationInternal(selection.location) {
            bType = blockType(for: target.block)
        } else {
            bType = .paragraph
        }
        
        return FormattingState(isBold: isBold, isItalic: isItalic, blockType: bType)
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
            let blockAttrs = TextKit2BlockAttributes.attributes(for: block.type, attributes: block.attributes)
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
