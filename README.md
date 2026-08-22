# 🪐 PLUTO for macOS — Local-First Sovereign Personal Operating System

> **"Does it let me *see* my life, or does it just *show me data* about my life?"**  
> — *The Central Question, PLUTO Engineering Manifesto*

[![Platform: macOS Exclusive](https://img.shields.io/badge/Platform-macOS%2014.0%2B%20(Sonoma%20%2F%20Sequoia)-000000?style=for-the-badge&logo=apple&logoColor=white)](https://apple.com/macos)
[![Swift: 6.0 Strict Concurrency](https://img.shields.io/badge/Swift-6.0%20Strict%20Concurrency-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![Storage: SwiftData + SQLite CRDT](https://img.shields.io/badge/Storage-Local--First%20SwiftData%20%2B%20SQLite%20(CRDT)-4A90E2?style=for-the-badge)](https://developer.apple.com/xcode/swiftdata/)
[![Security: E2EE ChaCha20-Poly1305](https://img.shields.io/badge/Security-ChaCha20--Poly1305%20E2EE-00C853?style=for-the-badge)](https://developer.apple.com/documentation/cryptokit)
[![AI Protocol: Model Context Protocol](https://img.shields.io/badge/AI%20Protocol-Model%20Context%20Protocol%20(MCP)-8A2BE2?style=for-the-badge)](https://modelcontextprotocol.io)

**PLUTO** is a sovereign, local-first personal operating system engineered **exclusively for macOS**. Designed from first principles for Apple Silicon, AppKit, TextKit 2, and macOS Sonoma/Sequoia, Pluto unifies diurnal day execution, GTD task inventory, mathematical CRDT note synthesis, deep focus sessions with procedural spatial audio DSP, and high-altitude life exploration atlases into a single cohesive desktop canvas.

---

## 📑 Table of Contents

1. [The 4 Sovereign macOS Navigation Pillars](#1-the-4-sovereign-macos-navigation-pillars)
2. [TODAY: Diurnal Execution Engine (Plan / List / Time)](#2-today-the-living-day-execution-engine)
3. [NOTES: Sovereign CRDT Knowledge Engine (TextKit 2 + E2EE)](#3-notes-sovereign-crdt-knowledge-engine)
4. [STUDIO: Executive Workspace (Projects / Journal / Analyse)](#4-studio-executive-workspace--synthesis)
5. [LIFE: Horizons, Mountain Trek Atlas & Travel Atlases](#5-life-horizons-mountain-atlas--travel-atlases)
6. [GHOST MODE: The Winter Arc (Three Rings & Season Ridge)](#6-ghost-mode-the-winter-arc-three-rings--season-ridge)
7. [Focus Room & Procedural Spatial Audio DSP Engine](#7-focus-room--spatial-audio-dsp-engine)
8. [On-Device Intelligence: Apple Neural Engine (ANE)](#8-on-device-intelligence-apple-neural-engine)
9. [Model Context Protocol (MCP) Server for Local AI Agents](#9-model-context-protocol-mcp-server)
10. [Private Alpha Telemetry & Creator Web Dossier](#10-private-alpha-telemetry--creator-web-dossier)
11. [Detailed Codebase Architecture](#11-detailed-codebase-architecture)
12. [Building, Running & Packaging Pluto for Mac](#12-building-running--packaging-pluto-for-mac)
13. [Master Keyboard Shortcut Matrix](#13-master-keyboard-shortcut-matrix)
14. [Core Mathematical & Engineering Invariants](#14-core-mathematical--engineering-invariants)

---

## 1. The 5 Sovereign macOS Navigation Pillars

Pluto organizes all human productivity, synthesis, discipline, and long-term exploration across 5 core navigation sections orchestrated in a native AppKit/SwiftUI `NavigationSplitView` with a machined obsidian sidebar (`MacSidebarView`):

```
                      ┌────────────────────────────────────────────────────────────────────────┐
                      │                          🪐 PLUTO FOR macOS                            │
                      └───────────────────────────────────┬────────────────────────────────────┘
                                                          │
         ┌───────────────────┬────────────────────┼────────────────────┬───────────────────┬───────────────────┐
         ▼                   ▼                    ▼                    ▼                   ▼                   ▼
 ┌───────────────┐   ┌───────────────┐    ┌───────────────┐    ┌───────────────┐   ┌───────────────┐   ┌───────────────┐
 │   1. TODAY    │   │   2. NOTES    │    │   3. STUDIO   │    │    4. LIFE    │   │ 5. GHOST MODE │   │  6. SETTINGS  │
 │  Day Planning │   │  CRDT Canvas  │    │ Projects & PM │    │ Mountain/Map  │   │  Winter Arc   │   │ Mission Ctrl  │
 ├───────────────┤   ├───────────────┤    ├───────────────┤    ├───────────────┤   ├───────────────┤   ├───────────────┤
 │ • Plan (Time) │   │ • TextKit 2   │    │ • Briefs (DB) │    │ • Trek Atlas  │   │ • Three Rings │   │ • Vault Lock  │
 │ • List (GTD)  │   │ • ⌘K Switcher │    │ • Journal     │    │ • Travel Atlas│   │ • Season Ridge│   │ • Diagnostics │
 │ • Time (Focus)│   │ • E2EE Sync   │    │ • Analyse     │    │ • Bucket List │   │ • Ghost Streak│   │ • Notifs Sync │
 └───────────────┘   └───────────────┘    └───────────────┘    └───────────────┘   └───────────────┘   └───────────────┘
```

---

## 2. TODAY: The Living Day Execution Engine

The `Today` workspace (`⌘1`) governs immediate diurnal execution through three specialized sub-modes:

### ⏱ Plan Mode (Proportional Day Planner Timeline)
* **Visual Time Blocking**: Chronological vertical timeline mapping scheduled tasks, meetings, and routines with proportional block heights and duration bubbles.
* **Smart Adaptive Start**: Dynamically anchors the viewport to the current hour or earliest scheduled item with intelligent morning/evening lookaheads.
* **Unscheduled Backlog Tray**: Slide-out tray holding unscheduled tasks due today for drag-to-time-block assignment.
* **Natural Language Scheduler**: Fast-entry input field that infers start times and durations directly from human input (e.g., `"Deep work 2pm for 90m"`).

### 📋 List Mode (High-Velocity GTD Task Inventory)
* **Flat Continuous Inventory**: Fast, friction-free task management with 0–3 priority dot scales and custom category badges.
* **Subtasks & Progress Rings**: Nested child tasks (`TodoItem.parentID`) with real-time radial completion meters.
* **Document Detail Panel**: Calm document side-panel replacing bulky form controls with grouped cards, date/time chips, and recurrence selectors.
* **MacBlockEditor**: Embedded slash-command block editor supporting Paragraphs, Headings (`H1`/`H2`/`H3`), Bullet lists, Numbered lists, Checklists with strikethrough, Quotes, and Dividers.

### 🎧 Time Mode (Fullscreen Focus Room & Spatial Audio)
* **Fullscreen Immersion**: Distraction-free StudyStream study environment (`FocusRoomView`) with persistent inspirational quotes and active session goals drawer.
* **Pomodoro Focus Engine**: Interactive round-based focus sprint timer with configurable intervals, phase switches, and countdowns.
* **Multi-Stem Spatial Audio Engine**: Procedural binaural soundscapes (5-Pole Rain & Thunder Matrix, Forest Birds, Deep Space White Noise, Polyphonic Chords) with logarithmic volume mixers.
* **Curated Wallpaper Canvas**: Zero-latency local disk/RAM cached focus backgrounds with StudyStream aesthetics and session duration tracking.

---

## 3. NOTES: Sovereign CRDT Knowledge Engine

The `Notes` workspace (`⌘2`) provides a sovereign, mathematical knowledge synthesis surface built directly on Apple's **AppKit TextKit 2** pipeline:

```
 ┌───────────────────────────┐     ┌───────────────────────────┐     ┌───────────────────────────┐
 │   TextKitCRDTBridge       │     │     CRDTDoc / Vector      │     │  ChaCha20-Poly1305 Vault  │
 │ (In-Place NSTextStorage)  │ ◄─► │  (Character Lamport Time) │ ◄─► │    (ShadowSync Engine)    │
 └───────────────────────────┘     └───────────────────────────┘     └───────────────────────────┘
```

* **Native AppKit TextKit 2 Surface**: Character-level CRDT math (`TextKitCRDTBridge`, `CRDTDoc`, `CRDTBlock`) with zero typing latency and guaranteed deterministic convergence.
* **Minimalist Markdown Magic ("Magic" Typing)**:
  - Instant block transformation upon typing space: `# ` $\to$ H1, `## ` $\to$ H2, `### ` $\to$ H3, `- ` or `* ` $\to$ Bullet List, `1. ` $\to$ Numbered List, `[] ` $\to$ Checklist.
  - **Instant Backspace Revert**: Pressing `Backspace` at the beginning of an auto-formatted block reverts it to plain text in-place without altering document history.
* **Margin-Drawn Circular Checklists**: Checkboxes are drawn directly in the left margin gutter (`circle` unchecked, `checkmark.circle.fill` checked with accent tint) without polluting storage characters or vector clocks.
* **Tab / Shift-Tab List Indentation**: Fluid indentation nesting for bullets and checklists with coordinated margin gutter drawing.
* **`⌘K` Quick Switcher (`QuickSwitcherView`)**: Frosted glass spotlight command palette providing instant sub-millisecond search across note titles and content.
* **Rich Multi-Representation Pasteboard**: Copying rich text outputs UTF-8 plain text, HTML (`public.html`), and formatted RTF (`public.rtf`) for seamless clipboard interop across Apple Notes, Mail, Pages, Slack, Notion, and Discord.
* **macOS Spotlight & Deep Linking**: Direct CoreSpotlight indexing (`NotesSpotlightIndexer`) supporting system-wide search and `pluto://note/{uuid}` deep-link navigation.
* **E2EE Vault & Sync Protocol**: ChaCha20-Poly1305 client-side encrypted sync coordinator (`ShadowSyncCoordinator`) communicating over encrypted WebSockets.

---

## 4. STUDIO: Executive Workspace & Synthesis

The `Studio` workspace (`⌘3`) unites project delivery, daily reflections, and cognitive analytics under **One Unified Presentation Engine (`PlutoDocumentEditor`)** across **Three Mathematically Isolated Memories**:

```
                               ┌─────────────────────────────┐
                               │   DocumentCoreRepository    │
                               └──────────────┬──────────────┘
                                              │
                ┌─────────────────────────────┼─────────────────────────────┐
                │                             │                             │
 ┌──────────────▼─────────────┐┌──────────────▼─────────────┐┌──────────────▼─────────────┐
 │       NotesRepository      ││   ProjectBriefRepository   ││  JournalDocumentRepository  │
 │   (E2EE Synced Storage)    ││ (Local project_briefs DB)  ││   (JournalDocumentEngine)   │
 └──────────────┬─────────────┘└──────────────┬─────────────┘└──────────────┬─────────────┘
                │                             │                             │
                │                             │                             │
 ┌──────────────▼─────────────────────────────▼─────────────────────────────▼─────────────┐
 │                                   PlutoDocumentEditor                                   │
 │   • AppKit TextKit 2 Pipeline              • Aa Typography Formatting Popover           │
 │   • Minimalist Markdown Magic (# -> H1)    • Spacebar Backspace Instant Revert          │
 │   • Margin-Drawn Circular Checklists       • Live Word Count & Read Time Footer         │
 │   • Multi-Representation Pasteboard        • Spotlight & Deep Linking Integration       │
 └─────────────────────────────────────────────────────────────────────────────────────────┘
```

### 💼 Projects (Command Center)
* **Isolated `project_briefs` SQLite Storage**: Backed by sovereign schema migration v3 (`LocalProjectBriefStore` & `ProjectBriefEngine.shared`). Completely decoupled from general notes and global search.
* **Structured Execution Pipeline**: Milestone checklists, subtask assignments, and project deliverables linked directly to the project brief.

### 📖 Journal (Apple Journal Canvas)
* **Sensory Formatting Chrome**: Compact `Aa` typography popover (`PlutoTypographyPopover`), date & time graphical picker popover, and live word count & reading time footer (`"X words • Y min read"`).
* **Media & Attachment Suite**: Photos gallery picker, Apple Maps location tagging (`MKLocalSearch`), and Voice Memo audio studio with live waveform visualization & playback.
* **Daylight Flow & Sleep Tracker**: Morning/evening keystone rituals, wake/bedtime tracking, and overnight sleep debt estimation.

### 📊 Analyse (Cognitive Dashboard)
* **Consistency & Habit Correlation**: 30-day consistency indices, monthly heatmaps, and sentiment correlation matrices via Apple Neural Engine (`LocaNeuralEngine`).

---

## 5. LIFE: Horizons, Mountain Atlas & Travel Atlases

The `Life` workspace (`⌘4`) provides high-altitude perspective across long-term goals and physical explorations:

### 🗺 Mountain Atlas (Trek & Expedition Canvas)
* **GPX Trail Engine**: Native parser and interactive elevation profile chart for mountaineering routes.
* **Interactive Mapbox / MapKit Canvas**: Trail rendering with Indian mountain range and state boundary GeoJSON data.
* **Expedition Passports**: High-res PDF document generation for completed expeditions, summit photo galleries, and mountaineer rank progression (`Bronze` ➔ `Silver` ➔ `Gold` ➔ `Summit Master`).
* **Apple Watch Sync**: HealthKit and workout sync bridge for altitude, heart rate, and distance stats.

### 🌏 Travel Atlas & Sovereign Bucket List
* **State & District Boundary Visualizer**: Interactive travel atlas tracking visited regions across India and worldwide.
* **Multi-Horizon Bucket List**: Multi-year life goals categorized by horizon, benchmark metrics, and trophy cabinet achievements (`🏆 Achieved` / `⏳ In Progress`).

---

## 6. GHOST MODE: The Winter Arc (Three Rings & Season Ridge)

The `Ghost Mode` workspace (`⌘5`) provides a sovereign, privacy-first discipline environment for the 120-day Winter Arc:

* **Sovereign Covenant Onboarding (`ContractOnboardingView`)**: Sign an on-device digital signature committing to The 120, 75 Hard, or Custom Arc with Hard Doctrine (zero compromise) or Arc Doctrine (resilient momentum).
* **Three Ghost Rings**:
  - **Body Ring**: Physical forge (daily workout, 10k steps, cold exposure).
  - **Mind Ring**: Mental synthesis (10 pages reading, evening reflection note).
  - **Silence Ring**: 45+ minutes deep focus silence or complete offline dark mode.
* **Ghost Streak & Rank Progression**:
  - Consecutive Ghost Days unlock ranks from `Apparition 👻` $\to$ `Shadow 👤` $\to$ `Phantom 🌫️` $\to$ `Wraith ⚔️` $\to$ `Specter 👁️` $\to$ `Ghost Sovereign 👑`.
  - Dynamic opacity silhouette glyph reflecting real-time streak materialization.
* **Season Ridge Mountain Elevation Visualizer (`GhostRidgeProfileChart`)**: SwiftCharts alpine terrain curve tracking 120 days of execution with missed-day valleys and a Dec 31 summit marker flag.
* **Cognitive Burnout Advisory**: Automatic recovery advisory triggered when the Apple Neural Engine (`LocaNeuralEngine`) detects a 14-day negative sentiment trend.
* **"Went Dark" Offline Logger**: Fast HUD toggle to log intentional offline off-grid disconnect intervals.
* **Vector PDF Sovereign Passport (`WinterArcPassportPDFGenerator`)**: High-resolution vector certificate export for completed seasons.
* **Strict Privacy Isolation**: Ghost data is 100% local, vault-lockable with `LocaVaultAuthManager`, and excluded from Spotlight and telemetry streams.

---

## 7. Focus Room & Spatial Audio DSP Engine

PLUTO contains an embedded digital signal processing (DSP) spatial audio engine (`SpatialAudioEngine.swift`):

* **Procedural Multi-Stem Mixer**: Synthesizes 4 distinct continuous ambient layers:
  1. **5-Pole Rain & Thunder Matrix**: Procedurally modulated white/pink noise filtered through low-pass resonant filters.
  2. **Forest Birds**: Randomized, spatialized stereo acoustic cues.
  3. **Deep Space White Noise**: Sub-bass filtered drone for alpha-wave entrainment.
  4. **Polyphonic Ambient Chords**: Ethereal synthesizer pad loop.
* **Logarithmic Volume Envelopes**: Individual stem gain adjustments with smooth fading to prevent audio clipping during focus sprints.
* **StudyStream Wallpaper Engine**: Zero-latency local disk & RAM cached background visuals with ambient quote overlays.

---

## 7. On-Device Intelligence: Apple Neural Engine

Pluto includes an embedded on-device natural language analysis pipeline (`LocaNeuralEngine.swift`):

```
 ┌───────────────────────────┐     ┌───────────────────────────┐     ┌───────────────────────────┐
 │   Journal Reflections &   │     │    Apple Neural Engine    │     │   Executive Tone Brief &  │
 │     Daily Check-ins       │ ──► │  NaturalLanguage (NLTagger│ ──► │   Circadian Sentiment     │
 │                           │     │    + Sentiment Analysis)  │     │      Trajectory Map       │
 └───────────────────────────┘     └───────────────────────────┘     └───────────────────────────┘
```

* **Zero Cloud Dependence**: 100% of sentiment analysis, keyword scoring, and executive synthesis executes on the Apple Silicon Neural Engine (NPU).
* **Circadian Mood Correlation**: Cross-references sleep logs with afternoon task velocity and journal valence to generate actionable lifestyle feedback.

---

## 8. Model Context Protocol (MCP) Server

PLUTO ships with a built-in **Model Context Protocol (MCP)** server (`mcp-server/`), allowing local macOS AI agents (**Claude Desktop, Cursor, Antigravity IDE, Windsurf**) to read and write to your local Pluto operating system:

```bash
# Build the MCP server
cd mcp-server
npm install
npm run build
```

### Connect to Claude Desktop for Mac
Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "pluto": {
      "command": "node",
      "args": [
        "/absolute/path/to/Plut0-main/mcp-server/build/index.js"
      ]
    }
  }
}
```

### Supported MCP Tool Capabilities (16 Tools)
- **`get_daily_briefing`**: Summarizes today's scheduled blocks, open tasks, habits, and focus metrics.
- **`manage_habits`**: Check-in, fetch streak heatmaps, and retrieve consistency stats.
- **`manage_tasks`**: Create, time-block, reschedule, and complete tasks on the day planner.
- **`query_journal`**: Search journal notes, sleep logs, and reflections.
- **`brainstorm_notes`**: Create and search rich-text notes and folders in the sovereign CRDT note store.

---

## 9. Private Alpha Telemetry & Creator Web Dossier

For private alpha testing, Pluto includes an invisible background telemetry pipeline that streams tester interactions to a real-time Creator Web Dossier:

* **Live Web Dashboard**: [https://mihirmaru22.github.io/Plut0/](https://mihirmaru22.github.io/Plut0/)
* **Direct PostgREST Supabase Ingestion**: Outbound HTTPS sync to `/rest/v1/alpha_testers`, `/rest/v1/alpha_events`, `/rest/v1/alpha_state_snapshots`, and `/rest/v1/alpha_crashes`.
* **Zero-Observer Footprint**: Asynchronous execution via `Task.detached` with zero UI lag and no tester popups.
* **Bounded Local Disk Queue**: 5,000-event / 25 MB FIFO disk limit with offline exponential backoff.

---

## 10. Detailed Codebase Architecture

```
Plut0-main/
├── ios/
│   ├── Loca_Mac/                          # Native macOS 14+ Target (Pluto for Mac)
│   │   ├── Window/                        # MacRootView, MacSidebarView, NavigationSplitView
│   │   ├── Today/ & Todo/                 # Day Planner, GTD List, MacBlockEditor, Projects
│   │   ├── Studio/                        # Studio Workspace Shell (Projects, Journal, Analyse)
│   │   ├── NotesFeature/                  # Sovereign Next-Gen Notes Engine
│   │   │   ├── Domain/                    # Note, NoteContent, NoteBlock, DocumentCoreRepository, NoteMutation
│   │   │   ├── Application/               # NotesEngine, ProjectBriefEngine, JournalDocumentEngine
│   │   │   ├── Data/
│   │   │   │   ├── Database/              # NotesDatabase, NotesMigrations (v1-v3), Mappers
│   │   │   │   ├── Local/                 # LocalNotesStore, LocalProjectBriefStore, LocalProjectBriefRepository
│   │   │   │   ├── Memory/                # InMemoryNotesRepository, InMemoryProjectBriefRepository
│   │   │   │   └── Events/                # NotesEventBus, NotesEvent, LockIsolated
│   │   │   ├── Sync/                      # E2EEVault, ShadowSyncCoordinator, WebSocketClient
│   │   │   ├── UI/
│   │   │   │   ├── Editor/                # PlutoDocumentEditor, PlutoTypographyPopover, EditorBridgeState
│   │   │   │   ├── Editor/TextKit2/       # NoteCanvasTextView, TextKit2EditorRepresentable
│   │   │   │   ├── Editor/Toolbar/        # NoteContextualToolbar, TypographyFormattingPopover
│   │   │   │   ├── Layout/                # NotesCanvasView, NotesListView, QuickSwitcherView (⌘K)
│   │   │   │   └── Coordination/          # TextKitCRDTBridge, CRDTDoc, CRDTBlock, CRDTTranslator
│   │   │   ├── Platform/                  # NotesSpotlightIndexer, LocaPasteboardHelper
│   │   │   └── Tests/                     # TextKitBridgeTests, ProjectBriefTests, QuickSwitcherTests
│   │   ├── Journal/                       # Apple Journal, Sleep Track, Daylight Routines
│   │   ├── Time/ & FocusRoom/             # Pomodoro Timer, Spatial Audio DSP, Wallpapers
│   │   ├── Life/                          # Mountain Atlas, GPX Engine, Travel Atlas, Passport PDF
│   │   ├── Habits/                        # Heatmaps, Progress Bars, Quantitative Habit Loggers
│   │   ├── Audit/                         # Milestone Horizons & Strategic Life Audits
│   │   ├── Platform/                      # Spotlight, Hotkeys, Telemetry, Diagnostics, Notifications
│   │   ├── Settings/                      # Mission Control, Chrono-Tunnel, Museum Gallery
│   │   └── Menus/                         # LOCACommands (macOS Menu Bar & Keybindings)
│   ├── LOCA/                              # Shared Core Models & SwiftData Schemas
│   │   ├── Core/Models/                   # HabitBoard, TodoItem, JournalNote, SleepEntry, BrainStorm
│   │   └── Core/DesignSystem/             # Spacing, Typography, Color, and Motion Tokens
│   └── LOCA.xcodeproj                    # Xcode Project Configuration
├── mcp-server/                            # Model Context Protocol (MCP) Server for AI Integration
├── supabase/                              # Schema SQL and Alpha Ingest Edge Functions
├── dashboard/ & docs/                     # Creator Analytics Web Dossier (GitHub Pages)
└── create_dmg.sh                          # Production macOS DMG Packaging Script
```

---

## 11. Building, Running & Packaging Pluto for Mac

### System Requirements
* **macOS 14.0+** (Sonoma / Sequoia)
* **Xcode 16.0+** (with Swift 6 compiler toolchain)
* **Apple Silicon (M1–M4) or Intel Mac**

### Build in Xcode
1. Clone or open the project folder in Xcode:
   ```bash
   open ios/LOCA.xcodeproj
   ```
2. Select the **`Loca_Mac`** target and destination **`My Mac`**.
3. Press **`⌘ + R`** to compile and launch **Pluto**.

### Build a Standalone macOS `.dmg` Installer
Run the bundled release script to package a signed distribution DMG:
```bash
./create_dmg.sh
```

---

## 12. Master Keyboard Shortcut Matrix

| Shortcut | Action | Scope |
| :--- | :--- | :--- |
| **`⌘ + 1`** | Navigate to **Today** (Plan / List / Time) | Global macOS |
| **`⌘ + 2`** | Navigate to **Notes** (Sovereign CRDT Canvas) | Global macOS |
| **`⌘ + 3`** | Navigate to **Studio** (Projects / Journal / Analyse) | Global macOS |
| **`⌘ + 4`** | Navigate to **Life** (Mountain Atlas / Travel / Bucket List) | Global macOS |
| **`⌘ + 5`** | Navigate to **Ghost Mode** (Winter Arc & Three Rings) | Global macOS |
| **`⌘ + ,`** | Navigate to **Settings & Mission Control** | Global macOS |
| **`⌘ + K`** | Open **Quick Switcher** / Spotlight Note Search | Notes & Studio |
| **`⌘ + ⌥ + S`**| Toggle Notes Navigator / Sidebar Column | Notes & Studio |
| **`⌘ + N`** | Create New Task / Note / Habit / Entry | Workspace-Aware |
| **`⌘ + F`** | Search across active workspace / In-Note Find | Workspace-Aware |
| **`Tab`** / **`⇧Tab`** | Indent / Outdent Checklist and Bullet items | Editor |
| **`⌥ + Space`**| Open System-Wide **Pluto Quick Action HUD** | System-Wide macOS |
| **`Space`** | Quick Look preview for selected document or attachment | Global macOS |

---

## 13. Core Mathematical & Engineering Invariants

* **Mathematical CRDT Ground Truth**: Character-level vector clocks and tombstone handling guarantee deterministic conflict resolution across concurrent edits.
* **Memory Isolation**: Notes (E2EE synced), Project Briefs (sovereign SQLite `project_briefs`), and Journal entries run on independent memory layers without cross-search leakage.
* **Calm Surface Protocol**: Zero persistent UI machinery at rest; headers and formatters quietly emerge only on user focus or hover.
* **Strict Concurrency**: Fully compliant with Swift 6 strict concurrency (`@MainActor`, `Sendable`, nonisolated DSP contexts, and `LockIsolated` event buses).
* **Soft Delete Architecture**: Entity deletion sets `archivedAt = Date()` or `deletedAt = Date()`, ensuring zero data loss and historical referential integrity.
* **Append-Only Completions**: Task completions mutate timestamp records (`completedAt = Date()` / `completedAt = nil`) without destructive row deletes.

---

## 📄 License

Copyright © 2024–2026 Mihir Maru. All rights reserved.
