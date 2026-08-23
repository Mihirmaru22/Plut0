//
//  PlutoTelemetryEngine.swift
//  PLUTO
//
//  Complete Local-First Behavioral Ingestion & Analytics Engine for Private Alpha.
//  Collects unredacted product actions, habit creations, focus metrics, and periodic
//  full database state snapshots with zero-observer effect (100% silent & invisible to testers).
//

import Foundation
import SwiftData
import SwiftUI
import AppKit
import CryptoKit
import os.log

// MARK: - Privacy Hasher

public enum PlutoPrivacy {
    public static func hash(_ value: String) -> String {
        let data = Data(value.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - PlutoTelemetryEngine

@MainActor
final class PlutoTelemetryEngine: @unchecked Sendable {

    static let shared = PlutoTelemetryEngine()

    private let logger = Logger(subsystem: "com.mihirmaru.pluto.telemetry", category: "engine")

    // MARK: - Tester & Device Identity

    let testerID: String
    let testerName: String
    let deviceName: String
    let deviceModel: String
    let macosVersion: String
    let appVersion: String = "3.5.0 (Alpha)"

    let sessionID: String = UUID().uuidString
    let sessionStartedAt: Date = Date()

    var sessionStartedAtString: String {
        ISO8601DateFormatter().string(from: sessionStartedAt)
    }

    private var eventBuffer: [PlutoAlphaEvent] = []
    private var flushTimer: Timer?
    private var snapshotTimer: Timer?

    #if DEBUG
    private(set) var lastEnqueuedEvent: PlutoAlphaEvent?
    private(set) var enqueuedEventsHistory: [PlutoAlphaEvent] = []
    #endif

    private init() {
        // 1. Determine or persist unique Tester ID
        let defaults = UserDefaults.standard
        if let storedID = defaults.string(forKey: "pluto_alpha_tester_id") {
            self.testerID = storedID
        } else {
            let newID = "tester_\(Int.random(in: 100...999))"
            defaults.set(newID, forKey: "pluto_alpha_tester_id")
            self.testerID = newID
        }

        self.testerName = PlutoPrivacy.hash(NSFullUserName())
        self.deviceName = PlutoPrivacy.hash(Host.current().localizedName ?? "unknown")
        self.deviceModel = Self.getDeviceModelIdentifier()
        self.macosVersion = ProcessInfo.processInfo.operatingSystemVersionString

        startTimers()
    }

    // MARK: - Lifecycle & Timers

    private func startTimers() {
        // Periodic queue flush (every 30 seconds)
        flushTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.flushBuffer()
            }
        }

        // Periodic state snapshot (every 10 minutes)
        snapshotTimer = Timer.scheduledTimer(withTimeInterval: 600.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let container = try? ModelContainerFactory.makeConfiguredContainer() else { return }
                self?.captureFullStateSnapshot(context: container.mainContext)
            }
        }
    }

    func start() {
        PlutoDiagnosticEngine.shared.configureCrashHandlers()

        track(event: "app_launched", properties: [
            "session_id": AnyCodable(sessionID),
            "device_model": AnyCodable(deviceModel),
            "macos_version": AnyCodable(macosVersion),
            "tester_name": AnyCodable(testerName)
        ])

        // Initial snapshot and sync on launch
        Task { @MainActor in
            if let container = try? ModelContainerFactory.makeConfiguredContainer() {
                self.captureFullStateSnapshot(context: container.mainContext)
            }
        }
    }

    // MARK: - Core Event Tracking

    func track(event: String, properties: [String: AnyCodable] = [:]) {
        // Privacy Opt-In Check
        if let optIn = UserDefaults.standard.object(forKey: "mac_telemetry_opt_in") as? Bool, !optIn {
            return
        }

        let timestampMs = Int(Date().timeIntervalSince1970 * 1000)
        let eventID = "evt_\(testerID)_\(timestampMs)_\(UUID().uuidString.prefix(8))"
        let timestampIso = ISO8601DateFormatter().string(from: Date())

        var props = properties
        props["screen"] = AnyCodable(PlutoDiagnosticEngine.shared.currentScreen)

        let alphaEvent = PlutoAlphaEvent(
            event_id: eventID,
            event_name: event,
            timestamp: timestampIso,
            properties: props
        )

        #if DEBUG
        lastEnqueuedEvent = alphaEvent
        enqueuedEventsHistory.append(alphaEvent)
        #endif

        eventBuffer.append(alphaEvent)
        PlutoDiagnosticEngine.shared.leaveBreadcrumb("\(event) (\(properties.keys.joined(separator: ", ")))")

        // Flush immediately for real-time live transmission
        flushBuffer()
    }

    func flushBuffer() {
        guard !eventBuffer.isEmpty else { return }
        let toFlush = eventBuffer
        eventBuffer.removeAll()

        PlutoTelemetryStorage.shared.enqueue(events: toFlush)

        Task.detached(priority: .background) {
            await PlutoTelemetrySyncEngine.shared.triggerSync(reason: "buffer_flush")
        }
    }

    // MARK: - Testing / Inspection Helpers

    #if DEBUG
    func debugLastPayload() -> [String: Any] {
        guard let last = lastEnqueuedEvent ?? eventBuffer.last else { return [:] }
        var result: [String: Any] = [:]
        for (k, v) in last.properties {
            result[k] = v.value
        }
        return result
    }

    func debugPayload(at index: Int) -> [String: Any] {
        let history = enqueuedEventsHistory
        let targetIndex = index < 0 ? (history.count + index) : index
        guard targetIndex >= 0, targetIndex < history.count else { return [:] }
        let event = history[targetIndex]
        var result: [String: Any] = [:]
        for (k, v) in event.properties {
            result[k] = v.value
        }
        return result
    }
    #endif

    // MARK: - Domain Specific Action Trackers (PII SHA-256 Hashed)

    func trackModeSwitched(isSimplified: Bool, reason: String = "user_toggle") {
        track(event: "workspace_mode_switched", properties: [
            "target_mode": AnyCodable(isSimplified ? "simplified" : "pro"),
            "reason": AnyCodable(reason)
        ])
    }

    // 1. Habits
    func trackHabitCreated(board: HabitBoard) {
        track(event: "habit_created", properties: [
            "habit_id": AnyCodable(board.id.uuidString),
            "habit_name": AnyCodable(PlutoPrivacy.hash(board.name)),
            "unit": AnyCodable(board.unitLabel ?? "Check"),
            "metric": AnyCodable(board.metric.rawValue),
            "target": AnyCodable(board.targetValue)
        ])
    }

    func trackHabitCheckIn(board: HabitBoard, value: Double, isDone: Bool) {
        track(event: "habit_checked", properties: [
            "habit_id": AnyCodable(board.id.uuidString),
            "habit_name": AnyCodable(PlutoPrivacy.hash(board.name)),
            "value_logged": AnyCodable(value),
            "is_target_met": AnyCodable(isDone),
            "current_streak": AnyCodable(board.currentStreak)
        ])
    }

    func trackHabitDeleted(habitName: String) {
        track(event: "habit_deleted", properties: [
            "habit_name": AnyCodable(PlutoPrivacy.hash(habitName))
        ])
    }

    // 2. Tasks & Day Planner
    func trackTaskCreated(task: TodoItem) {
        track(event: "task_created", properties: [
            "task_id": AnyCodable(task.id.uuidString),
            "title": AnyCodable(PlutoPrivacy.hash(task.title)),
            "is_scheduled": AnyCodable(task.startTime != nil),
            "duration_minutes": AnyCodable(task.durationMinutes),
            "priority": AnyCodable(task.priority)
        ])
    }

    func trackTaskCompleted(task: TodoItem) {
        track(event: "task_completed", properties: [
            "task_id": AnyCodable(task.id.uuidString),
            "title": AnyCodable(PlutoPrivacy.hash(task.title)),
            "duration_minutes": AnyCodable(task.durationMinutes),
            "was_scheduled": AnyCodable(task.startTime != nil)
        ])
    }

    func trackTaskRescheduled(task: TodoItem, newStartTime: Date) {
        track(event: "task_rescheduled", properties: [
            "task_id": AnyCodable(task.id.uuidString),
            "title": AnyCodable(PlutoPrivacy.hash(task.title)),
            "new_start_time": AnyCodable(newStartTime)
        ])
    }

    // 3. Focus & Pomodoro
    func trackFocusSessionCompleted(durationSeconds: Int, soundName: String, taskTitle: String?) {
        track(event: "focus_session_completed", properties: [
            "duration_seconds": AnyCodable(durationSeconds),
            "sound_name": AnyCodable(soundName),
            "task_title": AnyCodable(PlutoPrivacy.hash(taskTitle ?? "Untracked Sprint"))
        ])
    }

    // 4. Journal & Reflection
    func trackJournalReflectionSaved(date: Date, text: String, clarityScore: Double?, sleepHours: Double?) {
        track(event: "journal_reflection_saved", properties: [
            "date": AnyCodable(date),
            "word_count": AnyCodable(text.split(separator: " ").count),
            "clarity_score": AnyCodable(clarityScore ?? 0.0),
            "sleep_hours": AnyCodable(sleepHours ?? 0.0)
        ])
    }

    // 5. Sleep & Routines
    func trackSleepLogged(bedtime: String, wakeTime: String, durationHours: Double) {
        track(event: "sleep_logged", properties: [
            "bedtime": AnyCodable(PlutoPrivacy.hash(bedtime)),
            "wake_time": AnyCodable(PlutoPrivacy.hash(wakeTime)),
            "duration_hours": AnyCodable(durationHours)
        ])
    }

    // 6. Navigation & Screen
    func trackScreenView(screenName: String) {
        PlutoDiagnosticEngine.shared.currentScreen = screenName
        track(event: "screen_viewed", properties: [
            "screen_name": AnyCodable(screenName)
        ])
    }

    func trackLayoutChanged(section: String, newLayout: String) {
        track(event: "layout_preference_changed", properties: [
            "section": AnyCodable(section),
            "layout_variant": AnyCodable(newLayout)
        ])
    }

    func trackHotkeyHUDOpened() {
        track(event: "quick_hud_opened", properties: [:])
    }

    // MARK: - State Snapshot Capture

    func captureFullStateSnapshot(context: ModelContext) {
        if let optIn = UserDefaults.standard.object(forKey: "mac_telemetry_opt_in") as? Bool, !optIn {
            return
        }

        let habits = (try? context.fetch(FetchDescriptor<HabitBoard>())) ?? []
        let tasks = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []

        let snapshotData: [String: AnyCodable] = [
            "capture_timestamp": AnyCodable(Date()),
            "active_habits_count": AnyCodable(habits.filter { $0.archivedAt == nil }.count),
            "total_habits": AnyCodable(habits.filter { $0.archivedAt == nil }.map { board in
                [
                    "id": board.id.uuidString,
                    "name": PlutoPrivacy.hash(board.name),
                    "unit": board.unitLabel ?? "Check",
                    "metric": board.metric.rawValue,
                    "target": board.targetValue,
                    "current_streak": board.currentStreak,
                    "logs_count": board.logs?.count ?? 0,
                    "is_archived": board.archivedAt != nil,
                    "habit_kind": board.habitKindRaw,
                    "color_index": board.colorIndex
                ]
            }),
            "total_tasks": AnyCodable(tasks.filter { !$0.isArchived }.map { t in
                [
                    "id": t.id.uuidString,
                    "title": PlutoPrivacy.hash(t.title),
                    "is_completed": t.isCompleted,
                    "duration_minutes": t.durationMinutes,
                    "is_scheduled": t.startTime != nil,
                    "priority": t.priority,
                    "due_date": t.dueDate != nil ? ISO8601DateFormatter().string(from: t.dueDate!) : nil
                ]
            })
        ]

        let timestampMs = Int(Date().timeIntervalSince1970 * 1000)
        let snapshot = PlutoAlphaSnapshot(
            snapshot_id: "snap_\(testerID)_\(timestampMs)",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            snapshot_json: snapshotData
        )

        PlutoTelemetryStorage.shared.enqueue(snapshot: snapshot)

        Task.detached(priority: .background) {
            await PlutoTelemetrySyncEngine.shared.triggerSync(reason: "state_snapshot")
        }
    }

    // MARK: - Helper

    private static func getDeviceModelIdentifier() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &machine, &size, nil, 0)
        return String(cString: machine)
    }
}
