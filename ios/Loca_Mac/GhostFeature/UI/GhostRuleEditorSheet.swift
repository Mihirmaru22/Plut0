import SwiftUI
import UniformTypeIdentifiers

/// Modal sheet for creating or editing a custom Ghost protocol rule.
/// Lets users assign ring, proof type, target, icon, and unit label.
public struct GhostRuleEditorSheet: View {

    public var existingRule: GhostProtocolRule?
    public var onSave: (GhostProtocolRule) -> Void
    public var onDelete: ((String) -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var title:        String = ""
    @State private var subtitle:     String = ""
    @State private var ring:         GhostRing = .body
    @State private var phase:        GhostProtocolPhase = .day
    @State private var proofKind:    GhostProofKind = .binary
    @State private var targetValue:  Double = 1.0
    @State private var unitLabel:    String = ""
    @State private var selectedIcon: String = "star.fill"
    @State private var isEnabled:    Bool = true
    @State private var showDeleteConfirm: Bool = false

    private let curatedIcons: [String] = [
        "figure.run", "dumbbell.fill", "fork.knife", "drop.fill", "book.fill",
        "pencil.line", "moon.stars.fill", "sun.max.fill", "brain.head.profile",
        "speaker.slash.fill", "camera.fill", "heart.fill", "bolt.fill",
        "leaf.fill", "flame.fill", "trophy.fill", "star.fill", "checkmark.seal.fill",
        "timer", "stopwatch.fill", "bed.double.fill", "applewatch", "music.note.list",
        "map.fill", "mountain.2.fill", "bicycle", "figure.walk", "pills.fill",
        "note.text", "eye.fill"
    ]

    public init(
        existingRule: GhostProtocolRule? = nil,
        onSave: @escaping (GhostProtocolRule) -> Void,
        onDelete: ((String) -> Void)? = nil
    ) {
        self.existingRule = existingRule
        self.onSave  = onSave
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(existingRule == nil ? "NEW RULE" : "EDIT RULE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.Theme.amber)
                        .tracking(1.5)
                    Text(existingRule == nil ? "Create custom protocol rule" : "Modify rule configuration")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.Theme.textPrimary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(DS.Theme.textSecondary)
                    .font(.system(size: 12))

                Button("Save Rule") { saveRule() }
                    .buttonStyle(.plain)
                    .foregroundStyle(title.isEmpty ? DS.Theme.textTertiary : DS.Theme.amber)
                    .font(.system(size: 12, weight: .bold))
                    .disabled(title.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider().opacity(0.12)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Title + Subtitle
                    Group {
                        fieldLabel("Rule Name")
                        TextField("e.g. Cold Shower, Evening Walk...", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .foregroundStyle(DS.Theme.textPrimary)
                            .padding(10)
                            .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Theme.border, lineWidth: 1))

                        fieldLabel("Description (optional)")
                        TextField("Brief explanation of the rule", text: $subtitle)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Theme.textSecondary)
                            .padding(10)
                            .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Theme.border, lineWidth: 1))
                    }

                    // Ring + Phase
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel("Ring")
                            ringPicker
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel("Phase")
                            phasePicker
                        }
                    }

                    // Proof Type + Target
                    VStack(alignment: .leading, spacing: 6) {
                        fieldLabel("Proof Type")
                        proofTypePicker
                    }

                    if proofKind != .binary && proofKind != .artifact {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                fieldLabel("Target")
                                HStack {
                                    Button { if targetValue > 1 { targetValue -= 1 } } label: {
                                        Image(systemName: "minus")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(DS.Theme.textSecondary)
                                    }
                                    .buttonStyle(.plain)
                                    .frame(width: 28, height: 28)
                                    .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 6))

                                    Text(targetValue.truncatingRemainder(dividingBy: 1) == 0
                                         ? "\(Int(targetValue))" : String(format: "%.1f", targetValue))
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        .foregroundStyle(DS.Theme.textPrimary)
                                        .frame(minWidth: 40)

                                    Button { targetValue += 1 } label: {
                                        Image(systemName: "plus")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(DS.Theme.textSecondary)
                                    }
                                    .buttonStyle(.plain)
                                    .frame(width: 28, height: 28)
                                    .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 6))
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                fieldLabel("Unit")
                                TextField(proofKind == .duration ? "mins" : "reps", text: $unitLabel)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(DS.Theme.textPrimary)
                                    .frame(width: 80)
                                    .padding(8)
                                    .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Theme.border, lineWidth: 1))
                            }
                        }
                    }

                    // Icon Picker
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Icon")
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(36)), count: 10), spacing: 8) {
                            ForEach(curatedIcons, id: \.self) { iconName in
                                Button {
                                    selectedIcon = iconName
                                } label: {
                                    Image(systemName: iconName)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(selectedIcon == iconName ? DS.Theme.amber : DS.Theme.textSecondary)
                                        .frame(width: 32, height: 32)
                                        .background(
                                            selectedIcon == iconName
                                                ? DS.Theme.amber.opacity(0.15)
                                                : DS.Theme.card
                                            , in: RoundedRectangle(cornerRadius: 6)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(selectedIcon == iconName ? DS.Theme.amber.opacity(0.4) : DS.Theme.border, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Enabled toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rule Active")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(DS.Theme.textPrimary)
                            Text("Disabled rules are hidden from the daily checklist")
                                .font(.system(size: 10))
                                .foregroundStyle(DS.Theme.textTertiary)
                        }
                        Spacer()
                        Toggle("", isOn: $isEnabled)
                            .labelsHidden()
                            .tint(DS.Theme.amber)
                    }
                    .padding(12)
                    .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Theme.border, lineWidth: 1))

                    // Delete button (only for existing custom rules)
                    if let rule = existingRule, rule.isCustom, let onDelete = onDelete {
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                Text("Delete Rule")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DS.Theme.coral)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(DS.Theme.coral.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Theme.coral.opacity(0.25), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .alert("Delete Rule", isPresented: $showDeleteConfirm) {
                            Button("Delete", role: .destructive) { onDelete(rule.id); dismiss() }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("This rule and all its receipts will be permanently removed.")
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 460, height: 640)
        .background(DS.Theme.surface)
        .onAppear { populateFromExisting() }
    }

    // MARK: - Sub-pickers

    private var ringPicker: some View {
        HStack(spacing: 6) {
            ForEach(GhostRing.allCases) { r in
                Button {
                    ring = r
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(ringColor(r))
                            .frame(width: 6, height: 6)
                        Text(r.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ring == r ? DS.Theme.textPrimary : DS.Theme.textTertiary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        ring == r ? ringColor(r).opacity(0.15) : DS.Theme.card,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(ring == r ? ringColor(r).opacity(0.4) : DS.Theme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var phasePicker: some View {
        HStack(spacing: 6) {
            ForEach(GhostProtocolPhase.allCases) { p in
                Button {
                    phase = p
                } label: {
                    Text(p.title.components(separatedBy: " ").first ?? p.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(phase == p ? DS.Theme.textPrimary : DS.Theme.textTertiary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            phase == p ? DS.Theme.amber.opacity(0.12) : DS.Theme.card,
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(phase == p ? DS.Theme.amber.opacity(0.4) : DS.Theme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var proofTypePicker: some View {
        HStack(spacing: 6) {
            proofOption(.binary,   "Checkbox", "checkmark.circle.fill")
            proofOption(.quantity, "Counter",  "number")
            proofOption(.duration, "Timer",    "timer")
            proofOption(.artifact, "Photo",    "camera.fill")
        }
    }

    private func proofOption(_ kind: GhostProofKind, _ label: String, _ icon: String) -> some View {
        Button { proofKind = kind } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(proofKind == kind ? DS.Theme.amber : DS.Theme.textTertiary)
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(proofKind == kind ? DS.Theme.textPrimary : DS.Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                proofKind == kind ? DS.Theme.amber.opacity(0.12) : DS.Theme.card,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(proofKind == kind ? DS.Theme.amber.opacity(0.4) : DS.Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(DS.Theme.textTertiary)
            .tracking(1.0)
    }

    private func ringColor(_ r: GhostRing) -> Color {
        switch r {
        case .body:    return Color(hex: "#E54D2E")
        case .mind:    return Color(hex: "#3E63DD")
        case .silence: return Color(hex: "#0091FF")
        }
    }

    // MARK: - Helpers

    private func populateFromExisting() {
        guard let rule = existingRule else { return }
        title        = rule.title
        subtitle     = rule.subtitle
        ring         = rule.ring
        phase        = rule.phase
        proofKind    = rule.proofKind
        targetValue  = rule.targetValue
        unitLabel    = rule.unitLabel
        selectedIcon = rule.icon
        isEnabled    = rule.isEnabled
    }

    private func saveRule() {
        let id = existingRule?.id ?? UUID().uuidString
        let rule = GhostProtocolRule(
            id:               id,
            title:            title.trimmingCharacters(in: .whitespaces),
            subtitle:         subtitle.trimmingCharacters(in: .whitespaces),
            ring:             ring,
            phase:            phase,
            proofKind:        proofKind,
            targetValue:      max(1, targetValue),
            unitLabel:        unitLabel.trimmingCharacters(in: .whitespaces),
            icon:             selectedIcon,
            isOutdoorRequired: false,
            isCustom:         true,
            isEnabled:        isEnabled,
            sortOrder:        existingRule?.sortOrder ?? 999
        )
        onSave(rule)
        dismiss()
    }
}
