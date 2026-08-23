import SwiftData
import Foundation

// MARK: - TodoBucket

/// The display bucket a task falls into based on its due date.
enum TodoBucket: String, Codable, CaseIterable {
    case today    = "Today"
    case upcoming = "Upcoming"
    case anytime  = "Anytime"
}

// MARK: - TodoItem

/// A single user-authored task.
///
/// ## Design principles
/// - **Soft delete only.** Set `archivedAt` instead of calling `modelContext.delete()`.
/// - **Completion is reversible.** Set `completedAt = nil` to un-complete (T4).
/// - **CloudKit-compatible.** Every stored property has a default value or is Optional.
/// - **Append-only completion pattern.** To un-complete, null out `completedAt` rather
///   than deleting a completion record; simpler than the Android fact-deletion approach
///   and correct for SwiftData's last-write-wins CloudKit sync.
@Model
final class TodoItem {

    // MARK: Identity

    var id:        UUID   = UUID()
    var createdAt: Date   = Date()

    // MARK: Content

    var title:   String  = ""
    var notes:   String? = nil
    
    /// Rich text blocks for Priority 2 Editor, stored as JSON data.
    /// Use the `contentBlocks` computed property for read/write access.
    var contentBlocksData: Data? = nil
    
    var dueDate: Date?   = nil

    var priority: Int = 0

    // MARK: Category & Comments

    /// User-defined category (e.g., "Fitness", "Work"). `nil` implies Inbox.
    var category: String? = nil
    
    /// JSON-encoded array of TaskComment.
    var commentsData: Data? = nil

    // MARK: Day-planner scheduling (optional — nil = not on the timeline)

    /// When set, the task is placed on the day-planner timeline at this exact
    /// date + time. `nil` means the task lives only in the bucket list (T2) or,
    /// when due today, in the planner's Unscheduled tray. CloudKit-safe (Optional).
    var startTime: Date? = nil

    /// Length of the scheduled block in minutes. 0 = a point in time (no range).
    var durationMinutes: Int = 0

    /// SF Symbol name shown in the timeline icon bubble. `nil` falls back to a
    /// default glyph. Lets a planned block read at a glance (alarm, envelope…).
    var iconName: String? = nil

    // MARK: Project & Section Hierarchy
    var projectID: UUID? = nil
    var sectionID: UUID? = nil
    var noteRTFData: Data? = nil

    // MARK: Subtasks (parent link — CloudKit-safe, optional)

    /// `id` of this task's parent, or `nil` for a top-level task.
    /// Children are found by querying `allItems.filter { $0.parentID == parent.id }`.
    var parentID: UUID? = nil

    // MARK: Lifecycle

    /// Non-nil when the task is done. Nullify to un-complete (T4).
    var completedAt: Date? = nil

    /// Non-nil when the task is archived (soft-deleted). Never shown in UI.
    var archivedAt: Date? = nil

    // MARK: - Computed

    var isCompleted: Bool { completedAt != nil }
    var isArchived:  Bool { archivedAt  != nil }

    /// Decoded rich-text blocks. Returns `nil` when no block data is stored.
    var contentBlocks: [TodoContentBlock]? {
        get {
            guard let data = contentBlocksData else { return nil }
            return try? JSONDecoder().decode([TodoContentBlock].self, from: data)
        }
        set {
            if let blocks = newValue {
                contentBlocksData = try? JSONEncoder().encode(blocks)
            } else {
                contentBlocksData = nil
            }
        }
    }

    /// Decoded rich-text blocks with automatic plain-text legacy migration fallback.
    var effectiveContentBlocks: [TodoContentBlock] {
        if let blocks = contentBlocks, !blocks.isEmpty {
            return blocks
        }
        if let text = notes, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return [TodoContentBlock(type: .paragraph, text: text)]
        }
        return []
    }
    /// Decoded comments array. Returns `nil` when no comments exist.
    var comments: [TaskComment]? {
        get {
            guard let data = commentsData else { return nil }
            return try? JSONDecoder().decode([TaskComment].self, from: data)
        }
        set {
            if let newComments = newValue {
                commentsData = try? JSONEncoder().encode(newComments)
            } else {
                commentsData = nil
            }
        }
    }

    /// True when the task is placed on the day-planner timeline.
    var isScheduled: Bool { startTime != nil }

    /// End of the scheduled block, or `nil` when unscheduled. A zero-duration
    /// block returns its start time (a point on the timeline).
    var endTime: Date? {
        guard let start = startTime else { return nil }
        return Calendar.current.date(byAdding: .minute,
                                     value: max(0, durationMinutes),
                                     to: start)
    }

    /// Which display bucket this task belongs to.
    ///
    /// - **Today**: dueDate is today or already past (overdue).
    /// - **Upcoming**: dueDate exists and is in the future.
    /// - **Anytime**: no due date set.
    var bucket: TodoBucket {
        guard let due = dueDate else { return .anytime }
        let today = Calendar.current.startOfDay(for: .now)
        let dueDay = Calendar.current.startOfDay(for: due)
        return dueDay <= today ? .today : .upcoming
    }

    // MARK: - Init

    init(
        id:              UUID    = UUID(),
        title:           String  = "",
        notes:           String? = nil,
        contentBlocksData: Data? = nil,
        dueDate:         Date?   = nil,
        priority:        Int     = 0,
        startTime:       Date?   = nil,
        durationMinutes: Int     = 0,
        iconName:        String? = nil,
        parentID:        UUID?   = nil,
        projectID:       UUID?   = nil,
        sectionID:       UUID?   = nil,
        noteRTFData:     Data?   = nil,
        category:        String? = nil,
        commentsData:    Data?   = nil,
        completedAt:     Date?   = nil,
        archivedAt:      Date?   = nil
    ) {
        self.id              = id
        self.title           = title
        self.notes           = notes
        self.contentBlocksData = contentBlocksData
        self.dueDate         = dueDate
        self.priority        = priority
        self.startTime       = startTime
        self.durationMinutes = durationMinutes
        self.iconName        = iconName
        self.parentID        = parentID
        self.projectID       = projectID
        self.sectionID       = sectionID
        self.noteRTFData     = noteRTFData
        self.category        = category
        self.commentsData    = commentsData
        self.completedAt     = completedAt
        self.archivedAt      = archivedAt
    }

    // MARK: - Cascade Archiving

    func archiveCascade(in context: ModelContext) {
        let now = Date()
        self.archivedAt = now
        let targetParentID = self.id
        if let children = try? context.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.parentID == targetParentID })) {
            for child in children {
                child.archiveCascade(in: context)
            }
        }
    }
}

// MARK: - Priority 2 Block Editor Models

/// The type of a block in the rich task editor.
enum TodoBlockType: String, Codable, CaseIterable {
    case paragraph
    case h1
    case h2
    case h3
    case bullet
    case numbered
    case check
    case quote
    case divider
    case attachment
    case subtask
    case tag
    case link
}

/// A structured block of content for the rich task editor.
struct TodoContentBlock: Codable, Identifiable, Equatable {
    var id: UUID
    var type: TodoBlockType
    var text: String
    
    // For check items
    var isCompleted: Bool
    
    // For references (attachment, subtask, tag, link)
    var refID: UUID?
    
    init(
        id: UUID = UUID(),
        type: TodoBlockType = .paragraph,
        text: String = "",
        isCompleted: Bool = false,
        refID: UUID? = nil
    ) {
        self.id = id
        self.type = type
        self.text = text
        self.isCompleted = isCompleted
        self.refID = refID
    }
}

/// A persistent comment associated with a task.
struct TaskComment: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var text: String
    var createdAt: Date = Date()
}
