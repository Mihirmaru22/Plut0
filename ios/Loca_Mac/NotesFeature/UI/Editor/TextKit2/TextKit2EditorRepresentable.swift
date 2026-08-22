// MARK: - Architecture Decision Record (ADR)
// - SHIPPING TEXT SYSTEM: AppKit NSTextStorage (TextKit 1 compatible pipeline).
// - REASON: Hand-wired pure TextKit 2 stack produced a detached textStorage accessor, silently aborting insertText.
//   The AppKit NSTextStorage pipeline is proven, rock-solid, and zero-latency across all macOS versions.
// - The CRDT document model, block-attribute typography, and CRDT bridge are completely storage-agnostic.
// - TextKit 2 migration is deferred to Phase 5 (Polish) as a non-breaking optimization, not a correctness requirement.
//
// MARK: - Editing Contract: Option A (Native Apply + Observe)
// 1. textView(_:shouldChangeTextIn:replacementString:) updates the CRDT model and returns true for standard typing.
// 2. AppKit text engine natively commits glyphs to the backing store at 120fps with zero latency.
// 3. Return key triggers a custom block split and synchronous re-render with cursor placement.
// 4. Remote CRDT merges update textStorage only on remote deltas, preventing local render loops.
// 5. Checklist and bullet glyphs are drawn exclusively in the margin via custom draw(_:); storage string is untouched.
// 6. Bridge owns undo/redo history (allowsUndo = false) for deterministic state restoration.
// 7. Calm Surface Protocol: First block renders as title affordance (22pt bold); toolbar is contextual.
// 8. Phase 5 Native Hooks: Markdown prefix auto-formatting, instant backspace revert, tab indentation, rich pasteboard interop.

import Foundation
import Combine
import SwiftUI
import AppKit

/// Subclassed NSTextView supporting interactive margin-drawn glyphs, gutter clicks, focus callbacks, and text engine integration.
public final class NoteCanvasTextView: NSTextView {
    
    public weak var bridge: TextKitCRDTBridge?
    public var onGutterClicked: ((NSPoint) -> Bool)?
    public var onToggleBold: (() -> Void)?
    public var onToggleItalic: (() -> Void)?
    public var onUndo: (() -> Void)?
    public var onRedo: (() -> Void)?
    public var onFocusChanged: ((Bool) -> Void)?
    public var onIndentChanged: (() -> Void)?
    
    public override var acceptsFirstResponder: Bool { true }
    public override var canBecomeKeyView: Bool { true }
    public override var needsPanelToBecomeKey: Bool { true }
    
    public override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            onFocusChanged?(true)
        }
        return result
    }
    
    public override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result {
            onFocusChanged?(false)
        }
        return result
    }
    
    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        // Tab / Shift-Tab List Indentation
        if event.keyCode == 48 { // Tab key
            let isShift = event.modifierFlags.contains(.shift)
            let sel = self.selectedRange()
            if let bridge = self.bridge,
               let _ = bridge.indentBlock(at: sel.location, direction: isShift ? -1 : 1) {
                if let storage = self.textStorage {
                    let updated = bridge.renderAttributedString()
                    storage.setAttributedString(updated)
                    self.setSelectedRange(sel)
                    self.setNeedsDisplay(self.bounds)
                }
                onIndentChanged?()
                return true
            }
        }
        
        if flags == .command {
            if let chars = event.charactersIgnoringModifiers?.lowercased() {
                if chars == "b" {
                    onToggleBold?()
                    return true
                } else if chars == "i" {
                    onToggleItalic?()
                    return true
                } else if chars == "z" {
                    onUndo?()
                    return true
                } else if chars == "y" {
                    onRedo?()
                    return true
                } else if chars == "c" {
                    let sel = self.selectedRange()
                    self.bridge?.writeToPasteboard(selection: sel)
                    return true
                } else if chars == "x" {
                    let sel = self.selectedRange()
                    if let bridge = self.bridge {
                        bridge.writeToPasteboard(selection: sel)
                        if sel.length > 0 {
                            bridge.deleteRange(at: sel.location, length: sel.length)
                            if let storage = self.textStorage {
                                let updated = bridge.renderAttributedString()
                                storage.setAttributedString(updated)
                                let newSel = NSRange(location: sel.location, length: 0)
                                self.setSelectedRange(newSel)
                                bridge.updateLastKnownSelection(newSel)
                                self.setNeedsDisplay(self.bounds)
                            }
                            onIndentChanged?()
                        }
                    }
                    return true
                }
            }
        } else if flags == [.command, .shift] {
            if let chars = event.charactersIgnoringModifiers?.lowercased() {
                if chars == "z" {
                    onRedo?()
                    return true
                }
            }
        }
        return super.performKeyEquivalent(with: event)
    }
    
    public override func mouseDown(with event: NSEvent) {
        if window?.firstResponder != self {
            window?.makeFirstResponder(self)
        }
        
        let point = convert(event.locationInWindow, from: nil)
        if let handler = onGutterClicked, handler(point) {
            return
        }
        super.mouseDown(with: event)
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let bridge = bridge,
              let layoutManager = self.layoutManager,
              let textContainer = self.textContainer,
              let storage = self.textStorage else { return }
        
        let activeBlocks = bridge.doc.blocks.filter { !$0.isDeleted }
        let origin = self.textContainerOrigin
        
        for block in activeBlocks {
            guard block.type == "checklistItem" || block.type == "bullet" else { continue }
            guard let range = bridge.blockRanges[block.id] else { continue }
            guard range.location <= storage.length else { continue }
            
            let charIndex = min(range.location, max(0, storage.length - 1))
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: charIndex)
            guard glyphIndex < layoutManager.numberOfGlyphs || storage.length == 0 else { continue }
            
            var lineRange = NSRange(location: 0, length: 0)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineRange)
            
            let viewLineRect = NSRect(
                x: origin.x + lineRect.origin.x,
                y: origin.y + lineRect.origin.y,
                width: lineRect.width,
                height: lineRect.height
            )
            
            let indentLevel = min(3, max(0, Int(block.attributes["indentLevel", default: "0"]) ?? 0))
            let indentOffset = CGFloat(indentLevel) * 18.0
            
            if block.type == "checklistItem" {
                let isChecked = block.attributes["isChecked"] == "true"
                let symbolName = isChecked ? "checkmark.circle.fill" : "circle"
                let tintColor = isChecked ? NSColor.controlAccentColor : NSColor.secondaryLabelColor
                
                let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
                if let symbolImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Checkbox")?.withSymbolConfiguration(config) {
                    let tinted = symbolImage.copy() as! NSImage
                    tinted.lockFocus()
                    tintColor.set()
                    let imageRect = NSRect(origin: .zero, size: tinted.size)
                    imageRect.fill(using: .sourceAtop)
                    tinted.unlockFocus()
                    
                    let boxSize: CGFloat = 14
                    let boxX: CGFloat = origin.x + 4 + indentOffset
                    let boxY: CGFloat = viewLineRect.origin.y + max(0, (viewLineRect.height - boxSize) / 2)
                    let targetRect = NSRect(x: boxX, y: boxY, width: boxSize, height: boxSize)
                    
                    tinted.draw(in: targetRect, from: .zero, operation: .sourceOver, fraction: 1.0)
                }
            } else if block.type == "bullet" {
                let bulletStr = "•" as NSString
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 14, weight: .bold),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
                let bulletSize = bulletStr.size(withAttributes: attrs)
                let bulletX: CGFloat = origin.x + 6 + indentOffset
                let bulletY: CGFloat = viewLineRect.origin.y + max(0, (viewLineRect.height - bulletSize.height) / 2)
                bulletStr.draw(at: NSPoint(x: bulletX, y: bulletY), withAttributes: attrs)
            }
        }
    }
}

/// SwiftUI Representable wrapping AppKit NoteCanvasTextView wired to TextKitCRDTBridge.
public struct TextKit2EditorRepresentable: NSViewRepresentable {
    
    @ObservedObject public var state: EditorBridgeState
    public let onKeystroke: (CRDTDoc) -> Void
    public let onSelectionChanged: (NSRange) -> Void
    
    public init(
        state: EditorBridgeState,
        onKeystroke: @escaping (CRDTDoc) -> Void,
        onSelectionChanged: @escaping (NSRange) -> Void = { _ in }
    ) {
        self.state = state
        self.onKeystroke = onKeystroke
        self.onSelectionChanged = onSelectionChanged
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NoteCanvasTextView(frame: .zero)
        
        textView.bridge = state.bridge
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = false // Bridge owns undo/redo history
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.drawsBackground = false
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textColor = NSColor.labelColor
        textView.insertionPointColor = NSColor.controlAccentColor
        textView.textContainerInset = NSSize(width: 24, height: 20)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 676, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.lineFragmentPadding = 0
        
        textView.typingAttributes = [
            .font: NSFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: NSParagraphStyle.default
        ]
        
        context.coordinator.textView = textView
        
        // Focus state sync
        textView.onFocusChanged = { [weak state] isFocused in
            DispatchQueue.main.async {
                state?.isFocused = isFocused
            }
        }
        
        textView.onIndentChanged = { [weak state, weak self] in
            guard let state = state, let self = self else { return }
            self.onKeystroke(state.bridge.doc)
            DispatchQueue.main.async {
                state.refreshFormattingState()
            }
        }
        
        // Wire in-place format updates directly to textStorage with Programmatic-Edit Guard
        state.onInPlaceFormatUpdate = { [weak textView, weak state, weak coordinator = context.coordinator] in
            guard let tv = textView, let storage = tv.textStorage, let state = state else { return }
            let intendedCursor = state.bridge.lastKnownSelection
            coordinator?.isProgrammaticEdit = true
            let rendered = state.bridge.renderAttributedString()
            storage.setAttributedString(rendered)
            tv.setSelectedRange(intendedCursor)
            state.bridge.updateLastKnownSelection(intendedCursor)
            coordinator?.isProgrammaticEdit = false
            tv.setNeedsDisplay(tv.bounds)
            
            let bType = state.bridge.blockType(at: intendedCursor.location)
            var isChecked = false
            var isFirstBlock = false
            if let target = state.bridge.resolveLocation(intendedCursor.location) {
                isChecked = target.block.attributes["isChecked"] == "true"
                isFirstBlock = (target.blockIndex == 0)
            }
            coordinator?.syncTypingAttributes(for: bType, isChecked: isChecked, isFirstBlock: isFirstBlock)
            
            self.onKeystroke(state.bridge.doc)
        }
        
        // Wire Keyboard Shortcuts (⌘B / ⌘I)
        textView.onToggleBold = { [weak state] in
            guard let state = state else { return }
            DispatchQueue.main.async {
                state.toggleBold()
            }
        }
        
        textView.onToggleItalic = { [weak state] in
            guard let state = state else { return }
            DispatchQueue.main.async {
                state.toggleItalic()
            }
        }
        
        // Wire Bridge-Owned Undo / Redo
        textView.onUndo = { [weak textView, weak state, weak coordinator = context.coordinator] in
            guard let tv = textView, let storage = tv.textStorage, let state = state else { return }
            let curSel = state.bridge.lastKnownSelection
            if let restoredSelection = state.bridge.undo(currentSelection: curSel) {
                coordinator?.isProgrammaticEdit = true
                let rendered = state.bridge.renderAttributedString()
                storage.setAttributedString(rendered)
                let validCursor = min(restoredSelection.location, rendered.length)
                let targetSel = NSRange(location: validCursor, length: min(restoredSelection.length, rendered.length - validCursor))
                tv.setSelectedRange(targetSel)
                state.bridge.updateLastKnownSelection(targetSel)
                coordinator?.isProgrammaticEdit = false
                tv.setNeedsDisplay(tv.bounds)
                
                let bType = state.bridge.blockType(at: targetSel.location)
                var isChecked = false
                var isFirstBlock = false
                if let target = state.bridge.resolveLocation(targetSel.location) {
                    isChecked = target.block.attributes["isChecked"] == "true"
                    isFirstBlock = (target.blockIndex == 0)
                }
                coordinator?.syncTypingAttributes(for: bType, isChecked: isChecked, isFirstBlock: isFirstBlock)
                
                self.onKeystroke(state.bridge.doc)
                DispatchQueue.main.async {
                    state.refreshFormattingState()
                }
            }
        }
        
        textView.onRedo = { [weak textView, weak state, weak coordinator = context.coordinator] in
            guard let tv = textView, let storage = tv.textStorage, let state = state else { return }
            let curSel = state.bridge.lastKnownSelection
            if let restoredSelection = state.bridge.redo(currentSelection: curSel) {
                coordinator?.isProgrammaticEdit = true
                let rendered = state.bridge.renderAttributedString()
                storage.setAttributedString(rendered)
                let validCursor = min(restoredSelection.location, rendered.length)
                let targetSel = NSRange(location: validCursor, length: min(restoredSelection.length, rendered.length - validCursor))
                tv.setSelectedRange(targetSel)
                state.bridge.updateLastKnownSelection(targetSel)
                coordinator?.isProgrammaticEdit = false
                tv.setNeedsDisplay(tv.bounds)
                
                let bType = state.bridge.blockType(at: targetSel.location)
                var isChecked = false
                var isFirstBlock = false
                if let target = state.bridge.resolveLocation(targetSel.location) {
                    isChecked = target.block.attributes["isChecked"] == "true"
                    isFirstBlock = (target.blockIndex == 0)
                }
                coordinator?.syncTypingAttributes(for: bType, isChecked: isChecked, isFirstBlock: isFirstBlock)
                
                self.onKeystroke(state.bridge.doc)
                DispatchQueue.main.async {
                    state.refreshFormattingState()
                }
            }
        }
        
        // Gutter Click Handler
        textView.onGutterClicked = { [weak textView, weak coordinator = context.coordinator] clickPoint in
            guard let tv = textView, let storage = tv.textStorage else { return false }
            
            let relativeX = clickPoint.x - tv.textContainerOrigin.x
            let charIndex = tv.characterIndexForInsertion(at: clickPoint)
            guard let target = self.state.bridge.resolveLocation(charIndex),
                  target.block.type == "checklistItem" else {
                return false
            }
            
            let indentLevel = min(3, max(0, Int(target.block.attributes["indentLevel", default: "0"]) ?? 0))
            let indentOffset = CGFloat(indentLevel) * 18.0
            guard relativeX >= indentOffset && relativeX < indentOffset + 24 else { return false }
            
            // Toggle checklist state
            self.state.bridge.toggleChecklist(blockID: target.block.id)
            let intendedCursor = self.state.bridge.lastKnownSelection
            coordinator?.isProgrammaticEdit = true
            let updatedAttributed = self.state.bridge.renderAttributedString()
            storage.setAttributedString(updatedAttributed)
            tv.setSelectedRange(intendedCursor)
            self.state.bridge.updateLastKnownSelection(intendedCursor)
            coordinator?.isProgrammaticEdit = false
            
            tv.setNeedsDisplay(tv.bounds)
            
            let isChecked = target.block.attributes["isChecked"] != "true"
            coordinator?.syncTypingAttributes(for: .checklist, isChecked: isChecked, isFirstBlock: target.blockIndex == 0)
            
            DispatchQueue.main.async {
                self.state.refreshFormattingState()
                self.onKeystroke(self.state.bridge.doc)
            }
            return true
        }
        
        // Initial render directly into textStorage
        let initialAttributed = state.bridge.renderAttributedString()
        textView.textStorage?.setAttributedString(initialAttributed)
        
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        
        return scrollView
    }
    
    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        textView.bridge = state.bridge
        
        // Strictly guard against touching textStorage for local edits
        guard state.needsRemoteRefresh else {
            return
        }
        
        state.needsRemoteRefresh = false
        
        guard let storage = textView.textStorage else { return }
        let oldLength = storage.length
        let currentSelection = textView.selectedRange()
        
        context.coordinator.isProgrammaticEdit = true
        let newAttributed = state.bridge.renderAttributedString()
        storage.setAttributedString(newAttributed)
        
        // Hard Snap Cursor position based on length delta
        let delta = newAttributed.length - oldLength
        let newSelection = CursorSnapper.snapCursor(
            currentRange: currentSelection,
            remoteChangeLocation: currentSelection.location,
            deltaLength: delta,
            totalNewLength: newAttributed.length
        )
        textView.setSelectedRange(newSelection)
        state.bridge.updateLastKnownSelection(newSelection)
        textView.scrollRangeToVisible(newSelection)
        context.coordinator.isProgrammaticEdit = false
        textView.setNeedsDisplay(textView.bounds)
        
        let bType = state.bridge.blockType(at: newSelection.location)
        var isChecked = false
        var isFirstBlock = false
        if let target = state.bridge.resolveLocation(newSelection.location) {
            isChecked = target.block.attributes["isChecked"] == "true"
            isFirstBlock = (target.blockIndex == 0)
        }
        context.coordinator.syncTypingAttributes(for: bType, isChecked: isChecked, isFirstBlock: isFirstBlock)
    }
    
    public final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TextKit2EditorRepresentable
        weak var textView: NoteCanvasTextView?
        public var isProgrammaticEdit = false
        
        init(_ parent: TextKit2EditorRepresentable) {
            self.parent = parent
        }
        
        public func syncTypingAttributes(for blockType: EditorBlockType, isChecked: Bool = false, isFirstBlock: Bool = false) {
            guard let tv = textView else { return }
            let style = NSMutableParagraphStyle()
            var attrs: [NSAttributedString.Key: Any] = [:]
            
            switch blockType {
            case .checklist:
                style.headIndent = 24
                style.firstLineHeadIndent = 24
                style.paragraphSpacing = 4
                style.lineHeightMultiple = 1.2
                attrs[.font] = NSFont.systemFont(ofSize: 14)
                if isChecked {
                    attrs[.foregroundColor] = NSColor.secondaryLabelColor
                    attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                    attrs[.strikethroughColor] = NSColor.secondaryLabelColor
                } else {
                    attrs[.foregroundColor] = NSColor.labelColor
                }
            case .bullet:
                style.headIndent = 18
                style.firstLineHeadIndent = 18
                style.paragraphSpacing = 4
                style.lineHeightMultiple = 1.2
                attrs[.font] = NSFont.systemFont(ofSize: 14)
                attrs[.foregroundColor] = NSColor.labelColor
            case .h1:
                style.paragraphSpacingBefore = isFirstBlock ? 0 : 12
                style.paragraphSpacing = 6
                style.lineHeightMultiple = 1.15
                attrs[.font] = NSFont.systemFont(ofSize: 24, weight: .bold)
                attrs[.foregroundColor] = NSColor.labelColor
            case .h2:
                style.paragraphSpacingBefore = isFirstBlock ? 0 : 10
                style.paragraphSpacing = 4
                style.lineHeightMultiple = 1.15
                attrs[.font] = NSFont.systemFont(ofSize: 18, weight: .bold)
                attrs[.foregroundColor] = NSColor.labelColor
            case .h3:
                style.paragraphSpacingBefore = isFirstBlock ? 0 : 8
                style.paragraphSpacing = 3
                style.lineHeightMultiple = 1.15
                attrs[.font] = NSFont.systemFont(ofSize: 15, weight: .semibold)
                attrs[.foregroundColor] = NSColor.labelColor
            case .paragraph:
                style.headIndent = 0
                style.firstLineHeadIndent = 0
                if isFirstBlock {
                    style.paragraphSpacing = 8
                    style.lineHeightMultiple = 1.15
                    attrs[.font] = NSFont.systemFont(ofSize: 22, weight: .bold)
                } else {
                    style.paragraphSpacing = 4
                    style.lineHeightMultiple = 1.2
                    attrs[.font] = NSFont.systemFont(ofSize: 14)
                }
                attrs[.foregroundColor] = NSColor.labelColor
            }
            
            attrs[.paragraphStyle] = style
            tv.typingAttributes = attrs
        }
        
        public func textViewDidChangeSelection(_ notification: Notification) {
            guard !isProgrammaticEdit else { return }
            guard let tv = notification.object as? NSTextView else { return }
            let sel = tv.selectedRange()
            parent.state.bridge.updateLastKnownSelection(sel)
            parent.state.bridge.selectionDidChange(to: sel)
            
            let bType = parent.state.bridge.blockType(at: sel.location)
            var isChecked = false
            var isFirstBlock = false
            if let target = parent.state.bridge.resolveLocation(sel.location) {
                isChecked = target.block.attributes["isChecked"] == "true"
                isFirstBlock = (target.blockIndex == 0)
            }
            syncTypingAttributes(for: bType, isChecked: isChecked, isFirstBlock: isFirstBlock)
            
            DispatchQueue.main.async {
                self.parent.state.refreshFormattingState()
                self.parent.onSelectionChanged(sel)
            }
        }
        
        public func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            let replacement = replacementString ?? ""
            parent.state.bridge.updateLastKnownSelection(affectedCharRange)
            
            // 1. Markdown Auto-Formatting Prefix on Spacebar
            if replacement == " " {
                if let autoFormatted = parent.state.bridge.convertMarkdownPrefix(at: affectedCharRange.location) {
                    if let storage = textView.textStorage {
                        isProgrammaticEdit = true
                        let updatedAttributed = parent.state.bridge.renderAttributedString()
                        storage.setAttributedString(updatedAttributed)
                        let intendedCursor = NSRange(location: min(autoFormatted.newCursor, updatedAttributed.length), length: 0)
                        textView.setSelectedRange(intendedCursor)
                        parent.state.bridge.updateLastKnownSelection(intendedCursor)
                        isProgrammaticEdit = false
                        textView.setNeedsDisplay(textView.bounds)
                    }
                    
                    var isChecked = false
                    var isFirstBlock = false
                    if let target = parent.state.bridge.resolveLocation(autoFormatted.newCursor) {
                        isChecked = target.block.attributes["isChecked"] == "true"
                        isFirstBlock = (target.blockIndex == 0)
                    }
                    syncTypingAttributes(for: autoFormatted.blockType, isChecked: isChecked, isFirstBlock: isFirstBlock)
                    
                    parent.onKeystroke(parent.state.bridge.doc)
                    DispatchQueue.main.async {
                        self.parent.state.refreshFormattingState()
                    }
                    return false
                }
            }
            
            // 2. Instant Backspace Revert
            if replacement.isEmpty && (affectedCharRange.length == 1 || affectedCharRange.length == 0) {
                if let reverted = parent.state.bridge.revertAutoFormat() {
                    if let storage = textView.textStorage {
                        isProgrammaticEdit = true
                        let updatedAttributed = parent.state.bridge.renderAttributedString()
                        storage.setAttributedString(updatedAttributed)
                        let intendedCursor = NSRange(location: min(reverted.restoredCursor, updatedAttributed.length), length: 0)
                        textView.setSelectedRange(intendedCursor)
                        parent.state.bridge.updateLastKnownSelection(intendedCursor)
                        isProgrammaticEdit = false
                        textView.setNeedsDisplay(textView.bounds)
                    }
                    
                    var isChecked = false
                    var isFirstBlock = false
                    if let target = parent.state.bridge.resolveLocation(reverted.restoredCursor) {
                        isChecked = target.block.attributes["isChecked"] == "true"
                        isFirstBlock = (target.blockIndex == 0)
                    }
                    syncTypingAttributes(for: reverted.blockType, isChecked: isChecked, isFirstBlock: isFirstBlock)
                    
                    parent.onKeystroke(parent.state.bridge.doc)
                    DispatchQueue.main.async {
                        self.parent.state.refreshFormattingState()
                    }
                    return false
                }
            }
            
            // Clear auto-format revert state on other typing
            if replacement != " " && !replacement.isEmpty {
                parent.state.bridge.clearAutoFormatRevert()
            }
            
            // 3. Return key: Split block in-place with Apple Notes semantics
            if replacement == "\n" {
                if let split = parent.state.bridge.splitBlock(at: affectedCharRange.location) {
                    if let storage = textView.textStorage {
                        isProgrammaticEdit = true
                        let updatedAttributed = parent.state.bridge.renderAttributedString()
                        storage.setAttributedString(updatedAttributed)
                        let newCursorPos = min(split.newCursor, updatedAttributed.length)
                        let intendedCursor = NSRange(location: newCursorPos, length: 0)
                        textView.setSelectedRange(intendedCursor)
                        parent.state.bridge.updateLastKnownSelection(intendedCursor)
                        textView.scrollRangeToVisible(intendedCursor)
                        isProgrammaticEdit = false
                        textView.setNeedsDisplay(textView.bounds)
                    }
                    
                    let newBType = parent.state.bridge.blockType(at: split.newCursor)
                    var isChecked = false
                    var isFirstBlock = false
                    if let target = parent.state.bridge.resolveLocation(split.newCursor) {
                        isChecked = target.block.attributes["isChecked"] == "true"
                        isFirstBlock = (target.blockIndex == 0)
                    }
                    syncTypingAttributes(for: newBType, isChecked: isChecked, isFirstBlock: isFirstBlock)
                    
                    parent.onKeystroke(parent.state.bridge.doc)
                    DispatchQueue.main.async {
                        self.parent.state.refreshFormattingState()
                    }
                    return false
                }
            }
            
            // 4. Structured Multi-Line Paste (e.g. Cmd+V)
            if replacement.contains("\n") || replacement.contains("\r") {
                let newCursor = parent.state.bridge.insertStructuredText(replacement, at: affectedCharRange.location, replacingLength: affectedCharRange.length)
                if let storage = textView.textStorage {
                    isProgrammaticEdit = true
                    let updatedAttributed = parent.state.bridge.renderAttributedString()
                    storage.setAttributedString(updatedAttributed)
                    let intendedCursor = NSRange(location: min(newCursor, updatedAttributed.length), length: 0)
                    textView.setSelectedRange(intendedCursor)
                    parent.state.bridge.updateLastKnownSelection(intendedCursor)
                    textView.scrollRangeToVisible(intendedCursor)
                    isProgrammaticEdit = false
                    textView.setNeedsDisplay(textView.bounds)
                }
                let bType = parent.state.bridge.blockType(at: newCursor)
                var isChecked = false
                var isFirstBlock = false
                if let target = parent.state.bridge.resolveLocation(newCursor) {
                    isChecked = target.block.attributes["isChecked"] == "true"
                    isFirstBlock = (target.blockIndex == 0)
                }
                syncTypingAttributes(for: bType, isChecked: isChecked, isFirstBlock: isFirstBlock)
                
                parent.onKeystroke(parent.state.bridge.doc)
                DispatchQueue.main.async {
                    self.parent.state.refreshFormattingState()
                }
                return false
            }
            
            // 5. Multi-Block Deletion (e.g. Cmd+A + Delete, Backspace, or Selection Cut)
            if replacement.isEmpty && affectedCharRange.length > 0 {
                parent.state.bridge.deleteRange(at: affectedCharRange.location, length: affectedCharRange.length)
                if let storage = textView.textStorage {
                    isProgrammaticEdit = true
                    let updatedAttributed = parent.state.bridge.renderAttributedString()
                    storage.setAttributedString(updatedAttributed)
                    let intendedCursor = NSRange(location: min(affectedCharRange.location, updatedAttributed.length), length: 0)
                    textView.setSelectedRange(intendedCursor)
                    parent.state.bridge.updateLastKnownSelection(intendedCursor)
                    isProgrammaticEdit = false
                    textView.setNeedsDisplay(textView.bounds)
                }
                let bType = parent.state.bridge.blockType(at: affectedCharRange.location)
                var isChecked = false
                var isFirstBlock = false
                if let target = parent.state.bridge.resolveLocation(affectedCharRange.location) {
                    isChecked = target.block.attributes["isChecked"] == "true"
                    isFirstBlock = (target.blockIndex == 0)
                }
                syncTypingAttributes(for: bType, isChecked: isChecked, isFirstBlock: isFirstBlock)
                
                parent.onKeystroke(parent.state.bridge.doc)
                DispatchQueue.main.async {
                    self.parent.state.refreshFormattingState()
                }
                return false
            } else if !replacement.isEmpty {
                // If replacing a selection range before typing, delete the range first:
                if affectedCharRange.length > 0 {
                    parent.state.bridge.deleteRange(at: affectedCharRange.location, length: affectedCharRange.length)
                }
                parent.state.bridge.insertText(replacement, at: affectedCharRange.location)
            }
            
            textView.setNeedsDisplay(textView.bounds)
            parent.onKeystroke(parent.state.bridge.doc)
            DispatchQueue.main.async {
                self.parent.state.refreshFormattingState()
            }
            return true
        }
        
        public func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            let sel = tv.selectedRange()
            let bType = parent.state.bridge.blockType(at: sel.location)
            var isChecked = false
            var isFirstBlock = false
            if let target = parent.state.bridge.resolveLocation(sel.location) {
                isChecked = target.block.attributes["isChecked"] == "true"
                isFirstBlock = (target.blockIndex == 0)
            }
            syncTypingAttributes(for: bType, isChecked: isChecked, isFirstBlock: isFirstBlock)
        }
    }
}

/// Observable state container synchronizing the SwiftUI shell with the active TextKitCRDTBridge.
@MainActor
public final class EditorBridgeState: ObservableObject {
    public var bridge: TextKitCRDTBridge
    @Published public var formattingState: FormattingState = FormattingState()
    @Published public var isFocused: Bool = false
    public var needsRemoteRefresh: Bool = false
    public var currentSelection: NSRange = NSRange(location: 0, length: 0)
    
    // Callback to apply in-place text storage changes without triggering updateNSView
    public var onInPlaceFormatUpdate: (() -> Void)?
    
    public init(bridge: TextKitCRDTBridge) {
        self.bridge = bridge
        self.formattingState = bridge.currentFormattingState(at: bridge.lastKnownSelection)
    }
    
    public func updateSelection(_ newRange: NSRange) {
        self.currentSelection = newRange
        bridge.updateLastKnownSelection(newRange)
        bridge.selectionDidChange(to: newRange)
        refreshFormattingState()
    }
    
    public func refreshFormattingState() {
        let sel = bridge.lastKnownSelection
        let newState = bridge.currentFormattingState(at: sel)
        if formattingState != newState {
            formattingState = newState
        }
    }
    
    public func toggleBold() {
        let sel = bridge.lastKnownSelection
        bridge.toggleInlineMark(type: "bold", in: sel)
        if sel.length > 0 {
            onInPlaceFormatUpdate?()
        }
        refreshFormattingState()
    }
    
    public func toggleItalic() {
        let sel = bridge.lastKnownSelection
        bridge.toggleInlineMark(type: "italic", in: sel)
        if sel.length > 0 {
            onInPlaceFormatUpdate?()
        }
        refreshFormattingState()
    }
    
    public func toggleBlockType(_ type: EditorBlockType) {
        let sel = bridge.lastKnownSelection
        bridge.toggleBlockType(type, at: sel.location)
        onInPlaceFormatUpdate?()
        refreshFormattingState()
    }
    
    public func updateDocFromRemote(_ newDoc: CRDTDoc) {
        bridge.doc = newDoc
        bridge.clearUndoHistory()
        needsRemoteRefresh = true
        refreshFormattingState()
    }
    
    public func requestFormatRefresh() {
        onInPlaceFormatUpdate?()
        refreshFormattingState()
    }
}
