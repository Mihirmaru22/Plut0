import SwiftData
import Foundation

// MARK: - JournalNote

/// A Journal entry captured in the Journal → Collect surface.
///
/// Three kinds share this model (`.dailyNote`, `.moment`, `.win`), stored as
/// `noteKindRaw: Int` for CloudKit compatibility. Kind determines which section
/// of the Collect view captures it and which row of the content column aggregates it.
///
/// One daily note per calendar day is the intended pattern; moments and wins are
/// multi-capture (many per day). Nothing enforces uniqueness — CloudKit forbids
/// unique constraints.
@Model
final class JournalNote {

    var id:          UUID   = UUID()
    var date:        Date   = Date()
    var title:       String = ""
    var text:        String = ""
    var location:        String? = nil
    var locationAddress: String? = nil
    var latitude:        Double? = nil
    var longitude:       Double? = nil
    var isBookmarked:    Bool    = false
    var hasAudio:    Bool   = false
    var audioDuration: Double = 0
    var photoCount:     Int      = 0
    var photoFileNames: [String] = []
    var audioFileName:  String?  = nil
    var audioTitle:     String?  = "Voice Memo"
    var rtfData:        Data?    = nil
    var archivedAt:     Date?    = nil

    /// Stores `NoteKind` as an `Int` for CloudKit compatibility.
    /// Raw values are permanent — do not renumber.
    var noteKindRaw: Int = NoteKind.dailyNote.rawValue

    /// When true, this reflection or note is marked private and excluded from Spotlight or external indexing.
    var isPrivate: Bool = false

    var isArchived: Bool { archivedAt != nil }

    /// Type-safe accessor. Falls back to `.dailyNote` for records written by
    /// older builds (field absent → default 0 → `.dailyNote`).
    var noteKind: NoteKind {
        get { NoteKind(rawValue: noteKindRaw) ?? .dailyNote }
        set { noteKindRaw = newValue.rawValue }
    }

    init(date: Date = Date(), title: String = "", text: String = "", kind: NoteKind = .dailyNote, isPrivate: Bool = false) {
        self.date        = Calendar.current.startOfDay(for: date)
        self.title       = title
        self.text        = text
        self.noteKindRaw = kind.rawValue
        self.isPrivate   = isPrivate
    }
}

// MARK: - NoteKind

extension JournalNote {

    enum NoteKind: Int, CaseIterable {
        case dailyNote = 0
        case moment    = 1
        case win       = 2
    }
}
