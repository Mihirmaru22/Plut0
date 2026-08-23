import Foundation
import AVFoundation
import Combine
import SwiftUI

// MARK: - AmbientSoundTrack

struct AmbientSoundTrack: Identifiable {
    let id: String
    let name: String
    let emoji: String
    var volume: Float = 0.0
    var isMuted: Bool = false
    var previousVolume: Float = 0.5
}

// MARK: - FocusAudioDSPContext (Thread-Safe Real-Time CoreAudio DSP Engine)

final class FocusAudioDSPContext: @unchecked Sendable {

    // Primitive Atomic Volume States & Lock Protection
    private var lock = os_unfair_lock_s()
    
    private var _volLofi: Float = 0.0
    private var _volNature: Float = 0.0
    private var _volRain: Float = 0.0
    private var _volFire: Float = 0.0
    private var _volLibrary: Float = 0.0
    private var _volPiano: Float = 0.0
    private var _isAllPaused: Bool = false

    var volLofi: Float {
        get { os_unfair_lock_lock(&lock); defer { os_unfair_lock_unlock(&lock) }; return _volLofi }
        set { os_unfair_lock_lock(&lock); _volLofi = newValue; os_unfair_lock_unlock(&lock) }
    }
    var volNature: Float {
        get { os_unfair_lock_lock(&lock); defer { os_unfair_lock_unlock(&lock) }; return _volNature }
        set { os_unfair_lock_lock(&lock); _volNature = newValue; os_unfair_lock_unlock(&lock) }
    }
    var volRain: Float {
        get { os_unfair_lock_lock(&lock); defer { os_unfair_lock_unlock(&lock) }; return _volRain }
        set { os_unfair_lock_lock(&lock); _volRain = newValue; os_unfair_lock_unlock(&lock) }
    }
    var volFire: Float {
        get { os_unfair_lock_lock(&lock); defer { os_unfair_lock_unlock(&lock) }; return _volFire }
        set { os_unfair_lock_lock(&lock); _volFire = newValue; os_unfair_lock_unlock(&lock) }
    }
    var volLibrary: Float {
        get { os_unfair_lock_lock(&lock); defer { os_unfair_lock_unlock(&lock) }; return _volLibrary }
        set { os_unfair_lock_lock(&lock); _volLibrary = newValue; os_unfair_lock_unlock(&lock) }
    }
    var volPiano: Float {
        get { os_unfair_lock_lock(&lock); defer { os_unfair_lock_unlock(&lock) }; return _volPiano }
        set { os_unfair_lock_lock(&lock); _volPiano = newValue; os_unfair_lock_unlock(&lock) }
    }
    var isAllPaused: Bool {
        get { os_unfair_lock_lock(&lock); defer { os_unfair_lock_unlock(&lock) }; return _isAllPaused }
        set { os_unfair_lock_lock(&lock); _isAllPaused = newValue; os_unfair_lock_unlock(&lock) }
    }

    // Static Pre-Calculated Voicings (Zero Heap Allocations on Audio Render Thread)
    private static let lofiChords: [(Float, Float, Float, Float)] = [
        (146.83, 174.61, 220.00, 261.63), // Dm9
        (196.00, 246.94, 293.66, 329.63), // G13
        (130.81, 164.81, 196.00, 246.94), // Cmaj9
        (220.00, 277.18, 329.63, 370.00)  // A7#9
    ]

    private static let pianoChords: [(Float, Float, Float, Float)] = [
        (155.56, 196.00, 233.08, 293.66), // Ebmaj9
        (130.81, 155.56, 196.00, 293.66), // Cm9
        (174.61, 207.65, 261.63, 311.13), // Fm9
        (116.54, 146.83, 207.65, 261.63)  // Bb13
    ]

    // Real-Time Synthesis Sample Counter & Phases
    private var sampleIndex: UInt64 = 0

    // LoFi Rhodes States
    private var lofiPhase1: Float = 0.0
    private var lofiPhase2: Float = 0.0
    private var lofiPhase3: Float = 0.0
    private var lofiPhase4: Float = 0.0

    // Piano States
    private var pianoPhase1: Float = 0.0
    private var pianoPhase2: Float = 0.0
    private var pianoPhase3: Float = 0.0
    private var pianoPhase4: Float = 0.0

    // Rain 5-Pole Paul Kellet Filter States
    private var rainB0: Float = 0.0
    private var rainB1: Float = 0.0
    private var rainB2: Float = 0.0
    private var rainB3: Float = 0.0
    private var rainB4: Float = 0.0

    // Fireplace States
    private var fireHumPhase: Float = 0.0
    private var firePink: Float = 0.0

    // Nature States
    private var natureLfo: Float = 0.0
    private var naturePink: Float = 0.0

    // Library States
    private var libraryPink: Float = 0.0
    private var libraryLfo: Float = 0.0

    func render(frameCount: Int, ablPointer: UnsafeMutableAudioBufferListPointer, sampleRate: Float) {
        // Atomic Snapshot of Parameters to eliminate torn reads across stereo channels
        var curLofi: Float = 0.0
        var curNature: Float = 0.0
        var curRain: Float = 0.0
        var curFire: Float = 0.0
        var curLib: Float = 0.0
        var curPiano: Float = 0.0
        var curPaused: Bool = false

        os_unfair_lock_lock(&lock)
        curLofi = _volLofi
        curNature = _volNature
        curRain = _volRain
        curFire = _volFire
        curLib = _volLibrary
        curPiano = _volPiano
        curPaused = _isAllPaused
        os_unfair_lock_unlock(&lock)

        if curPaused {
            for buffer in ablPointer {
                memset(buffer.mData, 0, Int(buffer.mDataByteSize))
            }
            return
        }

        let gLofi = logarithmicGain(curLofi)
        let gNature = logarithmicGain(curNature)
        let gRain = logarithmicGain(curRain)
        let gFire = logarithmicGain(curFire)
        let gLib = logarithmicGain(curLib)
        let gPiano = logarithmicGain(curPiano)

        let isAnyActive = (gLofi + gNature + gRain + gFire + gLib + gPiano) > 0.0001
        if !isAnyActive {
            for buffer in ablPointer {
                memset(buffer.mData, 0, Int(buffer.mDataByteSize))
            }
            return
        }

        for frame in 0..<frameCount {
            sampleIndex &+= 1
            let t = Float(sampleIndex) / sampleRate

            var sumL: Float = 0.0
            var sumR: Float = 0.0

            // 1. LOFI BEATS (Polyphonic Rhodes Chord Progression)
            if gLofi > 0.0001 {
                let (lL, lR) = synthesizeLoFi(t: t, sampleRate: sampleRate)
                sumL += lL * gLofi
                sumR += lR * gLofi
            }

            // 2. PIANO & JAZZ (Harmonic Decay Voicings)
            if gPiano > 0.0001 {
                let (pL, pR) = synthesizePiano(t: t, sampleRate: sampleRate)
                sumL += pL * gPiano
                sumR += pR * gPiano
            }

            // 3. RAIN SOUNDS (5-Pole Binaural Paul Kellet Matrix)
            if gRain > 0.0001 {
                let (rL, rR) = synthesizeRain(t: t)
                sumL += rL * gRain
                sumR += rR * gRain
            }

            // 4. FIREPLACE SOUNDS (Hearth Lows + Crackle Spikes)
            if gFire > 0.0001 {
                let (fL, fR) = synthesizeFireplace(sampleRate: sampleRate)
                sumL += fL * gFire
                sumR += fR * gFire
            }

            // 5. NATURE SOUNDS (Alpine Mountain Breeze + Birds)
            if gNature > 0.0001 {
                let (nL, nR) = synthesizeNature(t: t, sampleRate: sampleRate)
                sumL += nL * gNature
                sumR += nR * gNature
            }

            // 6. LIBRARY AMBIENCE (Room Acoustics + Subtle Ticks)
            if gLib > 0.0001 {
                let (bL, bR) = synthesizeLibrary(t: t, sampleRate: sampleRate)
                sumL += bL * gLib
                sumR += bR * gLib
            }

            // Master Peak Limiting & Analogue Soft Clipping
            let finalL = tanh(sumL * 1.1) * 0.95
            let finalR = tanh(sumR * 1.1) * 0.95

            if ablPointer.count >= 2 {
                let bufL: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(ablPointer[0])
                let bufR: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(ablPointer[1])
                if frame < bufL.count { bufL[frame] = finalL }
                if frame < bufR.count { bufR[frame] = finalR }
            } else if ablPointer.count == 1 {
                let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(ablPointer[0])
                if frame < buf.count { buf[frame] = (finalL + finalR) * 0.5 }
            }
        }
    }

    private func logarithmicGain(_ sliderValue: Float) -> Float {
        guard sliderValue > 0.001 else { return 0.0 }
        return pow(min(1.0, max(0.0, sliderValue)), 1.85) * 0.55
    }

    private func synthesizeLoFi(t: Float, sampleRate: Float) -> (Float, Float) {
        // Lush Rhodes jazz chords (6s bar cycle: Dm9 -> G13 -> Cmaj9 -> A7#9)
        let chordCycle = Int(t / 6.0) % 4
        let currentNotes = Self.lofiChords[chordCycle]

        // Silky smooth tape wow & flutter (zero digital noise spikes)
        let flutter = 1.0 + 0.0018 * sin(2.0 * .pi * 0.30 * t)
        let tremolo = 0.90 + 0.10 * sin(2.0 * .pi * 0.20 * t)

        let twoPi = 2.0 * Float.pi
        let dt = 1.0 / sampleRate

        lofiPhase1 += twoPi * currentNotes.0 * flutter * dt
        lofiPhase2 += twoPi * currentNotes.1 * flutter * dt
        lofiPhase3 += twoPi * currentNotes.2 * flutter * dt
        lofiPhase4 += twoPi * currentNotes.3 * flutter * dt

        if lofiPhase1 > twoPi { lofiPhase1 -= twoPi }
        if lofiPhase2 > twoPi { lofiPhase2 -= twoPi }
        if lofiPhase3 > twoPi { lofiPhase3 -= twoPi }
        if lofiPhase4 > twoPi { lofiPhase4 -= twoPi }

        // Warm analogue tone generators
        let s1 = sin(lofiPhase1) * 0.28 + sin(lofiPhase1 * 2.0) * 0.08
        let s2 = sin(lofiPhase2) * 0.24 + sin(lofiPhase2 * 2.0) * 0.06
        let s3 = sin(lofiPhase3) * 0.20 + sin(lofiPhase3 * 2.0) * 0.05
        let s4 = sin(lofiPhase4) * 0.18

        let rawL = (s1 + s3) * tremolo
        let rawR = (s2 + s4) * tremolo

        return (tanh(rawL * 1.3) * 0.42, tanh(rawR * 1.3) * 0.42)
    }

    private func synthesizePiano(t: Float, sampleRate: Float) -> (Float, Float) {
        // Rich Polyphonic Jazz Chord Progression (6s per chord measure: Ebmaj9 -> Cm9 -> Fm9 -> Bb13)
        let chordCycle = Int(t / 6.0) % 4
        let notes = Self.pianoChords[chordCycle]

        let dt = 1.0 / sampleRate
        let twoPi = 2.0 * Float.pi

        pianoPhase1 += twoPi * notes.0 * dt
        pianoPhase2 += twoPi * notes.1 * dt
        pianoPhase3 += twoPi * notes.2 * dt
        pianoPhase4 += twoPi * notes.3 * dt

        if pianoPhase1 > twoPi { pianoPhase1 -= twoPi }
        if pianoPhase2 > twoPi { pianoPhase2 -= twoPi }
        if pianoPhase3 > twoPi { pianoPhase3 -= twoPi }
        if pianoPhase4 > twoPi { pianoPhase4 -= twoPi }

        // Natural piano hammer strike & acoustic damper decay envelope
        let chordTime = t.truncatingRemainder(dividingBy: 6.0)
        let decayEnv = exp(-chordTime * 0.65) // Smooth 6-second sustained decay

        let n1 = (sin(pianoPhase1) * 0.40 + sin(pianoPhase1 * 2.0) * 0.15) * decayEnv
        let n2 = (sin(pianoPhase2) * 0.35 + sin(pianoPhase2 * 2.0) * 0.12) * decayEnv
        let n3 = (sin(pianoPhase3) * 0.30 + sin(pianoPhase3 * 2.0) * 0.10) * decayEnv
        let n4 = (sin(pianoPhase4) * 0.25 + sin(pianoPhase4 * 2.0) * 0.08) * decayEnv

        // Stereo acoustic soundstage spread
        let pianoL = (n1 + n3 * 0.8) * 0.38
        let pianoR = (n2 + n4 * 0.8) * 0.38

        return (tanh(pianoL * 1.1), tanh(pianoR * 1.1))
    }

    private func synthesizeRain(t: Float) -> (Float, Float) {
        let white = Float.random(in: -1.0...1.0)
        rainB0 = 0.99886 * rainB0 + white * 0.0555179
        rainB1 = 0.99332 * rainB1 + white * 0.0750759
        rainB2 = 0.96900 * rainB2 + white * 0.1538520
        rainB3 = 0.86650 * rainB3 + white * 0.3104856
        rainB4 = 0.55000 * rainB4 + white * 0.5329522
        let pink = (rainB0 + rainB1 + rainB2 + rainB3 + rainB4 + white * 0.5362) * 0.075

        let rainMod = 0.70 + 0.30 * sin(2.0 * .pi * 0.08 * t)
        let drop = Float.random(in: 0...1) > 0.997 ? Float.random(in: 0.15...0.35) : 0.0

        let rL = (pink * rainMod + drop) * 0.38
        let rR = (pink * rainMod * Float.random(in: 0.96...1.04)) * 0.38
        return (rL, rR)
    }

    private func synthesizeFireplace(sampleRate: Float) -> (Float, Float) {
        let dt = 1.0 / sampleRate
        fireHumPhase += 2.0 * .pi * 68.0 * dt
        if fireHumPhase > 2.0 * .pi { fireHumPhase -= 2.0 * .pi }

        let white = Float.random(in: -1.0...1.0)
        firePink = 0.985 * firePink + white * 0.04
        let hearthHum = (sin(fireHumPhase) * 0.12 + firePink * 0.20)

        var popL: Float = 0.0
        var popR: Float = 0.0
        if Float.random(in: 0...1.0) < 0.0018 {
            let amp = Float.random(in: 0.35...0.75)
            if Float.random(in: 0...1.0) > 0.5 {
                popL = amp
            } else {
                popR = amp
            }
        }

        return ((hearthHum + popL) * 0.40, (hearthHum + popR) * 0.40)
    }

    private func synthesizeNature(t: Float, sampleRate: Float) -> (Float, Float) {
        let dt = 1.0 / sampleRate
        natureLfo += 2.0 * .pi * 0.12 * dt
        if natureLfo > 2.0 * .pi { natureLfo -= 2.0 * .pi }

        let white = Float.random(in: -1.0...1.0)
        naturePink = 0.96 * naturePink + white * 0.04
        let breeze = naturePink * (0.6 + 0.4 * sin(natureLfo)) * 0.25

        let birdCycle = t.truncatingRemainder(dividingBy: 14.0)
        var birdTone: Float = 0.0
        if birdCycle < 0.6 {
            let chirpPhase = 2.0 * .pi * 2800.0 * t
            birdTone = sin(chirpPhase) * sin((birdCycle / 0.6) * .pi) * 0.12
        }

        return ((breeze + birdTone * 0.8) * 0.35, (breeze + birdTone * 1.2) * 0.35)
    }

    private func synthesizeLibrary(t: Float, sampleRate: Float) -> (Float, Float) {
        let dt = 1.0 / sampleRate
        libraryLfo += 2.0 * .pi * 0.06 * dt
        if libraryLfo > 2.0 * .pi { libraryLfo -= 2.0 * .pi }

        let white = Float.random(in: -1.0...1.0)
        libraryPink = 0.94 * libraryPink + white * 0.06
        let roomAcoustic = libraryPink * (0.65 + 0.35 * sin(libraryLfo)) * 0.15

        let tickCycle = t.truncatingRemainder(dividingBy: 1.0)
        var tick: Float = 0.0
        if tickCycle < 0.02 {
            tick = Float.random(in: 0.10...0.25)
        }

        return ((roomAcoustic + tick) * 0.30, roomAcoustic * 0.30)
    }
}

// MARK: - FocusSoundViewModel (MainActor State Controller)

@MainActor
final class FocusSoundViewModel: ObservableObject {

    @Published var tracks: [AmbientSoundTrack] = [
        AmbientSoundTrack(id: "lofi", name: "LoFi beats", emoji: "⭐", volume: 0.0),
        AmbientSoundTrack(id: "nature", name: "Nature sounds", emoji: "🌿", volume: 0.0),
        AmbientSoundTrack(id: "rain", name: "Rain sounds", emoji: "💧", volume: 0.0),
        AmbientSoundTrack(id: "fireplace", name: "Fireplace sounds", emoji: "🔥", volume: 0.0),
        AmbientSoundTrack(id: "library", name: "Library ambience", emoji: "📚", volume: 0.0),
        AmbientSoundTrack(id: "piano", name: "Piano & jazz", emoji: "🎹", volume: 0.0)
    ]

    @Published var isAllPaused: Bool = false
    @Published var youtubeVolume: Double = 0.5

    // Multi-Track Studio Audio Engine
    private var audioEngine = AVAudioEngine()
    private var isEngineStarted: Bool = false

    // Real-Time Audio DSP Context (Isolated from MainActor)
    private let dspContext = FocusAudioDSPContext()
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadPersistedVolumes()
        setupMultiTrackEngine()
        setupAudioObservers()
    }

    // MARK: - Persistence

    private func loadPersistedVolumes() {
        for i in 0..<tracks.count {
            let id = tracks[i].id
            let key = "focus_sound_vol_\(id)"
            if let saved = UserDefaults.standard.value(forKey: key) as? Float {
                tracks[i].volume = saved
                syncDSPVolume(for: id, volume: saved)
            }
        }
    }

    private func persistVolume(for trackID: String, volume: Float) {
        UserDefaults.standard.set(volume, forKey: "focus_sound_vol_\(trackID)")
    }

    private func syncDSPVolume(for trackID: String, volume: Float) {
        switch trackID {
        case "lofi":      dspContext.volLofi = volume
        case "nature":    dspContext.volNature = volume
        case "rain":      dspContext.volRain = volume
        case "fireplace": dspContext.volFire = volume
        case "library":   dspContext.volLibrary = volume
        case "piano":     dspContext.volPiano = volume
        default: break
        }
    }

    // MARK: - Audio Engine Lifecycle & Hardware Routing

    private func setupAudioObservers() {
        NotificationCenter.default.publisher(for: .AVAudioEngineConfigurationChange, object: audioEngine)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleEngineConfigurationChange()
            }
            .store(in: &cancellables)

        #if os(iOS)
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let userInfo = notification.userInfo,
                      let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

                if type == .ended {
                    if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                        if options.contains(.shouldResume) {
                            self?.checkEngineRunning()
                        }
                    }
                }
            }
            .store(in: &cancellables)
        #endif
    }

    private func handleEngineConfigurationChange() {
        let wasRunning = isEngineStarted
        audioEngine.stop()
        isEngineStarted = false

        setupMultiTrackEngine()

        if wasRunning && !isAllPaused {
            checkEngineRunning()
        }
    }

    private func setupMultiTrackEngine() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AVAudioSession setup failed: \(error)")
        }
        #endif

        let mainMixer = audioEngine.mainMixerNode
        let format = mainMixer.outputFormat(forBus: 0)
        let sampleRate: Float = format.sampleRate > 0 ? Float(format.sampleRate) : 44100.0

        let context = self.dspContext

        // Dedicated High-Fidelity Stereo Synthesis Node (Safe pure C closure without MainActor captures)
        let source = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            context.render(frameCount: Int(frameCount), ablPointer: ablPointer, sampleRate: sampleRate)
            return noErr
        }

        audioEngine.attach(source)
        audioEngine.connect(source, to: mainMixer, format: format)
        isEngineStarted = false

        let hasActive = tracks.contains { $0.volume > 0.001 && !$0.isMuted }
        if hasActive {
            checkEngineRunning()
        }
    }

    // MARK: - Engine Controller

    private func checkEngineRunning() {
        let hasActiveTrack = tracks.contains { $0.volume > 0.001 && !$0.isMuted }
        if hasActiveTrack && !isAllPaused {
            if !isEngineStarted {
                do {
                    try audioEngine.start()
                    isEngineStarted = true
                } catch {
                    print("FocusSoundEngine failed to start: \(error)")
                }
            }
        } else {
            if isEngineStarted {
                audioEngine.pause()
                isEngineStarted = false
            }
        }
    }

    // MARK: - Public Control API

    func setVolume(for trackID: String, volume: Float) {
        guard let index = tracks.firstIndex(where: { $0.id == trackID }) else { return }
        let clamped = min(1.0, max(0.0, volume))
        tracks[index].volume = clamped
        syncDSPVolume(for: trackID, volume: clamped)
        persistVolume(for: trackID, volume: clamped)

        if clamped > 0.001 {
            tracks[index].isMuted = false
            tracks[index].previousVolume = clamped
        }
        checkEngineRunning()
    }

    func toggleMute(for trackID: String) {
        guard let index = tracks.firstIndex(where: { $0.id == trackID }) else { return }

        if tracks[index].isMuted {
            tracks[index].isMuted = false
            let restored = tracks[index].previousVolume > 0 ? tracks[index].previousVolume : 0.5
            tracks[index].volume = restored
            syncDSPVolume(for: trackID, volume: restored)
            persistVolume(for: trackID, volume: restored)
        } else {
            tracks[index].isMuted = true
            tracks[index].previousVolume = tracks[index].volume > 0 ? tracks[index].volume : 0.5
            tracks[index].volume = 0.0
            syncDSPVolume(for: trackID, volume: 0.0)
            persistVolume(for: trackID, volume: 0.0)
        }
        checkEngineRunning()
    }

    func togglePauseAll() {
        isAllPaused.toggle()
        dspContext.isAllPaused = isAllPaused
        checkEngineRunning()
        Haptics.impact(.medium)
    }

    // MARK: - Quick Mix Preset Shortcuts

    func applyPreset(lofi: Float, nature: Float, rain: Float, fire: Float, library: Float, piano: Float) {
        setVolume(for: "lofi", volume: lofi)
        setVolume(for: "nature", volume: nature)
        setVolume(for: "rain", volume: rain)
        setVolume(for: "fireplace", volume: fire)
        setVolume(for: "library", volume: library)
        setVolume(for: "piano", volume: piano)
        if isAllPaused {
            isAllPaused = false
            dspContext.isAllPaused = false
        }
        checkEngineRunning()
        Haptics.impact(.medium)
    }
}
