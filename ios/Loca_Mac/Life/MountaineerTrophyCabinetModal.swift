import SwiftUI
import SwiftData

// MARK: - MountaineerTrophyCabinetModal

/// Glassmorphic achievement and trophy cabinet showcase for Pluto's Trek Atlas.
/// Features dynamic Explorer Mountaineer ranks, progress bars, and 12 expedition achievement shields.
struct MountaineerTrophyCabinetModal: View {

    @Environment(\.modelContext) private var modelContext

    let conqueredTreks: [TrekRecord]
    let allTreks: [TrekRecord]
    let onDismiss: () -> Void

    @State private var selectedCategory: TrophyCategory = .all
    @State private var inspectedBadge: MountaineerBadge? = nil
    @State private var showResetConfirmation: Bool = false

    enum TrophyCategory: String, CaseIterable, Identifiable {
        case all        = "All Trophies"
        case unlocked   = "🔓 Unlocked"
        case inProgress = "🔒 In Progress"
        case regional   = "🇮🇳 Regional"

        var id: String { rawValue }
    }

    private var currentRank: ExplorerRank {
        MountaineerRankEngine.currentRank(conqueredTreks: conqueredTreks)
    }

    private var nextRankInfo: (nextRank: ExplorerRank?, progress: Double, remainingSummits: Int) {
        MountaineerRankEngine.nextRankProgress(conqueredTreks: conqueredTreks)
    }

    private var allBadges: [MountaineerBadge] {
        MountaineerRankEngine.evaluateBadges(conqueredTreks: conqueredTreks, allTreks: allTreks)
    }

    private var filteredBadges: [MountaineerBadge] {
        switch selectedCategory {
        case .all:
            return allBadges
        case .unlocked:
            return allBadges.filter(\.isUnlocked)
        case .inProgress:
            return allBadges.filter { !$0.isUnlocked }
        case .regional:
            return allBadges.filter { $0.category.contains("Regional") }
        }
    }

    private var unlockedCount: Int {
        allBadges.filter(\.isUnlocked).count
    }

    private var totalVerticalGainMeters: Double {
        conqueredTreks.compactMap(\.elevationGainMeters).reduce(0, +)
    }

    private var totalDistanceKm: Double {
        conqueredTreks.compactMap(\.trailDistanceKm).reduce(0, +)
    }

    var body: some View {
        VStack(spacing: 0) {

            // Top Header with Reset and Close Buttons
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.yellow)
                    Text("Mountaineer Trophy Cabinet")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DS.Color.textPrimary)
                }

                Spacer()

                // Reset Mountain Data Button
                Button {
                    showResetConfirmation = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10, weight: .bold))
                        Text("Reset Progress")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Color.red.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .confirmationDialog("Reset Mountain Progress?", isPresented: $showResetConfirmation, titleVisibility: .visible) {
                    Button("Reset All to Unclimbed", role: .destructive) {
                        TrekSeeder.resetAllTreks(context: modelContext)
                        PlutoSoundEngine.shared.play(.deleteTrash)
                        Haptics.notify(.success)
                    }
                    Button("Reseed Default Catalog", role: .destructive) {
                        TrekSeeder.reseedAllTreks(context: modelContext)
                        PlutoSoundEngine.shared.play(.completePop)
                        Haptics.notify(.success)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will mark all mountain peaks as unclimbed and reset your summit trophies, altitude, and ascent records.")
                }

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(DS.Color.textSecondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, DS.Space.xl)
            .padding(.top, DS.Space.lg)
            .padding(.bottom, DS.Space.md)

            Divider()

            ScrollView {
                VStack(spacing: DS.Space.xl) {

                    // MARK: - Rank Banner Card
                    rankProgressHeroCard

                    // MARK: - Category Filter Pills
                    categoryFilterBar

                    // MARK: - 3-Column Badges Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Space.md) {
                        ForEach(filteredBadges) { badge in
                            badgeTile(badge: badge)
                                .onTapGesture {
                                    inspectedBadge = badge
                                    Haptics.impact(.light)
                                }
                        }
                    }
                }
                .padding(DS.Space.xl)
            }
        }
        .frame(minWidth: 780, idealWidth: 840, maxWidth: .infinity, minHeight: 560, idealHeight: 620, maxHeight: .infinity)
        .background(DS.Color.background)
        .popover(item: $inspectedBadge) { badge in
            badgeDetailPopover(badge: badge)
        }
    }

    // MARK: - Rank Progress Hero Card

    private var rankProgressHeroCard: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            HStack(spacing: DS.Space.lg) {
                // Crest Badge Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [currentRank.accentColor.opacity(0.35), currentRank.accentColor.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .overlay(Circle().stroke(currentRank.accentColor.opacity(0.6), lineWidth: 2))

                    Image(systemName: currentRank.icon)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(currentRank.accentColor)
                }

                // Rank Title & Details
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(currentRank.title.uppercased())
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(DS.Color.textPrimary)

                        Text("RANK \(currentRank.rawValue) OF 6")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(currentRank.accentColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(currentRank.accentColor.opacity(0.15), in: Capsule())
                    }

                    Text(currentRank.subtitle)
                        .font(DS.Text.caption)
                        .foregroundStyle(DS.Color.textSecondary)

                    // Next Rank Progress
                    if let next = nextRankInfo.nextRank {
                        HStack(spacing: 8) {
                            ProgressView(value: nextRankInfo.progress)
                                .tint(currentRank.accentColor)
                                .frame(width: 180)

                            Text("\(nextRankInfo.remainingSummits) more summits to \(next.title)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(DS.Color.textTertiary)
                        }
                        .padding(.top, 4)
                    } else {
                        Text("🌟 Maximum Rank Achieved — Living Legend")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.yellow)
                            .padding(.top, 4)
                    }
                }

                Spacer()

                // Telemetry Quick Stats
                HStack(spacing: DS.Space.md) {
                    statBox(title: "TROPHIES", value: "\(unlockedCount)/\(allBadges.count)", color: Color.yellow)
                    statBox(title: "VERTICAL", value: "\(Int(totalVerticalGainMeters).formatted()) m", color: Color.cyan)
                    statBox(title: "DISTANCE", value: String(format: "%.0f km", totalDistanceKm), color: Color.green)
                }
            }
        }
        .padding(DS.Space.lg)
        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .stroke(currentRank.accentColor.opacity(0.3), lineWidth: 1)
        )
    }

    private func statBox(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(DS.Color.textTertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Category Filter Bar

    private var categoryFilterBar: some View {
        HStack(spacing: DS.Space.sm) {
            ForEach(TrophyCategory.allCases) { category in
                let isSelected = selectedCategory == category
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        selectedCategory = category
                    }
                    Haptics.impact(.light)
                } label: {
                    Text(category.rawValue)
                        .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? Color.white : DS.Color.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            isSelected ? Color(red: 0.38, green: 0.45, blue: 0.98) : DS.Color.surfaceRecessed,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - Badge Tile View

    private func badgeTile(badge: MountaineerBadge) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack {
                // Badge Icon with Glow
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            badge.isUnlocked
                                ? badge.tierColor.opacity(0.2)
                                : Color.white.opacity(0.04)
                        )
                        .frame(width: 42, height: 42)

                    Image(systemName: badge.icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(badge.isUnlocked ? badge.tierColor : DS.Color.textTertiary)
                }

                Spacer()

                if badge.isUnlocked {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(badge.tierColor)
                } else {
                    Text(badge.formattedProgress)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.Color.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.04), in: Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(badge.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(badge.isUnlocked ? DS.Color.textPrimary : DS.Color.textSecondary)
                    .lineLimit(1)

                Text(badge.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(DS.Color.textTertiary)
                    .lineLimit(2)
                    .frame(height: 26, alignment: .topLeading)
            }

            // Progress Bar if in progress
            if !badge.isUnlocked {
                ProgressView(value: badge.progress)
                    .tint(badge.tierColor.opacity(0.8))
                    .padding(.top, 2)
            } else if let date = badge.unlockedDate {
                HStack(spacing: 3) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 8))
                    Text("Unlocked \(date.formatted(.dateTime.month().year()))")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(badge.tierColor.opacity(0.9))
                .padding(.top, 2)
            }
        }
        .padding(DS.Space.md)
        .background(
            badge.isUnlocked ? Color.white.opacity(0.05) : DS.Color.surfaceRecessed.opacity(0.4),
            in: RoundedRectangle(cornerRadius: DS.Radius.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .stroke(
                    badge.isUnlocked ? badge.tierColor.opacity(0.5) : Color.white.opacity(0.06),
                    lineWidth: badge.isUnlocked ? 1.5 : 1
                )
        )
    }

    // MARK: - Badge Detail Popover

    private func badgeDetailPopover(badge: MountaineerBadge) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(badge.tierColor.opacity(0.2))
                        .frame(width: 48, height: 48)
                    Image(systemName: badge.icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(badge.tierColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(badge.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DS.Color.textPrimary)

                    Text(badge.category)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(badge.tierColor)
                }

                Spacer()

                if badge.isUnlocked {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                        Text("UNLOCKED")
                    }
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(badge.tierColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(badge.tierColor.opacity(0.15), in: Capsule())
                }
            }

            Divider()

            Text(badge.subtitle)
                .font(.system(size: 12))
                .foregroundStyle(DS.Color.textSecondary)

            if !badge.contributingTreks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Contributing Expeditions:")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(DS.Color.textTertiary)

                    ForEach(badge.contributingTreks, id: \.self) { trekName in
                        HStack(spacing: 6) {
                            Image(systemName: "mountain.2.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(badge.tierColor)
                            Text(trekName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(DS.Color.textPrimary)
                        }
                    }
                }
                .padding(8)
                .background(DS.Color.surfaceRecessed, in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(DS.Space.lg)
        .frame(width: 320)
        .background(DS.Color.surface)
    }
}
