import SwiftUI
import Charts

/// High-fidelity SwiftCharts alpine elevation visualizer for the Winter Arc Season Ridge.
/// Reuses the Trek Atlas mountain rendering philosophy with cyan/crimson glowing gradients,
/// missed-day valleys, and summit milestone flag.
public struct GhostRidgeProfileChart: View {
    public let points: [GhostRidgePoint]
    public var onSelectPoint: ((GhostRidgePoint?) -> Void)? = nil

    @State private var hoveredDayIndex: Int? = nil

    public init(
        points: [GhostRidgePoint],
        onSelectPoint: ((GhostRidgePoint?) -> Void)? = nil
    ) {
        self.points = points
        self.onSelectPoint = onSelectPoint
    }

    private var currentHoveredPoint: GhostRidgePoint? {
        guard let idx = hoveredDayIndex else { return nil }
        return points.first(where: { $0.dayIndex == idx })
    }

    private var minAlt: Double {
        (points.map(\.elevationMeters).min() ?? 800) * 0.95
    }

    private var maxAlt: Double {
        (points.map(\.elevationMeters).max() ?? 5000) * 1.10
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header HUD
            HStack(spacing: 12) {
                if let pt = currentHoveredPoint {
                    HStack(spacing: 6) {
                        Text("Day \(pt.dayIndex)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white)
                        Text("•")
                            .foregroundStyle(Color.white.opacity(0.3))
                        Text(pt.dateString)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.7))
                        Text("•")
                            .foregroundStyle(Color.white.opacity(0.3))
                        Text(pt.isGhostDay ? "🔥 Ghost Day (Score \(pt.score))" : "Score: \(pt.score)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(pt.isGhostDay ? Color(red: 0.0, green: 0.8, blue: 1.0) : Color.white.opacity(0.6))
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "mountain.2.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(red: 0.0, green: 0.8, blue: 1.0))
                        Text("SEASON RIDGE ELEVATION PROFILE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .tracking(1.0)
                    }
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "flag.checkered.2.crossed")
                        .font(.system(size: 10))
                    Text("Dec 31 Summit")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                }
                .foregroundStyle(Color.orange.opacity(0.85))
            }
            .padding(.horizontal, 4)

            // SwiftChart Canvas
            Chart {
                ForEach(points) { pt in
                    // Area Gradient Fill
                    AreaMark(
                        x: .value("Day", pt.dayIndex),
                        yStart: .value("Base", minAlt),
                        yEnd: .value("Altitude", pt.elevationMeters)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.0, green: 0.6, blue: 0.9).opacity(0.35),
                                Color(red: 0.05, green: 0.08, blue: 0.15).opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.monotone)

                    // Line Contour
                    LineMark(
                        x: .value("Day", pt.dayIndex),
                        y: .value("Altitude", pt.elevationMeters)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.0, green: 0.85, blue: 1.0),
                                Color(red: 0.88, green: 0.45, blue: 0.12)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)

                    // Today Marker
                    if pt.isToday {
                        RuleMark(x: .value("Today", pt.dayIndex))
                            .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .annotation(position: .top) {
                                Text("TODAY")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color.black)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color(red: 0.0, green: 0.85, blue: 1.0), in: RoundedRectangle(cornerRadius: 3))
                            }
                    }

                    // Summit Flag at Season End
                    if pt.isSummitMarker {
                        PointMark(
                            x: .value("Summit", pt.dayIndex),
                            y: .value("Altitude", pt.elevationMeters)
                        )
                        .symbol {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.orange)
                                .shadow(color: Color.orange.opacity(0.6), radius: 4)
                        }
                    }
                }
            }
            .chartXScale(domain: 1...(points.count > 0 ? points.count : 120))
            .chartYScale(domain: minAlt...maxAlt)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 8)) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                        .foregroundStyle(Color.white.opacity(0.08))
                    AxisValueLabel {
                        if let intVal = val.as(Int.self) {
                            Text("D\(intVal)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                        .foregroundStyle(Color.white.opacity(0.08))
                    AxisValueLabel {
                        if let alt = val.as(Double.self) {
                            Text("\(Int(alt))m")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.3))
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                if let dayIndex: Int = proxy.value(atX: location.x) {
                                    hoveredDayIndex = dayIndex
                                    let found = points.first(where: { $0.dayIndex == dayIndex })
                                    onSelectPoint?(found)
                                }
                            case .ended:
                                hoveredDayIndex = nil
                                onSelectPoint?(nil)
                            }
                        }
                }
            }
            .frame(height: 180)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.06, green: 0.06, blue: 0.08))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }
}
