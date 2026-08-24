import SwiftUI
import SwiftData
import AVFoundation
import AppKit
import Combine
import MapKit

// MARK: - JournalMediaManager

final class JournalMediaManager {
    static let shared = JournalMediaManager()

    private var mediaDirectory: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("Pluto/JournalMedia", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func saveImage(from sourceURL: URL) -> String? {
        let filename = "img_\(UUID().uuidString).jpg"
        let targetURL = mediaDirectory.appendingPathComponent(filename)

        if let image = NSImage(contentsOf: sourceURL) {
            let resized = downscaleImageIfNeeded(image, maxDimension: 2048)
            if let tiffData = resized.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.80]) {
                do {
                    try jpegData.write(to: targetURL, options: .atomic)
                    return filename
                } catch {
                    return nil
                }
            }
        }

        // Fallback to direct copy if representation fails
        do {
            try FileManager.default.copyItem(at: sourceURL, to: targetURL)
            return filename
        } catch {
            return nil
        }
    }

    private func downscaleImageIfNeeded(_ image: NSImage, maxDimension: CGFloat) -> NSImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }

        let aspectRatio = size.width / size.height
        var newSize: NSSize
        if aspectRatio > 1.0 {
            newSize = NSSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = NSSize(width: maxDimension * aspectRatio, height: maxDimension)
        }

        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy,
                   fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }

    func saveAudioRecording(tempURL: URL) -> String? {
        let filename = "audio_\(UUID().uuidString).m4a"
        let targetURL = mediaDirectory.appendingPathComponent(filename)
        do {
            try FileManager.default.copyItem(at: tempURL, to: targetURL)
            return filename
        } catch {
            return nil
        }
    }

    func fileURL(for filename: String) -> URL {
        mediaDirectory.appendingPathComponent(filename)
    }

    func deleteFile(named filename: String) {
        let targetURL = mediaDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: targetURL)
    }
}

// MARK: - JournalLocationItem

struct JournalLocationItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - AppleJournalLocationSearchEngine

final class AppleJournalLocationSearchEngine: ObservableObject {
    @Published var query: String = ""
    @Published var searchResults: [JournalLocationItem] = []
    @Published var isSearching: Bool = false

    private var cancellables = Set<AnyCancellable>()

    let defaultPlaces: [JournalLocationItem] = [
        JournalLocationItem(title: "Apple Park", subtitle: "1 Apple Park Way, Cupertino, CA", latitude: 37.3349, longitude: -122.0090),
        JournalLocationItem(title: "Central Park", subtitle: "New York, NY, United States", latitude: 40.785091, longitude: -73.968285),
        JournalLocationItem(title: "Golden Gate Bridge", subtitle: "San Francisco, CA, United States", latitude: 37.8199, longitude: -122.4783),
        JournalLocationItem(title: "Tokyo Tower", subtitle: "Minato City, Tokyo, Japan", latitude: 35.6586, longitude: 139.7454),
        JournalLocationItem(title: "Eiffel Tower", subtitle: "Champ de Mars, Paris, France", latitude: 48.8584, longitude: 2.2945),
        JournalLocationItem(title: "Marina Beach", subtitle: "Chennai, Tamil Nadu, India", latitude: 13.0500, longitude: 80.2824),
        JournalLocationItem(title: "Big Ben", subtitle: "Westminster, London, United Kingdom", latitude: 51.5007, longitude: -0.1246)
    ]

    init() {
        searchResults = defaultPlaces
        $query
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] searchText in
                self?.performSearch(query: searchText)
            }
            .store(in: &cancellables)
    }

    func performSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = defaultPlaces
            isSearching = false
            return
        }

        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed

        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, _ in
            DispatchQueue.main.async {
                self?.isSearching = false
                guard let mapItems = response?.mapItems, !mapItems.isEmpty else {
                    return
                }
                self?.searchResults = mapItems.map { item in
                    let title = item.name ?? "Location"
                    let subtitle = [
                        item.placemark.thoroughfare,
                        item.placemark.locality,
                        item.placemark.administrativeArea,
                        item.placemark.country
                    ].compactMap { $0 }.joined(separator: ", ")

                    return JournalLocationItem(
                        title: title,
                        subtitle: subtitle.isEmpty ? (item.placemark.title ?? "") : subtitle,
                        latitude: item.placemark.coordinate.latitude,
                        longitude: item.placemark.coordinate.longitude
                    )
                }
            }
        }
    }
}

// MARK: - AppleJournalRichTextController

final class AppleJournalRichTextController: NSObject, ObservableObject {
    @Published var changeCounter: Int = 0

    // Active Format States for UI Highlighting
    @Published var isBoldActive: Bool = false
    @Published var isItalicActive: Bool = false
    @Published var isUnderlineActive: Bool = false
    @Published var isStrikethroughActive: Bool = false
    @Published var isBulletActive: Bool = false
    @Published var isChecklistActive: Bool = false
    @Published var isNumberedActive: Bool = false
    @Published var isQuoteActive: Bool = false

    weak var textView: NSTextView?
    var onTextChange: ((String, Data?) -> Void)?

    func toggleBold() {
        guard let tv = textView else { return }
        let fm = NSFontManager.shared
        let range = tv.selectedRange()
        if range.length > 0 {
            if let ts = tv.textStorage {
                ts.beginEditing()
                ts.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
                    let cur = (value as? NSFont) ?? NSFont.systemFont(ofSize: 15)
                    let isBold = cur.fontDescriptor.symbolicTraits.contains(.bold)
                    let newFont = fm.convert(cur, toHaveTrait: isBold ? .unboldFontMask : .boldFontMask)
                    ts.addAttribute(.font, value: newFont, range: subrange)
                }
                ts.endEditing()
                notifyChange()
            }
        } else {
            var attrs = tv.typingAttributes
            let cur = (attrs[.font] as? NSFont) ?? NSFont.systemFont(ofSize: 15)
            let isBold = cur.fontDescriptor.symbolicTraits.contains(.bold)
            attrs[.font] = fm.convert(cur, toHaveTrait: isBold ? .unboldFontMask : .boldFontMask)
            tv.typingAttributes = attrs
        }
        updateActiveStates()
        Haptics.impact(.light)
    }

    func toggleItalic() {
        guard let tv = textView else { return }
        let fm = NSFontManager.shared
        let range = tv.selectedRange()
        if range.length > 0 {
            if let ts = tv.textStorage {
                ts.beginEditing()
                ts.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
                    let cur = (value as? NSFont) ?? NSFont.systemFont(ofSize: 15)
                    let isItalic = cur.fontDescriptor.symbolicTraits.contains(.italic)
                    let newFont = fm.convert(cur, toHaveTrait: isItalic ? .unitalicFontMask : .italicFontMask)
                    ts.addAttribute(.font, value: newFont, range: subrange)
                }
                ts.endEditing()
                notifyChange()
            }
        } else {
            var attrs = tv.typingAttributes
            let cur = (attrs[.font] as? NSFont) ?? NSFont.systemFont(ofSize: 15)
            let isItalic = cur.fontDescriptor.symbolicTraits.contains(.italic)
            attrs[.font] = fm.convert(cur, toHaveTrait: isItalic ? .unitalicFontMask : .italicFontMask)
            tv.typingAttributes = attrs
        }
        updateActiveStates()
        Haptics.impact(.light)
    }

    func toggleUnderline() {
        guard let tv = textView else { return }
        let range = tv.selectedRange()
        if range.length > 0 {
            if let ts = tv.textStorage {
                ts.beginEditing()
                let currentVal = ts.attribute(.underlineStyle, at: range.location, effectiveRange: nil) as? Int ?? 0
                let newVal = (currentVal == 0) ? NSUnderlineStyle.single.rawValue : 0
                ts.addAttribute(.underlineStyle, value: newVal, range: range)
                ts.endEditing()
                notifyChange()
            }
        } else {
            var attrs = tv.typingAttributes
            let currentVal = attrs[.underlineStyle] as? Int ?? 0
            attrs[.underlineStyle] = (currentVal == 0) ? NSUnderlineStyle.single.rawValue : 0
            tv.typingAttributes = attrs
        }
        updateActiveStates()
        Haptics.impact(.light)
    }

    func toggleStrikethrough() {
        guard let tv = textView else { return }
        let range = tv.selectedRange()
        if range.length > 0 {
            if let ts = tv.textStorage {
                ts.beginEditing()
                let currentVal = ts.attribute(.strikethroughStyle, at: range.location, effectiveRange: nil) as? Int ?? 0
                let newVal = (currentVal == 0) ? NSUnderlineStyle.single.rawValue : 0
                ts.addAttribute(.strikethroughStyle, value: newVal, range: range)
                ts.endEditing()
                notifyChange()
            }
        } else {
            var attrs = tv.typingAttributes
            let currentVal = attrs[.strikethroughStyle] as? Int ?? 0
            attrs[.strikethroughStyle] = (currentVal == 0) ? NSUnderlineStyle.single.rawValue : 0
            tv.typingAttributes = attrs
        }
        updateActiveStates()
        Haptics.impact(.light)
    }

    func insertBulletList() {
        resetFontToRegular()
        toggleLinePrefix("• ")
    }

    func insertChecklist() {
        resetFontToRegular()
        toggleLinePrefix("○ ")
    }

    func insertNumberedList() {
        resetFontToRegular()
        toggleLinePrefix("1. ")
    }

    func insertBlockquote() {
        resetFontToRegular()
        toggleLinePrefix("“ ")
    }

    func insertDivider() {
        guard let tv = textView else { return }
        tv.insertText("\n────────────────────────\n", replacementRange: tv.selectedRange())
        notifyChange()
        Haptics.impact(.light)
    }

    private func resetFontToRegular() {
        guard let tv = textView else { return }
        var attrs = tv.typingAttributes
        attrs[.font] = NSFont.systemFont(ofSize: 15, weight: .regular)
        attrs[.underlineStyle] = 0
        attrs[.strikethroughStyle] = 0
        tv.typingAttributes = attrs
    }

    private func toggleLinePrefix(_ prefix: String) {
        guard let tv = textView, let string = tv.string as NSString? else { return }
        let range = tv.selectedRange()
        let lineRange = string.lineRange(for: NSRange(location: range.location, length: 0))
        let currentLine = string.substring(with: lineRange)

        let prefixes = ["• ", "○ ", "● ", "1. ", "“ "]
        var cleanedLine = currentLine
        for p in prefixes {
            if cleanedLine.hasPrefix(p) {
                cleanedLine.removeFirst(p.count)
                break
            }
        }

        let newLine: String
        if currentLine.hasPrefix(prefix) {
            newLine = cleanedLine
        } else {
            newLine = prefix + cleanedLine
        }

        tv.setSelectedRange(lineRange)
        tv.insertText(newLine, replacementRange: lineRange)
        notifyChange()
        updateActiveStates()
        Haptics.impact(.light)
    }

    func updateActiveStates() {
        guard let tv = textView else { return }
        let range = tv.selectedRange()
        var font: NSFont? = nil
        var underline: Int = 0
        var strikethrough: Int = 0

        if range.length > 0, let ts = tv.textStorage, ts.length > 0 {
            let safeLoc = max(0, min(range.location, ts.length - 1))
            font = ts.attribute(.font, at: safeLoc, effectiveRange: nil) as? NSFont
            underline = ts.attribute(.underlineStyle, at: safeLoc, effectiveRange: nil) as? Int ?? 0
            strikethrough = ts.attribute(.strikethroughStyle, at: safeLoc, effectiveRange: nil) as? Int ?? 0
        } else {
            let attrs = tv.typingAttributes
            font = attrs[.font] as? NSFont
            underline = attrs[.underlineStyle] as? Int ?? 0
            strikethrough = attrs[.strikethroughStyle] as? Int ?? 0
        }

        let isBold = font?.fontDescriptor.symbolicTraits.contains(.bold) ?? false
        let isItalic = font?.fontDescriptor.symbolicTraits.contains(.italic) ?? false

        var hasBullet = false
        var hasChecklist = false
        var hasNumbered = false
        var hasQuote = false

        if let str = tv.string as NSString?, str.length > 0 {
            let safeLoc = max(0, min(range.location, str.length - 1))
            let lineRange = str.lineRange(for: NSRange(location: safeLoc, length: 0))
            let currentLine = str.substring(with: lineRange)
            hasBullet = currentLine.hasPrefix("• ")
            hasChecklist = currentLine.hasPrefix("○ ") || currentLine.hasPrefix("● ") || currentLine.hasPrefix("☑ ") || currentLine.hasPrefix("☐ ")
            hasNumbered = currentLine.range(of: "^[0-9]+\\. ", options: .regularExpression) != nil
            hasQuote = currentLine.hasPrefix("“ ") || currentLine.hasPrefix("> ")
        }

        DispatchQueue.main.async {
            self.isBoldActive = isBold
            self.isItalicActive = isItalic
            self.isUnderlineActive = (underline != 0)
            self.isStrikethroughActive = (strikethrough != 0)
            self.isBulletActive = hasBullet
            self.isChecklistActive = hasChecklist
            self.isNumberedActive = hasNumbered
            self.isQuoteActive = hasQuote
        }
    }

    func notifyChange() {
        guard let tv = textView else { return }
        let plain = tv.string
        let rtf = try? tv.textStorage?.data(from: NSRange(location: 0, length: tv.textStorage?.length ?? 0), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        onTextChange?(plain, rtf)
        changeCounter += 1
    }
}

// MARK: - AppleJournalRichTextView (NSViewRepresentable with Smart List Return & Circular Checkbox Toggles)

struct AppleJournalRichTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var rtfData: Data?
    let controller: AppleJournalRichTextController

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = true
        textView.isAutomaticDashSubstitutionEnabled = true
        textView.font = NSFont.systemFont(ofSize: 15, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.insertionPointColor = NSColor(red: 0.38, green: 0.45, blue: 0.98, alpha: 1.0)
        textView.textContainerInset = NSSize(width: 0, height: 12)

        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false

        controller.textView = textView
        controller.onTextChange = { plain, rtf in
            DispatchQueue.main.async {
                self.text = plain
                self.rtfData = rtf
            }
        }

        // Load Initial Content
        if let data = rtfData,
           let attrStr = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
            textView.textStorage?.setAttributedString(attrStr)
        } else if !text.isEmpty {
            textView.string = text
        }

        controller.updateActiveStates()
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text && !context.coordinator.isEditingLocally {
            if let data = rtfData,
               let attrStr = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
                textView.textStorage?.setAttributedString(attrStr)
            } else {
                textView.string = text
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AppleJournalRichTextView
        var isEditingLocally = false

        init(_ parent: AppleJournalRichTextView) {
            self.parent = parent
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            parent.controller.updateActiveStates()
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isEditingLocally = true
            parent.controller.notifyChange()
            parent.controller.updateActiveStates()
            isEditingLocally = false
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                let range = textView.selectedRange()
                guard let str = textView.string as NSString? else { return false }
                let lineRange = str.lineRange(for: NSRange(location: range.location, length: 0))
                let currentLine = str.substring(with: lineRange)

                if currentLine.hasPrefix("• ") {
                    if currentLine.trimmingCharacters(in: .whitespacesAndNewlines) == "•" {
                        textView.setSelectedRange(lineRange)
                        textView.insertText("", replacementRange: lineRange)
                    } else {
                        textView.insertText("\n• ", replacementRange: range)
                    }
                    parent.controller.notifyChange()
                    parent.controller.updateActiveStates()
                    return true
                } else if currentLine.hasPrefix("○ ") || currentLine.hasPrefix("● ") {
                    if currentLine.trimmingCharacters(in: .whitespacesAndNewlines) == "○" || currentLine.trimmingCharacters(in: .whitespacesAndNewlines) == "●" {
                        textView.setSelectedRange(lineRange)
                        textView.insertText("", replacementRange: lineRange)
                    } else {
                        textView.insertText("\n○ ", replacementRange: range)
                    }
                    parent.controller.notifyChange()
                    parent.controller.updateActiveStates()
                    return true
                } else if currentLine.hasPrefix("“ ") {
                    if currentLine.trimmingCharacters(in: .whitespacesAndNewlines) == "“" {
                        textView.setSelectedRange(lineRange)
                        textView.insertText("", replacementRange: lineRange)
                    } else {
                        textView.insertText("\n“ ", replacementRange: range)
                    }
                    parent.controller.notifyChange()
                    parent.controller.updateActiveStates()
                    return true
                }
            }
            return false
        }

        func textView(_ textView: NSTextView, clickedOn cell: NSTextAttachmentCellProtocol, in cellFrame: NSRect, at charIndex: Int) {
            handleCheckboxTap(textView, at: charIndex)
        }

        func handleCheckboxTap(_ textView: NSTextView, at charIndex: Int) {
            if let string = textView.string as NSString? {
                let range = NSRange(location: charIndex, length: 1)
                let char = string.substring(with: range)
                if char == "○" || char == "☐" {
                    textView.insertText("●", replacementRange: range)
                    parent.controller.notifyChange()
                    parent.controller.updateActiveStates()
                    Haptics.impact(.rigid)
                } else if char == "●" || char == "☑" {
                    textView.insertText("○", replacementRange: range)
                    parent.controller.notifyChange()
                    parent.controller.updateActiveStates()
                    Haptics.impact(.light)
                }
            }
        }
    }
}

// MARK: - JournalFilterType

enum JournalFilterType: String, CaseIterable, Identifiable {
    case all        = "All"
    case bookmarked = "Bookmarks"
    case photos     = "Photos"
    case audio      = "Audio"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all:        return "square.stack"
        case .bookmarked: return "bookmark.fill"
        case .photos:     return "photo"
        case .audio:      return "waveform"
        }
    }
}

// MARK: - AppleJournalEntriesList (Middle Column)

struct AppleJournalEntriesList: View {

    @Binding var selectedNote: JournalNote?
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\JournalNote.date, order: .reverse)])
    private var allNotes: [JournalNote]

    private var activeNotes: [JournalNote] {
        allNotes.filter { !$0.isArchived }
    }

    @State private var searchText = ""
    @State private var selectedFilter: JournalFilterType = .all

    var body: some View {
        VStack(spacing: 0) {
            // Header, Search & Filter Pills
            VStack(spacing: 8) {
                HStack {
                    Text("\(filteredNotes.count) of \(activeNotes.count) entries")
                        .font(DS.Text.caption)
                        .foregroundStyle(DS.Color.textTertiary)

                    Spacer()

                    Button {
                        createNewEntry()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus")
                            Text("New Entry")
                        }
                        .font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(.plutoGlassProminent(tint: Color(red: 0.38, green: 0.45, blue: 0.98)))
                    .keyboardShortcut("n", modifiers: .command)
                }

                // Search Bar
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Color.textTertiary)
                    TextField("Search entries or places…", text: $searchText)
                        .font(.system(size: 11))
                        .textFieldStyle(.plain)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(DS.Color.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(DS.Color.surfaceRecessed, in: RoundedRectangle(cornerRadius: 6))

                // Quick Filter Pills
                HStack(spacing: 4) {
                    ForEach(JournalFilterType.allCases) { filter in
                        let isSelected = selectedFilter == filter
                        Button {
                            selectedFilter = filter
                            Haptics.selection()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: filter.icon)
                                    .font(.system(size: 9))
                                Text(filter.rawValue)
                                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                            }
                        }
                        .buttonStyle(isSelected ? .plutoGlassProminent(tint: Color(red: 0.38, green: 0.45, blue: 0.98)) : .plutoGlass)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, 10)

            Divider()

            // Entries List
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(filteredNotes) { note in
                        AppleJournalEntryCard(
                            note: note,
                            isSelected: selectedNote?.id == note.id,
                            onSelect: { 
                                selectedNote = note
                                Haptics.selection()
                            },
                            onDelete: {
                                deleteNote(note)
                            },
                            onDuplicate: {
                                duplicateNote(note)
                            }
                        )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .overlay {
                if filteredNotes.isEmpty {
                    ContentUnavailableView {
                        Label("No Entries Found", systemImage: "book.pages")
                    } description: {
                        Text(searchText.isEmpty ? "Click + New Entry to create your first note." : "No entries matched your search.")
                    }
                }
            }
        }
        .background(.ultraThinMaterial)
        .background(DS.Theme.surface)
        .onAppear {
            if selectedNote == nil, let first = activeNotes.first {
                selectedNote = first
            }
        }
    }

    private var filteredNotes: [JournalNote] {
        activeNotes.filter { note in
            let matchesSearch = searchText.isEmpty ||
                note.title.localizedCaseInsensitiveContains(searchText) ||
                note.text.localizedCaseInsensitiveContains(searchText) ||
                (note.location?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (note.locationAddress?.localizedCaseInsensitiveContains(searchText) ?? false)

            let matchesFilter: Bool
            switch selectedFilter {
            case .all: matchesFilter = true
            case .bookmarked: matchesFilter = note.isBookmarked
            case .photos: matchesFilter = note.photoCount > 0
            case .audio: matchesFilter = note.hasAudio
            }

            return matchesSearch && matchesFilter
        }
    }

    private func createNewEntry() {
        let newNote = JournalNote(
            date: Date(),
            title: "",
            text: "",
            kind: .dailyNote
        )
        modelContext.insert(newNote)
        try? modelContext.save()
        selectedNote = newNote
        Haptics.impact(.rigid)
    }

    private func deleteNote(_ note: JournalNote) {
        note.archivedAt = Date()
        try? modelContext.save()
        if selectedNote?.id == note.id {
            selectedNote = activeNotes.first { $0.id != note.id }
        }
        Haptics.impact(.light)
    }

    private func duplicateNote(_ note: JournalNote) {
        let dup = JournalNote(
            date: Date(),
            title: "\(note.title) (Copy)",
            text: note.text,
            kind: note.noteKind
        )
        dup.location = note.location
        dup.locationAddress = note.locationAddress
        dup.latitude = note.latitude
        dup.longitude = note.longitude
        dup.photoFileNames = note.photoFileNames
        dup.photoCount = note.photoCount
        dup.rtfData = note.rtfData
        modelContext.insert(dup)
        try? modelContext.save()
        selectedNote = dup
        Haptics.impact(.rigid)
    }
}

// MARK: - AppleJournalEntryCard (With Context Menu)

struct AppleJournalEntryCard: View {
    let note: JournalNote
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void

    @State private var isHovered = false

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, d MMM 'at' h:mm a"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(Self.dayFormatter.string(from: note.date))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(red: 0.68, green: 0.45, blue: 0.98))

                Spacer()

                if note.hasAudio {
                    Image(systemName: "waveform")
                        .font(.system(size: 9))
                        .foregroundStyle(.pink)
                }

                if note.photoCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "photo")
                            .font(.system(size: 9))
                        Text("\(note.photoCount)")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(Color.accentColor)
                }

                if note.location != nil {
                    Image(systemName: "location.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color(red: 0.38, green: 0.45, blue: 0.98))
                }

                if note.isBookmarked {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow)
                }
            }

            Text(note.title.isEmpty ? (note.text.isEmpty ? "Untitled Entry" : note.text.components(separatedBy: .newlines).first ?? "Untitled Entry") : note.title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DS.Color.textPrimary)
                .lineLimit(1)

            if !note.text.isEmpty {
                Text(note.text)
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Color.textSecondary)
                    .lineLimit(2)
            }

            if let loc = note.location {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 8))
                    Text(loc)
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(DS.Color.textTertiary)
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isSelected
                ? Color(red: 0.38, green: 0.45, blue: 0.98).opacity(0.18)
                : (isHovered ? DS.Color.surfaceRecessed : DS.Color.surfaceRecessed.opacity(0.5)),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color(red: 0.38, green: 0.45, blue: 0.98).opacity(0.6) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
        .contextMenu {
            Button {
                note.isBookmarked.toggle()
                Haptics.impact(.light)
            } label: {
                Label(note.isBookmarked ? "Remove Bookmark" : "Bookmark Entry", systemImage: note.isBookmarked ? "bookmark.slash" : "bookmark")
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("\(note.title)\n\n\(note.text)", forType: .string)
            } label: {
                Label("Copy Note Text", systemImage: "doc.on.doc")
            }

            Button {
                onDuplicate()
            } label: {
                Label("Duplicate Entry", systemImage: "plus.square.on.square")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Entry", systemImage: "trash")
            }
        }
    }
}

// MARK: - AppleJournalEditorCanvas (Full Rich Editor Pane)

struct AppleJournalEditorCanvas: View {
    @Bindable var note: JournalNote

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TodoItem> { $0.completedAt != nil && $0.archivedAt == nil })
    private var completedTasks: [TodoItem]

    @StateObject private var richTextController = AppleJournalRichTextController()

    @State private var showAudioDrawer = false
    @State private var showFormattingPopover = false
    @State private var showLocationPopover = false
    @State private var showDatePopover = false
    @State private var showSavedToast = false
    @State private var previewImageURL: URL? = nil

    // Audio Player State
    @State private var isPlayingAudio = false
    @State private var audioPlayer: AVAudioPlayer? = nil
    @State private var playbackTimer: Timer? = nil

    private static let headerDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, d MMM 'at' h:mm a"
        return f
    }()

    private let applePrompts = [
        "What made you smile today?",
        "What was the most challenging part of today, and how did you handle it?",
        "What are you most grateful for right now?",
        "Describe a moment from today you want to remember."
    ]

    var body: some View {
        HStack(spacing: 0) {
            // Main Journal Canvas
            VStack(spacing: 0) {

                // Top Floating Apple Journal Navigation & Tool Bar (Screenshots 2 & 3)
                HStack(spacing: 12) {

                    // Date & Time Picker Button
                    Button {
                        showDatePopover = true
                    } label: {
                        HStack(spacing: 5) {
                            Text(Self.headerDateFormatter.string(from: note.date))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(DS.Color.textPrimary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(DS.Color.textTertiary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.16, green: 0.15, blue: 0.22), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showDatePopover) {
                        VStack(spacing: 10) {
                            DatePicker("Entry Date & Time", selection: $note.date, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.graphical)
                                .labelsHidden()
                                .onChange(of: note.date) { _, _ in saveNote() }

                            HStack {
                                Button("Set to Now") {
                                    note.date = Date()
                                    saveNote()
                                    showDatePopover = false
                                }
                                .buttonStyle(.plain)
                                .font(.caption)

                                Spacer()

                                Button("Done") { showDatePopover = false }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                            }
                        }
                        .padding(12)
                    }

                    Spacer()

                    // Center Floating Capsule Toolbar (Matching Apple Journal Screenshots)
                    HStack(spacing: 4) {
                        toolbarCapsuleItem(icon: "text.alignleft", label: "Text Mode", isActive: true) {
                            richTextController.textView?.window?.makeFirstResponder(richTextController.textView)
                        }

                        // Photos Picker
                        toolbarCapsuleItem(icon: "photo", label: "Attach Photos", isActive: note.photoCount > 0) {
                            choosePhotoFromDisk()
                        }

                        // Apple Maps Location Picker
                        toolbarCapsuleItem(icon: "location.north.line.fill", label: "Tag Apple Maps Location", isActive: note.location != nil) {
                            showLocationPopover.toggle()
                        }
                        .popover(isPresented: $showLocationPopover) {
                            AppleJournalLocationPopover(
                                currentLocation: note.location,
                                currentAddress: note.locationAddress,
                                currentCoordinate: (note.latitude != nil && note.longitude != nil) ? CLLocationCoordinate2D(latitude: note.latitude!, longitude: note.longitude!) : nil
                            ) { selectedPlace in
                                if let place = selectedPlace {
                                    note.location = place.title
                                    note.locationAddress = place.subtitle
                                    note.latitude = place.latitude
                                    note.longitude = place.longitude
                                } else {
                                    note.location = nil
                                    note.locationAddress = nil
                                    note.latitude = nil
                                    note.longitude = nil
                                }
                                saveNote()
                                showLocationPopover = false
                            }
                        }

                        // Audio Voice Memo Drawer
                        toolbarCapsuleItem(icon: "waveform", label: "Voice Memo Studio", isActive: showAudioDrawer || note.hasAudio) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                showAudioDrawer.toggle()
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.16, green: 0.15, blue: 0.22), in: Capsule())
                    .overlay(Capsule().stroke(DS.Color.border.opacity(0.3), lineWidth: 1))

                    Spacer()

                    // Right Actions (Aa Typography + Bookmark + Done Button)
                    HStack(spacing: 8) {
                        // Typography Aa Popover Button (Screenshot 3)
                        Button {
                            showFormattingPopover.toggle()
                        } label: {
                            HStack(spacing: 2) {
                                Text("Aa").font(.system(size: 13, weight: .bold))
                                Image(systemName: "pencil.and.outline").font(.system(size: 10))
                            }
                            .foregroundStyle(DS.Color.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(red: 0.16, green: 0.15, blue: 0.22), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showFormattingPopover) {
                            AppleJournalTypographyPopover(controller: richTextController)
                        }

                        // Bookmark Flag Toggle
                        Button {
                            note.isBookmarked.toggle()
                            saveNote()
                            Haptics.impact(.light)
                        } label: {
                            Image(systemName: note.isBookmarked ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 13))
                                .foregroundStyle(note.isBookmarked ? Color.yellow : DS.Color.textSecondary)
                                .padding(7)
                                .background(Color(red: 0.16, green: 0.15, blue: 0.22), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help(note.isBookmarked ? "Remove Bookmark" : "Bookmark Entry")

                        // Blue Done Checkmark Save Button
                        Button {
                            saveNote()
                            showSavedToast = true
                            Haptics.impact(.rigid)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showSavedToast = false
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.38, green: 0.45, blue: 0.98))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .help("Save Journal Entry")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(red: 0.10, green: 0.09, blue: 0.14))

                Divider()

                // Editor Content Body
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {

                        // Attached Apple Maps Interactive Card
                        if let loc = note.location {
                            AppleJournalMapCard(
                                title: loc,
                                address: note.locationAddress,
                                latitude: note.latitude ?? 37.3349,
                                longitude: note.longitude ?? -122.0090,
                                onRemove: {
                                    note.location = nil
                                    note.locationAddress = nil
                                    note.latitude = nil
                                    note.longitude = nil
                                    saveNote()
                                }
                            )
                        }

                        // Title Field
                        TextField("Title", text: $note.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(DS.Color.textPrimary)
                            .textFieldStyle(.plain)
                            .onChange(of: note.title) { _, _ in saveNote() }

                        // Apple Reflection Prompt Starters (Shows if entry is fresh/empty)
                        if note.text.isEmpty && note.title.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Reflection Prompts")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundStyle(DS.Color.textTertiary)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(applePrompts, id: \.self) { prompt in
                                            Button {
                                                note.title = prompt
                                                saveNote()
                                                Haptics.impact(.light)
                                            } label: {
                                                Text(prompt)
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundStyle(Color(red: 0.78, green: 0.75, blue: 0.98))
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(Color(red: 0.18, green: 0.17, blue: 0.26), in: Capsule())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        // Today's Work Accomplishments Ribbon
                        let todayCompleted = completedTasks.filter { task in
                            guard let completed = task.completedAt else { return false }
                            return Calendar.current.isDate(completed, inSameDayAs: note.date)
                        }
                        if !todayCompleted.isEmpty {
                            HStack(spacing: 10) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.yellow)

                                Text("You completed \(todayCompleted.count) task\(todayCompleted.count > 1 ? "s" : "") on this day.")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.85))

                                Spacer()

                                Button {
                                    var appendStr = "\n\nAccomplishments:\n"
                                    for t in todayCompleted {
                                        appendStr += "• \(t.title)\n"
                                    }
                                    note.text += appendStr
                                    saveNote()
                                    Haptics.impact(.light)
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Insert into Reflection")
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                }
                                .buttonStyle(.plutoGlassProminent(tint: Color.yellow))
                            }
                            .padding(10)
                            .plutoGlass(.tinted(Color.yellow), in: RoundedRectangle(cornerRadius: 10))
                            .padding(.vertical, 4)
                        }

                        // Native Rich Text Multiline Canvas
                        AppleJournalRichTextView(
                            text: $note.text,
                            rtfData: $note.rtfData,
                            controller: richTextController
                        )
                        .frame(minHeight: 280)
                        .onChange(of: note.text) { _, _ in saveNote() }

                        // Attached Photos Gallery (Prominent Apple Journal Hero Layout)
                        if !note.photoFileNames.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("ATTACHED PHOTOS (\(note.photoFileNames.count))")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(DS.Color.textTertiary)
                                        .tracking(0.5)

                                    Spacer()

                                    Button {
                                        choosePhotoFromDisk()
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus")
                                            Text("Add Photos")
                                        }
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Color(red: 0.38, green: 0.45, blue: 0.98))
                                    }
                                    .buttonStyle(.plain)
                                }

                                if note.photoFileNames.count == 1, let firstFile = note.photoFileNames.first {
                                    // 1 Photo: Full-Width Cinematic Hero Card
                                    JournalPhotoHeroCard(
                                        filename: firstFile,
                                        height: 340,
                                        onTap: { previewImageURL = JournalMediaManager.shared.fileURL(for: firstFile) },
                                        onDelete: {
                                            note.photoFileNames.removeAll { $0 == firstFile }
                                            note.photoCount = note.photoFileNames.count
                                            JournalMediaManager.shared.deleteFile(named: firstFile)
                                            saveNote()
                                        }
                                    )
                                } else if note.photoFileNames.count == 2 {
                                    // 2 Photos: Balanced 2-Column Split
                                    HStack(spacing: 12) {
                                        ForEach(note.photoFileNames, id: \.self) { filename in
                                            JournalPhotoHeroCard(
                                                filename: filename,
                                                height: 260,
                                                onTap: { previewImageURL = JournalMediaManager.shared.fileURL(for: filename) },
                                                onDelete: {
                                                    note.photoFileNames.removeAll { $0 == filename }
                                                    note.photoCount = note.photoFileNames.count
                                                    JournalMediaManager.shared.deleteFile(named: filename)
                                                    saveNote()
                                                }
                                            )
                                        }
                                    }
                                } else {
                                    // 3+ Photos: Rich Adaptive Grid (Min 220px per card)
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                                        ForEach(note.photoFileNames, id: \.self) { filename in
                                            JournalPhotoHeroCard(
                                                filename: filename,
                                                height: 200,
                                                onTap: { previewImageURL = JournalMediaManager.shared.fileURL(for: filename) },
                                                onDelete: {
                                                    note.photoFileNames.removeAll { $0 == filename }
                                                    note.photoCount = note.photoFileNames.count
                                                    JournalMediaManager.shared.deleteFile(named: filename)
                                                    saveNote()
                                                }
                                            )
                                        }
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }

                        // Playable Audio Attachment Card
                        if note.hasAudio {
                            HStack(spacing: 12) {
                                Image(systemName: isPlayingAudio ? "waveform.circle.fill" : "waveform.circle")
                                    .font(.system(size: 32))
                                    .foregroundStyle(Color(red: 0.38, green: 0.45, blue: 0.98))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(note.audioTitle ?? "Voice Memo")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(DS.Color.textPrimary)

                                    Text("\(formatDuration(note.audioDuration)) • High Fidelity Audio")
                                        .font(.system(size: 10))
                                        .foregroundStyle(DS.Color.textSecondary)
                                }

                                Spacer()

                                Button {
                                    togglePlayAudio()
                                } label: {
                                    Image(systemName: isPlayingAudio ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 26))
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    note.hasAudio = false
                                    if let file = note.audioFileName {
                                        JournalMediaManager.shared.deleteFile(named: file)
                                    }
                                    note.audioFileName = nil
                                    saveNote()
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                        .foregroundStyle(DS.Color.textTertiary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(14)
                            .background(Color(red: 0.16, green: 0.15, blue: 0.22), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(24)
                }

                // Bottom Status Bar (Word Count & Read Time)
                HStack {
                    let words = note.text.split { $0.isWhitespace || $0.isNewline }.count
                    let readTime = max(1, Int(ceil(Double(words) / 200.0)))
                    Text("\(words) words • \(readTime) min read")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.Color.textTertiary)

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 6)
                .background(DS.Theme.surface)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
            .background(DS.Theme.canvas)
            .sheet(item: $previewImageURL) { url in
                JournalPhotoPreviewModal(url: url)
            }
            .overlay(alignment: .bottomTrailing) {
                if showSavedToast {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Saved to Journal")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.85), in: Capsule())
                    .padding(20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // Right Audio Recording Studio Drawer (Screenshot 4)
            if showAudioDrawer {
                Divider()

                AppleJournalAudioStudioDrawer(
                    onAttach: { audioFile, duration in
                        note.hasAudio = true
                        note.audioFileName = audioFile
                        note.audioDuration = duration
                        saveNote()
                        withAnimation { showAudioDrawer = false }
                        Haptics.impact(.rigid)
                    },
                    onClose: {
                        withAnimation { showAudioDrawer = false }
                    }
                )
                .frame(width: 230)
                .background(Color(red: 0.12, green: 0.11, blue: 0.17))
            }
        }
        .onDisappear {
            audioPlayer?.stop()
            audioPlayer = nil
            playbackTimer?.invalidate()
            playbackTimer = nil
            isPlayingAudio = false
            saveNote()
        }
    }

    private func toolbarCapsuleItem(icon: String, label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: isActive ? .bold : .medium))
                .foregroundStyle(isActive ? Color.white : DS.Color.textSecondary)
                .frame(width: 28, height: 26)
                .background(isActive ? Color.white.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(label)
    }

    private func choosePhotoFromDisk() {
        let panel = NSOpenPanel()
        panel.title = "Select Photos for Journal Entry"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]

        if panel.runModal() == .OK {
            for url in panel.urls {
                if let savedFilename = JournalMediaManager.shared.saveImage(from: url) {
                    note.photoFileNames.append(savedFilename)
                }
            }
            note.photoCount = note.photoFileNames.count
            saveNote()
            Haptics.impact(.light)
        }
    }

    private func togglePlayAudio() {
        if isPlayingAudio {
            audioPlayer?.stop()
            isPlayingAudio = false
            playbackTimer?.invalidate()
            playbackTimer = nil
        } else {
            guard let filename = note.audioFileName else { return }
            let fileURL = JournalMediaManager.shared.fileURL(for: filename)
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
                audioPlayer?.play()
                isPlayingAudio = true
                playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    if let player = audioPlayer {
                        if !player.isPlaying {
                            isPlayingAudio = false
                            playbackTimer?.invalidate()
                        }
                    }
                }
            } catch {}
        }
    }

    private func formatDuration(_ sec: Double) -> String {
        let m = Int(sec) / 60
        let s = Int(sec) % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func saveNote() {
        try? modelContext.save()
    }
}

// MARK: - AppleJournalMapCard (Interactive Embedded Apple Maps Card)

private struct AppleJournalMapCard: View {
    let title: String
    let address: String?
    let latitude: Double
    let longitude: Double
    let onRemove: () -> Void

    @State private var mapRegion: MKCoordinateRegion

    init(title: String, address: String?, latitude: Double, longitude: Double, onRemove: @escaping () -> Void) {
        self.title = title
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.onRemove = onRemove
        _mapRegion = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Interactive Apple Map Snapshot
            ZStack(alignment: .topTrailing) {
                Map(coordinateRegion: $mapRegion, annotationItems: [JournalLocationItem(title: title, subtitle: address ?? "", latitude: latitude, longitude: longitude)]) { item in
                    MapAnnotation(coordinate: item.coordinate) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.38, green: 0.45, blue: 0.98).opacity(0.35))
                                .frame(width: 32, height: 32)
                            Circle()
                                .fill(Color(red: 0.38, green: 0.45, blue: 0.98))
                                .frame(width: 18, height: 18)
                            Image(systemName: "mappin")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .frame(height: 140)
                .disabled(true) // Static aesthetic card in note body

                // Remove Button
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white, Color.black.opacity(0.6))
                }
                .buttonStyle(.plain)
                .padding(8)
            }

            // Map Footer with Open in Apple Maps Button
            HStack(spacing: 12) {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(red: 0.38, green: 0.45, blue: 0.98))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DS.Color.textPrimary)

                    if let addr = address, !addr.isEmpty {
                        Text(addr)
                            .font(.system(size: 10))
                            .foregroundStyle(DS.Color.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button {
                    openInAppleMaps()
                } label: {
                    HStack(spacing: 4) {
                        Text("Apple Maps")
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(red: 0.38, green: 0.45, blue: 0.98), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Open Location in Apple Maps App")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(red: 0.14, green: 0.13, blue: 0.20))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func openInAppleMaps() {
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = title
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsMapTypeKey: MKMapType.standard.rawValue
        ])
    }
}

// MARK: - URL Identifiable Extension

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// MARK: - JournalPhotoPreviewModal

private struct JournalPhotoPreviewModal: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding([.top, .trailing], 12)

            if let image = NSImage(contentsOfFile: url.path) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 600, maxHeight: 500)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Spacer()
        }
        .frame(width: 640, height: 560)
        .background(Color(red: 0.10, green: 0.09, blue: 0.14))
    }
}

// MARK: - JournalPhotoHeroCard (High-Resolution Prominent Photo Card)

private struct JournalPhotoHeroCard: View {
    let filename: String
    var height: CGFloat = 260
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        let fileURL = JournalMediaManager.shared.fileURL(for: filename)
        ZStack(alignment: .topTrailing) {
            if let image = NSImage(contentsOfFile: fileURL.path) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { onTap() }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                            Text("Loading Photo…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    )
            }

            // Top Action Controls (Expand & Delete Buttons)
            HStack(spacing: 6) {
                Button(action: onTap) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Color.black.opacity(0.65), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Preview High-Res")

                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Color.red.opacity(0.85), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Remove Photo")
            }
            .padding(10)
            .opacity(isHovered ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .onHover { isHovered = $0 }
    }
}

// MARK: - AppleJournalAudioStudioDrawer (Live Recorder)

private struct AppleJournalAudioStudioDrawer: View {
    let onAttach: (String, Double) -> Void
    let onClose: () -> Void

    @State private var isRecording = false
    @State private var isPlaying = false
    @State private var recordTime: Double = 0
    @State private var timer: Timer? = nil
    @State private var audioRecorder: AVAudioRecorder? = nil
    @State private var audioPlayer: AVAudioPlayer? = nil
    @State private var tempAudioURL: URL? = nil
    @State private var showTranscriptModal = false
    @State private var transcriptText = "Today was a productive day. Focused on morning execution, completed the high-intensity workout, and spent quality deep work time."

    var body: some View {
        VStack(spacing: 18) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Audio Recording")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DS.Color.textPrimary)
                    Text(isRecording ? "Recording Live…" : "Voice Studio")
                        .font(.system(size: 10))
                        .foregroundStyle(isRecording ? .red : DS.Color.textTertiary)
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DS.Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer()

            // Waveform Visualizer Scrub Track (Screenshot 4)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.18, green: 0.17, blue: 0.25))
                    .frame(width: 150, height: 260)

                // Simulated Dynamic Waveform Bars
                HStack(alignment: .center, spacing: 3) {
                    ForEach(0..<18, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(isRecording ? Color.pink.opacity(Double.random(in: 0.4...0.9)) : Color.purple.opacity(0.6))
                            .frame(width: 3, height: isRecording ? CGFloat.random(in: 20...200) : 40)
                    }
                }
                .frame(width: 140, height: 250)

                // Vertical Audio Playhead Needle
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2, height: 260)
                    .overlay(
                        Circle().fill(Color.red).frame(width: 8, height: 8),
                        alignment: .top
                    )
            }

            // Digital Timer (00:00.00)
            Text(formatRecordTime(recordTime))
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.Color.textPrimary)

            // Skip & Playback Controls (-15s, Play/Pause, +15s)
            HStack(spacing: 28) {
                Button {
                    if recordTime > 15 { recordTime -= 15 }
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 16))
                        .foregroundStyle(DS.Color.textSecondary)
                }
                .buttonStyle(.plain)

                Button {
                    if isRecording {
                        stopRecording()
                    } else {
                        togglePlayback()
                    }
                } label: {
                    Image(systemName: isRecording ? "pause.fill" : (isPlaying ? "pause.fill" : "play.fill"))
                        .font(.system(size: 20))
                        .foregroundStyle(DS.Color.textPrimary)
                }
                .buttonStyle(.plain)

                Button {
                    recordTime += 15
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 16))
                        .foregroundStyle(DS.Color.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Bottom Bar (Transcript, Record Button, Checkmark Done)
            HStack(spacing: 20) {
                Button {
                    showTranscriptModal = true
                } label: {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 14))
                        .foregroundStyle(DS.Color.textSecondary)
                        .padding(8)
                        .background(Color(red: 0.18, green: 0.17, blue: 0.25), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Transcribe Audio")
                .popover(isPresented: $showTranscriptModal) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Live Transcript Preview")
                            .font(.system(size: 12, weight: .bold))
                        Text(transcriptText)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }
                    .padding(14)
                    .frame(width: 220)
                }

                // Big Red Record / Stop Button
                Button {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.95, green: 0.35, blue: 0.45))
                            .frame(width: 38, height: 38)
                        if isRecording {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white)
                                .frame(width: 14, height: 14)
                        } else {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 16, height: 16)
                        }
                    }
                }
                .buttonStyle(.plain)

                // Save / Attach Audio Checkmark
                Button {
                    if isRecording { stopRecording() }
                    if let url = tempAudioURL, let filename = JournalMediaManager.shared.saveAudioRecording(tempURL: url) {
                        onAttach(filename, recordTime)
                    } else {
                        onAttach("sample_memo.m4a", max(1.0, recordTime))
                    }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DS.Color.textSecondary)
                        .padding(8)
                        .background(Color(red: 0.18, green: 0.17, blue: 0.25), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Attach to Journal Note")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    private func startRecording() {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("temp_rec_\(UUID().uuidString).m4a")
        self.tempAudioURL = fileURL

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.record()
            isRecording = true
            recordTime = 0
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                recordTime += 0.1
            }
            Haptics.impact(.light)
        } catch {
            isRecording = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                recordTime += 0.1
            }
        }
    }

    private func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        timer?.invalidate()
        timer = nil
        Haptics.impact(.light)
    }

    private func togglePlayback() {
        if isPlaying {
            audioPlayer?.stop()
            isPlaying = false
        } else if let url = tempAudioURL {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.play()
                isPlaying = true
            } catch {}
        }
    }

    private func formatRecordTime(_ sec: Double) -> String {
        let mins = Int(sec) / 60
        let s = Int(sec) % 60
        let ms = Int((sec.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", mins, s, ms)
    }
}

// MARK: - AppleJournalLocationPopover (Powered by Apple Maps MKLocalSearch)

struct AppleJournalLocationPopover: View {
    let currentLocation: String?
    let currentAddress: String?
    let currentCoordinate: CLLocationCoordinate2D?
    let onSelect: (JournalLocationItem?) -> Void

    @StateObject private var searchEngine = AppleJournalLocationSearchEngine()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text("Tag Apple Maps Location")
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                if searchEngine.isSearching {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }

            // Search Bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                TextField("Search places, landmarks, cities…", text: $searchEngine.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
            }
            .padding(6)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))

            Divider()

            // Search Results / Suggested Places List
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(searchEngine.searchResults) { place in
                        Button {
                            onSelect(place)
                            Haptics.impact(.light)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(red: 0.38, green: 0.45, blue: 0.98))

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(place.title)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.primary)

                                    if !place.subtitle.isEmpty {
                                        Text(place.subtitle)
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()
                            }
                            .padding(.vertical, 5)
                            .padding(.horizontal, 6)
                            .background(
                                (currentLocation == place.title)
                                    ? Color(red: 0.38, green: 0.45, blue: 0.98).opacity(0.18)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 220)

            if currentLocation != nil {
                Divider()
                Button(role: .destructive) {
                    onSelect(nil)
                } label: {
                    Text("Remove Location Tag")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 260)
    }
}

// MARK: - AppleJournalTypographyPopover (Liquid Glass Formatting Controls)

struct AppleJournalTypographyPopover: View {
    @ObservedObject var controller: AppleJournalRichTextController

    var body: some View {
        VStack(spacing: 8) {
            // Row 1: B, I, U, S (With live active glass pill highlights)
            HStack(spacing: 3) {
                formatBtn("B", isActive: controller.isBoldActive) { controller.toggleBold() }
                formatBtn("I", isActive: controller.isItalicActive) { controller.toggleItalic() }
                formatBtn("U", isActive: controller.isUnderlineActive) { controller.toggleUnderline() }
                formatBtn("S", isActive: controller.isStrikethroughActive) { controller.toggleStrikethrough() }
            }
            .padding(3)
            .plutoGlass(.regular, in: RoundedRectangle(cornerRadius: 8))

            // Row 2: List Formats (Bullets, Checklist, Numbered, Blockquote, Divider)
            HStack(spacing: 3) {
                formatIconBtn("list.bullet", isActive: controller.isBulletActive) { controller.insertBulletList() }
                formatIconBtn("checklist", isActive: controller.isChecklistActive) { controller.insertChecklist() }
                formatIconBtn("list.number", isActive: controller.isNumberedActive) { controller.insertNumberedList() }
                formatIconBtn("quote.opening", isActive: controller.isQuoteActive) { controller.insertBlockquote() }
                formatIconBtn("switch.2", isActive: false) { controller.insertDivider() }
            }
            .padding(3)
            .plutoGlass(.regular, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(10)
        .plutoGlass(.prominent, in: RoundedRectangle(cornerRadius: 12))
    }

    private func formatBtn(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: title == "B" ? .bold : (title == "I" ? .medium : .regular)))
                .italic(title == "I")
                .underline(title == "U")
                .strikethrough(title == "S")
                .foregroundStyle(isActive ? Color.white : DS.Theme.textSecondary)
                .frame(width: 36, height: 26)
                .background(
                    isActive
                        ? DS.Theme.amber
                        : Color.white.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isActive ? Color.white.opacity(0.35) : Color.clear, lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
    }

    private func formatIconBtn(_ icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: isActive ? .bold : .regular))
                .foregroundStyle(isActive ? Color.white : DS.Theme.textSecondary)
                .symbolEffect(.bounce, value: isActive)
                .frame(width: 28, height: 26)
                .background(
                    isActive
                        ? DS.Theme.amber
                        : Color.white.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isActive ? Color.white.opacity(0.35) : Color.clear, lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MacAppleJournalView (Studio Workspace Integrated Journal)

struct MacAppleJournalView: View {
    @State private var selectedRow: JournalRow? = .todaysLog
    @State private var selectedNote: JournalNote? = nil

    var body: some View {
        HStack(spacing: 0) {
            MacJournalContentColumn(selectedRow: $selectedRow, selectedNote: $selectedNote)
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 360)
                .background(Color(nsColor: NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)))

            Divider().opacity(0.3)

            MacJournalDetailColumn(selectedRow: $selectedRow, selectedNote: $selectedNote)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DS.Color.background)
        }
    }
}
