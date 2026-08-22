# Notes Feature Engine — Phase 1 Abstraction Layer

Local-first, offline-first Notes Engine for macOS engineered with Swift Concurrency, SQLite persistence, and UI isolation.

---

## 1. Architectural Overview

```text
┌────────────────────────────────────────────────────────┐
│                        UI Layer                        │
│            (SwiftUI / AppKit / NotesDebugView)         │
└──────────────────────────┬─────────────────────────────┘
                           │ Interacts ONLY with
                           ▼
┌────────────────────────────────────────────────────────┐
│             NotesEngine & Domain Use Cases             │
│   (NotesEngine, CreateNoteUseCase, UpdateNoteUseCase)   │
└──────────────────────────┬─────────────────────────────┘
                           │ Depends on protocol
                           ▼
┌────────────────────────────────────────────────────────┐
│                NotesRepository Protocol                │
└──────────────┬───────────────────────────┬─────────────┘
               │                           │
   Production  │               Test/Preview│
               ▼                           ▼
┌──────────────────────────────┐ ┌──────────────────────────────┐
│     LocalNotesRepository     │ │   InMemoryNotesRepository    │
│  (LocalNotesStore Actor +    │ │(Thread-safe Dict Storage +   │
│   NotesDatabase SQLite WAL)  │ │      NotesEventBus)          │
└──────────────────────────────┘ └──────────────────────────────┘
```

---

## 2. Core Invariants

1. **Zero UI Leakage**: The UI layer and ViewModels never import SQLite/GRDB or interact with database rows directly. All communication is routed through `NotesEngine` / `NotesRepository` using strongly typed Domain entities (`Note`, `NoteSummary`, `Folder`, `Tag`).
2. **Structured Block Model**: Notes store structured block content (`NoteContent` + `[NoteBlock]`), enabling rich formatting, checklist state, headings, and future CRDT/block synchronization.
3. **Mutation-Based Writes**: All data mutations (`NoteMutation`) are executed atomically and broadcasted through `NotesEventBus` to notify active `AsyncStream` observers.
4. **Live Observation**: Real-time reactive updates via Swift Concurrency `AsyncStream<[NoteSummary]>` and `AsyncStream<Note?>`.
5. **Future-Sync Ready**: Tables and domain entities contain sync metadata (`deviceID`, `clientUpdatedAt`, `schemaVersion`).

---

## 3. How to Instantiate and Inject

### Default SQLite Engine (Production)
```swift
let engine = try NotesEngine.localDefault()
```

### In-Memory Engine (SwiftUI Previews & Unit Tests)
```swift
let memoryEngine = NotesEngine.inMemory()
```

### Custom Dependency Injection
```swift
let database = try NotesDatabase(fileURL: customURL)
let store = LocalNotesStore(database: database)
let eventBus = NotesEventBus()
let repository = LocalNotesRepository(store: store, eventBus: eventBus)
let engine = NotesEngine(repository: repository)
```

---

## 4. Running the Tests

All tests are implemented using Swift Testing (`import Testing`).

1. **Domain Tests** (`DomainTests.swift`):
   - Validates plain text extraction, preview string generation with ellipsis truncation, and block JSON serialization.
2. **SQLite Repository Tests** (`RepositoryTests.swift`):
   - Integration tests executing real SQLite file-based CRUD, pinning, folder moves, tag mappings, soft delete/restore, and live search.
3. **In-Memory Repository Tests** (`InMemoryRepositoryTests.swift`):
   - Verifies 100% behavioral equivalence for transient workflows.

Run tests via Xcode test navigator or command line:
```bash
xcodebuild test -scheme LOCA -destination 'platform=macOS'
```
