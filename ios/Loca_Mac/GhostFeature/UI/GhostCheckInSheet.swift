import SwiftUI

/// Evening Ghost Reflection & Attestation Sheet.
/// Allows fast check-in for Body, Mind reflection note, and Silence attestation with zero social clutter.
/// Optionally creates a structured Markdown note in Plut0 Journal.
public struct GhostCheckInSheet: View {
    @Environment(\.dismiss) private var dismiss
    public var onSaved: (() -> Void)?

    @State private var bodyClosed: Bool = false
    @State private var mindReflectionText: String = ""
    @State private var silenceAttestedMinutes: Double = 45.0
    @State private var isSocialMediaFree: Bool = true
    @State private var exportToJournal: Bool = true
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
                            .foregroundStyle(DS.Theme.amber)
                        Text("EVENING GHOST CHECK-IN")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(DS.Theme.amber)
                            .tracking(1.2)
                    }
                    Text("Seal Today's Ring Closures")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(DS.Theme.textPrimary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plutoGlassCircle)
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Divider().opacity(0.12)

            ScrollView {
                VStack(spacing: 14) {
                    // 1. Body Ring
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("1. Body Ring — Physical Forge", systemImage: "figure.run")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(hex: "#E54D2E"))
                            Spacer()
                            Toggle("", isOn: $bodyClosed)
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .tint(Color(hex: "#E54D2E"))
                        }
                        Text("Completed workout, cold plunge, or hit daily 10k physical baseline.")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Theme.textTertiary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(DS.Theme.card)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Theme.border, lineWidth: 1))

                    // 2. Mind Ring Reflection
                    VStack(alignment: .leading, spacing: 8) {
                        Label("2. Mind Ring — Reflection & Synthesis", systemImage: "brain.head.profile")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(hex: "#3E63DD"))

                        TextEditor(text: $mindReflectionText)
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Theme.textPrimary)
                            .frame(height: 70)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(DS.Theme.surface)
                            )
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(DS.Theme.border, lineWidth: 1))

                        Text("What was your highest leverage output or realization today?")
                            .font(.system(size: 10.5))
                            .foregroundStyle(DS.Theme.textMuted)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(DS.Theme.card)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Theme.border, lineWidth: 1))

                    // 3. Silence Ring Attestation
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("3. Silence Ring — Focus & Off-Grid", systemImage: "speaker.slash.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(hex: "#0091FF"))
                            Spacer()
                            Text("\(Int(silenceAttestedMinutes)) mins")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(hex: "#0091FF"))
                        }

                        Slider(value: $silenceAttestedMinutes, in: 0...240, step: 15)
                            .tint(Color(hex: "#0091FF"))

                        Text("Unplugged deep work, no notifications or social feeds.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(DS.Theme.textMuted)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(DS.Theme.card)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Theme.border, lineWidth: 1))

                    // 4. Social-Free Fast & Notes Export Toggles
                    VStack(spacing: 8) {
                        Toggle(isOn: $isSocialMediaFree) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Complete Social-Media Feed Fast")
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundStyle(DS.Theme.textPrimary)
                                Text("Zero infinite scroll feeds consumed today.")
                                    .font(.system(size: 10))
                                    .foregroundStyle(DS.Theme.textTertiary)
                            }
                        }
                        .toggleStyle(.checkbox)

                        Divider().opacity(0.1)

                        Toggle(isOn: $exportToJournal) {
                            HStack(spacing: 6) {
                                Image(systemName: "book.pages.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(DS.Theme.amber)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Export Reflection Note to Journal")
                                        .font(.system(size: 11.5, weight: .semibold))
                                        .foregroundStyle(DS.Theme.textPrimary)
                                    Text("Creates a structured Markdown note in Notes & Journal.")
                                        .font(.system(size: 10))
                                        .foregroundStyle(DS.Theme.textTertiary)
                                }
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(DS.Theme.card)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Theme.border, lineWidth: 1))
                }
                .padding(20)
            }

            Divider().opacity(0.12)

            // Save Action
            HStack {
                Button("Dismiss") { dismiss() }
                    .buttonStyle(.plutoGlass)

                Spacer()

                Button {
                    executeSaveCheckIn()
                } label: {
                    HStack(spacing: 6) {
                        if isSaving {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "checkmark.seal.fill")
                            Text("Seal Check-In")
                                .font(.system(size: 12, weight: .bold))
                        }
                    }
                }
                .buttonStyle(.plutoGlassProminent(tint: DS.Theme.amber))
                .disabled(isSaving)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(DS.Theme.surface.opacity(0.6))
        }
        .frame(width: 520, height: 600)
        .plutoGlass(.regular, in: RoundedRectangle(cornerRadius: 16))
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
        Haptics.notify(.success)

        Task {
            _ = try? await GhostEngine.shared.toggleRing(ring: .body, isClosed: bodyClosed)
            if !mindReflectionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                _ = try? await GhostEngine.shared.toggleRing(ring: .mind, isClosed: true)
            }
            let updatedDay = try? await GhostEngine.shared.recordAttestedSilenceMinutes(Int(silenceAttestedMinutes))

            if exportToJournal, let day = updatedDay {
                let season = try? await GhostEngine.shared.fetchActiveSeason()
                let receipts = (try? await GhostEngine.shared.fetchReceipts(for: Date())) ?? []
                let rules = await GhostEngine.shared.fetchRules(for: season)

                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM-dd"
                let intentionKey = "ghost_morning_intention_" + fmt.string(from: Date())
                let intention = UserDefaults.standard.string(forKey: intentionKey) ?? ""

                _ = try? await GhostReflectionNoteBridge.createOrUpdateReflectionNote(
                    date: Date(),
                    dayRecord: day,
                    receipts: receipts,
                    rules: rules,
                    morningIntention: intention,
                    eveningReflection: mindReflectionText
                )
            }

            await MainActor.run {
                isSaving = false
                onSaved?()
                dismiss()
            }
        }
    }
}
