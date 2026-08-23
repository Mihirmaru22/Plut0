import SwiftUI

/// Contribution-style 120-cell Chain Grid.
/// Each cell renders 3 micro-arcs for Body, Mind, and Silence closures.
/// Hover HUD reveals daily completion; click inspects the Day Ledger.
public struct GhostChainGridView: View {
    public let cells: [GhostEngine.GhostChainCell]
    public var onSelectCell: ((GhostEngine.GhostChainCell) -> Void)? = nil

    @State private var hoveredCell: GhostEngine.GhostChainCell? = nil

    public init(
        cells: [GhostEngine.GhostChainCell],
        onSelectCell: ((GhostEngine.GhostChainCell) -> Void)? = nil
    ) {
        self.cells = cells
        self.onSelectCell = onSelectCell
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header HUD
            HStack {
                if let h = hoveredCell {
                    HStack(spacing: 6) {
                        Text("Day \(h.dayIndex)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white)
                        Text("•")
                            .foregroundStyle(Color.white.opacity(0.3))
                        Text(h.dateString)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.7))
                        Text("•")
                            .foregroundStyle(Color.white.opacity(0.3))
                        Text(h.ghostDay ? "🔥 Ghost Day (Score \(h.score))" : (h.isFuture ? "Pending" : "Score: \(h.score)"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(h.ghostDay ? Color(red: 0.0, green: 0.85, blue: 1.0) : Color.white.opacity(0.6))
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "circle.grid.3x3.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
                        Text("120-DAY DISCIPLINE CHAIN GRID")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .tracking(1.0)
                    }
                }

                Spacer()

                // Legend
                HStack(spacing: 8) {
                    legendItem(color: Color(hex: "#E54D2E"), label: "Body")
                    legendItem(color: Color(hex: "#3E63DD"), label: "Mind")
                    legendItem(color: Color(hex: "#0091FF"), label: "Silence")
                }
            }
            .padding(.horizontal, 2)

            // Grid Cells
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 14, maximum: 20), spacing: 5), count: 15), spacing: 5) {
                ForEach(cells) { cell in
                    chainCellView(cell: cell)
                        .onHover { isHovered in
                            hoveredCell = isHovered ? cell : nil
                        }
                        .onTapGesture {
                            onSelectCell?(cell)
                        }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.06, green: 0.06, blue: 0.08))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    // MARK: - Cell View with 3 Micro-Arcs

    private func chainCellView(cell: GhostEngine.GhostChainCell) -> some View {
        let isHovered = hoveredCell?.id == cell.id

        return ZStack {
            // Background
            RoundedRectangle(cornerRadius: 4)
                .fill(cell.isFuture ? Color.white.opacity(0.02) : Color.white.opacity(0.05))

            if !cell.isFuture {
                // Micro-Arcs Ring Visualization
                ZStack {
                    // Outer: Body (Crimson)
                    Circle()
                        .trim(from: 0, to: cell.bodyClosed ? 1.0 : 0.0)
                        .stroke(Color(hex: "#E54D2E"), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                        .frame(width: 14, height: 14)

                    // Middle: Mind (Indigo)
                    Circle()
                        .trim(from: 0, to: cell.mindClosed ? 1.0 : 0.0)
                        .stroke(Color(hex: "#3E63DD"), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                        .frame(width: 9.5, height: 9.5)

                    // Inner: Silence (Ghost Cyan)
                    Circle()
                        .trim(from: 0, to: cell.silenceClosed ? 1.0 : 0.0)
                        .stroke(Color(hex: "#0091FF"), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                        .frame(width: 5, height: 5)
                }

                // If completely missed past day: broken link dot
                if !cell.ghostDay && !cell.bodyClosed && !cell.mindClosed && !cell.silenceClosed && !cell.isToday {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 3, height: 3)
                }
            }

            // Today Outline
            if cell.isToday {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(red: 0.0, green: 0.85, blue: 1.0), lineWidth: 1.2)
            }
        }
        .frame(height: 18)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isHovered ? Color.white.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.5))
        }
    }
}
