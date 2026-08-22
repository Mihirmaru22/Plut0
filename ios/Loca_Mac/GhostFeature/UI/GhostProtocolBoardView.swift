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
                        Text("DAILY PROTOCOL BOARD")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .tracking(1.2)
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
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.06, green: 0.06, blue: 0.08))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    // MARK: - Phase Section

    private func phaseSection(phase: GhostProtocolPhase, rules: [GhostProtocolRule]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: phase.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(phaseAccentColor(phase))
                Text(phase.title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .tracking(1.0)
            }
            .padding(.leading, 2)

            VStack(spacing: 6) {
                ForEach(rules) { rule in
                    protocolRow(rule: rule)
                }
            }
        }
    }

    // MARK: - Protocol Row

    private func protocolRow(rule: GhostProtocolRule) -> some View {
        let isDone = isRuleCompleted(rule)
        let currentVal = currentRuleValue(rule)
        let isHovered = hoveredRuleID == rule.id

        return HStack(spacing: 12) {
            // Icon & Ring Indicator
            ZStack {
                Circle()
                    .fill(isDone ? (Color(hex: rule.ring.accentHex) ?? Color.white).opacity(0.2) : Color.white.opacity(0.04))
                    .frame(width: 32, height: 32)

                Image(systemName: isDone ? "checkmark" : rule.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isDone ? (Color(hex: rule.ring.accentHex) ?? Color.white) : Color.white.opacity(0.5))
            }

            // Title & Subtitle
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(rule.title)
                        .font(.system(size: 12.5, weight: isDone ? .bold : .medium))
                        .foregroundStyle(isDone ? Color.white : Color.white.opacity(0.85))

                    if rule.isOutdoorRequired {
                        Text("OUTDOOR")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(Color.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
                    }
                }

                Text(rule.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer()

            // Proof Control by Kind
            proofControl(for: rule, currentValue: currentVal, isDone: isDone)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isDone ? Color.white.opacity(0.04) : (isHovered ? Color.white.opacity(0.02) : Color.clear))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isDone ? (Color(hex: rule.ring.accentHex) ?? Color.white).opacity(0.25) : Color.white.opacity(0.04), lineWidth: 1)
                )
        )
        .onHover { h in hoveredRuleID = h ? rule.id : nil }
    }

    // MARK: - Proof Controls

    @ViewBuilder
    private func proofControl(for rule: GhostProtocolRule, currentValue: Double, isDone: Bool) -> some View {
        switch rule.proofKind {
        case .binary:
            Button {
                Haptics.impact(.medium)
                let newVal = isDone ? 0.0 : 1.0
                onLogReceipt(rule, .binary, newVal, nil)
            } label: {
                Image(systemName: isDone ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isDone ? (Color(hex: rule.ring.accentHex) ?? Color(red: 0.0, green: 0.85, blue: 1.0)) : Color.white.opacity(0.3))
            }
            .buttonStyle(.plain)

        case .quantity:
            HStack(spacing: 8) {
                Text("\(Int(currentValue))/\(Int(rule.targetValue)) \(rule.unitLabel)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isDone ? Color(red: 0.0, green: 0.85, blue: 1.0) : Color.white.opacity(0.6))

                HStack(spacing: 2) {
                    Button {
                        Haptics.impact(.light)
                        let next = max(0.0, currentValue - 1.0)
                        onLogReceipt(rule, .quantity, next, nil)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 9, weight: .bold))
                            .frame(width: 20, height: 20)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)

                    Button {
                        Haptics.impact(.light)
                        let next = min(rule.targetValue * 2, currentValue + 1.0)
                        onLogReceipt(rule, .quantity, next, nil)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                            .frame(width: 20, height: 20)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
            }

        case .duration:
            HStack(spacing: 6) {
                Text("\(Int(currentValue))m")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isDone ? Color(red: 0.0, green: 0.85, blue: 1.0) : Color.white.opacity(0.6))

                Button("+15m") {
                    Haptics.impact(.light)
                    onLogReceipt(rule, .duration, currentValue + 15.0, nil)
                }
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .buttonStyle(.plain)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))

                Button("+45m") {
                    Haptics.impact(.medium)
                    onLogReceipt(rule, .duration, currentValue + 45.0, nil)
                }
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .buttonStyle(.plain)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
            }

        case .artifact:
            HStack(spacing: 6) {
                if let photoReceipt = receipts.first(where: { $0.ruleID == rule.id && $0.photoPath != nil }) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
                    Text("Sealed")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
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
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
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
