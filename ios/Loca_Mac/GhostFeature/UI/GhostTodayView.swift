import SwiftUI
import UniformTypeIdentifiers

/// Ghost Mode — Page 1: Today's Operations
/// Morning intention journal + flat tactical checklist + live ring bar + score
public struct GhostTodayView: View {

    let season: GhostSeason
    @Binding var todayRecord:    GhostDay?
    @Binding var protocolRules:  [GhostProtocolRule]
    @Binding var todayReceipts:  [GhostReceipt]
    @Binding var streakStatus:   GhostEngine.StreakStatus

    var onLogReceipt:    (GhostProtocolRule, GhostProofKind, Double, String?) -> Void
    var onToggleRing:    (GhostRing) -> Void
    var onAddCustomRule: () -> Void
    var onReload:        () -> Void

    @State private var intentionText:   String = ""
    @State private var hoveredRuleID:   String? = nil
    @State private var editingRule:     GhostProtocolRule? = nil
    @State private var showCheckIn:     Bool = false

    // Stepper state per rule
    @State private var stepperValues:   [String: Double] = [:]
    @State private var durationInputs:  [String: String] = [:]

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Morning Intention ────────────────────────────────
                morningIntentionPanel

                Divider()
                    .padding(.horizontal, 20)
                    .opacity(0.1)

                // ── Three Rings Status Bar ───────────────────────────
                ringsStatusBar
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                Divider()
                    .padding(.horizontal, 20)
                    .opacity(0.1)

                // ── Tactical Checklist ───────────────────────────────
                checklistHeader

                VStack(spacing: 2) {
                    ForEach(protocolRules.filter { $0.isEnabled }) { rule in
                        ruleRow(rule)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

                // Add Rule button
                addRuleButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                Divider()
                    .padding(.horizontal, 20)
                    .opacity(0.1)

                // ── Day Score + Evening Seal ─────────────────────────
                bottomBar
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
            }
        }
        .background(DS.Theme.canvas)
        .sheet(item: $editingRule) { rule in
            GhostRuleEditorSheet(existingRule: rule) { updated in
                Task { try? await GhostEngine.shared.saveCustomRule(updated); onReload() }
            } onDelete: { id in
                Task { try? await GhostEngine.shared.deleteCustomRule(id: id); onReload() }
            }
        }
        .sheet(isPresented: $showCheckIn) {
            GhostCheckInSheet { onReload() }
        }
        .onAppear { loadIntention() }
    }

    // MARK: - Morning Intention Panel

    private var morningIntentionPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DS.Theme.amber)
                Text("MORNING INTENTION")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.Theme.amber)
                    .tracking(1.5)
                Spacer()
                Text(formattedDate)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(DS.Theme.textTertiary)
            }

            TextEditor(text: $intentionText)
                .font(.system(size: 13, design: .serif))
                .foregroundStyle(DS.Theme.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 68, maxHeight: 90)
                .padding(10)
                .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(DS.Theme.border, lineWidth: 1)
                )
                .onChange(of: intentionText) { _, _ in saveIntention() }

            if intentionText.isEmpty {
                Text("Set your intention for today's arc...")
                    .font(.system(size: 12, design: .serif))
                    .foregroundStyle(DS.Theme.textMuted)
                    .padding(.horizontal, 14)
                    .padding(.top, -78)
                    .allowsHitTesting(false)
            }
        }
        .padding(20)
    }

    // MARK: - Rings Status Bar

    private var ringsStatusBar: some View {
        HStack(spacing: 10) {
            ringStatusPill(
                ring: .body,
                isClosed: todayRecord?.bodyClosed ?? false,
                color: Color(hex: "#E54D2E")
            )
            ringStatusPill(
                ring: .mind,
                isClosed: todayRecord?.mindClosed ?? false,
                color: Color(hex: "#3E63DD")
            )
            ringStatusPill(
                ring: .silence,
                isClosed: todayRecord?.silenceClosed ?? false,
                color: Color(hex: "#0091FF")
            )

            Spacer()

            // Ghost day indicator
            let isGhost = todayRecord?.ghostDay ?? false
            HStack(spacing: 5) {
                Image(systemName: isGhost ? "checkmark.seal.fill" : "seal")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isGhost ? DS.Theme.amber : DS.Theme.textMuted)
                Text(isGhost ? "GHOST DAY" : "UNSEALED")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(isGhost ? DS.Theme.amber : DS.Theme.textMuted)
                    .tracking(0.8)
            }
        }
    }

    private func ringStatusPill(ring: GhostRing, isClosed: Bool, color: Color) -> some View {
        Button { onToggleRing(ring) } label: {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(color.opacity(isClosed ? 0.4 : 0.2), lineWidth: 2)
                        .frame(width: 18, height: 18)
                    if isClosed {
                        Circle()
                            .fill(color)
                            .frame(width: 10, height: 10)
                    }
                }
                Text(ring.title.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(isClosed ? color : DS.Theme.textMuted)
                    .tracking(0.5)
                if isClosed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(color)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isClosed ? color.opacity(0.08) : DS.Theme.card,
                in: RoundedRectangle(cornerRadius: 20)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isClosed ? color.opacity(0.35) : DS.Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Checklist Header

    private var checklistHeader: some View {
        HStack {
            Text("PROTOCOL CHECKLIST")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.Theme.textTertiary)
                .tracking(1.5)
            Spacer()
            let done  = protocolRules.filter { isRuleDone($0) }.count
            let total = protocolRules.filter { $0.isEnabled }.count
            Text("\(done)/\(total)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(done == total && total > 0 ? DS.Theme.amber : DS.Theme.textTertiary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Rule Row

    private func ruleRow(_ rule: GhostProtocolRule) -> some View {
        let done    = isRuleDone(rule)
        let partial = partialProgress(rule)
        let ringColor: Color = {
            switch rule.ring {
            case .body:    return Color(hex: "#E54D2E")
            case .mind:    return Color(hex: "#3E63DD")
            case .silence: return Color(hex: "#0091FF")
            }
        }()

        return HStack(spacing: 10) {
            // Left ring accent bar
            Rectangle()
                .fill(done ? ringColor : ringColor.opacity(0.3))
                .frame(width: 3)
                .clipShape(Capsule())

            // Status circle
            ZStack {
                Circle()
                    .stroke(done ? ringColor : DS.Theme.border, lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(ringColor)
                } else if partial > 0 {
                    Circle()
                        .fill(ringColor.opacity(0.4))
                        .frame(width: 10, height: 10)
                }
            }

            // Icon
            Image(systemName: rule.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(done ? ringColor : DS.Theme.textTertiary)
                .frame(width: 18)

            // Title + target
            VStack(alignment: .leading, spacing: 1) {
                Text(rule.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(done ? DS.Theme.textPrimary : DS.Theme.textSecondary)
                    .strikethrough(done, color: DS.Theme.textTertiary)
                Text(targetDescription(rule))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(DS.Theme.textTertiary)
            }

            Spacer()

            // Inline proof control
            proofControl(rule, done: done, ringColor: ringColor)

            // Edit button for custom rules
            if rule.isCustom {
                Button {
                    editingRule = rule
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Theme.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(
            done
                ? ringColor.opacity(0.05)
                : (hoveredRuleID == rule.id ? DS.Theme.cardHover : DS.Theme.card),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(done ? ringColor.opacity(0.2) : DS.Theme.borderSubtle, lineWidth: 1)
        )
        .onHover { hoveredRuleID = $0 ? rule.id : nil }
    }

    @ViewBuilder
    private func proofControl(_ rule: GhostProtocolRule, done: Bool, ringColor: Color) -> some View {
        switch rule.proofKind {
        case .binary:
            Button {
                onLogReceipt(rule, .binary, done ? 0 : 1.0, nil)
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(done ? ringColor : DS.Theme.textMuted)
            }
            .buttonStyle(.plain)

        case .quantity:
            let current = currentValue(for: rule)
            HStack(spacing: 4) {
                Button {
                    if current > 0 { onLogReceipt(rule, .quantity, -1, nil) }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DS.Theme.textSecondary)
                        .frame(width: 22, height: 22)
                        .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)

                Text("\(Int(current))/\(Int(rule.targetValue))\(rule.unitLabel.isEmpty ? "" : " \(rule.unitLabel)")")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(done ? ringColor : DS.Theme.textSecondary)
                    .frame(minWidth: 50)

                Button {
                    onLogReceipt(rule, .quantity, 1, nil)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DS.Theme.textSecondary)
                        .frame(width: 22, height: 22)
                        .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }

        case .duration:
            let current = currentValue(for: rule)
            HStack(spacing: 4) {
                TextField("0", text: Binding(
                    get: { durationInputs[rule.id] ?? (current > 0 ? "\(Int(current))" : "") },
                    set: { durationInputs[rule.id] = $0 }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DS.Theme.textPrimary)
                .frame(width: 36)
                .multilineTextAlignment(.center)
                .padding(5)
                .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(DS.Theme.border, lineWidth: 1))

                Text("min")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(DS.Theme.textTertiary)

                Button("Log") {
                    let val = Double(durationInputs[rule.id] ?? "") ?? 0
                    if val > 0 {
                        onLogReceipt(rule, .duration, val, nil)
                        durationInputs[rule.id] = nil
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DS.Theme.amber)
            }

        case .artifact:
            Button {
                pickPhoto(for: rule)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: done ? "photo.fill.on.rectangle.fill" : "camera.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(done ? ringColor : DS.Theme.textMuted)
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(ringColor)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var addRuleButton: some View {
        Button { onAddCustomRule() } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                Text("Add Custom Rule")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(DS.Theme.textTertiary)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(DS.Theme.borderSubtle, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Theme.border, lineWidth: 1).opacity(0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 14) {
            // Score gauge
            VStack(alignment: .leading, spacing: 3) {
                Text("TODAY")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.Theme.textMuted)
                    .tracking(1.0)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(todayRecord?.score ?? 0)")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundStyle(DS.Theme.textPrimary)
                    Text("/ 100")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(DS.Theme.textTertiary)
                }
            }

            // Thin progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DS.Theme.border)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DS.Theme.amber)
                        .frame(width: geo.size.width * CGFloat(todayRecord?.score ?? 0) / 100.0)
                        .animation(.easeOut(duration: 0.4), value: todayRecord?.score)
                }
            }
            .frame(height: 4)

            Spacer()

            Button {
                showCheckIn = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Evening Seal")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(DS.Theme.canvas)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(DS.Theme.amber, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: Date()).uppercased()
    }

    private func isRuleDone(_ rule: GhostProtocolRule) -> Bool {
        let matching = todayReceipts.filter { $0.ruleID == rule.id }
        let total    = matching.reduce(0.0) { $0 + $1.valueReal }
        return total >= rule.targetValue
    }

    private func partialProgress(_ rule: GhostProtocolRule) -> Double {
        let matching = todayReceipts.filter { $0.ruleID == rule.id }
        return matching.reduce(0.0) { $0 + $1.valueReal }
    }

    private func currentValue(for rule: GhostProtocolRule) -> Double {
        todayReceipts.filter { $0.ruleID == rule.id }.reduce(0.0) { $0 + $1.valueReal }
    }

    private func targetDescription(_ rule: GhostProtocolRule) -> String {
        switch rule.proofKind {
        case .binary:   return "Complete"
        case .quantity: return "\(Int(rule.targetValue)) \(rule.unitLabel)"
        case .duration: return "\(Int(rule.targetValue)) min"
        case .artifact: return "Photo proof"
        }
    }

    private func pickPhoto(for rule: GhostProtocolRule) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .png, .jpeg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let path = url.path
                onLogReceipt(rule, .artifact, 1.0, path)
            }
        }
    }

    private let intentionKey: String = "ghost_morning_intention_"

    private func intentionStorageKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return intentionKey + f.string(from: Date())
    }

    private func loadIntention() {
        intentionText = UserDefaults.standard.string(forKey: intentionStorageKey()) ?? ""
    }

    private func saveIntention() {
        UserDefaults.standard.set(intentionText, forKey: intentionStorageKey())
    }
}
