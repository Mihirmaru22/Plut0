import SwiftUI
import Combine

// MARK: - PomodoroMode

enum PomodoroMode: String, CaseIterable, Identifiable {
    case focus      = "Focus"
    case shortBreak = "Short Break"
    case longBreak  = "Long Break"

    var id: String { rawValue }

    var defaultMinutes: Int {
        switch self {
        case .focus: return 25
        case .shortBreak: return 5
        case .longBreak: return 15
        }
    }

    var icon: String {
        switch self {
        case .focus: return "brain.head.profile"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "leaf.fill"
        }
    }

    var themeColor: Color {
        switch self {
        case .focus: return Color(red: 0.20, green: 0.55, blue: 0.95)
        case .shortBreak: return Color(red: 0.18, green: 0.80, blue: 0.44)
        case .longBreak: return Color(red: 0.65, green: 0.40, blue: 0.90)
        }
    }
}

// MARK: - FocusTimerViewModel (Precision Pomodoro & Focus Engine)

@MainActor
final class FocusTimerViewModel: ObservableObject {

    @Published var mode: PomodoroMode = .focus
    @Published var customFocusMinutes: Int = 25
    @Published var customShortBreakMinutes: Int = 5
    @Published var customLongBreakMinutes: Int = 15

    @Published var secondsRemaining: Int = 25 * 60
    @Published var isRunning: Bool = false
    @Published var isMuted: Bool = false
    @Published var completedRounds: Int = 0
    @Published var totalRoundsTarget: Int = 4

    // Total accumulated focused seconds for session tracking
    @Published var totalSecondsFocused: Int = 0

    private var cancellables = Set<AnyCancellable>()
    private var timerPublisher = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    // Wall-clock delta anchors
    private var lastResumeDate: Date? = nil
    private var targetEndDate: Date? = nil

    init() {
        resetToCurrentMode()
        setupTimer()
    }

    var totalDurationSeconds: Int {
        switch mode {
        case .focus: return max(60, customFocusMinutes * 60)
        case .shortBreak: return max(60, customShortBreakMinutes * 60)
        case .longBreak: return max(60, customLongBreakMinutes * 60)
        }
    }

    var progress: Double {
        guard totalDurationSeconds > 0 else { return 0 }
        let elapsed = totalDurationSeconds - secondsRemaining
        return Double(elapsed) / Double(totalDurationSeconds)
    }

    var secondsElapsed: Int {
        totalDurationSeconds - secondsRemaining
    }

    private func setupTimer() {
        timerPublisher
            .sink { [weak self] _ in
                guard let self = self, self.isRunning, let target = self.targetEndDate else { return }
                let remaining = max(0, Int(ceil(target.timeIntervalSince(Date()))))
                self.secondsRemaining = remaining

                if remaining <= 0 {
                    self.handleSessionCompleted()
                }
            }
            .store(in: &cancellables)
    }

    func setMode(_ newMode: PomodoroMode) {
        guard mode != newMode else { return }
        pause()
        mode = newMode
        resetToCurrentMode()
        Haptics.impact(.light)
    }

    func togglePlayPause() {
        if isRunning {
            pause()
        } else {
            resume()
        }
        Haptics.impact(.light)
    }

    func resume() {
        guard secondsRemaining > 0 else {
            resetToCurrentMode()
            return
        }
        lastResumeDate = Date()
        targetEndDate = Date().addingTimeInterval(TimeInterval(secondsRemaining))
        isRunning = true
        if mode == .focus {
            LocaPowerManager.shared.beginFocusSleepAssertion()
        }
    }

    func pause() {
        if let target = targetEndDate {
            secondsRemaining = max(0, Int(ceil(target.timeIntervalSince(Date()))))
        }
        lastResumeDate = nil
        targetEndDate = nil
        isRunning = false
        LocaPowerManager.shared.endFocusSleepAssertion()
    }

    func resetTimer() {
        pause()
        resetToCurrentMode()
        Haptics.impact(.medium)
    }

    func skipNext() {
        pause()
        advanceToNextPhase()
        resetToCurrentMode()
        Haptics.impact(.light)
    }

    func adjustDuration(deltaMinutes: Int) {
        switch mode {
        case .focus:
            customFocusMinutes = max(1, min(120, customFocusMinutes + deltaMinutes))
        case .shortBreak:
            customShortBreakMinutes = max(1, min(30, customShortBreakMinutes + deltaMinutes))
        case .longBreak:
            customLongBreakMinutes = max(1, min(60, customLongBreakMinutes + deltaMinutes))
        }

        if !isRunning {
            resetToCurrentMode()
        } else {
            // Adjust running end date
            let adjustment = TimeInterval(deltaMinutes * 60)
            targetEndDate = targetEndDate?.addingTimeInterval(adjustment)
            secondsRemaining = max(0, secondsRemaining + deltaMinutes * 60)
        }
        Haptics.impact(.light)
    }

    private func handleSessionCompleted() {
        pause()
        if !isMuted {
            PlutoSoundEngine.shared.play(.completePop)
        }
        Haptics.notify(.success)

        // Ghost Mode OS Bridge: automatically credit verified focus minutes to Silence Ring
        if mode == .focus {
            let focusMins = totalDurationSeconds / 60
            if focusMins > 0 {
                Task {
                    _ = try? await GhostEngine.shared.recordVerifiedSilenceMinutes(focusMins)
                }
            }
        }

        advanceToNextPhase()
        resetToCurrentMode()
    }

    private func advanceToNextPhase() {
        if mode == .focus {
            completedRounds += 1
            totalSecondsFocused += totalDurationSeconds
            if completedRounds % totalRoundsTarget == 0 {
                mode = .longBreak
            } else {
                mode = .shortBreak
            }
        } else {
            mode = .focus
        }
    }

    private func resetToCurrentMode() {
        secondsRemaining = totalDurationSeconds
        lastResumeDate = nil
        targetEndDate = nil
    }

    var formattedTime: String {
        let minutes = secondsRemaining / 60
        let seconds = secondsRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
