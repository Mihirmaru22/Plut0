import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Daily Protocol Board for executing and verifying Ghost Season rules with authentic proof receipts.
/// Organized by Morning Forge, Day Grind, and Night Seal.
public struct GhostProtocolBoardView: View {
    public let rules: [GhostProtocolRule]
    public let receipts: [GhostReceipt]
    public var onLogReceipt: (GhostProtocolRule, GhostProofKind, Double, String?) -> Void

    @State private var hoveredRuleID: String? = nil

    public init(
        rules: [GhostProtocolRule],
        receipts: [GhostReceipt],
        onLogReceipt: @escaping (GhostProtocolRule, GhostProofKind, Double, String?) -> Void
    ) {
        self.rules = rules
        self.receipts = receipts
        self.onLogReceipt = onLogReceipt
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "checklist.checked")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
                        Text("Daily Protocol Board")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    Text("Proof of Discipline")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)
                }

                Spacer()

                let completedCount = rules.filter { isRuleCompleted($0) }.count
                Text("\(completedCount)/\(rules.count) Sealed")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(completedCount == rules.count ? Color(red: 0.0, green: 0.85, blue: 1.0) : Color.white.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
            }

            // Phase Columns / Sections
            VStack(spacing: 14) {
                ForEach(GhostProtocolPhase.allCases) { phase in
                    let phaseRules = rules.filter { $0.phase == phase }
                    if !phaseRules.isEmpty {
                        phaseSection(phase: phase, rules: phaseRules)
                    }
                }
            }
        }
        .padding(16)
        .plutoGlass(.regular, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Phase Section

    private func phaseSection(phase: GhostProtocolPhase, rules: [GhostProtocolRule]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: phase.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(phaseAccentColor(phase))
                Text(phase.title)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            .padding(.leading, 2)

            VStack(spacing: 6) {
                ForEach(rules) { rule in
                    protocolRow(rule: rule)
                }
            }
        }
    }

    private func toggleRule(_ rule: GhostProtocolRule) {
        if rule.proofKind == .artifact {
            pickPhotoForArtifact(rule: rule)
            return
        }
        let isDone = isRuleCompleted(rule)
        let newVal: Double = isDone ? 0.0 : max(1.0, rule.targetValue)
        Haptics.impact(.medium)
        if !isDone {
            PlutoSoundEngine.shared.play(.checkmark)
        } else {
            PlutoSoundEngine.shared.play(.tabSwitch)
        }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
            onLogReceipt(rule, rule.proofKind, newVal, nil)
        }
    }

    private func protocolRow(rule: GhostProtocolRule) -> some View {
        let isDone = isRuleCompleted(rule)
        let currentVal = currentRuleValue(rule)
        let isHovered = hoveredRuleID == rule.id
        let ringColor = Color(hex: rule.ring.accentHex) ?? Color.white

        return HStack(spacing: 12) {
            // Icon & Ring Indicator Button (Instant 1-tap checkout)
            Button {
                toggleRule(rule)
            } label: {
                ZStack {
                    Circle()
                        .stroke(isDone ? Color.white.opacity(0.8) : Color.white.opacity(0.20), lineWidth: 1.5)
                        .frame(width: 24, height: 24)

                    if isDone {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 19, height: 19)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9.5, weight: .black))
                            .foregroundStyle(Color.black)
                            .symbolEffect(.bounce, value: isDone)
                    } else {
                        Image(systemName: rule.icon)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(isDone ? "Mark Incomplete" : "Mark Complete")

            // Title & Subtitle
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(rule.title)
                        .font(.system(size: 12.5, weight: isDone ? .bold : .medium))
                        .foregroundStyle(isDone ? Color.white : Color.white.opacity(0.85))
                        .strikethrough(isDone, color: Color.white.opacity(0.4))

                    if rule.isOutdoorRequired {
                        Text("OUTDOOR")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(Color.white.opacity(0.8))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 3))
                    }
                }

                Text(rule.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                toggleRule(rule)
            }

            Spacer()

            // Proof Control by Kind (Photo proof or clean status badge)
            proofControl(for: rule, currentValue: currentVal, isDone: isDone, ringColor: ringColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? DS.Theme.cardHover : DS.Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isDone ? Color.white.opacity(0.15) : DS.Theme.borderSubtle, lineWidth: 1)
                )
        )
        .onHover { h in hoveredRuleID = h ? rule.id : nil }
    }

    // MARK: - Proof Controls

    @ViewBuilder
    private func proofControl(for rule: GhostProtocolRule, currentValue: Double, isDone: Bool, ringColor: Color) -> some View {
        switch rule.proofKind {
        case .binary:
            EmptyView()

        case .quantity:
            HStack(spacing: 6) {
                Text("\(Int(currentValue))/\(Int(rule.targetValue)) \(rule.unitLabel)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(isDone ? ringColor : Color.white.opacity(0.6))
                    .contentTransition(.numericText())

                HStack(spacing: 3) {
                    Button {
                        Haptics.impact(.light)
                        let next = max(0.0, currentValue - 1.0)
                        onLogReceipt(rule, .quantity, next, nil)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .frame(width: 18, height: 18)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)

                    Button {
                        Haptics.impact(.light)
                        let next = currentValue + 1.0
                        onLogReceipt(rule, .quantity, next, nil)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .frame(width: 18, height: 18)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
            }

        case .duration:
            HStack(spacing: 6) {
                Text("\(Int(currentValue))/\(Int(rule.targetValue)) min")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(isDone ? ringColor : Color.white.opacity(0.6))
                    .contentTransition(.numericText())
            }

        case .artifact:
            HStack(spacing: 6) {
                if let photoReceipt = receipts.first(where: { $0.ruleID == rule.id && $0.photoPath != nil }) {
                    HStack(spacing: 4) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 10.5, weight: .bold))
                        Text("Photo Logged")
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .black))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(ringColor)
                    .background(ringColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                } else {
                    Button {
                        pickPhotoForArtifact(rule: rule)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 10))
                            Text("Attach Photo")
                                .font(.system(size: 10.5, weight: .bold))
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(
                        PlutoGlassButtonStyle(
                            shape: RoundedRectangle(cornerRadius: 6, style: .continuous),
                            tint: ringColor.opacity(0.3),
                            isProminent: false
                        )
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func isRuleCompleted(_ rule: GhostProtocolRule) -> Bool {
        let matching = receipts.filter { $0.ruleID == rule.id }
        let total = matching.reduce(0.0) { $0 + $1.valueReal }
        return total >= rule.targetValue
    }

    private func currentRuleValue(_ rule: GhostProtocolRule) -> Double {
        let matching = receipts.filter { $0.ruleID == rule.id }
        return matching.reduce(0.0) { $0 + $1.valueReal }
    }

    private func phaseAccentColor(_ phase: GhostProtocolPhase) -> Color {
        switch phase {
        case .morning: return Color.orange
        case .day:     return Color.yellow
        case .night:   return Color(red: 0.25, green: 0.45, blue: 0.95)
        }
    }

    private func pickPhotoForArtifact(rule: GhostProtocolRule) {
        let panel = NSOpenPanel()
        panel.title = "Select Daily Progress Photo"
        panel.allowedContentTypes = [.image, .png, .jpeg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        panel.begin { response in
            if response == .OK, let url = panel.url {
                saveArtifactPhotoLocally(sourceURL: url, rule: rule)
            }
        }
    }

    private func saveArtifactPhotoLocally(sourceURL: URL, rule: GhostProtocolRule) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let photosDir = appSupport.appendingPathComponent("Pluto/GhostPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)

        let targetFilename = "\(UUID().uuidString)_\(sourceURL.lastPathComponent)"
        let targetURL = photosDir.appendingPathComponent(targetFilename)

        try? FileManager.default.copyItem(at: sourceURL, to: targetURL)
        Haptics.notification(.success)
        onLogReceipt(rule, .artifact, 1.0, targetURL.path)
    }
}
