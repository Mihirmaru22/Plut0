import SwiftData

// MARK: - Schema V1

/// The initial versioned schema for Ripple-Clone.
///
/// ## CloudKit Schema Immutability
/// Property names, entity names, and relationship names declared in this schema
/// become permanent record field names in the CloudKit container the moment any
/// device performs its first sync. They **cannot** be renamed, removed, or have
/// their types changed after that point.
///
/// Before syncing to any production CloudKit environment, every property name here
/// must be reviewed and signed off. Changes after production sync require a new
/// `VersionedSchema` — they cannot be made in place.
///
/// ## Adding Future Properties or Entities
/// 1. Create `RippleSchemaV2: VersionedSchema` with the updated model definitions.
/// 2. Add the new models (or modified models) to `RippleSchemaV2.models`.
/// 3. Define a `MigrationStage` in `RippleMigrationPlan` for the V1 → V2 transition.
/// 4. Append `RippleSchemaV2.self` to `RippleMigrationPlan.schemas` **after** `RippleSchemaV1.self`.
/// 5. Test the upgrade path against a seeded in-memory V1 store before shipping.
///
/// Never modify `RippleSchemaV1` after the first production release.
enum RippleSchemaV1: VersionedSchema {

    static let versionIdentifier = Schema.Version(1, 0, 0)

    /// Every `@Model` type that participates in the schema.
    ///
    /// A `@Model` type absent from this array is invisible to the `ModelContainer`
    /// and causes a runtime crash during container initialisation. Update this list
    /// whenever a new `@Model` type is introduced to the project.
    ///
    /// The Personal Life Model entities (`SignalEvent`, `InferredState`, `LifeEvent`,
    /// `WeeklyRegime`, `Chapter`, `Trait`, `Person`, `PersonAppearance`,
    /// `UncertaintyRecord`, `ComposedView`) were added in Phases 3–5 before the
    /// first production CloudKit sync, so appending them here does not violate the
    /// post-release immutability rule documented above.
    ///
    /// `Direction` and `Fork` were added in Phase 7 (the first-person layer)
    /// before the first production CloudKit sync.
    static var models: [any PersistentModel.Type] {
        [
            HabitBoard.self,
            LogEntry.self,
            SignalEvent.self,
            InferredState.self,
            LifeEvent.self,
            WeeklyRegime.self,
            Chapter.self,
            Trait.self,
            Person.self,
            PersonAppearance.self,
            UncertaintyRecord.self,
            ComposedView.self,
            Direction.self,
            Fork.self,
            Calibration.self,
            PatternFeedback.self,
            NarrativeFeedback.self,
            SensorConflict.self,
            SourceProvenance.self,
            UserProfile.self,
            TodoItem.self,
            JournalNote.self,
            SleepEntry.self,
            TrekRecord.self,
            TravelRecord.self,
            FocusSession.self,
            FocusGoal.self,
            WorkProject.self,
            WorkSection.self,
        ]
    }
}

// MARK: - Migration Plan

/// Governs all schema version transitions for Ripple-Clone.
///
/// In v1.0 no migration stages exist — the schema is freshly established with no
/// prior version to migrate from. When v2 is introduced:
///
/// ```swift
/// // Example V1 → V2 lightweight migration
/// static let migrateV1toV2 = MigrationStage.lightweight(
///     fromVersion: RippleSchemaV1.self,
///     toVersion:   RippleSchemaV2.self
/// )
///
/// // Example V1 → V2 custom migration (when data fixup is required)
/// static let migrateV1toV2 = MigrationStage.custom(
///     fromVersion: RippleSchemaV1.self,
///     toVersion:   RippleSchemaV2.self,
///     willMigrate: nil,
///     didMigrate: { context in
///         // Post-migration data fixup — runs on the migrated store
///         // e.g., backfill a new property on existing records
///     }
/// )
/// ```
///
/// ## Testing Requirement (Engineering Principles §8)
/// Every `MigrationStage` must be exercised by upgrading from a seeded store at
/// the previous schema version before submitting to App Review. A migration that
/// traps on real user data after an App Store update is a critical incident.
enum RippleMigrationPlan: SchemaMigrationPlan {

    /// All schema versions in chronological order.
    ///
    /// SwiftData walks this array to construct the upgrade path from the version
    /// stored on disk to the current version. Order is significant: always append
    /// new versions; never insert or reorder existing entries.
    static var schemas: [any VersionedSchema.Type] {
        [
            RippleSchemaV1.self,
        ]
    }

    /// Migration stages between adjacent schema versions.
    ///
    /// Empty for v1 — no prior version exists to migrate from.
    static var stages: [MigrationStage] {
        []
    }
}
