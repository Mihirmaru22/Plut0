import SwiftUI

/// Executive Sovereign Ghost Covenant Studio.
/// 2-Column High-Clarity Architecture:
/// - Left: Precision configuration of Protocol, Doctrine, and the 3 Core Ghost Rings (Mind, Body, Silence).
/// - Right: Live Daily Protocol Blueprint, Calendar Window, Callsign Signature, and Seal Action.
public struct ContractOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    public var onContractSigned: ((GhostSeason) -> Void)?

    // MARK: - Core Protocol & Doctrine
    @State private var selectedProtocol: GhostProtocolKind = .the120
    @State private var customDurationDays: Int = 90
    @State private var selectedDoctrine: GhostDoctrine = .hard
    @State private var seasonName: String = "The Winter Arc 2026"

    // MARK: - Core 3 Rings State (Ultra-Clean Defaults)
    // 1. Mind Ring
    @State private var readingPages: Int = 10
    @State private var includeEveningSynthesis: Bool = true

    // 2. Body Ring
    @State private var workoutMinutes: Int = 45
    @State private var isOutdoorWorkoutRequired: Bool = false
    @State private var includeSecondWorkout: Bool = false
    @State private var includeWaterTarget: Bool = false
    @State private var waterTargetGlasses: Int = 8

    // 3. Silence Ring
    @State private var deepFocusMinutes: Int = 45
    @State private var includeSocialMediaFast: Bool = true

    // 4. Optional Add-On Disciplines (Collapsed by default)
    @State private var showOptionalAddOns: Bool = false
    @State private var include10kSteps: Bool = false
    @State private var includeStrictDiet: Bool = false
    @State private var includeDailyPhoto: Bool = false
    @State private var includeOfflineSleepMode: Bool = false

    // MARK: - Legal / Covenant Authorization State
    @State private var signatureName: String = ""
    @State private var isSigning: Bool = false
    @State private var hasAgreedToTerms: Bool = false

    public init(onContractSigned: ((GhostSeason) -> Void)? = nil) {
        self.onContractSigned = onContractSigned
    }

    private var activeDurationDays: Int {
        switch selectedProtocol {
        case .the120:          return 120
        case .seventyFiveHard: return 75
        case .custom:          return customDurationDays
        }
    }

    private var startDate: Date {
        Date()
    }

    private var endDate: Date {
        Calendar.current.date(byAdding: .day, value: activeDurationDays, to: Date()) ?? Date()
    }

    private var durationMonthsText: String {
        let months = max(1, activeDurationDays / 30)
        return "\(activeDurationDays) Days (\(months) Months)"
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            Divider().opacity(0.12)

            // 2-Column Split Studio
            HStack(alignment: .top, spacing: 0) {

                // LEFT COLUMN: Controls & Ring Dials
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {

                        // 1. Protocol Selection (Clean 3-Segment Picker)
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("1. PROTOCOL ARCHITECTURE")

                            HStack(spacing: 8) {
                                ForEach(GhostProtocolKind.allCases) { proto in
                                    let isSelected = selectedProtocol == proto
                                    Button {
                                        selectedProtocol = proto
                                        applyProtocolPresetDefaults(proto)
                                        Haptics.selection()
                                    } label: {
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack {
                                                Text(proto.title)
                                                    .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                                                    .foregroundStyle(isSelected ? Color.white : DS.Theme.textPrimary)
                                                Spacer()
                                                Text("\(proto.durationDays)d")
                                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                    .foregroundStyle(isSelected ? DS.Theme.amber : DS.Theme.textTertiary)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(
                                            isSelected ? DS.Theme.amber.opacity(0.15) : Color.white.opacity(0.04),
                                            in: RoundedRectangle(cornerRadius: 6)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(isSelected ? DS.Theme.amber.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            if selectedProtocol == .custom {
                                customDurationRow
                            }
                        }

                        // 2. Governing Doctrine
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("2. GOVERNING DOCTRINE")

                            HStack(spacing: 8) {
                                ForEach(GhostDoctrine.allCases) { doc in
                                    let isSelected = selectedDoctrine == doc
                                    Button {
                                        selectedDoctrine = doc
                                        Haptics.selection()
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(isSelected ? DS.Theme.amber : DS.Theme.textMuted)

                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(doc.title)
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundStyle(Color.white)
                                                Text(doc == .hard ? "Missed day resets streak to 0" : "Missed day creates elevation dent")
                                                    .font(.system(size: 9.5))
                                                    .foregroundStyle(DS.Theme.textTertiary)
                                            }
                                            Spacer()
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(
                                            isSelected ? DS.Theme.amber.opacity(0.10) : Color.white.opacity(0.03),
                                            in: RoundedRectangle(cornerRadius: 6)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(isSelected ? DS.Theme.amber.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Divider().opacity(0.08)

                        // 3. The 3 Core Ghost Rings (Compact & Direct)
                        VStack(alignment: .leading, spacing: 12) {
                            sectionLabel("3. THE THREE CORE GHOST RINGS")

                            // Mind Ring Row
                            ringCard(
                                ring: .mind,
                                color: Color(hex: "#3E63DD"),
                                title: "Mind Ring — Mental Synthesis"
                            ) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Text("Daily Reading:")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(DS.Theme.textSecondary)

                                        ForEach([5, 10, 15, 20, 30], id: \.self) { pages in
                                            choiceChip(label: "\(pages)p", isSelected: readingPages == pages) {
                                                readingPages = pages
                                            }
                                        }
                                    }

                                    Toggle(isOn: $includeEveningSynthesis) {
                                        Text("Evening Synthesis Note (Seal 1 insight nightly)")
                                            .font(.system(size: 10.5))
                                            .foregroundStyle(DS.Theme.textPrimary)
                                    }
                                    .toggleStyle(.checkbox)
                                }
                            }

                            // Body Ring Row
                            ringCard(
                                ring: .body,
                                color: Color(hex: "#E54D2E"),
                                title: "Body Ring — Physical Forge"
                            ) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Text("Workout Duration:")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(DS.Theme.textSecondary)

                                        ForEach([30, 45, 60, 90], id: \.self) { mins in
                                            choiceChip(label: "\(mins)m", isSelected: workoutMinutes == mins) {
                                                workoutMinutes = mins
                                            }
                                        }
                                    }

                                    HStack(spacing: 16) {
                                        Toggle(isOn: $includeWaterTarget) {
                                            Text("1 Gallon (3L) Water")
                                                .font(.system(size: 10.5))
                                                .foregroundStyle(DS.Theme.textPrimary)
                                        }
                                        .toggleStyle(.checkbox)

                                        Toggle(isOn: $isOutdoorWorkoutRequired) {
                                            Text("Strict Outdoor Requirement")
                                                .font(.system(size: 10.5))
                                                .foregroundStyle(DS.Theme.textPrimary)
                                        }
                                        .toggleStyle(.checkbox)
                                    }
                                }
                            }

                            // Silence Ring Row
                            ringCard(
                                ring: .silence,
                                color: Color(hex: "#0091FF"),
                                title: "Silence Ring — Deep Focus & Fasting"
                            ) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Text("Deep Focus Silence:")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(DS.Theme.textSecondary)

                                        ForEach([30, 45, 60, 90], id: \.self) { mins in
                                            choiceChip(label: "\(mins)m", isSelected: deepFocusMinutes == mins) {
                                                deepFocusMinutes = mins
                                            }
                                        }
                                    }

                                    Toggle(isOn: $includeSocialMediaFast) {
                                        Text("Social Media Feed Fast (Zero infinite scroll)")
                                            .font(.system(size: 10.5))
                                            .foregroundStyle(DS.Theme.textPrimary)
                                    }
                                    .toggleStyle(.checkbox)
                                }
                            }
                        }

                        // 4. Optional Add-On Disciplines (Collapsible)
                        VStack(alignment: .leading, spacing: 6) {
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    showOptionalAddOns.toggle()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: showOptionalAddOns ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 9.5, weight: .bold))
                                        .foregroundStyle(DS.Theme.amber)
                                    Text("OPTIONAL EXTRA DISCIPLINES")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(DS.Theme.amber)
                                    Spacer()
                                    Text(showOptionalAddOns ? "Hide" : "Expand (4 optional)")
                                        .font(.system(size: 9.5))
                                        .foregroundStyle(DS.Theme.textTertiary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)

                            if showOptionalAddOns {
                                VStack(alignment: .leading, spacing: 8) {
                                    Toggle(isOn: $include10kSteps) {
                                        Text("10,000 Daily Steps Baseline / Cold Plunge")
                                            .font(.system(size: 10.5))
                                            .foregroundStyle(DS.Theme.textPrimary)
                                    }
                                    .toggleStyle(.checkbox)

                                    Toggle(isOn: $includeStrictDiet) {
                                        Text("Strict Nutrition & Zero Alcohol")
                                            .font(.system(size: 10.5))
                                            .foregroundStyle(DS.Theme.textPrimary)
                                    }
                                    .toggleStyle(.checkbox)

                                    Toggle(isOn: $includeDailyPhoto) {
                                        Text("Daily Progress Photo Artifact")
                                            .font(.system(size: 10.5))
                                            .foregroundStyle(DS.Theme.textPrimary)
                                    }
                                    .toggleStyle(.checkbox)

                                    Toggle(isOn: $includeOfflineSleepMode) {
                                        Text("Offline Dark Mode 1h Pre-Sleep")
                                            .font(.system(size: 10.5))
                                            .foregroundStyle(DS.Theme.textPrimary)
                                    }
                                    .toggleStyle(.checkbox)
                                }
                                .padding(10)
                                .background(Color.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.06), lineWidth: 1))
                            }
                        }
                    }
                    .padding(20)
                }
                .frame(maxWidth: .infinity)

                Divider().opacity(0.12)

                // RIGHT COLUMN: Live Blueprint Summary, Digital Signature & Seal
                VStack(alignment: .leading, spacing: 16) {

                    // Time Period Box
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(DS.Theme.amber)
                            Text("CONFIRMED WINDOW")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(DS.Theme.amber)
                                .tracking(1)
                            Spacer()
                            Text(durationMonthsText.uppercased())
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(DS.Theme.textTertiary)
                        }

                        HStack(spacing: 6) {
                            Text(formatDate(startDate))
                                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.white)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(DS.Theme.amber)
                            Text(formatDate(endDate))
                                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.white)
                        }
                    }
                    .padding(12)
                    .background(DS.Theme.amber.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Theme.amber.opacity(0.25), lineWidth: 1))

                    // Live Blueprint Checklist
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("DAILY PROTOCOL BLUEPRINT")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(DS.Theme.textTertiary)
                                .tracking(1)
                            Spacer()
                            Text("\(generatedCustomRules().count) Daily Rules")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(DS.Theme.amber)
                        }

                        ScrollView {
                            VStack(alignment: .leading, spacing: 5) {
                                ForEach(generatedCustomRules()) { rule in
                                    HStack(spacing: 7) {
                                        Image(systemName: rule.icon)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(ruleColor(rule.ring))
                                            .frame(width: 14)

                                        Text(rule.title)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(Color.white)
                                            .lineLimit(1)

                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 4))
                                }
                            }
                        }
                        .frame(maxHeight: 180)
                    }
                    .padding(12)
                    .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Theme.border, lineWidth: 1))

                    Spacer()

                    // Callsign & Signature
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SOVEREIGN CALLSIGN / SIGNATURE")
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(DS.Theme.textTertiary)

                            TextField("Enter your name or callsign…", text: $signatureName)
                                .font(.system(size: 12, design: .serif))
                                .textFieldStyle(.plain)
                                .foregroundStyle(DS.Theme.textPrimary)
                                .padding(10)
                                .background(DS.Theme.surface, in: RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(DS.Theme.border, lineWidth: 1))
                        }

                        Toggle(isOn: $hasAgreedToTerms) {
                            Text("I solemnly covenant to execute these daily rules without excuse or compromise.")
                                .font(.system(size: 10))
                                .foregroundStyle(DS.Theme.textSecondary)
                        }
                        .toggleStyle(.checkbox)

                        // Seal Covenant Button
                        Button {
                            executeSignContract()
                        } label: {
                            HStack(spacing: 6) {
                                if isSigning {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "seal.fill")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Seal Formal Covenant (\(activeDurationDays) Days)")
                                        .font(.system(size: 12, weight: .bold))
                                }
                            }
                            .foregroundStyle(canSign ? Color.black : DS.Theme.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(canSign ? DS.Theme.amber : DS.Theme.card, in: RoundedRectangle(cornerRadius: 7))
                            .shadow(color: canSign ? DS.Theme.amber.opacity(0.3) : Color.clear, radius: 6, y: 2)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSign || isSigning)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 1))
                }
                .frame(width: 320)
                .padding(20)
                .background(DS.Theme.surface.opacity(0.6))
            }
        }
        .frame(minWidth: 840, idealWidth: 960, maxWidth: .infinity, minHeight: 640, idealHeight: 740, maxHeight: .infinity)
        .background(DS.Theme.canvas)
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DS.Theme.amber)
                Text("SOVEREIGN GHOST COVENANT")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.Theme.amber)
                    .tracking(1.5)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(DS.Theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    // MARK: - Components

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(DS.Theme.textTertiary)
            .tracking(1)
    }

    private func choiceChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.selection()
        } label: {
            Text(label)
                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? Color.white : DS.Theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(
                    isSelected ? DS.Theme.amber.opacity(0.8) : Color.white.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 4)
                )
        }
        .buttonStyle(.plain)
    }

    private func ringCard<Content: View>(ring: GhostRing, color: Color, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: ring.icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Color.white)
            }

            content()
                .padding(.top, 2)
        }
        .padding(10)
        .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(color.opacity(0.25), lineWidth: 1))
    }

    private func ruleColor(_ ring: GhostRing) -> Color {
        switch ring {
        case .body:    return Color(hex: "#E54D2E")
        case .mind:    return Color(hex: "#3E63DD")
        case .silence: return Color(hex: "#0091FF")
        }
    }

    private var customDurationRow: some View {
        HStack(spacing: 6) {
            Text("Duration:")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DS.Theme.textTertiary)

            ForEach([30, 60, 90, 100, 120, 180], id: \.self) { days in
                choiceChip(label: "\(days)d", isSelected: customDurationDays == days) {
                    customDurationDays = days
                }
            }
        }
        .padding(.top, 2)
    }

    private var canSign: Bool {
        !signatureName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hasAgreedToTerms
    }

    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: date)
    }

    private func applyProtocolPresetDefaults(_ proto: GhostProtocolKind) {
        switch proto {
        case .the120:
            seasonName = "The Winter Arc 2026"
            readingPages = 10
            workoutMinutes = 45
            isOutdoorWorkoutRequired = false
            includeSecondWorkout = false
            include10kSteps = false
            includeWaterTarget = false
            waterTargetGlasses = 8
            includeStrictDiet = false
            includeDailyPhoto = false
            deepFocusMinutes = 45
            includeSocialMediaFast = true
            includeEveningSynthesis = true
            includeOfflineSleepMode = false
        case .seventyFiveHard:
            seasonName = "75 Hard Season"
            readingPages = 10
            workoutMinutes = 45
            isOutdoorWorkoutRequired = true
            includeSecondWorkout = true
            include10kSteps = false
            includeWaterTarget = true
            waterTargetGlasses = 10 // 1 Gallon
            includeStrictDiet = true
            includeDailyPhoto = true
            deepFocusMinutes = 45
            includeSocialMediaFast = false
            includeEveningSynthesis = false
            includeOfflineSleepMode = false
        case .custom:
            seasonName = "Custom Sovereign Arc"
        }
    }

    // MARK: - Rule Generator

    private func generatedCustomRules() -> [GhostProtocolRule] {
        var rules: [GhostProtocolRule] = []
        var order = 0

        // 1. Mind Ring - Reading
        rules.append(GhostProtocolRule(
            id: "mind_reading_custom",
            title: "Read \(readingPages) Pages Non-Fiction",
            subtitle: "Physical book or dedicated reader. High-density synthesis.",
            ring: .mind,
            phase: .day,
            proofKind: .quantity,
            targetValue: Double(readingPages),
            unitLabel: "pages",
            icon: "book.fill",
            isCustom: true,
            sortOrder: order
        ))
        order += 1

        // 2. Mind Ring - Evening Synthesis
        if includeEveningSynthesis {
            rules.append(GhostProtocolRule(
                id: "mind_synthesis_custom",
                title: "Evening Synthesis Note",
                subtitle: "High-leverage realization sealed to Mind ring.",
                ring: .mind,
                phase: .night,
                proofKind: .artifact,
                targetValue: 1.0,
                unitLabel: "entry",
                icon: "pencil.line",
                isCustom: true,
                sortOrder: order
            ))
            order += 1
        }

        // 3. Body Ring - Workout
        rules.append(GhostProtocolRule(
            id: "body_workout_custom",
            title: isOutdoorWorkoutRequired ? "Outdoor Workout (\(workoutMinutes)')" : "Physical Forge (\(workoutMinutes)')",
            subtitle: isOutdoorWorkoutRequired ? "\(workoutMinutes) minutes strictly in open elements." : "Daily training, cold exposure, or strength session.",
            ring: .body,
            phase: .morning,
            proofKind: .duration,
            targetValue: Double(workoutMinutes),
            unitLabel: "mins",
            icon: "figure.run",
            isOutdoorRequired: isOutdoorWorkoutRequired,
            isCustom: true,
            sortOrder: order
        ))
        order += 1

        // 4. Body Ring - Second Workout
        if includeSecondWorkout {
            rules.append(GhostProtocolRule(
                id: "body_second_workout_custom",
                title: "Second Workout (45')",
                subtitle: "45-minute strength, cardio, or mobility session.",
                ring: .body,
                phase: .day,
                proofKind: .duration,
                targetValue: 45.0,
                unitLabel: "mins",
                icon: "dumbbell.fill",
                isCustom: true,
                sortOrder: order
            ))
            order += 1
        }

        // 5. Body Ring - Water
        if includeWaterTarget {
            rules.append(GhostProtocolRule(
                id: "body_water_custom",
                title: waterTargetGlasses >= 10 ? "1 Gallon Water" : "\(waterTargetGlasses) Glasses Water",
                subtitle: "Hydration target: \(waterTargetGlasses) full glasses.",
                ring: .body,
                phase: .day,
                proofKind: .quantity,
                targetValue: Double(waterTargetGlasses),
                unitLabel: "glasses",
                icon: "drop.fill",
                isCustom: true,
                sortOrder: order
            ))
            order += 1
        }

        // 6. Body Ring - Steps / Basal Forge
        if include10kSteps {
            rules.append(GhostProtocolRule(
                id: "body_steps_custom",
                title: "10,000 Steps Baseline",
                subtitle: "Minimum daily activity threshold for basal metabolic activation.",
                ring: .body,
                phase: .day,
                proofKind: .quantity,
                targetValue: 10000.0,
                unitLabel: "steps",
                icon: "figure.walk",
                isCustom: true,
                sortOrder: order
            ))
            order += 1
        }

        // 7. Body Ring - Strict Nutrition
        if includeStrictDiet {
            rules.append(GhostProtocolRule(
                id: "body_diet_custom",
                title: "Strict Nutrition & Zero Alcohol",
                subtitle: "Zero cheat meals, zero alcohol. Total nutritional discipline.",
                ring: .body,
                phase: .morning,
                proofKind: .binary,
                targetValue: 1.0,
                unitLabel: "adherence",
                icon: "fork.knife",
                isCustom: true,
                sortOrder: order
            ))
            order += 1
        }

        // 8. Body Ring - Daily Progress Photo
        if includeDailyPhoto {
            rules.append(GhostProtocolRule(
                id: "body_photo_custom",
                title: "Daily Progress Photo",
                subtitle: "Visual proof artifact sealed to local vault.",
                ring: .body,
                phase: .night,
                proofKind: .artifact,
                targetValue: 1.0,
                unitLabel: "photo",
                icon: "camera.fill",
                isCustom: true,
                sortOrder: order
            ))
            order += 1
        }

        // 9. Silence Ring - Deep Focus
        rules.append(GhostProtocolRule(
            id: "silence_focus_custom",
            title: "Deep Focus Silence (\(deepFocusMinutes)')",
            subtitle: "Uninterrupted deep work sprint in Focus Room.",
            ring: .silence,
            phase: .day,
            proofKind: .duration,
            targetValue: Double(deepFocusMinutes),
            unitLabel: "mins",
            icon: "speaker.slash.fill",
            isCustom: true,
            sortOrder: order
        ))
        order += 1

        // 10. Silence Ring - Social Media Fast
        if includeSocialMediaFast {
            rules.append(GhostProtocolRule(
                id: "silence_social_fast_custom",
                title: "Social Media Feed Fast",
                subtitle: "Zero algorithmic infinite-scroll consumption.",
                ring: .silence,
                phase: .night,
                proofKind: .binary,
                targetValue: 1.0,
                unitLabel: "adherence",
                icon: "moon.stars.fill",
                isCustom: true,
                sortOrder: order
            ))
            order += 1
        }

        // 11. Silence Ring - Offline Sleep Mode
        if includeOfflineSleepMode {
            rules.append(GhostProtocolRule(
                id: "silence_sleep_mode_custom",
                title: "Offline Dark Mode 1h Pre-Sleep",
                subtitle: "No screens or notifications 60 minutes prior to resting.",
                ring: .silence,
                phase: .night,
                proofKind: .binary,
                targetValue: 1.0,
                unitLabel: "adherence",
                icon: "bed.double.fill",
                isCustom: true,
                sortOrder: order
            ))
            order += 1
        }

        return rules
    }

    private func executeSignContract() {
        guard canSign else { return }
        isSigning = true
        Haptics.notify(.success)

        let customizedRules = generatedCustomRules()

        Task {
            do {
                let season = try await GhostEngine.shared.signContract(
                    name: seasonName,
                    protocolKind: selectedProtocol,
                    startDate: startDate,
                    endDate: endDate,
                    doctrine: selectedDoctrine,
                    customRules: customizedRules
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
