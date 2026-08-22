import SwiftUI
import AppKit
import Combine

// MARK: - RichTextEditorController (Live Command Bridge for Apple Notes Engine)

@MainActor
public final class RichTextEditorController: ObservableObject {
    public weak var textView: LocaAppKitTextView?
    public var onTextChange: ((NSAttributedString, String) -> Void)?
    public var onSlashTriggered: ((CGPoint) -> Void)?
    
    // Live Active Formatting States (Observed by Aa Popover & Toolbar)
    @Published public var activeParagraphStyle: NoteParagraphStyle = .body
    @Published public var isBold: Bool = false
    @Published public var isItalic: Bool = false
    @Published public var isUnderlined: Bool = false
    @Published public var isStrikethrough: Bool = false
    @Published public var isHighlighted: Bool = false
    
    private var stateUpdateWorkItem: DispatchWorkItem?
    
    public init() {}
    
    // MARK: - Update Active States from Selection (Throttled for 120Hz Fluidity)
    
    public func updateActiveStates(immediate: Bool = false) {
        stateUpdateWorkItem?.cancel()
        
        let updateBlock = { [weak self] in
            guard let self = self, let textView = self.textView, let textStorage = textView.textStorage else { return }
            let selectedRange = textView.selectedRange()
            let string = textStorage.string as NSString
            
            let targetLocation = selectedRange.location > 0 ? (selectedRange.location < string.length ? selectedRange.location : string.length - 1) : 0
            
            var newStyle: NoteParagraphStyle = .body
            var newBold = false
            var newItalic = false
            var newUnderlined = false
            var newStrikethrough = false
            var newHighlighted = false
            
            if string.length > 0 && targetLocation < string.length {
                let paragraphRange = string.paragraphRange(for: NSRange(location: targetLocation, length: 0))
                let paragraphText = string.substring(with: paragraphRange)
                
                // Check list prefixes
                if paragraphText.hasPrefix("• ") {
                    newStyle = .bulletedList
                } else if paragraphText.hasPrefix("– ") {
                    newStyle = .dashedList
                } else if paragraphText.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil {
                    newStyle = .numberedList
                } else if let font = textStorage.attribute(.font, at: targetLocation, effectiveRange: nil) as? NSFont {
                    if font.pointSize >= 24 {
                        newStyle = .title
                    } else if font.pointSize >= 18 {
                        newStyle = .heading
                    } else if font.pointSize >= 15 {
                        newStyle = .subheading
                    } else if font.fontDescriptor.symbolicTraits.contains(.monoSpace) {
                        newStyle = .monostyled
                    } else {
                        newStyle = .body
                    }
                }
                
                // Check inline marks
                if let font = textStorage.attribute(.font, at: targetLocation, effectiveRange: nil) as? NSFont {
                    newBold = font.fontDescriptor.symbolicTraits.contains(.bold)
                    newItalic = font.fontDescriptor.symbolicTraits.contains(.italic)
                }
                
                let underlineVal = textStorage.attribute(.underlineStyle, at: targetLocation, effectiveRange: nil) as? Int
                newUnderlined = (underlineVal != nil && underlineVal != 0)
                
                let strikeVal = textStorage.attribute(.strikethroughStyle, at: targetLocation, effectiveRange: nil) as? Int
                newStrikethrough = (strikeVal != nil && strikeVal != 0)
                
                let bgVal = textStorage.attribute(.backgroundColor, at: targetLocation, effectiveRange: nil)
                newHighlighted = (bgVal != nil)
            }
            
            if self.activeParagraphStyle != newStyle { self.activeParagraphStyle = newStyle }
            if self.isBold != newBold { self.isBold = newBold }
            if self.isItalic != newItalic { self.isItalic = newItalic }
            if self.isUnderlined != newUnderlined { self.isUnderlined = newUnderlined }
            if self.isStrikethrough != newStrikethrough { self.isStrikethrough = newStrikethrough }
            if self.isHighlighted != newHighlighted { self.isHighlighted = newHighlighted }
        }
        
        if immediate {
            updateBlock()
        } else {
            let work = DispatchWorkItem(block: updateBlock)
            stateUpdateWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: work)
        }
    }
    
    // MARK: - Paragraph Style
    
    public func applyParagraphStyle(_ style: NoteParagraphStyle, preset: TypographyPreset) {
        guard let textView = textView, let textStorage = textView.textStorage else { return }
        let selectedRange = textView.selectedRange()
        let paragraphRange = (textStorage.string as NSString).paragraphRange(for: selectedRange)
        
        RichTextTypography.applyParagraphStyle(style, to: textStorage, range: paragraphRange, preset: preset)
        textView.typingAttributes = RichTextTypography.defaultAttributes(for: style, preset: preset)
        textView.didChangeText()
        activeParagraphStyle = style
        onTextChange?(NSAttributedString(attributedString: textStorage), textStorage.string)
    }
    
    // MARK: - Inline Traits
    
    public func toggleBold(preset: TypographyPreset) {
        guard let textView = textView, let textStorage = textView.textStorage else { return }
        let selectedRange = textView.selectedRange()
        let defaultFont = preset.font(for: activeParagraphStyle)
        
        if selectedRange.length > 0 {
            RichTextTypography.toggleTrait(.bold, in: textStorage, range: selectedRange, defaultFont: defaultFont)
            textView.didChangeText()
            updateActiveStates(immediate: true)
            onTextChange?(NSAttributedString(attributedString: textStorage), textStorage.string)
        } else {
            var currentFont = (textView.typingAttributes[.font] as? NSFont) ?? defaultFont
            var traits = currentFont.fontDescriptor.symbolicTraits
            if traits.contains(.bold) {
                traits.remove(.bold)
                isBold = false
            } else {
                traits.insert(.bold)
                isBold = true
            }
            let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits)
            let newFont = NSFont(descriptor: descriptor, size: currentFont.pointSize) ?? currentFont
            textView.typingAttributes[.font] = newFont
        }
    }
    
    public func toggleItalic(preset: TypographyPreset) {
        guard let textView = textView, let textStorage = textView.textStorage else { return }
        let selectedRange = textView.selectedRange()
        let defaultFont = preset.font(for: activeParagraphStyle)
        
        if selectedRange.length > 0 {
            RichTextTypography.toggleTrait(.italic, in: textStorage, range: selectedRange, defaultFont: defaultFont)
            textView.didChangeText()
            updateActiveStates(immediate: true)
            onTextChange?(NSAttributedString(attributedString: textStorage), textStorage.string)
        } else {
            var currentFont = (textView.typingAttributes[.font] as? NSFont) ?? defaultFont
            var traits = currentFont.fontDescriptor.symbolicTraits
            if traits.contains(.italic) {
                traits.remove(.italic)
                isItalic = false
            } else {
                traits.insert(.italic)
                isItalic = true
            }
            let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits)
            let newFont = NSFont(descriptor: descriptor, size: currentFont.pointSize) ?? currentFont
            textView.typingAttributes[.font] = newFont
        }
    }
    
    public func toggleUnderline() {
        guard let textView = textView, let textStorage = textView.textStorage else { return }
        let selectedRange = textView.selectedRange()
        if selectedRange.length > 0 {
            RichTextTypography.toggleUnderline(in: textStorage, range: selectedRange)
            textView.didChangeText()
            updateActiveStates(immediate: true)
            onTextChange?(NSAttributedString(attributedString: textStorage), textStorage.string)
        } else {
            let current = (textView.typingAttributes[.underlineStyle] as? Int) ?? 0
            let newVal = (current == 0) ? NSUnderlineStyle.single.rawValue : 0
            textView.typingAttributes[.underlineStyle] = newVal
            isUnderlined = (newVal != 0)
        }
    }
    
    public func toggleStrikethrough() {
        guard let textView = textView, let textStorage = textView.textStorage else { return }
        let selectedRange = textView.selectedRange()
        if selectedRange.length > 0 {
            RichTextTypography.toggleStrikethrough(in: textStorage, range: selectedRange)
            textView.didChangeText()
            updateActiveStates(immediate: true)
            onTextChange?(NSAttributedString(attributedString: textStorage), textStorage.string)
        } else {
            let current = (textView.typingAttributes[.strikethroughStyle] as? Int) ?? 0
            let newVal = (current == 0) ? NSUnderlineStyle.single.rawValue : 0
            textView.typingAttributes[.strikethroughStyle] = newVal
            isStrikethrough = (newVal != 0)
        }
    }
    
    public func toggleHighlight(color: RichTextTypography.NoteHighlightColor = .amber) {
        guard let textView = textView, let textStorage = textView.textStorage else { return }
        let selectedRange = textView.selectedRange()
        if selectedRange.length > 0 {
            RichTextTypography.toggleHighlight(in: textStorage, range: selectedRange, color: color)
            textView.didChangeText()
            updateActiveStates(immediate: true)
            onTextChange?(NSAttributedString(attributedString: textStorage), textStorage.string)
        } else {
            let current = textView.typingAttributes[.backgroundColor]
            if current != nil {
                textView.typingAttributes.removeValue(forKey: .backgroundColor)
                isHighlighted = false
            } else {
                textView.typingAttributes[.backgroundColor] = color.color
                isHighlighted = true
            }
        }
    }
    
    public func applyTextColor(_ color: NSColor) {
        guard let textView = textView, let textStorage = textView.textStorage else { return }
        let selectedRange = textView.selectedRange()
        if selectedRange.length > 0 {
            RichTextTypography.applyTextColor(color, in: textStorage, range: selectedRange)
            textView.didChangeText()
            onTextChange?(NSAttributedString(attributedString: textStorage), textStorage.string)
        } else {
            textView.typingAttributes[.foregroundColor] = color
        }
    }
    
    public func toggleChecklist(preset: TypographyPreset) {
        guard let textView = textView, let textStorage = textView.textStorage else { return }
        
        // Ensure text view is first responder so selectedRange is 100% active and valid
        if textView.window?.firstResponder != textView {
            textView.window?.makeFirstResponder(textView)
        }
        
        let selectedRange = textView.selectedRange()
        let defaultFont = preset.font(for: activeParagraphStyle)
        
        let newRange = RichTextTypography.toggleChecklistOnCurrentParagraph(in: textStorage, selectedRange: selectedRange, defaultFont: defaultFont)
        textView.setSelectedRange(newRange)
        textView.didChangeText()
        textView.setNeedsDisplay(textView.bounds)
        updateActiveStates(immediate: true)
        onTextChange?(NSAttributedString(attributedString: textStorage), textStorage.string)
    }
    
    public func insertImage(image: NSImage) {
        guard let textView = textView, let textStorage = textView.textStorage else { return }
        let location = textView.selectedRange().location
        RichTextTypography.insertImageAttachment(image: image, in: textStorage, at: location)
        textView.didChangeText()
        onTextChange?(NSAttributedString(attributedString: textStorage), textStorage.string)
    }
    
    public func insertLink(url: URL, title: String, preset: TypographyPreset) {
        guard let textView = textView, let textStorage = textView.textStorage else { return }
        let selectedRange = textView.selectedRange()
        
        let linkText = title.isEmpty ? url.absoluteString : title
        let attr = NSMutableAttributedString(string: linkText, attributes: RichTextTypography.defaultAttributes(for: activeParagraphStyle, preset: preset))
        attr.addAttribute(.link, value: url, range: NSRange(location: 0, length: attr.length))
        attr.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: attr.length))
        attr.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: NSRange(location: 0, length: attr.length))
        
        if selectedRange.length > 0 {
            textStorage.replaceCharacters(in: selectedRange, with: attr)
        } else {
            textStorage.insert(attr, at: selectedRange.location)
        }
        textView.didChangeText()
        onTextChange?(NSAttributedString(attributedString: textStorage), textStorage.string)
    }
    
    public func insertTable(rows: Int = 2, cols: Int = 2, preset: TypographyPreset) {
        guard let textView = textView, let textStorage = textView.textStorage else { return }
        let selectedRange = textView.selectedRange()
        
        var tableString = "\n┌" + String(repeating: "──────────────┬", count: cols - 1) + "──────────────┐\n"
        for r in 0..<rows {
            tableString += "│" + String(repeating: "              │", count: cols) + "\n"
            if r < rows - 1 {
                tableString += "├" + String(repeating: "──────────────┼", count: cols - 1) + "──────────────┤\n"
            }
        }
        tableString += "└" + String(repeating: "──────────────┴", count: cols - 1) + "──────────────┘\n"
        
        let font = preset.font(for: .monostyled)
        let attr = NSAttributedString(string: tableString, attributes: [
            .font: font,
            .foregroundColor: NSColor.textColor
        ])
        
        textStorage.insert(attr, at: selectedRange.location)
        textView.setSelectedRange(NSRange(location: selectedRange.location + attr.length, length: 0))
        textView.didChangeText()
        onTextChange?(NSAttributedString(attributedString: textStorage), textStorage.string)
    }
    
    // MARK: - In-Note Search Navigation
    
    public func jumpToNextMatch(query: String) {
        guard let textView = textView, let textStorage = textView.textStorage, !query.isEmpty else { return }
        let currentPos = textView.selectedRange().location + textView.selectedRange().length
        let fullString = textStorage.string as NSString
        let searchRange = NSRange(location: currentPos < fullString.length ? currentPos : 0, length: currentPos < fullString.length ? fullString.length - currentPos : fullString.length)
        
        var foundRange = fullString.range(of: query, options: .caseInsensitive, range: searchRange)
        if foundRange.location == NSNotFound && currentPos > 0 {
            // Wrap around
            foundRange = fullString.range(of: query, options: .caseInsensitive, range: NSRange(location: 0, length: fullString.length))
        }
        
        if foundRange.location != NSNotFound {
            textView.setSelectedRange(foundRange)
            textView.scrollRangeToVisible(foundRange)
            textView.showFindIndicator(for: foundRange)
        }
    }
    
    public func jumpToPreviousMatch(query: String) {
        guard let textView = textView, let textStorage = textView.textStorage, !query.isEmpty else { return }
        let currentPos = textView.selectedRange().location
        let fullString = textStorage.string as NSString
        let searchRange = NSRange(location: 0, length: min(currentPos, fullString.length))
        
        var foundRange = fullString.range(of: query, options: [.caseInsensitive, .backwards], range: searchRange)
        if foundRange.location == NSNotFound {
            // Wrap to end
            foundRange = fullString.range(of: query, options: [.caseInsensitive, .backwards], range: NSRange(location: 0, length: fullString.length))
        }
        
        if foundRange.location != NSNotFound {
            textView.setSelectedRange(foundRange)
            textView.scrollRangeToVisible(foundRange)
            textView.showFindIndicator(for: foundRange)
        }
    }
}

// MARK: - MacRichTextEditor (AppKit NSTextView Wrapper with 120Hz Decoupled Pipeline)

public struct MacRichTextEditor: NSViewRepresentable {
    
    let initialAttributedText: NSAttributedString
    let initialPlainText: String
    var preset: TypographyPreset = .standard
    var isEditable: Bool = true
    var controller: RichTextEditorController? = nil
    var onTextChangeDebounced: ((NSAttributedString, String) -> Void)? = nil
    var onSlashTriggered: ((CGPoint) -> Void)? = nil
    
    public init(
        initialAttributedText: NSAttributedString,
        initialPlainText: String,
        preset: TypographyPreset = .standard,
        isEditable: Bool = true,
        controller: RichTextEditorController? = nil,
        onTextChangeDebounced: ((NSAttributedString, String) -> Void)? = nil,
        onSlashTriggered: ((CGPoint) -> Void)? = nil
    ) {
        self.initialAttributedText = initialAttributedText
        self.initialPlainText = initialPlainText
        self.preset = preset
        self.isEditable = isEditable
        self.controller = controller
        self.onTextChangeDebounced = onTextChangeDebounced
        self.onSlashTriggered = onSlashTriggered
    }

    public init(
        attributedText: Binding<NSAttributedString>,
        plainText: Binding<String>,
        preset: TypographyPreset = .standard,
        isEditable: Bool = true,
        controller: RichTextEditorController? = nil,
        onTextChange: ((NSAttributedString, String) -> Void)? = nil
    ) {
        self.initialAttributedText = attributedText.wrappedValue
        self.initialPlainText = plainText.wrappedValue
        self.preset = preset
        self.isEditable = isEditable
        self.controller = controller
        self.onTextChangeDebounced = { attr, plain in
            attributedText.wrappedValue = attr
            plainText.wrappedValue = plain
            onTextChange?(attr, plain)
        }
        self.onSlashTriggered = nil
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        
        let contentSize = scrollView.contentSize
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        
        let textContainer = NSTextContainer(containerSize: NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)
        
        let textView = LocaAppKitTextView(frame: .zero, textContainer: textContainer)
        textView.minSize = NSSize(width: 0.0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        
        textView.drawsBackground = false
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.delegate = context.coordinator
        
        // Drag & Drop
        textView.registerForDraggedTypes([.fileURL, .png, .tiff, .string])
        
        // Native Apple Notes Insets & Caret
        textView.textContainerInset = NSSize(width: 32, height: 20)
        textView.insertionPointColor = NSColor(red: 0.96, green: 0.65, blue: 0.18, alpha: 1.0)
        textView.currentPreset = preset
        
        // Default typing attributes
        textView.typingAttributes = RichTextTypography.defaultAttributes(for: .body, preset: preset)
        
        // Populate Initial Content
        if initialAttributedText.length > 0 {
            textStorage.setAttributedString(initialAttributedText)
        } else if !initialPlainText.isEmpty {
            let migrated = RichTextTypography.convertMarkdownToAttributedString(markdown: initialPlainText, preset: preset)
            textStorage.setAttributedString(migrated)
        }
        
        context.coordinator.textView = textView
        if let ctrl = controller {
            ctrl.textView = textView
            ctrl.onTextChange = onTextChangeDebounced
            ctrl.onSlashTriggered = onSlashTriggered
            ctrl.updateActiveStates(immediate: true)
        }
        
        scrollView.documentView = textView
        return scrollView
    }
    
    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? LocaAppKitTextView else { return }
        
        context.coordinator.parent = self
        textView.currentPreset = preset
        if let ctrl = controller {
            ctrl.textView = textView
            ctrl.onTextChange = onTextChangeDebounced
            ctrl.onSlashTriggered = onSlashTriggered
        }
        
        textView.isEditable = isEditable
    }
    
    // MARK: - Coordinator (Decoupled Zero-Lag RunLoop Coordinator)
    
    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacRichTextEditor
        weak var textView: LocaAppKitTextView?
        private var debounceWorkItem: DispatchWorkItem?
        
        init(_ parent: MacRichTextEditor) {
            self.parent = parent
        }
        
        public func textDidChange(_ notification: Notification) {
            guard let textView = textView, let textStorage = textView.textStorage else { return }
            
            // 1. Throttled UI state update for formatting toolbar
            parent.controller?.updateActiveStates(immediate: false)
            
            // 2. Debounced save callback (Zero lag during continuous 120Hz keystrokes)
            debounceWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self, weak textStorage] in
                guard let self = self, let storage = textStorage else { return }
                let attrCopy = NSAttributedString(attributedString: storage)
                let plainCopy = storage.string
                self.parent.onTextChangeDebounced?(attrCopy, plainCopy)
            }
            debounceWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
        }
        
        public func textViewDidChangeSelection(_ notification: Notification) {
            parent.controller?.updateActiveStates(immediate: false)
        }
    }
}

// MARK: - LocaAppKitTextView (Subclass for Apple Notes Smart Mechanics, Line Swapping & Drag-Drop)

public final class LocaAppKitTextView: NSTextView {
    
    public var currentPreset: TypographyPreset = .standard
    public var onSlashRequested: ((CGPoint) -> Void)?
    
    // MARK: - Drag & Drop Operations (Images & Files from Finder)
    
    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if sender.draggingPasteboard.canReadItem(withDataConformingToTypes: ["public.file-url", "public.image"]) {
            return .copy
        }
        return super.draggingEntered(sender)
    }
    
    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pboard = sender.draggingPasteboard
        
        // 1. Image Files
        if let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let firstURL = urls.first {
            if let image = NSImage(contentsOf: firstURL) {
                let point = convert(sender.draggingLocation, from: nil)
                if let layoutManager = self.layoutManager, let textContainer = self.textContainer, let textStorage = self.textStorage {
                    let glyph = layoutManager.glyphIndex(for: point, in: textContainer)
                    let charIndex = layoutManager.characterIndexForGlyph(at: glyph)
                    RichTextTypography.insertImageAttachment(image: image, in: textStorage, at: charIndex)
                    self.didChangeText()
                    Haptics.notify(.success)
                    return true
                }
            }
        }
        
        // 2. Direct Image Objects
        if let images = pboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage], let firstImage = images.first {
            if let textStorage = self.textStorage {
                let location = self.selectedRange().location
                RichTextTypography.insertImageAttachment(image: firstImage, in: textStorage, at: location)
                self.didChangeText()
                Haptics.notify(.success)
                return true
            }
        }
        
        return super.performDragOperation(sender)
    }
    
    // MARK: - Line Reordering Handlers (⌥↑ / ⌥↓)
    
    public override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.option) {
            if event.keyCode == 126 { // Option + Up Arrow
                moveParagraphUp()
                return
            } else if event.keyCode == 125 { // Option + Down Arrow
                moveParagraphDown()
                return
            }
        }
        super.keyDown(with: event)
    }
    
    public func moveParagraphUp() {
        guard let textStorage = self.textStorage else { return }
        let string = textStorage.string as NSString
        let selectedRange = self.selectedRange()
        let currentParaRange = string.paragraphRange(for: selectedRange)
        
        guard currentParaRange.location > 0 else { return }
        
        let prevParaRange = string.paragraphRange(for: NSRange(location: currentParaRange.location - 1, length: 0))
        
        textStorage.beginEditing()
        let currentAttr = textStorage.attributedSubstring(from: currentParaRange)
        let prevAttr = textStorage.attributedSubstring(from: prevParaRange)
        
        let combinedRange = NSRange(location: prevParaRange.location, length: prevParaRange.length + currentParaRange.length)
        let swapped = NSMutableAttributedString(attributedString: currentAttr)
        swapped.append(prevAttr)
        
        textStorage.replaceCharacters(in: combinedRange, with: swapped)
        textStorage.endEditing()
        
        let relativeOffset = selectedRange.location - currentParaRange.location
        let newLocation = prevParaRange.location + relativeOffset
        self.setSelectedRange(NSRange(location: min(newLocation, textStorage.length), length: selectedRange.length))
        self.didChangeText()
        Haptics.impact(.light)
    }
    
    public func moveParagraphDown() {
        guard let textStorage = self.textStorage else { return }
        let string = textStorage.string as NSString
        let selectedRange = self.selectedRange()
        let currentParaRange = string.paragraphRange(for: selectedRange)
        let nextLocation = currentParaRange.location + currentParaRange.length
        
        guard nextLocation < string.length else { return }
        
        let nextParaRange = string.paragraphRange(for: NSRange(location: nextLocation, length: 0))
        
        textStorage.beginEditing()
        let currentAttr = textStorage.attributedSubstring(from: currentParaRange)
        let nextAttr = textStorage.attributedSubstring(from: nextParaRange)
        
        let combinedRange = NSRange(location: currentParaRange.location, length: currentParaRange.length + nextParaRange.length)
        let swapped = NSMutableAttributedString(attributedString: nextAttr)
        swapped.append(currentAttr)
        
        textStorage.replaceCharacters(in: combinedRange, with: swapped)
        textStorage.endEditing()
        
        let relativeOffset = selectedRange.location - currentParaRange.location
        let newLocation = currentParaRange.location + nextParaRange.length + relativeOffset
        self.setSelectedRange(NSRange(location: min(newLocation, textStorage.length), length: selectedRange.length))
        self.didChangeText()
        Haptics.impact(.light)
    }
    
    // MARK: - Smart Paste (Auto-Imports Markdown - [ ] / - [x] Checklists)
    
    public override func paste(_ sender: Any?) {
        let pboard = NSPasteboard.general
        
        // Auto-detect and import raw markdown checklist text
        if let plainText = pboard.string(forType: .string),
           (plainText.contains("- [ ] ") || plainText.contains("- [x] ") || plainText.contains("- [X] ") || plainText.hasPrefix("[] ") || plainText.hasPrefix("[ ] ")) {
            
            let selectedRange = self.selectedRange()
            let attributedPaste = RichTextTypography.convertMarkdownToAttributedString(markdown: plainText, preset: currentPreset)
            
            self.undoManager?.beginUndoGrouping()
            if let textStorage = self.textStorage {
                textStorage.beginEditing()
                textStorage.replaceCharacters(in: selectedRange, with: attributedPaste)
                textStorage.endEditing()
                self.setSelectedRange(NSRange(location: selectedRange.location + attributedPaste.length, length: 0))
            }
            self.undoManager?.endUndoGrouping()
            self.didChangeText()
            return
        }
        
        // Default AppKit paste (preserves internal rich text RTFD attributes and handles plain text without bleed)
        super.paste(sender)
    }
    
    // MARK: - Smart Markdown Trigger on Type (e.g. '# ', '- ', '1. ', '[] ')
    
    public override func shouldChangeText(in affectedCharRange: NSRange, replacementString: String?) -> Bool {
        guard let rep = replacementString, let textStorage = self.textStorage else {
            return super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
        }
        
        // Guard against firing markdown triggers during IME marked text composition
        guard !self.hasMarkedText() else {
            return super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
        }
        
        let string = textStorage.string as NSString
        let paragraphRange = string.paragraphRange(for: affectedCharRange)
        let paragraphText = string.substring(with: paragraphRange)
        let prefixLength = affectedCharRange.location - paragraphRange.location
        
        if rep == " " {
            if prefixLength > 0 && prefixLength <= 6 {
                let typedPrefix = string.substring(with: NSRange(location: paragraphRange.location, length: prefixLength))
                
                // Check if paragraph is already a checklist item (prevents double-conversion)
                let safeIndex = min(paragraphRange.location, max(0, textStorage.length - 1))
                let isAlreadyChecklist = textStorage.length > 0 && (textStorage.attribute(.noteChecklistState, at: safeIndex, effectiveRange: nil) != nil)
                
                // 1. Title (# )
                if typedPrefix == "#" {
                    textStorage.beginEditing()
                    textStorage.replaceCharacters(in: NSRange(location: paragraphRange.location, length: prefixLength), with: "")
                    RichTextTypography.applyParagraphStyle(.title, to: textStorage, range: NSRange(location: paragraphRange.location, length: 0), preset: currentPreset)
                    self.typingAttributes = RichTextTypography.defaultAttributes(for: .title, preset: currentPreset)
                    textStorage.endEditing()
                    self.setSelectedRange(NSRange(location: paragraphRange.location, length: 0))
                    self.didChangeText()
                    return false
                }
                
                // 2. Heading (## )
                if typedPrefix == "##" {
                    textStorage.beginEditing()
                    textStorage.replaceCharacters(in: NSRange(location: paragraphRange.location, length: prefixLength), with: "")
                    RichTextTypography.applyParagraphStyle(.heading, to: textStorage, range: NSRange(location: paragraphRange.location, length: 0), preset: currentPreset)
                    self.typingAttributes = RichTextTypography.defaultAttributes(for: .heading, preset: currentPreset)
                    textStorage.endEditing()
                    self.setSelectedRange(NSRange(location: paragraphRange.location, length: 0))
                    self.didChangeText()
                    return false
                }
                
                // 3. Subheading (### )
                if typedPrefix == "###" {
                    textStorage.beginEditing()
                    textStorage.replaceCharacters(in: NSRange(location: paragraphRange.location, length: prefixLength), with: "")
                    RichTextTypography.applyParagraphStyle(.subheading, to: textStorage, range: NSRange(location: paragraphRange.location, length: 0), preset: currentPreset)
                    self.typingAttributes = RichTextTypography.defaultAttributes(for: .subheading, preset: currentPreset)
                    textStorage.endEditing()
                    self.setSelectedRange(NSRange(location: paragraphRange.location, length: 0))
                    self.didChangeText()
                    return false
                }
                
                // 4. Bullet List (- or *)
                if typedPrefix == "-" || typedPrefix == "*" {
                    textStorage.beginEditing()
                    textStorage.replaceCharacters(in: NSRange(location: paragraphRange.location, length: prefixLength), with: "• ")
                    RichTextTypography.applyParagraphStyle(.bulletedList, to: textStorage, range: NSRange(location: paragraphRange.location, length: 2), preset: currentPreset)
                    self.typingAttributes = RichTextTypography.defaultAttributes(for: .bulletedList, preset: currentPreset)
                    textStorage.endEditing()
                    self.setSelectedRange(NSRange(location: paragraphRange.location + 2, length: 0))
                    self.didChangeText()
                    return false
                }
                
                // 5. Checklist ([] or [ ] or - [ ]) - Atomic Markdown Trigger
                if !isAlreadyChecklist && (typedPrefix == "[]" || typedPrefix == "[ ]" || typedPrefix == "- [ ]" || typedPrefix == "()" || typedPrefix == "( )") && paragraphText.hasPrefix(typedPrefix) {
                    self.undoManager?.beginUndoGrouping()
                    textStorage.beginEditing()
                    textStorage.replaceCharacters(in: NSRange(location: paragraphRange.location, length: prefixLength), with: "")
                    let pStyle = RichTextTypography.makeParagraphStyle(for: .checklist, preset: currentPreset)
                    let updatedRange = (textStorage.string as NSString).paragraphRange(for: NSRange(location: paragraphRange.location, length: 0))
                    textStorage.addAttribute(.paragraphStyle, value: pStyle, range: updatedRange)
                    textStorage.addAttribute(.noteChecklistState, value: ChecklistState.unchecked.rawValue, range: updatedRange)
                    textStorage.removeAttribute(.strikethroughStyle, range: updatedRange)
                    textStorage.addAttribute(.foregroundColor, value: NSColor.textColor, range: updatedRange)
                    self.typingAttributes = RichTextTypography.defaultAttributes(for: .checklist, preset: currentPreset)
                    textStorage.endEditing()
                    self.undoManager?.endUndoGrouping()
                    self.setSelectedRange(NSRange(location: paragraphRange.location, length: 0))
                    self.didChangeText()
                    return false
                }
                
                // 6. Blockquote (> )
                if typedPrefix == ">" && paragraphText.hasPrefix(">") {
                    self.undoManager?.beginUndoGrouping()
                    textStorage.beginEditing()
                    textStorage.replaceCharacters(in: NSRange(location: paragraphRange.location, length: prefixLength), with: "")
                    RichTextTypography.applyParagraphStyle(.quote, to: textStorage, range: NSRange(location: paragraphRange.location, length: 0), preset: currentPreset)
                    self.typingAttributes = RichTextTypography.defaultAttributes(for: .quote, preset: currentPreset)
                    textStorage.endEditing()
                    self.undoManager?.endUndoGrouping()
                    self.setSelectedRange(NSRange(location: paragraphRange.location, length: 0))
                    self.didChangeText()
                    return false
                }
            }
        }
        
        return super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
    }
    
    // MARK: - Smart Return & Continuations
    
    public override func insertNewline(_ sender: Any?) {
        guard let textStorage = self.textStorage else {
            super.insertNewline(sender)
            return
        }
        
        let selectedRange = self.selectedRange()
        let string = textStorage.string as NSString
        let paragraphRange = string.paragraphRange(for: selectedRange)
        let paragraphText = string.substring(with: paragraphRange)
        
        // 1. Checklist smart continuation (Pure Paragraph Attribute)
        guard textStorage.length > 0 else {
            super.insertNewline(sender)
            return
        }
        let safeIndex = min(paragraphRange.location, textStorage.length - 1)
        let isChecklist = textStorage.attribute(.noteChecklistState, at: safeIndex, effectiveRange: nil) != nil
        if isChecklist {
            let cleanText = paragraphText.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanText.isEmpty {
                // Empty line -> escape checklist mode and convert to plain body
                self.undoManager?.beginUndoGrouping()
                textStorage.beginEditing()
                textStorage.removeAttribute(.noteChecklistState, range: paragraphRange)
                textStorage.removeAttribute(.strikethroughStyle, range: paragraphRange)
                textStorage.addAttribute(.foregroundColor, value: NSColor.textColor, range: paragraphRange)
                let bodyStyle = RichTextTypography.makeParagraphStyle(for: .body, preset: currentPreset)
                textStorage.addAttribute(.paragraphStyle, value: bodyStyle, range: paragraphRange)
                self.typingAttributes = RichTextTypography.defaultAttributes(for: .body, preset: currentPreset)
                textStorage.endEditing()
                self.undoManager?.endUndoGrouping()
                self.didChangeText()
                return
            } else {
                // Populated line -> create new unchecked checklist line inheriting exact indent level
                let currentStyle = (textStorage.attribute(.paragraphStyle, at: safeIndex, effectiveRange: nil) as? NSParagraphStyle) ?? RichTextTypography.makeParagraphStyle(for: .checklist, preset: currentPreset)
                
                self.undoManager?.beginUndoGrouping()
                super.insertNewline(sender)
                let newParaRange = (textStorage.string as NSString).paragraphRange(for: self.selectedRange())
                textStorage.beginEditing()
                textStorage.addAttribute(.paragraphStyle, value: currentStyle, range: newParaRange)
                textStorage.addAttribute(.noteChecklistState, value: ChecklistState.unchecked.rawValue, range: newParaRange)
                textStorage.removeAttribute(.strikethroughStyle, range: newParaRange)
                textStorage.addAttribute(.foregroundColor, value: NSColor.textColor, range: newParaRange)
                
                var typingAttrs = RichTextTypography.defaultAttributes(for: .checklist, preset: currentPreset)
                typingAttrs[.paragraphStyle] = currentStyle
                self.typingAttributes = typingAttrs
                
                textStorage.endEditing()
                self.undoManager?.endUndoGrouping()
                self.didChangeText()
                return
            }
        }
        
        // 2. Bulleted List continuation
        if paragraphText.hasPrefix("• ") {
            let contentInLine = paragraphText.replacingOccurrences(of: "• ", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            if contentInLine.isEmpty {
                textStorage.replaceCharacters(in: paragraphRange, with: "\n")
                self.setSelectedRange(NSRange(location: paragraphRange.location, length: 0))
                self.didChangeText()
                return
            } else {
                super.insertNewline(sender)
                let font = (self.typingAttributes[.font] as? NSFont) ?? currentPreset.font(for: .bulletedList)
                let pStyle = RichTextTypography.makeParagraphStyle(for: .bulletedList, preset: currentPreset)
                let bulletAttr = NSAttributedString(string: "• ", attributes: [
                    .font: font,
                    .paragraphStyle: pStyle,
                    .foregroundColor: NSColor.textColor
                ])
                let newLocation = self.selectedRange().location
                textStorage.insert(bulletAttr, at: newLocation)
                self.setSelectedRange(NSRange(location: newLocation + 2, length: 0))
                self.didChangeText()
                return
            }
        }
        
        // 3. Blockquote continuation
        if let existingStyle = textStorage.attribute(.paragraphStyle, at: paragraphRange.location, effectiveRange: nil) as? NSParagraphStyle {
            if existingStyle.headIndent == 18 {
                let contentInLine = paragraphText.trimmingCharacters(in: .whitespacesAndNewlines)
                if contentInLine.isEmpty {
                    let bodyStyle = RichTextTypography.makeParagraphStyle(for: .body, preset: currentPreset)
                    textStorage.addAttribute(.paragraphStyle, value: bodyStyle, range: paragraphRange)
                    self.typingAttributes = RichTextTypography.defaultAttributes(for: .body, preset: currentPreset)
                    self.didChangeText()
                    return
                }
            }
        }
        
        super.insertNewline(sender)
    }
    
    // MARK: - Soft Line Break (Shift+Return)
    
    public override func insertLineBreak(_ sender: Any?) {
        // Inserts soft newline inside current paragraph without creating a new checklist item
        self.insertText("\u{2028}", replacementRange: self.selectedRange())
    }
    
    // MARK: - Smart Tab & Shift-Tab Indentation (Multi-Line & Clamped)
    
    public override func insertTab(_ sender: Any?) {
        guard let textStorage = self.textStorage else {
            super.insertTab(sender)
            return
        }
        
        let selectedRange = self.selectedRange()
        let string = textStorage.string as NSString
        guard textStorage.length > 0 else {
            super.insertTab(sender)
            return
        }
        
        let fullSelectionParaRange = string.paragraphRange(for: selectedRange)
        var hasChecklistInSelection = false
        
        // Check if any paragraph in selection is a checklist item
        var checkLoc = fullSelectionParaRange.location
        while checkLoc < fullSelectionParaRange.location + fullSelectionParaRange.length && checkLoc < string.length {
            let singleRange = string.paragraphRange(for: NSRange(location: checkLoc, length: 0))
            let safeIdx = min(singleRange.location, textStorage.length - 1)
            if textStorage.attribute(.noteChecklistState, at: safeIdx, effectiveRange: nil) != nil {
                hasChecklistInSelection = true
                break
            }
            checkLoc = singleRange.location + singleRange.length
        }
        
        if hasChecklistInSelection {
            self.undoManager?.beginUndoGrouping()
            textStorage.beginEditing()
            
            var loc = fullSelectionParaRange.location
            while loc < fullSelectionParaRange.location + fullSelectionParaRange.length && loc < string.length {
                let singleParaRange = string.paragraphRange(for: NSRange(location: loc, length: 0))
                let safeIndex = min(singleParaRange.location, textStorage.length - 1)
                
                if let existingStyle = (textStorage.attribute(.paragraphStyle, at: safeIndex, effectiveRange: nil) as? NSParagraphStyle) ?? (textStorage.attribute(.noteChecklistState, at: safeIndex, effectiveRange: nil) != nil ? RichTextTypography.makeParagraphStyle(for: .checklist, preset: currentPreset) : nil) {
                    let mutableStyle = existingStyle.mutableCopy() as! NSMutableParagraphStyle
                    let isChecklist = textStorage.attribute(.noteChecklistState, at: safeIndex, effectiveRange: nil) != nil
                    
                    if isChecklist {
                        // Max indent clamped to level 5 (128pt)
                        let currentIndent = mutableStyle.headIndent
                        let indentLevel = Int(round((currentIndent - 28.0) / 20.0))
                        let newLevel = min(5, indentLevel + 1)
                        let newIndent = 28.0 + CGFloat(newLevel) * 20.0
                        mutableStyle.headIndent = newIndent
                        mutableStyle.firstLineHeadIndent = newIndent
                    } else {
                        mutableStyle.headIndent += 20.0
                        mutableStyle.firstLineHeadIndent += 20.0
                    }
                    textStorage.addAttribute(.paragraphStyle, value: mutableStyle, range: singleParaRange)
                }
                loc = singleParaRange.location + singleParaRange.length
            }
            
            textStorage.endEditing()
            self.undoManager?.endUndoGrouping()
            self.didChangeText()
            return
        }
        
        super.insertTab(sender)
    }
    
    public override func insertBacktab(_ sender: Any?) {
        guard let textStorage = self.textStorage else {
            super.insertBacktab(sender)
            return
        }
        
        let selectedRange = self.selectedRange()
        let string = textStorage.string as NSString
        guard textStorage.length > 0 else {
            super.insertBacktab(sender)
            return
        }
        
        let fullSelectionParaRange = string.paragraphRange(for: selectedRange)
        var hasChecklistInSelection = false
        
        // Check if any paragraph in selection is a checklist item
        var checkLoc = fullSelectionParaRange.location
        while checkLoc < fullSelectionParaRange.location + fullSelectionParaRange.length && checkLoc < string.length {
            let singleRange = string.paragraphRange(for: NSRange(location: checkLoc, length: 0))
            let safeIdx = min(singleRange.location, textStorage.length - 1)
            if textStorage.attribute(.noteChecklistState, at: safeIdx, effectiveRange: nil) != nil {
                hasChecklistInSelection = true
                break
            }
            checkLoc = singleRange.location + singleRange.length
        }
        
        if hasChecklistInSelection {
            self.undoManager?.beginUndoGrouping()
            textStorage.beginEditing()
            
            var loc = fullSelectionParaRange.location
            while loc < fullSelectionParaRange.location + fullSelectionParaRange.length && loc < string.length {
                let singleParaRange = string.paragraphRange(for: NSRange(location: loc, length: 0))
                let safeIndex = min(singleParaRange.location, textStorage.length - 1)
                
                if let existingStyle = textStorage.attribute(.paragraphStyle, at: safeIndex, effectiveRange: nil) as? NSParagraphStyle {
                    let mutableStyle = existingStyle.mutableCopy() as! NSMutableParagraphStyle
                    let isChecklist = textStorage.attribute(.noteChecklistState, at: safeIndex, effectiveRange: nil) != nil
                    
                    if isChecklist {
                        let currentIndent = mutableStyle.headIndent
                        let indentLevel = Int(round((currentIndent - 28.0) / 20.0))
                        
                        if indentLevel <= 0 {
                            // Outdent at level 0 reverts checklist back to plain body paragraph
                            textStorage.removeAttribute(.noteChecklistState, range: singleParaRange)
                            textStorage.removeAttribute(.strikethroughStyle, range: singleParaRange)
                            textStorage.addAttribute(.foregroundColor, value: NSColor.textColor, range: singleParaRange)
                            let bodyStyle = RichTextTypography.makeParagraphStyle(for: .body, preset: currentPreset)
                            textStorage.addAttribute(.paragraphStyle, value: bodyStyle, range: singleParaRange)
                        } else {
                            let newIndent = 28.0 + CGFloat(indentLevel - 1) * 20.0
                            mutableStyle.headIndent = newIndent
                            mutableStyle.firstLineHeadIndent = newIndent
                            textStorage.addAttribute(.paragraphStyle, value: mutableStyle, range: singleParaRange)
                        }
                    } else {
                        if mutableStyle.headIndent >= 20.0 {
                            mutableStyle.headIndent -= 20.0
                            mutableStyle.firstLineHeadIndent = max(0, mutableStyle.firstLineHeadIndent - 20.0)
                            textStorage.addAttribute(.paragraphStyle, value: mutableStyle, range: singleParaRange)
                        }
                    }
                }
                loc = singleParaRange.location + singleParaRange.length
            }
            
            textStorage.endEditing()
            self.undoManager?.endUndoGrouping()
            self.didChangeText()
            return
        }
        
        super.insertBacktab(sender)
    }
    
    // MARK: - Smart Delete Backward (Backspace removes checklist attribute in 1 keystroke)
    
    public override func deleteBackward(_ sender: Any?) {
        guard let textStorage = self.textStorage else {
            super.deleteBackward(sender)
            return
        }
        
        let selectedRange = self.selectedRange()
        if selectedRange.length > 0 {
            super.deleteBackward(sender)
            return
        }
        
        let string = textStorage.string as NSString
        let paragraphRange = string.paragraphRange(for: selectedRange)
        
        // 1. If at line start of a checklist item: remove checklist attribute in 1 keystroke
        if selectedRange.location == paragraphRange.location && textStorage.length > 0 {
            let safeIndex = min(paragraphRange.location, textStorage.length - 1)
            let isChecklist = textStorage.attribute(.noteChecklistState, at: safeIndex, effectiveRange: nil) != nil
            if isChecklist {
                self.undoManager?.beginUndoGrouping()
                textStorage.beginEditing()
                textStorage.removeAttribute(.noteChecklistState, range: paragraphRange)
                textStorage.removeAttribute(.strikethroughStyle, range: paragraphRange)
                textStorage.addAttribute(.foregroundColor, value: NSColor.textColor, range: paragraphRange)
                let bodyStyle = RichTextTypography.makeParagraphStyle(for: .body, preset: currentPreset)
                textStorage.addAttribute(.paragraphStyle, value: bodyStyle, range: paragraphRange)
                self.typingAttributes = RichTextTypography.defaultAttributes(for: .body, preset: currentPreset)
                textStorage.endEditing()
                self.undoManager?.endUndoGrouping()
                self.didChangeText()
                return
            }
        }
        
        // 2. Bullet list prefix deletion
        let paragraphText = string.substring(with: paragraphRange)
        for prefix in ["• ", "– ", "1. ", "2. "] {
            if paragraphText.hasPrefix(prefix) {
                let prefixLen = (prefix as NSString).length
                if selectedRange.location == paragraphRange.location + prefixLen || paragraphText.trimmingCharacters(in: .whitespacesAndNewlines) == prefix.trimmingCharacters(in: .whitespacesAndNewlines) {
                    textStorage.beginEditing()
                    let replaceRange = NSRange(location: paragraphRange.location, length: prefixLen)
                    textStorage.replaceCharacters(in: replaceRange, with: "")
                    textStorage.endEditing()
                    self.setSelectedRange(NSRange(location: paragraphRange.location, length: 0))
                    self.didChangeText()
                    return
                }
            }
        }
        
        super.deleteBackward(sender)
    }
    
    // MARK: - Mouse Tracking & Vector Gutter Indicator System
    
    private var hoveredCheckboxParaRange: NSRange? = nil
    private var checklistTrackingArea: NSTrackingArea? = nil
    
    public override func updateTrackingAreas() {
        if let existing = checklistTrackingArea {
            removeTrackingArea(existing)
        }
        let options: NSTrackingArea.Options = [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect]
        checklistTrackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        if let trackingArea = checklistTrackingArea {
            addTrackingArea(trackingArea)
        }
        super.updateTrackingAreas()
    }
    
    public override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let layoutManager = self.layoutManager, let textContainer = self.textContainer, let textStorage = self.textStorage else {
            super.mouseMoved(with: event)
            return
        }
        
        let string = textStorage.string as NSString
        let origin = self.textContainerOrigin
        var foundCheckbox = false
        
        if point.x < 28.0 && textStorage.length > 0 {
            // Sample inside text column at (x = 35.0, y = point.y - origin.y) to prevent snapping to next paragraph on wrapped lines
            let samplePoint = NSPoint(x: 35.0, y: point.y - origin.y)
            let charIndex = layoutManager.characterIndex(for: samplePoint, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
            if charIndex < string.length {
                let paraRange = string.paragraphRange(for: NSRange(location: charIndex, length: 0))
                let safeIndex = min(paraRange.location, textStorage.length - 1)
                let isChecklist = textStorage.attribute(.noteChecklistState, at: safeIndex, effectiveRange: nil) != nil
                if isChecklist {
                    foundCheckbox = true
                    if hoveredCheckboxParaRange != paraRange {
                        hoveredCheckboxParaRange = paraRange
                        self.setNeedsDisplay(self.bounds)
                    }
                    NSCursor.pointingHand.set()
                    return
                }
            }
        }
        
        if !foundCheckbox && hoveredCheckboxParaRange != nil {
            hoveredCheckboxParaRange = nil
            self.setNeedsDisplay(self.bounds)
            NSCursor.iBeam.set()
        }
        
        super.mouseMoved(with: event)
    }
    
    public override func mouseExited(with event: NSEvent) {
        if hoveredCheckboxParaRange != nil {
            hoveredCheckboxParaRange = nil
            self.setNeedsDisplay(self.bounds)
            NSCursor.iBeam.set()
        }
        super.mouseExited(with: event)
    }
    
    // MARK: - Native Vector Checklist Drawing (Pure Gutter Layer)
    
    public override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        
        guard let layoutManager = self.layoutManager, let textContainer = self.textContainer, let textStorage = self.textStorage else { return }
        guard textStorage.length > 0 else { return }
        
        let string = textStorage.string as NSString
        let origin = self.textContainerOrigin
        
        // Convert dirty rect from view coordinates to textContainer coordinate space for 100% jitter-free fast scrolling
        let containerRect = NSRect(
            x: rect.origin.x - origin.x,
            y: rect.origin.y - origin.y,
            width: rect.size.width,
            height: rect.size.height
        )
        
        let glyphRange = layoutManager.glyphRange(forBoundingRect: containerRect, in: textContainer)
        var charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        charRange = string.paragraphRange(for: charRange)
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.shouldAntialias = true
        
        var paraLoc = charRange.location
        while paraLoc < charRange.location + charRange.length && paraLoc < string.length {
            let paraRange = string.paragraphRange(for: NSRange(location: paraLoc, length: 0))
            let safeIndex = min(paraRange.location, textStorage.length - 1)
            let checklistState = textStorage.attribute(.noteChecklistState, at: safeIndex, effectiveRange: nil) as? String
            
            if let state = checklistState {
                let firstGlyph = layoutManager.glyphIndexForCharacter(at: paraRange.location)
                var lineRect: NSRect? = nil
                
                if firstGlyph < layoutManager.numberOfGlyphs {
                    lineRect = layoutManager.lineFragmentRect(forGlyphAt: firstGlyph, effectiveRange: nil)
                } else if layoutManager.extraLineFragmentTextContainer != nil {
                    lineRect = layoutManager.extraLineFragmentRect
                }
                
                if let lineRect = lineRect {
                    let circleSize: CGFloat = 18.0
                    let circleX: CGFloat = origin.x + 5.0
                    let circleY: CGFloat = origin.y + lineRect.origin.y + (lineRect.height - circleSize) / 2
                    let circleRect = NSRect(x: circleX, y: circleY, width: circleSize, height: circleSize)
                    
                    let circlePath = NSBezierPath(ovalIn: circleRect)
                    
                    if state == ChecklistState.checked.rawValue {
                        // Solid Plut0 Signature Amber Gold Checkbox Badge
                        let amberGold = NSColor(red: 0.96, green: 0.76, blue: 0.28, alpha: 1.0)
                        amberGold.setFill()
                        circlePath.fill()
                        
                        // Crisp Checkmark ✓ Path inside circle
                        let checkmark = NSBezierPath()
                        checkmark.lineWidth = 2.0
                        checkmark.lineCapStyle = .round
                        checkmark.lineJoinStyle = .round
                        NSColor.black.withAlphaComponent(0.85).setStroke()
                        
                        let cx = circleRect.origin.x
                        let cy = circleRect.origin.y
                        checkmark.move(to: NSPoint(x: cx + 4.2, y: cy + 8.8))
                        checkmark.line(to: NSPoint(x: cx + 7.2, y: cy + 5.0))
                        checkmark.line(to: NSPoint(x: cx + 13.2, y: cy + 12.6))
                        checkmark.stroke()
                    } else {
                        // Unchecked Circular Ring (Appearance & Retina Aware)
                        let isHovered = hoveredCheckboxParaRange?.location == paraRange.location
                        let strokeColor = isHovered
                            ? NSColor(red: 0.96, green: 0.76, blue: 0.28, alpha: 0.95)
                            : NSColor.labelColor.withAlphaComponent(0.38)
                        strokeColor.setStroke()
                        circlePath.lineWidth = isHovered ? 1.8 : 1.5
                        circlePath.stroke()
                        
                        if isHovered {
                            NSColor(red: 0.96, green: 0.76, blue: 0.28, alpha: 0.14).setFill()
                            circlePath.fill()
                        }
                    }
                }
            }
            paraLoc = paraRange.location + paraRange.length
        }
        
        NSGraphicsContext.restoreGraphicsState()
    }
    
    // MARK: - Interactive Gutter Checkbox Click Toggling
    
    public override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let layoutManager = self.layoutManager, let textContainer = self.textContainer, let textStorage = self.textStorage else {
            super.mouseDown(with: event)
            return
        }
        
        let string = textStorage.string as NSString
        let origin = self.textContainerOrigin
        
        // Multi-line safe hit-testing: Clicking anywhere at x < 28pt toggles the item
        if point.x < 28.0 && textStorage.length > 0 {
            // Sample at x = 35.0 inside text container space to guarantee resolution of wrapped multi-line items
            let samplePoint = NSPoint(x: 35.0, y: point.y - origin.y)
            let charIndex = layoutManager.characterIndex(for: samplePoint, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
            if charIndex < string.length {
                let paragraphRange = string.paragraphRange(for: NSRange(location: charIndex, length: 0))
                let safeIndex = min(paragraphRange.location, textStorage.length - 1)
                let checklistState = textStorage.attribute(.noteChecklistState, at: safeIndex, effectiveRange: nil) as? String
                
                if let state = checklistState {
                    // Activate first responder status if text view is not already focused
                    if self.window?.firstResponder != self {
                        self.window?.makeFirstResponder(self)
                    }
                    
                    self.undoManager?.beginUndoGrouping()
                    textStorage.beginEditing()
                    if state == ChecklistState.unchecked.rawValue {
                        // Unchecked -> Checked
                        textStorage.addAttribute(.noteChecklistState, value: ChecklistState.checked.rawValue, range: paragraphRange)
                        textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: paragraphRange)
                        textStorage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: paragraphRange)
                    } else {
                        // Checked -> Unchecked
                        textStorage.addAttribute(.noteChecklistState, value: ChecklistState.unchecked.rawValue, range: paragraphRange)
                        textStorage.removeAttribute(.strikethroughStyle, range: paragraphRange)
                        textStorage.addAttribute(.foregroundColor, value: NSColor.textColor, range: paragraphRange)
                    }
                    textStorage.endEditing()
                    self.undoManager?.endUndoGrouping()
                    
                    self.setNeedsDisplay(self.bounds)
                    self.didChangeText()
                    Haptics.impact(.light)
                    return
                }
            }
        }
        
        super.mouseDown(with: event)
    }
}
