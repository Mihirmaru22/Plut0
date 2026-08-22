import SwiftUI

/// Onboarding & Contract Covenant flow for initiating a new Ghost Season / Winter Arc.
/// Designed for high intentionality with template picker, doctrine toggle, and digital signature moment.
public struct ContractOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    public var onContractSigned: ((GhostSeason) -> Void)?

    @State private var selectedProtocol: GhostProtocolKind = .the120
    @State private var selectedDoctrine: GhostDoctrine = .hard
    @State private var seasonName: String = "The Winter Arc 2026"
    @State private var signatureName: String = ""
    @State private var isSigning: Bool = false
    @State private var hasAgreedToTerms: Bool = false

    public init(onContractSigned: ((GhostSeason) -> Void)? = nil) {
        self.onContractSigned = onContractSigned
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
                        Text("SOVEREIGN GHOST COVENANT")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .tracking(1.5)
                    }
                    Text("Enter the Winter Arc")
                        .font(.system(size: 20, weight: .bold))
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
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()
                .opacity(0.12)

            ScrollView {
                VStack(spacing: 20) {
                    // Protocol Template Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. SELECT PROTOCOL ARCHITECTURE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .tracking(1.0)

                        VStack(spacing: 8) {
                            ForEach(GhostProtocolKind.allCases) { proto in
                                protocolCard(proto)
                            }
                        }
                    }

                    // Doctrine Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("2. SELECT GOVERNING DOCTRINE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .tracking(1.0)

                        HStack(spacing: 12) {
                            ForEach(GhostDoctrine.allCases) { doc in
                                doctrineCard(doc)
                            }
                        }
                    }

                    // Three Rings Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("3. THE THREE GHOST RINGS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .tracking(1.0)

                        HStack(spacing: 10) {
                            ringPreviewCard(
                                ring: .body,
                                label: "Body Ring",
                                detail: "Daily physical forge (Workout / 10k steps / Cold plunge)"
                            )
                            ringPreviewCard(
                                ring: .mind,
                                label: "Mind Ring",
                                detail: "Mental synthesis (Reading 10p / Evening reflection)"
                            )
                            ringPreviewCard(
                                ring: .silence,
                                label: "Silence Ring",
                                detail: "45m deep focus silence or complete offline dark mode"
                            )
                        }
                    }

                    // Signature Moment
                    VStack(alignment: .leading, spacing: 10) {
                        Text("4. DIGITAL SIGNATURE & COVENANT")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .tracking(1.0)

                        VStack(spacing: 12) {
                            TextField("Enter your full legal name or sovereign callsign…", text: $signatureName)
                                .font(.system(size: 13, design: .serif))
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.04))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                )

                            Toggle(isOn: $hasAgreedToTerms) {
                                Text("I commit to the silence, physical rigor, and daily closure for the full duration of this season.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.white.opacity(0.7))
                            }
                            .toggleStyle(.checkbox)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red: 0.08, green: 0.08, blue: 0.11))
                        )
                    }
                }
                .padding(24)
            }

            Divider()
                .opacity(0.12)

            // Bottom Action Bar
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white.opacity(0.6))

                Spacer()

                Button {
                    executeSignContract()
                } label: {
                    HStack(spacing: 6) {
                        if isSigning {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "seal.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("Seal Contract & Enter Silence")
                                .font(.system(size: 12, weight: .bold))
                        }
                    }
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(
                        canSign
                            ? LinearGradient(
                                colors: [Color(red: 0.0, green: 0.85, blue: 1.0), Color(red: 0.0, green: 0.65, blue: 0.95)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : LinearGradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.1)], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 7)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canSign || isSigning)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(red: 0.06, green: 0.06, blue: 0.08))
        }
        .frame(width: 680, height: 640)
        .background(Color(red: 0.05, green: 0.05, blue: 0.07))
    }

    private var canSign: Bool {
        !signatureName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hasAgreedToTerms
    }

    private func protocolCard(_ proto: GhostProtocolKind) -> some View {
        let isSelected = (selectedProtocol == proto)
        return Button {
            selectedProtocol = proto
            if proto == .the120 {
                seasonName = "The Winter Arc 2026"
            } else if proto == .seventyFiveHard {
                seasonName = "75 Hard Season"
            } else {
                seasonName = "Custom Ghost Arc"
            }
            Haptics.selection()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isSelected ? Color(red: 0.0, green: 0.85, blue: 1.0) : Color.white.opacity(0.3))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(proto.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.white)
                        Text("(\(proto.durationDays) Days)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
                    }
                    Text(proto.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.6))
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.08) : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func doctrineCard(_ doc: GhostDoctrine) -> some View {
        let isSelected = (selectedDoctrine == doc)
        return Button {
            selectedDoctrine = doc
            Haptics.selection()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(doc.title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color(red: 0.0, green: 0.85, blue: 1.0) : Color.white.opacity(0.3))
                }

                Text(doc.ruleDescription)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .lineLimit(3)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.08) : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func ringPreviewCard(ring: GhostRing, label: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: ring.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: ring.accentHex) ?? Color.white)
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white)
            }
            Text(detail)
                .font(.system(size: 10))
                .foregroundStyle(Color.white.opacity(0.55))
                .lineLimit(3)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 75, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 1))
        )
    }

    private func executeSignContract() {
        guard canSign else { return }
        isSigning = true
        Haptics.notification(.success)

        Task {
            do {
                let season = try await GhostEngine.shared.signContract(
                    name: seasonName,
                    protocolKind: selectedProtocol,
                    doctrine: selectedDoctrine
                )
                await MainActor.run {
                    isSigning = false
                    onContractSigned?(season)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSigning = false
                }
            }
        }
    }
}
