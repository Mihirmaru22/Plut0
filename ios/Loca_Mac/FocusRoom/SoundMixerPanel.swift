import SwiftUI

// MARK: - SoundMixerPanel (Studio Multi-Stem Audio Console)

struct SoundMixerPanel: View {

    @ObservedObject var soundVM: FocusSoundViewModel
    @Binding var isPresented: Bool

    @State private var hoveredPreset: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "slider.vertical.3")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.accentColor)

                    Text("Sound Console")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(.white)
                }

                Spacer()

                // Master Pause / Resume All Button
                Button {
                    soundVM.togglePauseAll()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: soundVM.isAllPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(soundVM.isAllPaused ? "Resume" : "Mute All")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .help(soundVM.isAllPaused ? "Resume All Tracks" : "Mute All Tracks")

                Button {
                    isPresented = false
                    Haptics.impact(.light)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }

            // Quick Atmospheric Preset Switcher
            VStack(alignment: .leading, spacing: 6) {
                Text("Focus Presets")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.45))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        presetPill(title: "🌧️ Rainy Fire", lofi: 0.0, nature: 0.0, rain: 0.35, fire: 0.25, lib: 0.0, piano: 0.0)
                        presetPill(title: "⭐ Deep LoFi", lofi: 0.45, nature: 0.0, rain: 0.15, fire: 0.0, lib: 0.0, piano: 0.20)
                        presetPill(title: "☕ Jazz Cafe", lofi: 0.0, nature: 0.0, rain: 0.10, fire: 0.15, lib: 0.20, piano: 0.40)
                        presetPill(title: "🌿 Alpine Zen", lofi: 0.0, nature: 0.45, rain: 0.20, fire: 0.0, lib: 0.0, piano: 0.0)
                        presetPill(title: "🔇 Clear", lofi: 0.0, nature: 0.0, rain: 0.0, fire: 0.0, lib: 0.0, piano: 0.0)
                    }
                }
            }

            Divider().opacity(0.25)

            // Tracks List
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(soundVM.tracks) { track in
                        trackRow(track: track)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: 280)
        }
        .padding(16)
        .frame(width: 310)
        .background(
            Color.black.opacity(0.80)
                .background(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.55), radius: 24, x: 0, y: 10)
    }

    private func presetPill(title: String, lofi: Float, nature: Float, rain: Float, fire: Float, lib: Float, piano: Float) -> some View {
        Button {
            soundVM.applyPreset(lofi: lofi, nature: nature, rain: rain, fire: fire, library: lib, piano: piano)
        } label: {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.6))
        }
        .buttonStyle(.plain)
    }

    private func trackRow(track: AmbientSoundTrack) -> some View {
        let isActive = track.volume > 0.001 && !track.isMuted && !soundVM.isAllPaused

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Text(track.emoji)
                        .font(.system(size: 13))

                    Text(track.name)
                        .font(.system(size: 12, weight: isActive ? .semibold : .medium))
                        .foregroundStyle(Color.white)

                    if isActive {
                        // Mini pulsing equalizer visualizer
                        HStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { bar in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.blue)
                                    .frame(width: 2, height: CGFloat.random(in: 4...12))
                                    .animation(.easeInOut(duration: 0.4).repeatForever(), value: track.volume)
                            }
                        }
                    }
                }

                Spacer()

                Button {
                    soundVM.toggleMute(for: track.id)
                    Haptics.impact(.light)
                } label: {
                    Image(systemName: (track.volume > 0.001 && !track.isMuted) ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 11))
                        .foregroundStyle((track.volume > 0.001 && !track.isMuted) ? Color.blue : Color.white.opacity(0.35))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Slider(
                    value: Binding(
                        get: { Double(track.volume) },
                        set: { soundVM.setVolume(for: track.id, volume: Float($0)) }
                    ),
                    in: 0.0...1.0
                )
                .tint(Color.blue)

                Text("\(Int(track.volume * 100))%")
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.40))
                    .frame(width: 34, alignment: .trailing)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            isActive ? Color.white.opacity(0.06) : Color.white.opacity(0.02),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isActive ? Color.blue.opacity(0.35) : Color.white.opacity(0.05), lineWidth: 0.8)
        )
    }
}
