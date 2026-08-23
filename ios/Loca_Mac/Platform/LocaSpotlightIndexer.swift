import Foundation
import CoreSpotlight
import UniformTypeIdentifiers
import SwiftData

// MARK: - LocaSpotlightIndexer (macOS Core Spotlight ⌘Space Search Engine)

/// Automatically indexes Habits, Tasks, Goals, Life Principles, Bucket List Dreams,
/// and Journal Reflections into native macOS Spotlight (`CSSearchableIndex`).
/// Enables direct search from anywhere in macOS (`⌘Space`) with instant deep linking.
final class LocaSpotlightIndexer {

    static let shared = LocaSpotlightIndexer()

    private let domainIdentifier = "com.mihirmaru.loca.spotlight"

    private init() {}

    // MARK: - Domain Prefixes for Deep Linking

    enum ItemType: String {
        case habit     = "habit"
        case task      = "task"
        case principle = "principle"
        case bucket    = "bucket"
        case goal      = "goal"
        case journal   = "journal"

        func makeIdentifier(id: String) -> String {
            "\(rawValue):\(id)"
        }

        static func parseIdentifier(_ identifier: String) -> (type: ItemType, id: String)? {
            let parts = identifier.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2, let type = ItemType(rawValue: parts[0]) else { return nil }
            return (type, parts[1])
        }
    }

    // MARK: - Batch Re-index All Core Items

    func indexAll(context: ModelContext) {
        Task {
            var itemsToIndex: [CSSearchableItem] = []

            // 1. Index Habits
            if let habits = try? context.fetch(FetchDescriptor<HabitBoard>()) {
                for habit in habits where habit.archivedAt == nil {
                    itemsToIndex.append(makeHabitItem(habit))
                }
            }

            // 2. Index Tasks
            if let tasks = try? context.fetch(FetchDescriptor<TodoItem>()) {
                for task in tasks where task.archivedAt == nil && !task.title.isEmpty {
                    itemsToIndex.append(makeTaskItem(task))
                }
            }

            // 3. Index Journal Notes & Purge Private Notes
            if let notes = try? context.fetch(FetchDescriptor<JournalNote>()) {
                var identifiersToPurge: [String] = []
                for note in notes {
                    if note.isPrivate || note.isArchived || note.text.isEmpty {
                        identifiersToPurge.append(ItemType.journal.makeIdentifier(id: note.id.uuidString))
                    } else {
                        itemsToIndex.append(makeJournalItem(note))
                    }
                }
                if !identifiersToPurge.isEmpty {
                    try? await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifiersToPurge)
                }
            }

            // 4. Index Static Life & Goal Principles
            itemsToIndex.append(contentsOf: makeDefaultLifeAndGoalItems())

            // Push to macOS Spotlight Search Index
            do {
                try await CSSearchableIndex.default().indexSearchableItems(itemsToIndex)
            } catch {
                print("CoreSpotlight indexing error: \(error)")
            }
        }
    }

    // MARK: - Granular Incremental Indexing

    func indexHabit(_ habit: HabitBoard) {
        guard habit.archivedAt == nil else {
            removeHabit(id: habit.id.uuidString)
            return
        }
        let item = makeHabitItem(habit)
        Task {
            try? await CSSearchableIndex.default().indexSearchableItems([item])
        }
    }

    func removeHabit(id: String) {
        let identifier = ItemType.habit.makeIdentifier(id: id)
        Task {
            try? await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [identifier])
        }
    }

    func indexTaskItem(_ task: TodoItem) {
        guard task.archivedAt == nil, !task.title.isEmpty else {
            removeTask(id: task.id.uuidString)
            return
        }
        let item = makeTaskItem(task)
        Task {
            try? await CSSearchableIndex.default().indexSearchableItems([item])
        }
    }

    func removeTask(id: String) {
        let identifier = ItemType.task.makeIdentifier(id: id)
        Task {
            try? await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [identifier])
        }
    }

    func indexJournalNoteItem(_ note: JournalNote) {
        guard !note.isPrivate, !note.isArchived, !note.text.isEmpty else {
            removeJournalNote(id: note.id.uuidString)
            return
        }
        let item = makeJournalItem(note)
        Task {
            try? await CSSearchableIndex.default().indexSearchableItems([item])
        }
    }

    func removeJournalNote(id: String) {
        let identifier = ItemType.journal.makeIdentifier(id: id)
        Task {
            try? await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [identifier])
        }
    }

    // MARK: - Item Builders

    private func makeHabitItem(_ habit: HabitBoard) -> CSSearchableItem {
        let attr = CSSearchableItemAttributeSet(contentType: .content)
        attr.title = habit.name
        attr.contentDescription = "Habit · Streak: \(habit.currentStreak) days · Target: \(Int(habit.effectiveTarget)) \(habit.unitLabel ?? "")"
        attr.keywords = ["habit", "streak", habit.name, habit.unitLabel ?? "", "pluto"]
        attr.containerTitle = "PLUTO Habits"

        return CSSearchableItem(
            uniqueIdentifier: ItemType.habit.makeIdentifier(id: habit.id.uuidString),
            domainIdentifier: domainIdentifier,
            attributeSet: attr
        )
    }

    private func makeTaskItem(_ task: TodoItem) -> CSSearchableItem {
        let attr = CSSearchableItemAttributeSet(contentType: .content)
        attr.title = task.title
        let prio = task.priority > 0 ? ["Low", "Medium", "High"][min(task.priority - 1, 2)] : "Normal"
        let dueStr = task.dueDate?.formatted(.dateTime.month().day()) ?? "Anytime"
        attr.contentDescription = "Task · Due: \(dueStr) · Priority: \(prio)"
        attr.keywords = ["task", "todo", task.title, task.category ?? "", "pluto"]
        attr.containerTitle = "PLUTO Tasks"

        return CSSearchableItem(
            uniqueIdentifier: ItemType.task.makeIdentifier(id: task.id.uuidString),
            domainIdentifier: domainIdentifier,
            attributeSet: attr
        )
    }

    private func makeJournalItem(_ note: JournalNote) -> CSSearchableItem {
        let attr = CSSearchableItemAttributeSet(contentType: .content)
        attr.title = "Journal: \(note.date.formatted(.dateTime.weekday().month().day()))"
        attr.contentDescription = String(note.text.prefix(160))
        attr.keywords = ["journal", "note", "reflection", "pluto", "\(note.noteKind)"]
        attr.containerTitle = "PLUTO Journal"

        return CSSearchableItem(
            uniqueIdentifier: ItemType.journal.makeIdentifier(id: note.id.uuidString),
            domainIdentifier: domainIdentifier,
            attributeSet: attr
        )
    }

    private func makeDefaultLifeAndGoalItems() -> [CSSearchableItem] {
        var items: [CSSearchableItem] = []

        // Life Principles
        let principles = [
            ("First Principles Thinking", "Boil things down to their fundamental truths and reason up from there."),
            ("Radical Ownership", "Never blame external conditions. Total accountability over health, craft, and mindset."),
            ("The Compounding Rule", "Small, consistent 1% daily actions compound exponentially over 5–10 years."),
            ("Physical Sovereignty", "Energy and physical resilience are the bedrock of cognitive clarity."),
            ("Essentialism & Deep Focus", "Say no to the 99% of non-essential noise to pour relentless focus into the vital few."),
            ("Inner Stillness", "Protect mental peace above all. Respond with deliberate poise.")
        ]

        for (title, maxim) in principles {
            let attr = CSSearchableItemAttributeSet(contentType: .content)
            attr.title = title
            attr.contentDescription = "Life Principle · \(maxim)"
            attr.keywords = ["principle", "maxim", "life", "north star", title, "pluto"]
            attr.containerTitle = "PLUTO Life Suite"

            items.append(CSSearchableItem(
                uniqueIdentifier: ItemType.principle.makeIdentifier(id: title),
                domainIdentifier: domainIdentifier,
                attributeSet: attr
            ))
        }

        // Strategic Goals
        let goals = [
            ("Complete Half-Marathon Sub-1h45m", "Athletic endurance and cardiovascular peak state."),
            ("Ship PLUTO App Version 3.5", "Local-first SwiftData productivity powerhouse with Apple Silicon Neural Engine."),
            ("Deep Work Mastery: 1,000 Focus Hours", "Annual craft and output velocity milestone.")
        ]

        for (title, desc) in goals {
            let attr = CSSearchableItemAttributeSet(contentType: .content)
            attr.title = title
            attr.contentDescription = "Strategic Goal · \(desc)"
            attr.keywords = ["goal", "milestone", "audit", title, "pluto"]
            attr.containerTitle = "PLUTO Strategic Goals"

            items.append(CSSearchableItem(
                uniqueIdentifier: ItemType.goal.makeIdentifier(id: title),
                domainIdentifier: domainIdentifier,
                attributeSet: attr
            ))
        }

        return items
    }

    // MARK: - Remove Items

    func removeIndex(for identifier: String) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [identifier]) { _ in }
    }
}
