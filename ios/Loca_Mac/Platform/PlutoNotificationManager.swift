//
//  PlutoNotificationManager.swift
//  PLUTO
//
//  Apple Native Notification System for PLUTO Version 3:
//  - A1: Smart Habit Reminders (dynamic streak-aware copy & custom times)
//  - A2: Actionable Notification Buttons (Mark as Done in background, Snooze 1 Hour)
//  - A3: Evening Reflection Prompt (daily 9 PM journal nudge)
//  - A4: Streak Break Alert (10 PM warning for incomplete active streaks)
//  - A5: Focus Session Complete (Timer completion stats & background delivery)
//  - A6: Weekly Progress Digest (Sunday 8 AM passive digest)
//  - A7: Deep Link from Notifications (Tapping deep-links to habit/task/journal/audit)
//  - A8: Notification Interrupt Levels (.timeSensitive vs .passive)
//

import Foundation
import UserNotifications
import SwiftData
import WidgetKit
import SwiftUI
import AppKit
import Combine

// MARK: - PlutoNotificationManager

@MainActor
final class PlutoNotificationManager: NSObject, ObservableObject {

    static let shared = PlutoNotificationManager()

    // MARK: - Published State

    @Published var isAuthorized: Bool = false
    @Published var pendingRequestsCount: Int = 0

    // MARK: - Notification Category Identifiers

    enum Category {
        static let habitReminder     = "PLUTO_HABIT_REMINDER"
        static let journalReflection  = "PLUTO_JOURNAL_REFLECTION"
        static let streakWarning      = "PLUTO_STREAK_WARNING"
        static let focusComplete      = "PLUTO_FOCUS_COMPLETE"
        static let weeklyDigest       = "PLUTO_WEEKLY_DIGEST"
    }

    // MARK: - Action Identifiers

    enum Action {
        static let markDone          = "ACTION_DONE"
        static let snoozeOneHour     = "ACTION_SNOOZE"
        static let captureReflection = "ACTION_CAPTURE_REFLECTION"
        static let logNow            = "ACTION_LOG_NOW"
        static let openHabit         = "ACTION_OPEN_HABIT"
        static let startBreak        = "ACTION_START_BREAK"
        static let nextSprint        = "ACTION_NEXT_SPRINT"
        static let viewAudit         = "ACTION_VIEW_AUDIT"
    }

    // MARK: - Notification Identifier Prefixes

    enum Identifier {
        static let habitPrefix        = "pluto_habit_reminder_"
        static let eveningReflection  = "pluto_evening_reflection"
        static let streakBreakAlert   = "pluto_streak_break_alert"
        static let snoozePrefix       = "pluto_snooze_"
        static let focusTimer             = "pluto_focus_timer"
        static let weeklyDigest           = "pluto_weekly_digest"
        static let workdayWellnessPrefix  = "pluto_workday_wellness_"
    }

    // MARK: - Deep Link Payload (A7)

    struct DeepLinkPayload {
        let section: MacSection
        let habitID: UUID?
        let taskID: UUID?
        let date: Date?
    }

    // MARK: - Lifecycle & Configuration

    private override init() {
        super.init()
    }

    /// Initializes categories, delegates, and checks current authorization status.
    func configure() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        registerCategories()
        checkAuthorization()
    }

    // MARK: - Category & Action Registration (A2, A5, A6)

    private func registerCategories() {
        let center = UNUserNotificationCenter.current()

        // 1. Habit Reminder Category: Mark as Done (Background) + Snooze 1 Hour
        let markDoneAction = UNNotificationAction(
            identifier: Action.markDone,
            title: "✅ Mark as Done",
            options: [] // Background action
        )

        let snoozeAction = UNNotificationAction(
            identifier: Action.snoozeOneHour,
            title: "⏰ Snooze 1 Hour",
            options: [] // Background action
        )

        let habitCategory = UNNotificationCategory(
            identifier: Category.habitReminder,
            actions: [markDoneAction, snoozeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // 2. Journal Reflection Category: Capture Reflection (Foreground)
        let captureAction = UNNotificationAction(
            identifier: Action.captureReflection,
            title: "✍️ Capture Reflection",
            options: [.foreground]
        )

        let journalCategory = UNNotificationCategory(
            identifier: Category.journalReflection,
            actions: [captureAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // 3. Streak Warning Category: Log Habit Now (Background) + View in PLUTO (Foreground)
        let logNowAction = UNNotificationAction(
            identifier: Action.logNow,
            title: "⚡ Log Habit Now",
            options: []
        )

        let openHabitAction = UNNotificationAction(
            identifier: Action.openHabit,
            title: "View Habit in PLUTO",
            options: [.foreground]
        )

        let streakCategory = UNNotificationCategory(
            identifier: Category.streakWarning,
            actions: [logNowAction, openHabitAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // 4. Focus Session Complete Category: Start Break / Next Sprint (A5)
        let startBreakAction = UNNotificationAction(
            identifier: Action.startBreak,
            title: "☕ Start Break",
            options: [.foreground]
        )

        let nextSprintAction = UNNotificationAction(
            identifier: Action.nextSprint,
            title: "⚡ Next Sprint",
            options: [.foreground]
        )

        let focusCategory = UNNotificationCategory(
            identifier: Category.focusComplete,
            actions: [startBreakAction, nextSprintAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // 5. Weekly Digest Category: Open Weekly Audit (A6)
        let viewAuditAction = UNNotificationAction(
            identifier: Action.viewAudit,
            title: "📈 Open Weekly Audit",
            options: [.foreground]
        )

        let digestCategory = UNNotificationCategory(
            identifier: Category.weeklyDigest,
            actions: [viewAuditAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        center.setNotificationCategories([
            habitCategory,
            journalCategory,
            streakCategory,
            focusCategory,
            digestCategory
        ])
    }

    // MARK: - Authorization

    func checkAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
                self?.refreshPendingCount()
            }
        }
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            self.isAuthorized = granted
            self.refreshPendingCount()
            return granted
        } catch {
            self.isAuthorized = false
            return false
        }
    }

    /// Sends an immediate test notification with auto-authorization request and 1s delivery.
    @discardableResult
    func sendImmediateTestNotification(
        title: String,
        body: String,
        sound: UNNotificationSound = .default,
        type: String = "general"
    ) async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            let granted = await requestAuthorization()
            guard granted else { return false }
        } else if settings.authorizationStatus == .denied {
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound
        content.interruptionLevel = .timeSensitive
        content.userInfo = ["target": "test", "type": type]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(
            identifier: "pluto_test_\(UUID().uuidString.prefix(8))",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            self.refreshPendingCount()
            return true
        } catch {
            print("Failed to schedule test notification: \(error.localizedDescription)")
            return false
        }
    }

    func refreshPendingCount() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { [weak self] requests in
            DispatchQueue.main.async {
                self?.pendingRequestsCount = requests.count
            }
        }
    }

    // MARK: - A1: Smart Habit Reminders (Streak-Aware & Time-Sensitive)

    /// Schedules or updates a daily streak-aware notification for an individual habit.
    func scheduleSmartHabitReminder(
        boardID: UUID,
        name: String,
        currentStreak: Int,
        timeString: String
    ) {
        guard let (hour, minute) = parseTime(timeString) else { return }

        let center = UNUserNotificationCenter.current()
        let identifier = "\(Identifier.habitPrefix)\(boardID.uuidString)"

        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()

        // Dynamic Streak-Aware Messaging (A1)
        if currentStreak > 1 {
            content.title = "🔥 \(name) · \(currentStreak)-Day Streak"
            content.body = "Keep your \(currentStreak)-day compounding momentum alive! Time to execute."
        } else if currentStreak == 1 {
            content.title = "⚡ \(name) · Streak in Motion"
            content.body = "1-day streak rolling! Lock in today's check-in to build momentum."
        } else {
            content.title = "✨ Time for \(name)"
            content.body = "Daily habit focus scheduled. Tap or click Mark as Done to log."
        }

        content.sound = .default
        content.categoryIdentifier = Category.habitReminder
        content.interruptionLevel = .timeSensitive // A8: High priority
        content.userInfo = [
            "target": "habits",
            "habitID": boardID.uuidString,
            "habitName": name,
            "streak": currentStreak
        ]

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request) { [weak self] _ in
            DispatchQueue.main.async { self?.refreshPendingCount() }
        }
    }

    /// Cancels the reminder for a specific habit.
    func cancelHabitReminder(boardID: UUID) {
        let identifier = "\(Identifier.habitPrefix)\(boardID.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        refreshPendingCount()
    }

    // MARK: - A3: Evening Reflection Prompt

    /// Schedules the 9:00 PM (or custom time) daily gentle journal reflection prompt.
    func scheduleEveningReflectionPrompt(timeString: String = "21:00") {
        guard let (hour, minute) = parseTime(timeString) else { return }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Identifier.eveningReflection])

        let content = UNMutableNotificationContent()
        content.title = "Evening Reflection · PLUTO"
        content.body = "Capture today's wins, moments, and cognitive clarity before you rest."
        content.sound = .default
        content.categoryIdentifier = Category.journalReflection
        content.interruptionLevel = .active // A8: Active priority
        content.userInfo = [
            "target": "journal",
            "type": "evening_reflection"
        ]

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: Identifier.eveningReflection, content: content, trigger: trigger)

        center.add(request) { [weak self] _ in
            DispatchQueue.main.async { self?.refreshPendingCount() }
        }
    }

    func cancelEveningReflectionPrompt() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Identifier.eveningReflection])
        refreshPendingCount()
    }

    // MARK: - A4: Streak Break Alert

    /// Schedules the 10:00 PM (or custom time) urgent warning for incomplete habits with active streaks.
    func scheduleStreakBreakAlert(timeString: String = "22:00") {
        guard let (hour, minute) = parseTime(timeString) else { return }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Identifier.streakBreakAlert])

        let content = UNMutableNotificationContent()
        content.title = "⚠️ Streak at Risk · PLUTO"
        content.body = "Don't let your active daily streaks slip! Less than 2 hours left before midnight."
        content.sound = .default
        content.categoryIdentifier = Category.streakWarning
        content.interruptionLevel = .timeSensitive // A8: Urgent warning
        content.userInfo = [
            "target": "habits",
            "type": "streak_break_alert"
        ]

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: Identifier.streakBreakAlert, content: content, trigger: trigger)

        center.add(request) { [weak self] _ in
            DispatchQueue.main.async { self?.refreshPendingCount() }
        }
    }

    func cancelStreakBreakAlert() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Identifier.streakBreakAlert])
        refreshPendingCount()
    }

    // MARK: - A5: Focus Session Complete (Timer Sync & Background Delivery)

    /// Schedules a background timer completion notification to fire exactly when an active Pomodoro/Countdown expires.
    func scheduleFocusCompletionNotification(tag: String, seconds: Int, mode: String = "Pomodoro") {
        guard seconds > 0 else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Identifier.focusTimer])

        let content = UNMutableNotificationContent()
        content.title = "🎯 Focus Sprint Completed · PLUTO"
        content.body = "Deep work sprint finished (\(tag)). Step back and enjoy your rest interval or start next sprint."
        content.sound = .default
        content.categoryIdentifier = Category.focusComplete
        content.interruptionLevel = .timeSensitive // A8: Break through Focus
        content.userInfo = [
            "target": "time",
            "tag": tag,
            "mode": mode
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: Identifier.focusTimer, content: content, trigger: trigger)

        center.add(request) { [weak self] _ in
            DispatchQueue.main.async { self?.refreshPendingCount() }
        }
    }

    /// Cancels any scheduled background focus timer notification (e.g. on pause or reset).
    func cancelFocusCompletionNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Identifier.focusTimer])
        refreshPendingCount()
    }

    /// Delivers an immediate focus session complete notification with session stats.
    func deliverImmediateFocusComplete(tag: String, durationMinutes: Int, mode: String = "Pomodoro") {
        cancelFocusCompletionNotification()
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "🎯 Focus Sprint Completed · PLUTO"
        content.body = "Completed \(durationMinutes)m deep work session on \(tag). Time for a rest interval."
        content.sound = .default
        content.categoryIdentifier = Category.focusComplete
        content.interruptionLevel = .timeSensitive // A8: Time Sensitive
        content.userInfo = [
            "target": "time",
            "tag": tag,
            "duration": durationMinutes,
            "mode": mode
        ]

        let request = UNNotificationRequest(
            identifier: "pluto_focus_complete_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Immediate delivery
        )

        center.add(request) { [weak self] _ in
            DispatchQueue.main.async { self?.refreshPendingCount() }
        }
    }

    // MARK: - A6: Weekly Progress Digest (Passive Sunday Digest)

    /// Schedules the weekly executive progress digest for Sunday at 8:00 AM.
    func scheduleWeeklyProgressDigest(hour: Int = 8, minute: Int = 0, weekday: Int = 1) { // 1 = Sunday
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Identifier.weeklyDigest])

        let content = UNMutableNotificationContent()
        content.title = "📊 Weekly Executive Digest · PLUTO"
        content.body = "Your weekly audit is ready: Review your 7-day habit compounding, deep work velocity, and reflection insights."
        content.sound = nil // Passive delivery
        content.categoryIdentifier = Category.weeklyDigest
        content.interruptionLevel = .passive // A8: Passive priority (silent/non-intrusive)
        content.userInfo = [
            "target": "audit",
            "type": "weekly_digest"
        ]

        var comp = DateComponents()
        comp.weekday = weekday
        comp.hour = hour
        comp.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: comp, repeats: true)
        let request = UNNotificationRequest(identifier: Identifier.weeklyDigest, content: content, trigger: trigger)

        center.add(request) { [weak self] _ in
            DispatchQueue.main.async { self?.refreshPendingCount() }
        }
    }

    func cancelWeeklyProgressDigest() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Identifier.weeklyDigest])
        refreshPendingCount()
    }

    // MARK: - Workday Alternating Wellness Reminders (Mon-Sat, 9 AM - 6 PM)

    /// Schedules alternating Hydration (💧) and Stretch (🚶) reminders across the workday.
    func scheduleWorkdayWellnessReminders(
        enabled: Bool = true,
        startHour: Int = 9,
        endHour: Int = 18,
        intervalMinutes: Int = 60,
        days: [Int] = [2, 3, 4, 5, 6, 7] // Mon(2) to Sat(7)
    ) {
        let center = UNUserNotificationCenter.current()

        center.getPendingNotificationRequests { requests in
            let idsToRemove = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(Identifier.workdayWellnessPrefix) }
            if !idsToRemove.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
            }

            guard enabled else {
                DispatchQueue.main.async { self.refreshPendingCount() }
                return
            }

            var promptIndex = 0
            for weekday in days {
                var currentMinute = startHour * 60 + intervalMinutes
                let endMinute = endHour * 60

                while currentMinute <= endMinute {
                    let hour = currentMinute / 60
                    let minute = currentMinute % 60

                    let isHydrate = (promptIndex % 2 == 0)
                    let title = isHydrate ? "💧 Time to Hydrate" : "🚶 Stand & Stretch"
                    let body = isHydrate ? "Take a sip of water and reset." : "Roll your shoulders and take a quick stretch."

                    let content = UNMutableNotificationContent()
                    content.title = title
                    content.body = body
                    content.sound = .default
                    content.categoryIdentifier = Category.habitReminder
                    content.interruptionLevel = .timeSensitive
                    content.userInfo = [
                        "target": "wellness",
                        "type": isHydrate ? "hydrate" : "stretch"
                    ]

                    var dateComponents = DateComponents()
                    dateComponents.weekday = weekday
                    dateComponents.hour = hour
                    dateComponents.minute = minute

                    let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                    let reqId = "\(Identifier.workdayWellnessPrefix)\(weekday)_\(hour)_\(minute)"
                    let request = UNNotificationRequest(identifier: reqId, content: content, trigger: trigger)

                    center.add(request)

                    promptIndex += 1
                    currentMinute += intervalMinutes
                }
            }

            DispatchQueue.main.async { self.refreshPendingCount() }
        }
    }

    func cancelWorkdayWellnessReminders() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let idsToRemove = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(Identifier.workdayWellnessPrefix) }
            if !idsToRemove.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
            }
            DispatchQueue.main.async { self.refreshPendingCount() }
        }
    }

    // MARK: - A7: Deep Link URL Scheme Parser

    /// Handles incoming `pluto://` custom URLs from notifications or system scripts.
    func handleDeepLinkURL(_ url: URL) {
        guard url.scheme == "pluto" || url.scheme == "loca" else { return }
        let host = url.host ?? url.path.replacingOccurrences(of: "/", with: "")

        switch host.lowercased() {
        case "habit", "habits":
            var habitUUID: UUID? = nil
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let idStr = components.queryItems?.first(where: { $0.name == "id" })?.value,
               let uuid = UUID(uuidString: idStr) {
                habitUUID = uuid
            }
            NotificationCenter.default.post(
                name: .locaDeepLink,
                object: DeepLinkPayload(section: .today, habitID: habitUUID, taskID: nil, date: nil)
            )

        case "today", "task", "tasks":
            var taskUUID: UUID? = nil
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let idStr = components.queryItems?.first(where: { $0.name == "id" })?.value,
               let uuid = UUID(uuidString: idStr) {
                taskUUID = uuid
            }
            NotificationCenter.default.post(
                name: .locaDeepLink,
                object: DeepLinkPayload(section: .today, habitID: nil, taskID: taskUUID, date: nil)
            )

        case "journal", "notes", "studio", "brainstorm":
            NotificationCenter.default.post(
                name: .locaDeepLink,
                object: DeepLinkPayload(section: .studio, habitID: nil, taskID: nil, date: nil)
            )

        case "time", "focus", "pomodoro":
            NotificationCenter.default.post(
                name: .locaDeepLink,
                object: DeepLinkPayload(section: .today, habitID: nil, taskID: nil, date: nil)
            )

        case "audit", "work", "digest", "weekly", "projects":
            NotificationCenter.default.post(
                name: .locaDeepLink,
                object: DeepLinkPayload(section: .studio, habitID: nil, taskID: nil, date: nil)
            )

        case "life", "mountain", "trek":
            NotificationCenter.default.post(
                name: .locaDeepLink,
                object: DeepLinkPayload(section: .life, habitID: nil, taskID: nil, date: nil)
            )

        case "settings":
            NotificationCenter.default.post(
                name: .locaDeepLink,
                object: DeepLinkPayload(section: .settings, habitID: nil, taskID: nil, date: nil)
            )

        default:
            break
        }
    }

    // MARK: - Master Sync Across All Active Habits & Schedules

    /// Synchronizes all scheduled reminders across all active habits according to user preferences.
    func syncAll(
        habits: [HabitBoard],
        masterEnabled: Bool,
        eveningReflectionEnabled: Bool,
        eveningReflectionTime: String,
        streakAlertEnabled: Bool,
        streakAlertTime: String,
        weeklyDigestEnabled: Bool = true,
        defaultHabitTime: String = "09:00"
    ) {
        let center = UNUserNotificationCenter.current()

        guard masterEnabled else {
            center.removeAllPendingNotificationRequests()
            refreshPendingCount()
            return
        }

        // 1. Sync per-habit smart reminders
        let activeHabits = habits.filter { $0.archivedAt == nil }

        // Remove old habit reminders to prevent orphans
        center.getPendingNotificationRequests { [weak self] requests in
            let habitIdentifiers = requests.map(\.identifier).filter { $0.hasPrefix(Identifier.habitPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: habitIdentifiers)

            DispatchQueue.main.async {
                for habit in activeHabits {
                    let time = habit.preferredReminderTime ?? defaultHabitTime
                    self?.scheduleSmartHabitReminder(
                        boardID: habit.id,
                        name: habit.name,
                        currentStreak: habit.currentStreak,
                        timeString: time
                    )
                }

                // 2. Evening Reflection Prompt (A3)
                if eveningReflectionEnabled {
                    self?.scheduleEveningReflectionPrompt(timeString: eveningReflectionTime)
                } else {
                    self?.cancelEveningReflectionPrompt()
                }

                // 3. Streak Break Alert (A4)
                if streakAlertEnabled {
                    self?.scheduleStreakBreakAlert(timeString: streakAlertTime)
                } else {
                    self?.cancelStreakBreakAlert()
                }

                // 4. Weekly Progress Digest (A6)
                if weeklyDigestEnabled {
                    self?.scheduleWeeklyProgressDigest()
                } else {
                    self?.cancelWeeklyProgressDigest()
                }

                self?.refreshPendingCount()
            }
        }
    }

    // MARK: - Instant Test Notifications

    /// Fires a demo notification in 3 seconds to immediately test actionable buttons.
    func sendInstantTestNotification(habitName: String = "Morning Deep Work", streak: Int = 14) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "🔥 \(habitName) · \(streak)-Day Streak"
        content.body = "Keep your \(streak)-day compounding momentum alive! Tap Mark as Done to check in."
        content.sound = .default
        content.categoryIdentifier = Category.habitReminder
        content.interruptionLevel = .timeSensitive
        content.userInfo = [
            "target": "habits",
            "habitID": UUID().uuidString,
            "habitName": habitName,
            "streak": streak
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(
            identifier: "pluto_test_notification_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        center.add(request) { [weak self] _ in
            DispatchQueue.main.async { self?.refreshPendingCount() }
        }
    }

    // MARK: - Time Helper

    private func parseTime(_ timeString: String) -> (hour: Int, minute: Int)? {
        let parts = timeString.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        return (hour, minute)
    }
}

// MARK: - UNUserNotificationCenterDelegate (Action Handling A2, A5, A6, A7)

extension PlutoNotificationManager: UNUserNotificationCenterDelegate {

    /// Foreground presentation: shows banner and plays sound even if app is open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge, .list])
    }

    /// Handles user interaction with notifications and action buttons (A2, A5, A6, A7).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionID = response.actionIdentifier

        Task { @MainActor in
            switch actionID {

            // A2: "Mark as Done" or "Log Habit Now" (Background execution)
            case Action.markDone, Action.logNow:
                if let habitIDStr = userInfo["habitID"] as? String,
                   let habitUUID = UUID(uuidString: habitIDStr) {
                    await self.logHabitInBackground(habitID: habitUUID)
                }

            // A2: "Snooze 1 Hour"
            case Action.snoozeOneHour:
                if let habitIDStr = userInfo["habitID"] as? String,
                   let habitName = userInfo["habitName"] as? String ?? userInfo["name"] as? String {
                    self.scheduleOneHourSnooze(habitID: habitIDStr, habitName: habitName)
                }

            // A3: "Capture Reflection"
            case Action.captureReflection:
                NotificationCenter.default.post(
                    name: .locaDeepLink,
                    object: DeepLinkPayload(section: .today, habitID: nil, taskID: nil, date: nil)
                )

            // A5: Focus actions
            case Action.startBreak, Action.nextSprint:
                NotificationCenter.default.post(
                    name: .locaDeepLink,
                    object: DeepLinkPayload(section: .today, habitID: nil, taskID: nil, date: nil)
                )

            // A6: Weekly Digest action
            case Action.viewAudit:
                NotificationCenter.default.post(
                    name: .locaDeepLink,
                    object: DeepLinkPayload(section: .studio, habitID: nil, taskID: nil, date: nil)
                )

            // Default click or "View Habit" (A7 Deep Linking)
            case UNNotificationDefaultActionIdentifier, Action.openHabit:
                if let targetStr = userInfo["target"] as? String {
                    switch targetStr {
                    case "journal", "today", "reflection":
                        NotificationCenter.default.post(
                            name: .locaDeepLink,
                            object: DeepLinkPayload(section: .today, habitID: nil, taskID: nil, date: nil)
                        )
                    case "time", "focus":
                        NotificationCenter.default.post(
                            name: .locaDeepLink,
                            object: DeepLinkPayload(section: .today, habitID: nil, taskID: nil, date: nil)
                        )
                    case "audit", "work", "projects", "notes", "studio":
                        NotificationCenter.default.post(
                            name: .locaDeepLink,
                            object: DeepLinkPayload(section: .studio, habitID: nil, taskID: nil, date: nil)
                        )
                    case "life", "mountain":
                        NotificationCenter.default.post(
                            name: .locaDeepLink,
                            object: DeepLinkPayload(section: .life, habitID: nil, taskID: nil, date: nil)
                        )
                    default:
                        let habitUUID = (userInfo["habitID"] as? String).flatMap(UUID.init)
                        NotificationCenter.default.post(
                            name: .locaDeepLink,
                            object: DeepLinkPayload(section: .today, habitID: habitUUID, taskID: nil, date: nil)
                        )
                    }
                } else if let type = userInfo["type"] as? String, type == "evening_reflection" {
                    NotificationCenter.default.post(
                        name: .locaDeepLink,
                        object: DeepLinkPayload(section: .today, habitID: nil, taskID: nil, date: nil)
                    )
                } else {
                    NotificationCenter.default.post(
                        name: .locaDeepLink,
                        object: DeepLinkPayload(section: .today, habitID: nil, taskID: nil, date: nil)
                    )
                }

            default:
                break
            }

            completionHandler()
        }
    }

    // MARK: - Background Check-in Execution

    @MainActor
    private func logHabitInBackground(habitID: UUID) async {
        guard let container = try? ModelContainerFactory.makeConfiguredContainer() else { return }
        let context = container.mainContext

        let descriptor = FetchDescriptor<HabitBoard>(
            predicate: #Predicate<HabitBoard> { $0.id == habitID && $0.archivedAt == nil }
        )

        guard let board = (try? context.fetch(descriptor))?.first else { return }

        do {
            try CheckInWriter.insert(
                value: board.effectiveTarget,
                timestamp: .now,
                note: "Logged via PLUTO Notification Action",
                board: board,
                context: context
            )

            // Refresh Widgets & UI
            WidgetCenter.shared.reloadAllTimelines()
            Haptics.impact(.rigid)
        } catch {
            print("Failed to log habit from notification action: \(error)")
        }
    }

    // MARK: - Snooze Helper

    @MainActor
    private func scheduleOneHourSnooze(habitID: String, habitName: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "⏰ Snoozed: \(habitName)"
        content.body = "1 hour elapsed! Ready to complete \(habitName) and preserve your streak?"
        content.sound = .default
        content.categoryIdentifier = Category.habitReminder
        content.interruptionLevel = .timeSensitive
        content.userInfo = [
            "target": "habits",
            "habitID": habitID,
            "habitName": habitName
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(Identifier.snoozePrefix)\(habitID)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        center.add(request) { [weak self] _ in
            DispatchQueue.main.async { self?.refreshPendingCount() }
        }
    }
}
