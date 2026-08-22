# 🪐 PLUTO for macOS — Local-First Sovereign Personal Operating System

> **"Does it let me *see* my life, or does it just *show me data* about my life?"**  
> — *The Central Question, PLUTO Engineering Manifesto*

[![Platform: macOS Exclusive](https://img.shields.io/badge/Platform-macOS%2014.0%2B%20(Sonoma%20%2F%20Sequoia)-000000?style=for-the-badge&logo=apple&logoColor=white)](https://apple.com/macos)
[![Swift: 6.0 Strict Concurrency](https://img.shields.io/badge/Swift-6.0%20Strict%20Concurrency-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![Storage: SwiftData + SQLite CRDT](https://img.shields.io/badge/Storage-Local--First%20SwiftData%20%2B%20SQLite%20(CRDT)-4A90E2?style=for-the-badge)](https://developer.apple.com/xcode/swiftdata/)
[![Security: E2EE ChaCha20-Poly1305](https://img.shields.io/badge/Security-ChaCha20--Poly1305%20E2EE-00C853?style=for-the-badge)](https://developer.apple.com/documentation/cryptokit)
[![AI Protocol: Model Context Protocol](https://img.shields.io/badge/AI%20Protocol-Model%20Context%20Protocol%20(MCP)-8A2BE2?style=for-the-badge)](https://modelcontextprotocol.io)

**PLUTO** is a sovereign, local-first personal operating system engineered **exclusively for macOS**. Designed from the ground up for Apple Silicon, AppKit, TextKit 2, and macOS Sonoma/Sequoia, Pluto unifies daily time execution, high-velocity GTD task inventory, keystone habit tracking, mathematical CRDT note synthesis, deep focus sessions with procedural spatial audio DSP, and high-altitude life exploration atlases into a single cohesive, Apple-native desktop canvas.

---

## 📑 Table of Contents

1. [Architectural Overview: The 3 Primary macOS Domains](#1-architectural-overview-the-3-primary-macos-domains)
2. [Dual-Tier Workspaces: Hero Mode vs. Architect Mode](#2-dual-tier-workspace-architecture)
3. [TODAY: Diurnal Execution Engine (Plan / List / Time)](#3-today-the-living-day-execution-engine)
4. [STUDIO: Sovereign Knowledge & Synthesis (One Engine, Three Memories)](#4-studio-sovereign-knowledge--synthesis)
5. [LIFE: Horizons, Mountain Trek Atlas & Travel Atlases](#5-life-horizons--adventure-atlases)
6. [Focus Studio & Procedural Spatial Audio DSP Engine](#6-focus-room--spatial-audio-dsp-engine)
7. [On-Device Intelligence: Apple Neural Engine & Sentiment Analytics](#7-on-device-intelligence-apple-neural-engine)
8. [Model Context Protocol (MCP) Server for Local AI Agents](#8-model-context-protocol-mcp-server)
9. [Private Alpha Telemetry & Creator Web Dossier](#9-private-alpha-telemetry--creator-web-dossier)
10. [Detailed macOS Codebase Architecture](#10-detailed-macos-codebase-architecture)
11. [Building, Running & Packaging Pluto for Mac](#11-building-running--packaging-pluto-for-mac)
12. [Master Keyboard Shortcut & Gesture Matrix](#12-master-keyboard-shortcut--gesture-matrix)
13. [Core Mathematical & Engineering Invariants](#13-core-mathematical--engineering-invariants)

---

## 1. Architectural Overview: The 3 Primary macOS Domains

Pluto organizes all human intentionality into three distinct structural domains, fluidly orchestrated through a native AppKit/SwiftUI `NavigationSplitView` with Liquid Glass interactive controls:

```
                      ┌────────────────────────────────────────────────────────┐
                      │                 🪐 PLUTO FOR macOS                     │
                      └──────────────┬─────────────────┬───────────────────────┘
                                     │                 │
                ┌────────────────────┘                 └────────────────────┐
                ▼                                                           ▼
    ┌─────────────────────────┐                                 ┌─────────────────────────┐
    │       1. TODAY          │                                 │       2. STUDIO         │
    │  Living Day Execution   │                                 │ Knowledge & Synthesis   │
    ├─────────────────────────┤                                 ├─────────────────────────┤
    │ • Plan: Day Timeline    │                                 │ • Notes: CRDT Engine    │
    │ • List: GTD Tasks       │                                 │ • Journal: Reflections  │
    │ • Time: Focus Studio    │                                 │ • Projects: PM Briefs   │
    └─────────────────────────┘                                 └─────────────────────────┘
                                             │
                                             ▼
                                ┌─────────────────────────┐
                                │        3. LIFE          │
                                │   Horizons & Atlases    │
                                ├─────────────────────────┤
                                │ • Mountain Trek Atlas   │
                                │ • GeoJSON Travel Atlas  │
                                │ • Bucket List / Badges  │
                                └─────────────────────────┘
```

---

## 2. Dual-Tier Workspace Architecture

Pluto accommodates different cognitive modes throughout the day by providing two distinct desktop workspace environments:

```
                  ┌──────────────────────────────────────────────────┐
                  │              PRESS  ⌘ + ⇧ + P                     │
                  │   Toggle Hero Cockpit <-> Architect Matrix       │
                  └──────────────┬───────────────────┬───────────────┘
                                 │                   │
                 ┌───────────────┘                   └───────────────┐
                 ▼                                                   ▼
   ┌───────────────────────────┐                       ┌───────────────────────────┐
   │       ⚔️ HERO MODE        │                       │     👑 ARCHITECT MODE     │
   │  2-Column Daily Cockpit   │                       │  3-Column Sovereign Desk  │
   ├───────────────────────────┤                       ├───────────────────────────┤
   │ • Tri-Diurnal Timeline    │                       │ • Proportional Day Plan   │
   │ • Rule of 3 Top Missions  │                       │ • Sovereign CRDT Canvas   │
   │ • Circadian Battery Dial  │                       │ • PM Project Workspaces   │
   │ • Habit Streaks & Streaks │                       │ • Interactive Map Atlases │
   │ • Ambient Audio Soundscape│                       │ • Strategic Life Audits   │
   └───────────────────────────┘                       └───────────────────────────┘
```

| Workspace | Mode Name | Layout | Capabilities & Cognitive Objective |
|---|---|---|---|
| **⚔️ Tier 1** | **Hero Mode** | **2-Column Focus Engine** | **Left Column**: Tri-Diurnal Horizontal Timeline (Morning 🌅, Afternoon ☀️, Evening 🌙) + Rule of 3 Active Mission Objectives.<br>**Right Column**: Circadian Energy Battery dial (calculating wake time, sleep debt, and schedule density), Keystone Habit consistency list with live flame streaks, Weekly Momentum index, Ambient Focus Soundscape player, and Quick Check-in drawer. |
| **👑 Tier 2** | **Architect Mode** | **3-Column Sovereign OS** | Full 3-column `NavigationSplitView` with proportional Day Planner timeline, CRDT Notes canvas, Projects management, Mountain Trek Atlas, GeoJSON Travel Atlas, Life Audit matrix, and local Model Context Protocol (MCP) AI agent integration. |

---

## 3. TODAY: The Living Day Execution Engine

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

### 🎧 Time Mode (Focus Room & Spatial Audio Studio)
* **Pomodoro Focus Engine**: Interactive round-based focus sprint timer with configurable intervals, phase switches, and countdowns.
* **Multi-Stem Spatial Audio Engine**: Procedural binaural soundscapes (5-Pole Rain & Thunder Matrix, Forest Birds, Deep Space White Noise, Polyphonic Chords) with logarithmic volume mixers.
* **Curated Wallpaper Canvas**: Zero-latency local disk/RAM cached focus backgrounds with StudyStream aesthetics, inspiring quotes, and session duration tracking.

---

## 4. STUDIO: Sovereign Knowledge & Synthesis

The `Studio` workspace (`⌘2`) unifies document drafting, daily reflection, and project execution under **One Unified Presentation Engine (`PlutoDocumentEditor`)** backed by **Three Mathematically Isolated Memories**:

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

### 📝 Notes: Sovereign CRDT Engine
* **Native AppKit TextKit 2 Surface**: Character-level CRDT math (`TextKitCRDTBridge`, `CRDTDoc`, `CRDTBlock`) with zero typing latency and guaranteed convergence.
* **Minimalist Markdown Magic ("Magic" Typing)**:
  - Instant block transformation upon typing space: `# ` $\to$ H1, `## ` $\to$ H2, `### ` $\to$ H3, `- ` or `* ` $\to$ Bullet List, `1. ` $\to$ Numbered List, `[] ` $\to$ Checklist.
  - **Instant Backspace Revert**: Pressing `Backspace` at the beginning of an auto-formatted block reverts it to plain text in-place.
* **Margin-Drawn Circular Checklists**: Checkboxes are drawn directly in the left margin gutter (`circle` unchecked, `checkmark.circle.fill` checked with accent tint) without polluting storage characters or vector clocks.
* **Tab / Shift-Tab List Indentation**: Fluid indentation nesting for bullets and checklists with coordinated margin gutter drawing.
* **`⌘K` Quick Switcher (`QuickSwitcherView`)**: Frosted glass spotlight command palette providing instant sub-millisecond search across note titles and content.
* **Rich Multi-Representation Pasteboard**: Copying rich text outputs UTF-8 plain text, HTML (`public.html`), and formatted RTF (`public.rtf`) for seamless clipboard interop across Apple Notes, Mail, Pages, Slack, Notion, and Discord.
* **macOS Spotlight & Deep Linking**: Direct CoreSpotlight indexing (`NotesSpotlightIndexer`) supporting system-wide search and `pluto://note/{uuid}` deep-link navigation.
* **E2EE Vault & Sync Protocol**: ChaCha20-Poly1305 client-side encrypted sync coordinator (`ShadowSyncCoordinator`) communicating over encrypted WebSockets.

### 💼 Projects: Studio Project Briefs
* **Isolated `project_briefs` SQLite Storage**: Backed by sovereign schema migration v3 (`LocalProjectBriefStore` & `ProjectBriefEngine.shared`). Completely decoupled from general notes and global search.
* **Structured Execution Pipeline**: Milestone checklists, subtask assignments, and project deliverables linked directly to the project brief.

### 📖 Journal: Apple Journal Surface & Life Reflections
* **Sensory Formatting Chrome**: Compact `Aa` typography popover (`PlutoTypographyPopover`), date & time graphical picker popover, and live word count & reading time footer (`"X words • Y min read"`).
* **Media & Attachment Suite**: Photos gallery picker, Apple Maps location tagging (`MKLocalSearch`), and Voice Memo audio studio with live waveform visualization & playback.
* **Daylight Flow & Sleep Tracker**: Morning/evening keystone rituals, wake/bedtime tracking, and overnight sleep debt estimation.
* **Analyse Dashboard**: 30-day consistency indices, monthly heatmaps, and sentiment correlation matrices via Apple Neural Engine (`LocaNeuralEngine`).

---

## 5. LIFE: Horizons & Adventure Atlases

The `Life` workspace (`⌘3`) provides high-altitude perspective across long-term goals and physical explorations:

### 🗺 Mountain Atlas (Trek & Expedition Canvas)
* **GPX Trail Engine**: Native parser and interactive elevation profile chart for mountaineering routes.
* **Interactive Mapbox / MapKit Canvas**: Trail rendering with Indian mountain range and state boundary GeoJSON data.
* **Expedition Passports**: High-res PDF document generation for completed expeditions, summit photo galleries, and mountaineer rank progression (`Bronze` ➔ `Silver` ➔ `Gold` ➔ `Summit Master`).
* **Apple Watch Sync**: HealthKit and workout sync bridge for altitude, heart rate, and distance stats.

### 🌏 Travel Atlas & Sovereign Bucket List
* **State & District Boundary Visualizer**: Interactive travel atlas tracking visited regions across India and worldwide.
* **Multi-Horizon Bucket List**: Multi-year life goals categorized by horizon, benchmark metrics, and trophy cabinet achievements (`🏆 Achieved` / `⏳ In Progress`).

---

## 6. Focus Room & Spatial Audio DSP Engine

PLUTO contains an embedded, non-blocking digital signal processing (DSP) spatial audio engine (`SpatialAudioEngine.swift`):

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

## 10. Detailed macOS Codebase Architecture

```
Plut0-main/
├── ios/
│   ├── Loca_Mac/                          # Native macOS 14+ Target (Pluto for Mac)
│   │   ├── Window/                        # MacRootView, MacSidebarView, NavigationSplitView
│   │   ├── Today/ & Todo/                 # Day Planner, GTD List, MacBlockEditor, Projects
│   │   ├── Studio/                        # Studio Workspace Shell
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

## 12. Master Keyboard Shortcut & Gesture Matrix

| Shortcut | Action | Scope |
| :--- | :--- | :--- |
| **`⌘ + 1`** | Navigate to **Today** (Plan / List / Time) | Global macOS |
| **`⌘ + 2`** | Navigate to **Studio** (Notes / Journal / Projects) | Global macOS |
| **`⌘ + 3`** | Navigate to **Life** (Mountain Atlas / Travel / Bucket List) | Global macOS |
| **`⌘ + 4`** | Navigate to **Settings & Mission Control** | Global macOS |
| **`⌘ + K`** | Open **Quick Switcher** / Spotlight Note Search | Notes & Studio |
| **`⌘ + ⇧ + P`**| Toggle **Hero Mode** $\leftrightarrow$ **Architect Mode** | Global macOS |
| **`⌘ + ⌥ + S`**| Toggle Notes & Sidebar Navigator Column | Notes & Studio |
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
