//
//  PlutoCalendarSync.swift
//  PLUTO
//
//  EventKit Apple Calendar Synchronization for PLUTO Day Planner.
//  Bridges native macOS Calendar events into the Day Planner timeline.
//

import Foundation
import EventKit
import SwiftUI
import Combine

// MARK: - PlutoCalendarEvent

struct PlutoCalendarEvent: Identifiable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let notes: String?
    let location: String?
    let isAllDay: Bool
    let calendarTitle: String
    let calendarColorHex: String

    var durationMinutes: Int {
        let diff = Calendar.current.dateComponents([.minute], from: startDate, to: endDate).minute ?? 30
        return max(15, diff)
    }

    var calendarColor: Color {
        Color(hex: calendarColorHex)
    }
}

// MARK: - PlutoCalendarSync

@MainActor
final class PlutoCalendarSync: ObservableObject {

    static let shared = PlutoCalendarSync()

    private let eventStore = EKEventStore()

    // MARK: - Published State

    @Published var isAuthorized: Bool = false
    @Published var eventsForSelectedDate: [PlutoCalendarEvent] = []
    @Published var lastSyncTime: Date? = nil

    private init() {
        checkAuthorization()
    }

    // MARK: - Permission & Authorization

    func checkAuthorization() {
        let status = EKEventStore.authorizationStatus(for: .event)
        #if os(macOS)
        if #available(macOS 14.0, *) {
            self.isAuthorized = (status == .fullAccess || status == .authorized)
        } else {
            self.isAuthorized = (status == .authorized)
        }
        #else
        self.isAuthorized = (status == .authorized)
        #endif
    }

    func requestAuthorization() async -> Bool {
        do {
            #if os(macOS)
            if #available(macOS 14.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                self.isAuthorized = granted
                return granted
            } else {
                let granted = try await eventStore.requestAccess(to: .event)
                self.isAuthorized = granted
                return granted
            }
            #else
            let granted = try await eventStore.requestAccess(to: .event)
            self.isAuthorized = granted
            return granted
            #endif
        } catch {
            self.isAuthorized = false
            return false
        }
    }

    // MARK: - Fetch Events for a Specific Date

    func fetchEvents(for date: Date) {
        guard isAuthorized else {
            eventsForSelectedDate = []
            return
        }

        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        guard let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let rawEvents = eventStore.events(matching: predicate)

        self.eventsForSelectedDate = rawEvents
            .filter { !$0.isAllDay } // Timeline renders timed events
            .map { ek in
                let colorHex: String
                if let cgColor = ek.calendar?.cgColor {
                    colorHex = NSColor(cgColor: cgColor)?.hexString ?? "#4A90E2"
                } else {
                    colorHex = "#4A90E2"
                }

                return PlutoCalendarEvent(
                    id: ek.eventIdentifier ?? UUID().uuidString,
                    title: ek.title?.isEmpty == false ? ek.title! : "Untitled Event",
                    startDate: ek.startDate,
                    endDate: ek.endDate,
                    notes: ek.notes,
                    location: ek.location,
                    isAllDay: ek.isAllDay,
                    calendarTitle: ek.calendar?.title ?? "Calendar",
                    calendarColorHex: colorHex
                )
            }
            .sorted { $0.startDate < $1.startDate }

        self.lastSyncTime = .now
    }
}

// MARK: - NSColor Hex Extension Helper

#if os(macOS)
import AppKit

private extension NSColor {
    var hexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#4A90E2" }
        let r = Int(rgb.redComponent * 255.0)
        let g = Int(rgb.greenComponent * 255.0)
        let b = Int(rgb.blueComponent * 255.0)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
#endif
