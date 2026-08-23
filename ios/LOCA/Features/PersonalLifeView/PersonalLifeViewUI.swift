//
//  PersonalLifeViewUI.swift
//  LOCA
//
//  Phase 4 — Personal Life View UI renderer
//  Renders ComposedView as bendable interactive scene
//

import SwiftUI
import SwiftData

struct PersonalLifeViewUI: View {
    let composedView: ComposedView
    @State private var isShowingCounterfactual = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.lg) {
                    // MARK: - Question/Title
                    VStack(alignment: .leading, spacing: DS.Space.sm) {
                        Text("Personal Perspective")
                            .font(DS.Text.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                            .textCase(.uppercase)

                        Text(composedView.question)
                            .font(DS.Text.heading)
                            .foregroundStyle(DS.Color.textPrimary)
                    }

                    Divider()

                    // MARK: - Timeline Visualization
                    VStack(alignment: .leading, spacing: DS.Space.md) {
                        // Stress underlay
                        StressUnderlayView(timeline: composedView.stressTimeline)
                            .frame(height: 120)

                        // Energy line (main)
                        EnergyTimelineView(timeline: composedView.energyTimeline)
                            .frame(height: 140)

                        // Mood dots
                        MoodDotsView(timeline: composedView.moodTimeline)
                            .frame(height: 80)
                    }
                    .padding(DS.Space.md)
                    .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))

                    // MARK: - Evidence (C1.2 provenance)
                    EvidenceSection(start: composedView.startDate, end: composedView.endDate)

                    // MARK: - Life Event Markers
                    if !composedView.eventMarkers.isEmpty {
                        VStack(alignment: .leading, spacing: DS.Space.sm) {
                            Text("Key Moments")
                                .font(DS.Text.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(DS.Color.textPrimary)

                            ForEach(composedView.eventMarkers, id: \.timestamp) { marker in
                                EventMarkerRow(marker: marker)
                            }
                        }
                        .padding(DS.Space.md)
                        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))
                    }

                    // MARK: - Annotations
                    if !composedView.annotations.isEmpty {
                        VStack(alignment: .leading, spacing: DS.Space.sm) {
                            Text("Notable Patterns")
                                .font(DS.Text.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(DS.Color.textPrimary)

                            ForEach(composedView.annotations, id: \.timestamp) { annotation in
                                AnnotationRow(annotation: annotation)
                            }
                        }
                        .padding(DS.Space.md)
                        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))
                    }

                    // MARK: - Counterfactual Toggle
                    if let counterfactualVar = composedView.counterfactualVariable {
                        VStack(alignment: .leading, spacing: DS.Space.sm) {
                            HStack {
                                Text("Explore Counterfactual")
                                    .font(DS.Text.body)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(DS.Color.textPrimary)

                                Spacer()

                                Toggle("", isOn: $isShowingCounterfactual)
                                    .onChange(of: isShowingCounterfactual) { oldValue, newValue in
                                        // Trigger counterfactual re-composition
                                    }
                            }

                            if isShowingCounterfactual {
                                Text(counterfactualVar)
                                    .font(DS.Text.caption)
                                    .foregroundStyle(DS.Color.textSecondary)
                                    .italic()
                            }
                        }
                        .padding(DS.Space.md)
                        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))
                    }

                    // MARK: - Uncertainty Type (C1.3)
                    // Distinguish reducible from irreducible uncertainty — a field
                    // carried on every TimelinePoint but never previously shown.
                    if let type = dominantUncertaintyType(composedView.energyTimeline) {
                        UncertaintyTypeNote(type: type)
                            .padding(.horizontal, DS.Space.md)
                    }

                    // MARK: - Uncertainty Legend
                    UncertaintyLegendView()

                    Spacer(minLength: DS.Space.xxxl)
                }
                .padding(DS.Space.lg)
            }
            .navigationTitle("Your Life")
            .inlineNavigationTitleDisplay()
        }
    }

    /// C1.3: the majority uncertainty type among the timeline's uncertain (present,
    /// non-crisp) points. Returns nil when nothing is uncertain — no note to show.
    private func dominantUncertaintyType(_ timeline: [TimelinePoint]) -> UncertaintyType? {
        var epistemic = 0
        var aleatoric = 0
        for point in timeline where !point.isAbsent && point.confidence != .crisp {
            switch point.uncertaintyType {
            case UncertaintyType.epistemic.rawValue: epistemic += 1
            case UncertaintyType.aleatoric.rawValue: aleatoric += 1
            default: break
            }
        }
        guard epistemic + aleatoric > 0 else { return nil }
        return epistemic >= aleatoric ? .epistemic : .aleatoric
    }
}

// MARK: - Evidence Section (C1.2 provenance)

/// Queries the inferred states in the composed window and rolls up their stored
/// provenance into a "what this draws on" summary. No pipeline changes — it reads
/// provenance already persisted on InferredState.
private struct EvidenceSection: View {
    let start: Date
    let end: Date

    @Environment(\.modelContext) private var modelContext
    @State private var summary: EvidenceSummary?

    var body: some View {
        Group {
            if let summary, !summary.sources.isEmpty {
                EvidenceSummaryRow(summary: summary)
                    .padding(DS.Space.md)
                    .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))
            }
        }
        .task { await load() }
    }

    private func load() async {
        let lower = start
        let upper = end
        let descriptor = FetchDescriptor<InferredState>(
            predicate: #Predicate { $0.timestamp >= lower && $0.timestamp <= upper }
        )
        let states = (try? modelContext.fetch(descriptor)) ?? []
        summary = summarizeEvidence(states: states)
    }
}

// MARK: - Stress Underlay

private struct StressUnderlayView: View {
    let timeline: [TimelinePoint]

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#FEE2E2").opacity(0.1),
                    Color(hex: "#EF4444").opacity(0.2)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(timeline, id: \.timestamp) { point in
                    VStack(spacing: 0) {
                        Spacer()

                        // C1.4: absent points have no stress bar — absence is not zero stress.
                        if !point.isAbsent {
                            RoundedRectangle(cornerRadius: 2)
                                .frame(height: CGFloat(point.value * 100))
                                .foregroundStyle(Color(hex: "#EF4444"))
                                .opacity(opacityForConfidence(point.confidence))
                        }
                    }
                    .frame(height: 120)
                }
            }
            .padding(DS.Space.sm)
        }
        .background(DS.Color.surfaceRecessed, in: RoundedRectangle(cornerRadius: DS.Radius.control))
    }

    private func opacityForConfidence(_ confidence: ConfidenceLevel) -> Double {
        switch confidence {
        case .crisp: return 0.6
        case .soft: return 0.4
        case .speculative: return 0.2
        }
    }
}

// MARK: - Energy Timeline

private struct EnergyTimelineView: View {
    let timeline: [TimelinePoint]

    var body: some View {
        Canvas { context, size in
            guard timeline.count > 1 else { return }

            let width = size.width
            let height = size.height
            let points = timeline
            let strokeColor = Color(hex: "#10B981")

            // C1.4: Build the line path with natural gaps at absent points.
            // An absent point is a break in the line, not a point at 0.
            var path = Path()
            var inGap = true  // start with a gap until the first present point

            for (index, point) in points.enumerated() {
                guard !point.isAbsent else {
                    inGap = true
                    continue
                }
                let x = (CGFloat(index) / CGFloat(points.count - 1)) * width
                let y = height - (CGFloat(point.value) * height)

                if inGap {
                    path.move(to: CGPoint(x: x, y: y))
                    inGap = false
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            context.stroke(path, with: .color(strokeColor.opacity(0.8)), style: StrokeStyle(lineWidth: 2))

            // Draw dots only for present points.
            for (index, point) in points.enumerated() {
                guard !point.isAbsent else { continue }

                let x = (CGFloat(index) / CGFloat(points.count - 1)) * width
                let y = height - (CGFloat(point.value) * height)
                let dotSize = sizeForConfidence(point.confidence)
                let opacity = opacityForConfidence(point.confidence)

                let dotPath = Path(ellipseIn: CGRect(
                    x: x - dotSize / 2,
                    y: y - dotSize / 2,
                    width: dotSize,
                    height: dotSize
                ))

                context.fill(dotPath, with: .color(strokeColor.opacity(opacity)))
            }
        }
    }

    private func opacityForConfidence(_ confidence: ConfidenceLevel) -> Double {
        switch confidence {
        case .crisp: return 1.0
        case .soft: return 0.6
        case .speculative: return 0.25
        }
    }

    private func sizeForConfidence(_ confidence: ConfidenceLevel) -> CGFloat {
        switch confidence {
        case .crisp: return 5
        case .soft: return 4
        case .speculative: return 3
        }
    }
}

// MARK: - Mood Dots

private struct MoodDotsView: View {
    let timeline: [TimelinePoint]

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            ForEach(timeline, id: \.timestamp) { point in
                VStack(spacing: 4) {
                    if point.isAbsent {
                        // C1.4: absent mood is not zero mood — render as an empty ring with no value.
                        Circle()
                            .strokeBorder(Color(hex: "#F59E0B").opacity(0.3), lineWidth: 1.5)
                            .frame(width: 16, height: 16)

                        Text("–")
                            .font(.caption2)
                            .foregroundStyle(DS.Color.textTertiary)
                    } else {
                        Circle()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(Color(hex: "#F59E0B"))
                            .opacity(opacityForConfidence(point.confidence))

                        Text(formattedValue(point.value))
                            .font(.caption2)
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                }
            }
            Spacer()
        }
    }

    private func opacityForConfidence(_ confidence: ConfidenceLevel) -> Double {
        switch confidence {
        case .crisp: return 1.0
        case .soft: return 0.6
        case .speculative: return 0.3
        }
    }

    private func formattedValue(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }
}

// MARK: - Event Marker Row

private struct EventMarkerRow: View {
    let marker: EventMarker

    var body: some View {
        HStack(spacing: DS.Space.md) {
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundStyle(.tint)

                    Text(marker.label)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Color.textPrimary)
                }

                Text(formattedDate(marker.timestamp))
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
            }

            Spacer()
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Annotation Row

private struct AnnotationRow: View {
    let annotation: AnnotationPoint

    var body: some View {
        HStack(spacing: DS.Space.md) {
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(annotation.text)
                    .font(.caption)
                    .foregroundStyle(DS.Color.textPrimary)

                Text(formattedDate(annotation.timestamp))
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
            }

            Spacer()
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Uncertainty Legend

private struct UncertaintyLegendView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            Text("Reading the View")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(DS.Color.textSecondary)
                .textCase(.uppercase)

            HStack(spacing: DS.Space.lg) {
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .frame(height: 3)
                        .frame(width: 40)
                        .foregroundStyle(.gray)
                        .opacity(1.0)

                    Text("Certain")
                        .font(.caption2)
                        .foregroundStyle(DS.Color.textSecondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .frame(height: 3)
                        .frame(width: 40)
                        .foregroundStyle(.gray)
                        .opacity(0.25)

                    Text("Speculative")
                        .font(.caption2)
                        .foregroundStyle(DS.Color.textSecondary)
                }

                // C1.4: "No data" is a distinct rendering state — not faint, but absent.
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 1)
                                .frame(width: 10, height: 3)
                                .foregroundStyle(Color.gray.opacity(0.4))
                        }
                    }
                    .frame(width: 40, alignment: .leading)

                    Text("No data")
                        .font(.caption2)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }

            Text("Gaps in lines and hollow dots mean no data arrived — not that the value was low. Fainter solid lines are real but uncertain measurements.")
                .font(.caption2)
                .foregroundStyle(DS.Color.textTertiary)
        }
        .padding(DS.Space.md)
        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))
    }
}

// MARK: - Preview

#Preview {
    let sampleTimeline = (0..<20).map { i in
        TimelinePoint(
            timestamp: Date().addingTimeInterval(Double(i) * 3600),
            value: Double.random(in: 0.3...0.8),
            uncertainty: Double.random(in: 0.1...0.4),
            confidence: ConfidenceLevel(uncertainty: Double.random(in: 0.1...0.4)),
            renderingStyle: "crisp"
        )
    }

    let sampleView = ComposedView(
        question: "Am I happier since starting the internship?",
        startDate: Date().addingTimeInterval(-60 * 86400),
        endDate: Date(),
        energyTimeline: sampleTimeline,
        stressTimeline: sampleTimeline,
        focusTimeline: sampleTimeline,
        moodTimeline: sampleTimeline,
        eventMarkers: [
            EventMarker(
                timestamp: Date().addingTimeInterval(-30 * 86400),
                eventType: "workChange",
                label: "Started Internship",
                metadata: ["summary": "Major schedule shift"]
            )
        ],
        annotations: []
    )

    PersonalLifeViewUI(composedView: sampleView)
}
