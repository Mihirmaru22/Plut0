import SwiftUI

/// Evening Ghost Reflection & Attestation Sheet.
/// Allows fast check-in for Body, Mind reflection note, and Silence attestation with zero social clutter.
public struct GhostCheckInSheet: View {
    @Environment(\.dismiss) private var dismiss
    public var onSaved: (() -> Void)?

    @State private var bodyClosed: Bool = false
    @State private var mindReflectionText: String = ""
    @State private var silenceAttestedMinutes: Double = 45.0
    @State private var isSocialMediaFree: Bool = true
    @State private var isSaving: Bool = false

    public init(onSaved: (() -> Void)? = nil) {
        self.onSaved = onSaved
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
                        Text("EVENING GHOST CHECK-IN")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .tracking(1.2)
                    }
                    Text("Seal Today's Ring Closures")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.white)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Divider().opacity(0.12)

            ScrollView {
                VStack(spacing: 16) {
                    // 1. Body Ring
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("1. Body Ring — Physical Forge", systemImage: "figure.run")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(red: 0.9, green: 0.3, blue: 0.2))
                            Spacer()
                            Toggle("", isOn: $bodyClosed)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                        Text("Completed workout, cold plunge, or hit daily 10k physical baseline.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))

                    // 2. Mind Ring Reflection
                    VStack(alignment: .leading, spacing: 8) {
                        Label("2. Mind Ring — Reflection & Synthesis", systemImage: "brain.head.profile")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(red: 0.25, green: 0.45, blue: 0.95))

                        TextEditor(text: $mindReflectionText)
                            .font(.system(size: 12))
                            .frame(height: 75)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.black.opacity(0.3))
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.08), lineWidth: 1))
                            )

                        Text("What was your highest leverage output or realization today?")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Color.white.opacity(0.45))
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))

                    // 3. Silence Ring Attestation
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("3. Silence Ring — Focus & Off-Grid", systemImage: "speaker.slash.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
                            Spacer()
                            Text("\(Int(silenceAttestedMinutes)) mins")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
                        }

                        Slider(value: $silenceAttestedMinutes, in: 0...180, step: 15)
                            .tint(Color(red: 0.0, green: 0.85, blue: 1.0))

                        Text("Total deep work focus or deliberate offline silence logged today.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Color.white.opacity(0.45))
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))

                    // 4. Social-Free Tap
                    Toggle(isOn: $isSocialMediaFree) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Complete Social-Media Feed Fast")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.white)
                            Text("Zero infinite scroll feeds consumed today.")
                                .font(.system(size: 10.5))
                                .foregroundStyle(Color.white.opacity(0.5))
                        }
                    }
                    .toggleStyle(.checkbox)
                    .padding(10)
                }
                .padding(20)
            }

            Divider().opacity(0.12)

            // Save Action
            HStack {
                Button("Dismiss") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.white.opacity(0.5))

                Spacer()

                Button {
                    executeSaveCheckIn()
                } label: {
                    HStack(spacing: 6) {
                        if isSaving {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Seal Check-In")
                                .font(.system(size: 12, weight: .bold))
                        }
                    }
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .background(
                        Color(red: 0.0, green: 0.85, blue: 1.0),
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(Color(red: 0.06, green: 0.06, blue: 0.08))
        }
        .frame(width: 520, height: 560)
        .background(Color(red: 0.07, green: 0.07, blue: 0.09))
        .onAppear {
            loadTodayExistingValues()
        }
    }

    private func loadTodayExistingValues() {
        Task {
            if let day = try? await GhostEngine.shared.getOrCreateDayRecord(for: Date()) {
                await MainActor.run {
                    self.bodyClosed = day.bodyClosed
                    self.silenceAttestedMinutes = Double(max(30, day.silenceMinutesAttested))
                }
            }
        }
    }

    private func executeSaveCheckIn() {
        isSaving = true
        Haptics.notification(.success)

        Task {
            _ = try? await GhostEngine.shared.toggleRing(ring: .body, isClosed: bodyClosed)
            if !mindReflectionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                _ = try? await GhostEngine.shared.toggleRing(ring: .mind, isClosed: true)
            }
            _ = try? await GhostEngine.shared.recordAttestedSilenceMinutes(Int(silenceAttestedMinutes))

            await MainActor.run {
                isSaving = false
                onSaved?()
                dismiss()
            }
        }
    }
}
