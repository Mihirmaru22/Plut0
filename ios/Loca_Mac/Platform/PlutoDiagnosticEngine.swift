//
//  PlutoDiagnosticEngine.swift
//  PLUTO
//
//  Crash & Diagnostic Telemetry Engine for Private Alpha.
//  Captures uncaught exceptions, system signals, and maintains an in-memory breadcrumb trail
//  with automatic persistence to PlutoTelemetryStorage for crash analysis.
//

import Foundation
import AppKit
import os.log

// MARK: - PlutoDiagnosticEngine

final class PlutoDiagnosticEngine: @unchecked Sendable {

    static let shared = PlutoDiagnosticEngine()

    private let logger = Logger(subsystem: "com.mihirmaru.pluto.telemetry", category: "diagnostics")
    private let lock = NSLock()

    private var _currentScreen: String = "launch"
    var currentScreen: String {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _currentScreen
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _currentScreen = newValue
        }
    }

    private var breadcrumbBuffer: [String] = []
    private let maxBreadcrumbs = 100
    private var isConfigured = false

    private init() {}

    // MARK: - Breadcrumbs

    func leaveBreadcrumb(_ message: String) {
        lock.lock()
        defer { lock.unlock() }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] \(message)"
        breadcrumbBuffer.append(entry)

        if breadcrumbBuffer.count > maxBreadcrumbs {
            breadcrumbBuffer.removeFirst(breadcrumbBuffer.count - maxBreadcrumbs)
        }
    }

    func getBreadcrumbs() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return breadcrumbBuffer
    }

    // MARK: - Crash Handling Configuration

    func configureCrashHandlers() {
        lock.lock()
        defer { lock.unlock() }

        guard !isConfigured else { return }
        isConfigured = true

        // 1. Uncaught NSException Handler
        NSSetUncaughtExceptionHandler { exception in
            PlutoDiagnosticEngine.shared.handleUncaughtException(exception)
        }

        // 2. POSIX Signal Handlers for native crashes
        signal(SIGABRT) { sig in PlutoDiagnosticEngine.handleSignal(sig, name: "SIGABRT") }
        signal(SIGILL)  { sig in PlutoDiagnosticEngine.handleSignal(sig, name: "SIGILL") }
        signal(SIGSEGV) { sig in PlutoDiagnosticEngine.handleSignal(sig, name: "SIGSEGV") }
        signal(SIGFPE)  { sig in PlutoDiagnosticEngine.handleSignal(sig, name: "SIGFPE") }
        signal(SIGBUS)  { sig in PlutoDiagnosticEngine.handleSignal(sig, name: "SIGBUS") }
        signal(SIGTRAP) { sig in PlutoDiagnosticEngine.handleSignal(sig, name: "SIGTRAP") }

        logger.info("Pluto diagnostic and crash handlers successfully configured.")
    }

    // MARK: - Exception & Crash Reporting

    func handleUncaughtException(_ exception: NSException) {
        let timestampIso = ISO8601DateFormatter().string(from: Date())
        let stackSymbols = exception.callStackSymbols.joined(separator: "\n")
        let crumbs = getBreadcrumbs()

        let crash = PlutoAlphaCrash(
            session_id: nil,
            timestamp: timestampIso,
            app_version: "3.5.0 (Alpha)",
            macos_version: ProcessInfo.processInfo.operatingSystemVersionString,
            current_screen: currentScreen,
            exception_name: exception.name.rawValue,
            exception_reason: exception.reason,
            stack_trace: stackSymbols,
            breadcrumbs: crumbs,
            metadata: [
                "exception_type": AnyCodable("NSException")
            ]
        )

        PlutoTelemetryStorage.shared.enqueue(crash: crash)
        logger.fault("Uncaught NSException recorded: \(exception.name.rawValue) - \(exception.reason ?? "")")
    }

    private static func handleSignal(_ signal: Int32, name: String) {
        let timestampIso = ISO8601DateFormatter().string(from: Date())
        let stackSymbols = Thread.callStackSymbols.joined(separator: "\n")
        let engine = PlutoDiagnosticEngine.shared
        let crumbs = engine.getBreadcrumbs()

        let crash = PlutoAlphaCrash(
            session_id: nil,
            timestamp: timestampIso,
            app_version: "3.5.0 (Alpha)",
            macos_version: ProcessInfo.processInfo.operatingSystemVersionString,
            current_screen: engine.currentScreen,
            exception_name: "POSIX_SIGNAL_\(name)",
            exception_reason: "Signal \(signal) (\(name)) received",
            stack_trace: stackSymbols,
            breadcrumbs: crumbs,
            metadata: [
                "signal_number": AnyCodable(Int(signal)),
                "signal_name": AnyCodable(name)
            ]
        )

        PlutoTelemetryStorage.shared.enqueue(crash: crash)
    }

    // MARK: - Manual Error & Performance Logging

    func recordError(_ error: Error, metadata: [String: AnyCodable] = [:]) {
        let timestampIso = ISO8601DateFormatter().string(from: Date())
        var meta = metadata
        meta["error_description"] = AnyCodable(error.localizedDescription)

        let crash = PlutoAlphaCrash(
            session_id: nil,
            timestamp: timestampIso,
            app_version: "3.5.0 (Alpha)",
            macos_version: ProcessInfo.processInfo.operatingSystemVersionString,
            current_screen: currentScreen,
            exception_name: String(describing: type(of: error)),
            exception_reason: error.localizedDescription,
            stack_trace: Thread.callStackSymbols.joined(separator: "\n"),
            breadcrumbs: getBreadcrumbs(),
            metadata: meta
        )

        PlutoTelemetryStorage.shared.enqueue(crash: crash)
    }

    func recordPerformance(sessionID: String?, traceName: String, durationMs: Double, metadata: [String: AnyCodable] = [:]) {
        let timestampIso = ISO8601DateFormatter().string(from: Date())
        let perf = PlutoAlphaPerformance(
            session_id: sessionID,
            trace_name: traceName,
            duration_ms: durationMs,
            timestamp: timestampIso,
            metadata: metadata
        )
        PlutoTelemetryStorage.shared.enqueue(performance: perf)
    }
}
