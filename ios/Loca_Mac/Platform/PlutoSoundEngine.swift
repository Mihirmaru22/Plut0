import Foundation
import Combine

// MARK: - PlutoSoundEngine (Completely Silenced Sound Engine)

/// Native macOS acoustic feedback engine — completely silenced.
public final class PlutoSoundEngine: ObservableObject {

    public static let shared = PlutoSoundEngine()

    @Published public var isSoundEnabled: Bool = false

    private init() {
        self.isSoundEnabled = false
    }

    public enum AcousticSound {
        case checkmark
        case completePop
        case taskComplete
        case timerStart
        case timerComplete
        case summitPassport
        case tabSwitch
        case vaultLock
        case deleteTrash
    }

    /// Completely silent — zero click/tab sounds.
    public func play(_ sound: AcousticSound) {
        // Completely disabled by user request
    }
}
