import SwiftUI

/// Formal Sovereign Ghost Covenant & Authorization Studio for initiating a new Season.
/// Provides exhaustive configuration of daily rules (reading pages, workout duration, hydration, deep work),
/// real-time date windows, doctrine accountability models, and a cryptographic digital signature seal.
public struct ContractOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    public var onContractSigned: ((GhostSeason) -> Void)?

    // MARK: - Core Architecture & Doctrine State
    @State private var selectedProtocol: GhostProtocolKind = .the120
    @State private var customDurationDays: Int = 90
    @State private var selectedDoctrine: GhostDoctrine = .hard
    @State private var seasonName: String = "The Winter Arc 2026"

    // MARK: - Granular Rule Customizations (Mind, Body, Silence)
    // 1. Mind Ring
    @State private var readingPages: Int = 10
    @State private var includeEveningSynthesis: Bool = true

    // 2. Body Ring
    @State private var workoutMinutes: Int = 45
    @State private var isOutdoorWorkoutRequired: Bool = false
    @State private var includeSecondWorkout: Bool = false
    @State private var include10kSteps: Bool = true
    @State private var waterTargetGlasses: Int = 8 // 8 glasses = 3.0 Litres
    @State private var includeStrictDiet: Bool = true
    @State private var includeDailyPhoto: Bool = false

    // 3. Silence Ring
    @State private var deepFocusMinutes: Int = 45
    @State private var includeSocialMediaFast: Bool = true
    @State private var includeOfflineSleepMode: Bool = true

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
        return "\(activeDurationDays) Days (\(months) Calendar Months)"
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            Divider().opacity(0.12)

            ScrollView {
                VStack(spacing: 24) {
                    // Time Period & Calendar Window Banner
                    executionWindowBanner

                    // 1. Protocol Architecture
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("1. SELECT PROTOCOL ARCHITECTURE")

                        VStack(spacing: 8) {
                            ForEach(GhostProtocolKind.allCases) { proto in
                                protocolCard(proto)
                            }
                        }

                        // Custom Duration Slider if Custom Arc
                        if selectedProtocol == .custom {
                            customDurationPicker
                                .padding(.top, 4)
                        }
                    }

                    // 2. Governing Doctrine Selection
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("2. SELECT GOVERNING DOCTRINE")

                        HStack(spacing: 12) {
                            ForEach(GhostDoctrine.allCases) { doc in
                                doctrineCard(doc)
                            }
                        }
                    }

                    // 3. Granular Daily Rules & Target Customization
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            sectionHeader("3. CUSTOMIZE NON-NEGOTIABLE DAILY RINGS")
                            Spacer()
                            Text("Tailor your exact metrics before sealing")
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(DS.Theme.amber.opacity(0.8))
                        }

                        // Mind Ring Customizer
                        mindRingCustomizerCard

                        // Body Ring Customizer
                        bodyRingCustomizerCard

                        // Silence Ring Customizer
                        silenceRingCustomizerCard
                    }

                    // 4. Live Covenant Blueprint Summary
                    covenantSummaryCard

                    // 5. Formal Digital Covenant & Authorization
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("5. FORMAL COVENANT & AUTHORIZATION")

                        VStack(spacing: 14) {
                            // Signature Field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("SOVEREIGN CALLSIGN / LEGAL NAME")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(DS.Theme.textTertiary)

                                TextField("Enter your full legal name or sovereign callsign…", text: $signatureName)
                                    .font(.system(size: 13, design: .serif))
                                    .textFieldStyle(.plain)
                                    .foregroundStyle(DS.Theme.textPrimary)
                                    .padding(12)
                                    .background(DS.Theme.surface, in: RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Theme.border, lineWidth: 1))
                            }

                            // Explicit Permission & Commitment Toggle
                            Toggle(isOn: $hasAgreedToTerms) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("I grant explicit permission to initiate this \(activeDurationDays)-day Ghost Protocol.")
                                        .font(.system(size: 11.5, weight: .semibold))
                                        .foregroundStyle(DS.Theme.textPrimary)
                                    Text("I solemnly covenant to execute these \(generatedCustomRules().count) daily rules from \(formatDate(startDate)) to \(formatDate(endDate)) without excuse, compromise, or dilution.")
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(DS.Theme.textTertiary)
                                }
                            }
                            .toggleStyle(.checkbox)
                            .padding(.top, 2)
                        }
                        .padding(16)
                        .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(DS.Theme.border, lineWidth: 1))
                    }
                }
                .padding(24)
            }

            Divider().opacity(0.12)

            // Bottom Action Bar
            bottomActionBar
        }
        .frame(minWidth: 840, idealWidth: 900, maxWidth: .infinity, minHeight: 720, idealHeight: 800, maxHeight: .infinity)
        .background(DS.Theme.canvas)
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DS.Theme.amber)
                    Text("SOVEREIGN GHOST COVENANT")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.Theme.amber)
                        .tracking(1.5)
                }
                Text("Enter the \(activeDurationDays)-Day Arc")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DS.Theme.textPrimary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(DS.Theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    // MARK: - Time Window Banner

    private var executionWindowBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(DS.Theme.amber)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("CONFIRMED TIME PERIOD")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.Theme.amber)
                        .tracking(1.2)
                    Text("· \(durationMonthsText.uppercased())")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.Theme.textTertiary)
                }

                HStack(spacing: 8) {
                    Text(formatDate(startDate))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.Theme.textPrimary)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DS.Theme.amber)
                    Text(formatDate(endDate))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.Theme.textPrimary)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(DS.Theme.amber.opacity(0.08))
        )
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(DS.Theme.amber.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Protocol Card

    private func protocolCard(_ proto: GhostProtocolKind) -> some View {
        let isSelected = (selectedProtocol == proto)
        return Button {
            selectedProtocol = proto
            applyProtocolPresetDefaults(proto)
            Haptics.selection()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isSelected ? DS.Theme.amber : DS.Theme.textMuted)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(proto.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(DS.Theme.textPrimary)
                        Text("(\(proto.durationDays) Days)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(DS.Theme.amber)
                    }
                    Text(proto.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Theme.textSecondary)
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? DS.Theme.amber.opacity(0.08) : DS.Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? DS.Theme.amber.opacity(0.5) : DS.Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var customDurationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CUSTOM DURATION:")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.Theme.textTertiary)
                Text("\(customDurationDays) Days (\(max(1, customDurationDays / 30)) Months)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.Theme.amber)
            }

            HStack(spacing: 6) {
                ForEach([30, 45, 60, 90, 100, 120, 180], id: \.self) { days in
                    Button {
                        customDurationDays = days
                        Haptics.selection()
                    } label: {
                        Text("\(days)d")
                            .font(.system(size: 10.5, weight: customDurationDays == days ? .bold : .medium))
                            .foregroundStyle(customDurationDays == days ? Color.black : DS.Theme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                customDurationDays == days ? DS.Theme.amber : Color.white.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.Theme.border, lineWidth: 1))
    }

    // MARK: - Doctrine Card

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
                        .foregroundStyle(DS.Theme.textPrimary)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? DS.Theme.amber : DS.Theme.textMuted)
                }

                Text(doc.ruleDescription)
                    .font(.system(size: 10.5))
                    .foregroundStyle(DS.Theme.textSecondary)
                    .lineLimit(3)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? DS.Theme.amber.opacity(0.08) : DS.Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? DS.Theme.amber.opacity(0.5) : DS.Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 1. Mind Ring Customizer

    private var mindRingCustomizerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: "#3E63DD"))

                Text("MIND RING — MENTAL SYNTHESIS & READING")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DS.Theme.textPrimary)

                Spacer()
            }

            // Reading Target Selection
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Daily Reading Commitment:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.Theme.textSecondary)
                    Spacer()
                    Text("\(readingPages) Pages / Day")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#3E63DD"))
                }

                HStack(spacing: 6) {
                    ForEach([5, 10, 15, 20, 30, 50], id: \.self) { pages in
                        Button {
                            readingPages = pages
                            Haptics.selection()
                        } label: {
                            Text("\(pages)p")
                                .font(.system(size: 10.5, weight: readingPages == pages ? .bold : .medium))
                                .foregroundStyle(readingPages == pages ? Color.white : DS.Theme.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    readingPages == pages ? Color(hex: "#3E63DD") : Color.white.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 5)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    // Stepper (+ / -)
                    HStack(spacing: 4) {
                        Button {
                            if readingPages > 5 { readingPages -= 5 }
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 22, height: 22)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)

                        Button {
                            readingPages += 5
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 22, height: 22)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider().opacity(0.10)

            // Evening Reflection Toggle
            Toggle(isOn: $includeEveningSynthesis) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Evening Synthesis Note")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(DS.Theme.textPrimary)
                    Text("Seal one high-leverage realization, decision, or synthesis entry each evening.")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.Theme.textTertiary)
                }
            }
            .toggleStyle(.checkbox)
        }
        .padding(14)
        .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#3E63DD").opacity(0.3), lineWidth: 1))
    }

    // MARK: - 2. Body Ring Customizer

    private var bodyRingCustomizerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "figure.run")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: "#E54D2E"))

                Text("BODY RING — PHYSICAL FORGE & HYDRATION")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DS.Theme.textPrimary)

                Spacer()
            }

            // Workout Duration Selection
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Primary Workout Target:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.Theme.textSecondary)
                    Spacer()
                    Text("\(workoutMinutes) Minutes")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#E54D2E"))
                }

                HStack(spacing: 6) {
                    ForEach([30, 45, 60, 90], id: \.self) { mins in
                        Button {
                            workoutMinutes = mins
                            Haptics.selection()
                        } label: {
                            Text("\(mins)m")
                                .font(.system(size: 10.5, weight: workoutMinutes == mins ? .bold : .medium))
                                .foregroundStyle(workoutMinutes == mins ? Color.white : DS.Theme.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    workoutMinutes == mins ? Color(hex: "#E54D2E") : Color.white.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 5)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Button {
                            if workoutMinutes > 15 { workoutMinutes -= 15 }
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 22, height: 22)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)

                        Button {
                            workoutMinutes += 15
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 22, height: 22)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Hydration Target Selection
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Daily Hydration Target:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.Theme.textSecondary)
                    Spacer()
                    Text(waterLabel(waterTargetGlasses))
                        .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#0091FF"))
                }

                HStack(spacing: 6) {
                    ForEach([6, 8, 10, 12], id: \.self) { glasses in
                        Button {
                            waterTargetGlasses = glasses
                            Haptics.selection()
                        } label: {
                            Text(waterShortLabel(glasses))
                                .font(.system(size: 10.5, weight: waterTargetGlasses == glasses ? .bold : .medium))
                                .foregroundStyle(waterTargetGlasses == glasses ? Color.white : DS.Theme.textSecondary)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(
                                    waterTargetGlasses == glasses ? Color(hex: "#0091FF") : Color.white.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider().opacity(0.10)

            // Body Ring Add-on Toggles
            VStack(spacing: 8) {
                Toggle(isOn: $isOutdoorWorkoutRequired) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Strict Outdoor Workout Requirement")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(DS.Theme.textPrimary)
                        Text("At least one workout strictly outdoors regardless of weather conditions.")
                            .font(.system(size: 10))
                            .foregroundStyle(DS.Theme.textTertiary)
                    }
                }
                .toggleStyle(.checkbox)

                Toggle(isOn: $includeSecondWorkout) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Second Workout (45m Daily)")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(DS.Theme.textPrimary)
                        Text("Two separate physical sessions every single day (Standard 75 Hard requirement).")
                            .font(.system(size: 10))
                            .foregroundStyle(DS.Theme.textTertiary)
                    }
                }
                .toggleStyle(.checkbox)

                Toggle(isOn: $include10kSteps) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("10,000 Daily Steps Baseline / Cold Plunge")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(DS.Theme.textPrimary)
                        Text("Minimum daily activity threshold for basal metabolic activation.")
                            .font(.system(size: 10))
                            .foregroundStyle(DS.Theme.textTertiary)
                    }
                }
                .toggleStyle(.checkbox)

                Toggle(isOn: $includeStrictDiet) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Strict Nutrition & Zero Alcohol")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(DS.Theme.textPrimary)
                        Text("Zero cheat meals, zero alcohol, clean macronutrient adherence.")
                            .font(.system(size: 10))
                            .foregroundStyle(DS.Theme.textTertiary)
                    }
                }
                .toggleStyle(.checkbox)

                Toggle(isOn: $includeDailyPhoto) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily Progress Photo Artifact")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(DS.Theme.textPrimary)
                        Text("Capture visual proof artifact sealed to your encrypted local vault.")
                            .font(.system(size: 10))
                            .foregroundStyle(DS.Theme.textTertiary)
                    }
                }
                .toggleStyle(.checkbox)
            }
        }
        .padding(14)
        .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#E54D2E").opacity(0.3), lineWidth: 1))
    }

    // MARK: - 3. Silence Ring Customizer

    private var silenceRingCustomizerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "speaker.slash.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: "#0091FF"))

                Text("SILENCE RING — DEEP FOCUS & DIGITAL FASTING")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DS.Theme.textPrimary)

                Spacer()
            }

            // Deep Focus Target Selection
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Deep Focus Silence Duration:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.Theme.textSecondary)
                    Spacer()
                    Text("\(deepFocusMinutes) Minutes")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#0091FF"))
                }

                HStack(spacing: 6) {
                    ForEach([30, 45, 60, 90, 120], id: \.self) { mins in
                        Button {
                            deepFocusMinutes = mins
                            Haptics.selection()
                        } label: {
                            Text("\(mins)m")
                                .font(.system(size: 10.5, weight: deepFocusMinutes == mins ? .bold : .medium))
                                .foregroundStyle(deepFocusMinutes == mins ? Color.white : DS.Theme.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    deepFocusMinutes == mins ? Color(hex: "#0091FF") : Color.white.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 5)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Button {
                            if deepFocusMinutes > 15 { deepFocusMinutes -= 15 }
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 22, height: 22)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)

                        Button {
                            deepFocusMinutes += 15
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 22, height: 22)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider().opacity(0.10)

            // Silence Add-on Toggles
            VStack(spacing: 8) {
                Toggle(isOn: $includeSocialMediaFast) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Social Media Feed Fast")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(DS.Theme.textPrimary)
                        Text("Zero algorithmic infinite-scroll consumption across all mobile & desktop platforms.")
                            .font(.system(size: 10))
                            .foregroundStyle(DS.Theme.textTertiary)
                    }
                }
                .toggleStyle(.checkbox)

                Toggle(isOn: $includeOfflineSleepMode) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Offline Dark Mode 1h Before Sleep")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(DS.Theme.textPrimary)
                        Text("Screens and notifications disabled 60 minutes prior to resting.")
                            .font(.system(size: 10))
                            .foregroundStyle(DS.Theme.textTertiary)
                    }
                }
                .toggleStyle(.checkbox)
            }
        }
        .padding(14)
        .background(DS.Theme.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#0091FF").opacity(0.3), lineWidth: 1))
    }

    // MARK: - Covenant Summary Card

    private var covenantSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "list.bullet.clipboard.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DS.Theme.amber)
                Text("COVENANT ARCHITECTURE SUMMARY")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.Theme.amber)
                    .tracking(1.2)
                Spacer()
                Text("\(generatedCustomRules().count) Non-Negotiables Daily")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(DS.Theme.amber.opacity(0.2), in: Capsule())
            }

            VStack(spacing: 6) {
                summaryRow(icon: "brain.head.profile", color: Color(hex: "#3E63DD"), title: "Mind Ring", detail: "Read \(readingPages) pages" + (includeEveningSynthesis ? " · Evening Synthesis Note" : ""))
                summaryRow(icon: "figure.run", color: Color(hex: "#E54D2E"), title: "Body Ring", detail: "\(workoutMinutes)m Workout" + (isOutdoorWorkoutRequired ? " (Outdoor)" : "") + (includeSecondWorkout ? " + 2nd 45m Session" : "") + " · \(waterShortLabel(waterTargetGlasses)) Water" + (includeStrictDiet ? " · Strict Diet" : ""))
                summaryRow(icon: "speaker.slash.fill", color: Color(hex: "#0091FF"), title: "Silence Ring", detail: "\(deepFocusMinutes)m Deep Focus Silence" + (includeSocialMediaFast ? " · Social Media Fast" : "") + (includeOfflineSleepMode ? " · Screen-Free Sleep" : ""))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }

    private func summaryRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 16, height: 16)
                .background(color.opacity(0.15), in: Circle())

            Text(title + ":")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white)

            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(DS.Theme.textSecondary)
                .lineLimit(2)

            Spacer()
        }
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundStyle(DS.Theme.textTertiary)

            Spacer()

            Button {
                executeSignContract()
            } label: {
                HStack(spacing: 6) {
                    if isSigning {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "seal.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Seal Formal Covenant (\(activeDurationDays) Days)")
                            .font(.system(size: 12, weight: .bold))
                    }
                }
                .foregroundStyle(canSign ? Color.black : DS.Theme.textMuted)
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(canSign ? DS.Theme.amber : DS.Theme.card)
                )
            }
            .buttonStyle(.plain)
            .disabled(!canSign || isSigning)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(DS.Theme.surface)
    }

    private var canSign: Bool {
        !signatureName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hasAgreedToTerms
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(DS.Theme.textTertiary)
            .tracking(1.2)
    }

    private func waterLabel(_ glasses: Int) -> String {
        switch glasses {
        case 6:  return "6 Glasses (2.2 Litres)"
        case 8:  return "8 Glasses (3.0 Litres)"
        case 10: return "1 Gallon (3.8 Litres)"
        case 12: return "12 Glasses (4.5 Litres)"
        default: return "\(glasses) Glasses"
        }
    }

    private func waterShortLabel(_ glasses: Int) -> String {
        switch glasses {
        case 6:  return "2.2L (6g)"
        case 8:  return "3.0L (8g)"
        case 10: return "1 Gallon"
        case 12: return "4.5L (12g)"
        default: return "\(glasses)g"
        }
    }

    private func applyProtocolPresetDefaults(_ proto: GhostProtocolKind) {
        switch proto {
        case .the120:
            seasonName = "The Winter Arc 2026"
            readingPages = 10
            workoutMinutes = 45
            isOutdoorWorkoutRequired = false
            includeSecondWorkout = false
            include10kSteps = true
            waterTargetGlasses = 8
            includeStrictDiet = true
            includeDailyPhoto = false
            deepFocusMinutes = 45
            includeSocialMediaFast = true
            includeEveningSynthesis = true
            includeOfflineSleepMode = true
        case .seventyFiveHard:
            seasonName = "75 Hard Season"
            readingPages = 10
            workoutMinutes = 45
            isOutdoorWorkoutRequired = true
            includeSecondWorkout = true
            include10kSteps = false
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
        rules.append(GhostProtocolRule(
            id: "body_water_custom",
            title: waterTargetGlasses >= 10 ? "1 Gallon Water" : "\(waterLabel(waterTargetGlasses))",
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

    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: date)
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
