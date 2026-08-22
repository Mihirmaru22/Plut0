import SwiftUI
import SwiftData

// MARK: - LifeDesignVariant

enum LifeDesignVariant: String, CaseIterable, Identifiable {
    case mountainAtlas = "Mountain Atlas"
    case travelAtlas   = "Travel Atlas"
    case bucketList    = "Bucket List"

    var id: String { rawValue }

    var shortTitle: String { rawValue }

    var icon: String {
        switch self {
        case .mountainAtlas: return "mountain.2.fill"
        case .travelAtlas:   return "globe.asia.australia.fill"
        case .bucketList:    return "trophy.fill"
        }
    }
}

// MARK: - MacLifeView (Clean Minimalist Executive Life Operating System)

/// Dedicated Standalone Life Section for macOS following LOCA's sleek, unified minimalist dark aesthetic.
struct MacLifeView: View {

    @AppStorage("mac_life_layout_v4") private var selectedVariant: LifeDesignVariant = .mountainAtlas

    var body: some View {
        VStack(spacing: 0) {

            // Top Header: Linear Obsidian Minimalist Precision Bar
            HStack(alignment: .center, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: selectedVariant.icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DS.Theme.accent)

                    Text(selectedVariant.shortTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white)
                }

                Spacer()

                // Sleek Segmented Switcher
                HStack(spacing: 2) {
                    ForEach(LifeDesignVariant.allCases) { variant in
                        let isSelected = selectedVariant == variant
                        Button {
                            withAnimation(.easeInOut(duration: 0.12)) {
                                selectedVariant = variant
                            }
                            Haptics.impact(.light)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: variant.icon)
                                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                Text(variant.shortTitle)
                                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                            }
                            .foregroundStyle(isSelected ? Color.white : DS.Theme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4.5)
                            .background(
                                isSelected ? Color.white.opacity(0.12) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 5)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2.5)
                .background(DS.Theme.sidebar, in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(DS.Theme.border, lineWidth: 1))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(DS.Theme.surface)

            Divider().opacity(0.20)

            // Main Body: Full Canvas for Mountain & Travel Atlas, Scrollable Body for Bucket List
            Group {
                switch selectedVariant {
                case .mountainAtlas:
                    MacTrekAtlasCanvas()
                case .travelAtlas:
                    MacTravelAtlasCanvas()
                case .bucketList:
                    ScrollView {
                        Life2MasterBucketListView()
                            .padding(.horizontal, DS.Space.xl)
                            .padding(.vertical, DS.Space.lg)
                            .frame(maxWidth: 1040, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DS.Color.background)
    }
}

// MARK: =====================================================================
// MARK: 🏛️ LIFE 1: BLUEPRINT & CORE PRINCIPLES
// MARK: =====================================================================

private struct Life1BlueprintPrinciplesView: View {

    @AppStorage("life_north_star_mission") private var northStarMission: String = "Build timeless software, master physical vitality, cultivate unwavering mental clarity, and compound compounding relationships."
    @AppStorage("life_annual_theme_2026") private var annualTheme: String = "Relentless Focus & Peak Craft"

    @State private var isEditingMission = false
    @State private var tempMissionText = ""

    private struct PrincipleItem: Identifiable {
        let id: String
        let title: String
        let maxim: String
        let domain: String
        let icon: String
    }

    private static let defaultPrinciples: [PrincipleItem] = [
        PrincipleItem(id: "1", title: "First Principles Thinking", maxim: "Boil things down to their fundamental truths and reason up from there, rather than reasoning by analogy.", domain: "Wisdom & Intellect", icon: "atom"),
        PrincipleItem(id: "2", title: "Radical Ownership", maxim: "Never blame external conditions. Total accountability over health, craft, outcomes, and emotional state.", domain: "Leadership & Mindset", icon: "shield.fill"),
        PrincipleItem(id: "3", title: "The Compounding Rule", maxim: "Small, consistent 1% daily actions compound exponentially over 5–10 years. Never underestimate consistency.", domain: "Execution & Wealth", icon: "chart.line.uptrend.xyaxis"),
        PrincipleItem(id: "4", title: "Physical Sovereignty", maxim: "Energy and physical resilience are the bedrock of cognitive clarity. Sleep 8 hours, train hard, eat clean.", domain: "Health & Vitality", icon: "bolt.heart.fill"),
        PrincipleItem(id: "5", title: "Essentialism & Deep Focus", maxim: "Say no to the 99% of non-essential noise to pour relentless focus into the vital few high-leverage priorities.", domain: "Craft & Career", icon: "target"),
        PrincipleItem(id: "6", title: "Inner Stillness", maxim: "Protect mental peace above all. Do not react to chaos with chaos; respond with deliberate poise.", domain: "Spiritual & Peace", icon: "leaf.fill")
    ]

    private struct NonNegotiableRule: Identifiable {
        let id: String
        let rule: String
        let frequency: String
    }

    private static let defaultRules: [NonNegotiableRule] = [
        NonNegotiableRule(id: "r1", rule: "No screens or social media for the first 60 minutes after waking", frequency: "Daily Morning"),
        NonNegotiableRule(id: "r2", rule: "Never break high-priority standards 2 days in a row", frequency: "Universal Law"),
        NonNegotiableRule(id: "r3", rule: "Minimum 45 minutes of strenuous physical exertion", frequency: "Daily Habit"),
        NonNegotiableRule(id: "r4", rule: "Read at least 20 pages of high-density books before sleep", frequency: "Daily Evening"),
        NonNegotiableRule(id: "r5", rule: "Weekly complete digital & strategic life review", frequency: "Every Sunday")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xl) {

            // North Star & Mission Manifesto Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Color.textSecondary)
                        Text("PERSONAL NORTH STAR MANIFESTO")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(DS.Color.textTertiary)
                            .tracking(0.8)
                    }

                    Spacer()

                    Button {
                        if isEditingMission {
                            northStarMission = tempMissionText
                            isEditingMission = false
                        } else {
                            tempMissionText = northStarMission
                            isEditingMission = true
                        }
                    } label: {
                        Text(isEditingMission ? "Save" : "Edit")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DS.Color.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(DS.Color.surfaceRecessed, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }

                if isEditingMission {
                    TextField("Enter your personal mission statement…", text: $tempMissionText, axis: .vertical)
                        .font(DS.Text.body)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...5)
                } else {
                    Text("“\(northStarMission)”")
                        .font(.system(size: 16, weight: .medium, design: .serif))
                        .foregroundStyle(DS.Color.textPrimary)
                        .lineSpacing(5)
                        .italic()
                }

                Divider()

                HStack {
                    Text("2026 Core Focus Theme:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.Color.textTertiary)

                    Text(annualTheme)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.Color.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(DS.Color.surfaceRecessed, in: Capsule())
                }
            }
            .padding(DS.Space.xl)
            .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.card).stroke(DS.Color.border.opacity(0.4), lineWidth: 1))

            // 6 Core Principles Bento Grid
            VStack(alignment: .leading, spacing: DS.Space.md) {
                Text("GUIDING LIFE PRINCIPLES & MAXIMS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DS.Color.textTertiary)
                    .tracking(0.8)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 280, maximum: 440), spacing: DS.Space.md)],
                    spacing: DS.Space.md
                ) {
                    ForEach(Self.defaultPrinciples) { principle in
                        principleCard(principle)
                    }
                }
            }

            // Daily Non-Negotiables Rulebook
            VStack(alignment: .leading, spacing: DS.Space.md) {
                Text("PERSONAL NON-NEGOTIABLES & CODES")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DS.Color.textTertiary)
                    .tracking(0.8)

                VStack(spacing: 0) {
                    ForEach(Array(Self.defaultRules.enumerated()), id: \.element.id) { idx, rule in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(DS.Color.textTertiary)
                                .frame(width: 6, height: 6)

                            Text(rule.rule)
                                .font(DS.Text.body)
                                .foregroundStyle(DS.Color.textPrimary)

                            Spacer()

                            Text(rule.frequency)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(DS.Color.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(DS.Color.surfaceRecessed, in: Capsule())
                        }
                        .padding(.horizontal, DS.Space.lg)
                        .padding(.vertical, DS.Space.md)

                        if idx != Self.defaultRules.count - 1 {
                            Divider().padding(.leading, 32)
                        }
                    }
                }
                .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.card).stroke(DS.Color.border.opacity(0.4), lineWidth: 1))
            }
        }
    }

    private func principleCard(_ p: PrincipleItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: p.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(DS.Color.textSecondary)
                Text(p.domain.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DS.Color.textTertiary)
                    .tracking(0.6)

                Spacer()
            }

            Text(p.title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(DS.Color.textPrimary)

            Text(p.maxim)
                .font(.system(size: 12))
                .foregroundStyle(DS.Color.textSecondary)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DS.Space.lg)
        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .stroke(DS.Color.border.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: =====================================================================
// MARK: 🎯 LIFE 2: MASTER BUCKET LIST (Clean Minimalist Grid)
// MARK: =====================================================================

private struct Life2MasterBucketListView: View {

    enum BucketCategory: String, CaseIterable, Identifiable, Codable {
        case all        = "All Dreams"
        case travel     = "Travel & World"
        case master     = "Craft & Mastery"
        case physical   = "Fitness & Feats"
        case lifestyle  = "Living & Legacy"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .all:       return "square.grid.2x2"
            case .travel:    return "airplane.departure"
            case .master:    return "sparkles"
            case .physical:  return "figure.run"
            case .lifestyle: return "house.fill"
            }
        }
    }

    @State private var selectedCategory: BucketCategory = .all
    @State private var showingAddSheet = false

    private struct BucketItem: Identifiable, Equatable, Codable {
        let id: String
        var title: String
        var category: BucketCategory
        var targetHorizon: String
        var isAchieved: Bool
        var achievedYear: String?
        var locationOrNotes: String
    }

    @State private var bucketItems: [BucketItem] = []

    private func loadBucketItems() {
        if let data = UserDefaults.standard.data(forKey: "pluto_bucket_items_v1"),
           let decoded = try? JSONDecoder().decode([BucketItem].self, from: data) {
            bucketItems = decoded
        } else {
            bucketItems = []
        }
    }

    private func saveBucketItems() {
        if let encoded = try? JSONEncoder().encode(bucketItems) {
            UserDefaults.standard.set(encoded, forKey: "pluto_bucket_items_v1")
        }
    }

    @State private var newTitle = ""
    @State private var newCategory: BucketCategory = .travel
    @State private var newHorizon = "2027"
    @State private var newNotes = ""

    private var filteredItems: [BucketItem] {
        if selectedCategory == .all {
            return bucketItems
        }
        return bucketItems.filter { $0.category == selectedCategory }
    }

    private var achievedCount: Int {
        bucketItems.filter { $0.isAchieved }.count
    }

    private var completionRate: Double {
        guard !bucketItems.isEmpty else { return 0 }
        return Double(achievedCount) / Double(bucketItems.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.lg) {

            // Clean Minimalist Bucket List Header Banner
            VStack(alignment: .leading, spacing: DS.Space.md) {
                HStack(spacing: DS.Space.xl) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MASTER BUCKET LIST")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(DS.Color.textTertiary)
                            .tracking(0.8)

                        HStack(alignment: .lastTextBaseline, spacing: 8) {
                            Text("\(achievedCount) of \(bucketItems.count)")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(DS.Color.textPrimary)
                                .monospacedDigit()

                            Text("Dreams Realized (\(Int(completionRate * 100))%)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(DS.Color.success)
                        }

                        Text("Live intentionally. Every year is an opportunity to cross off lifetime milestones.")
                            .font(DS.Text.caption)
                            .foregroundStyle(DS.Color.textTertiary)
                    }

                    Spacer()

                    // Minimalist Progress Ring
                    ZStack {
                        Circle()
                            .stroke(DS.Color.surfaceRecessed, lineWidth: 5)
                            .frame(width: 52, height: 52)
                        Circle()
                            .trim(from: 0, to: CGFloat(completionRate))
                            .stroke(DS.Color.success, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .frame(width: 52, height: 52)
                            .rotationEffect(.degrees(-90))

                        Text("\(Int(completionRate * 100))%")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DS.Color.textPrimary)
                    }
                }

                Divider()

                // Clean Category Count Badges
                HStack(spacing: 12) {
                    categoryStatChip(cat: .travel, count: countFor(.travel))
                    categoryStatChip(cat: .master, count: countFor(.master))
                    categoryStatChip(cat: .physical, count: countFor(.physical))
                    categoryStatChip(cat: .lifestyle, count: countFor(.lifestyle))
                    Spacer()
                }
            }
            .padding(DS.Space.xl)
            .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.card).stroke(DS.Color.border.opacity(0.4), lineWidth: 1))

            // Clean Filter Pills Row + Add Dream Button
            HStack(spacing: 6) {
                ForEach(BucketCategory.allCases) { cat in
                    let isSelected = selectedCategory == cat
                    Button {
                        selectedCategory = cat
                        Haptics.impact(.light)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 10))
                            Text(cat.rawValue)
                                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                        }
                        .foregroundStyle(isSelected ? DS.Color.textPrimary : DS.Color.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            isSelected ? DS.Color.surfaceRecessed : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? DS.Color.border.opacity(0.6) : DS.Color.border.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button {
                    showingAddSheet = true
                    Haptics.impact(.light)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("Add Dream")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(DS.Color.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(DS.Color.surfaceRecessed, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(DS.Color.border.opacity(0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingAddSheet) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add to Master Bucket List")
                            .font(.system(size: 13, weight: .bold))

                        TextField("Dream title (e.g., Visit Iceland)", text: $newTitle)
                            .textFieldStyle(.roundedBorder)

                        Picker("Category", selection: $newCategory) {
                            Text("Travel & World").tag(BucketCategory.travel)
                            Text("Craft & Mastery").tag(BucketCategory.master)
                            Text("Fitness & Feats").tag(BucketCategory.physical)
                            Text("Living & Legacy").tag(BucketCategory.lifestyle)
                        }

                        TextField("Target Year (e.g. 2027 or Lifetime)", text: $newHorizon)
                            .textFieldStyle(.roundedBorder)

                        TextField("Location / Details", text: $newNotes)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            Button("Cancel") { showingAddSheet = false }
                            Spacer()
                            Button("Add Dream") {
                                if !newTitle.isEmpty {
                                    let item = BucketItem(
                                        id: UUID().uuidString,
                                        title: newTitle,
                                        category: newCategory,
                                        targetHorizon: newHorizon,
                                        isAchieved: false,
                                        achievedYear: nil,
                                        locationOrNotes: newNotes
                                    )
                                    bucketItems.append(item)
                                    saveBucketItems()
                                    newTitle = ""
                                    newNotes = ""
                                    showingAddSheet = false
                                    PlutoSoundEngine.shared.play(.checkmark)
                                    Haptics.impact(.rigid)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(newTitle.isEmpty)
                        }
                    }
                    .padding(DS.Space.lg)
                    .frame(width: 300)
                }
            }

            // Minimalist Bucket List Cards Grid (Uniform Dark Surface with Subtle Neutral Borders)
            if filteredItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundStyle(DS.Color.textTertiary)
                    Text("No bucket list dreams in this category")
                        .font(DS.Text.body)
                        .foregroundStyle(DS.Color.textTertiary)
                    Text("Click '+ Add Dream' to log your lifetime milestones.")
                        .font(DS.Text.caption)
                        .foregroundStyle(DS.Color.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(DS.Space.xxl)
                .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.card).stroke(DS.Color.border.opacity(0.4), lineWidth: 1))
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 280, maximum: 460), spacing: DS.Space.md)],
                    spacing: DS.Space.md
                ) {
                    ForEach(filteredItems) { item in
                        minimalistBucketItemCard(item)
                    }
                }
            }
        }
        .onAppear {
            loadBucketItems()
        }
        .onReceive(NotificationCenter.default.publisher(for: .plutoDataDidReset)) { _ in
            loadBucketItems()
        }
    }

    private func countFor(_ cat: BucketCategory) -> Int {
        bucketItems.filter { $0.category == cat }.count
    }

    private func categoryStatChip(cat: BucketCategory, count: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: cat.icon)
                .font(.system(size: 9))
                .foregroundStyle(DS.Color.textTertiary)
            Text("\(count) \(cat.rawValue.components(separatedBy: " & ").first ?? cat.rawValue)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    private func minimalistBucketItemCard(_ item: BucketItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {

            // Top Row: Category Tag Pill + Checkmark Button
            HStack(alignment: .center) {
                HStack(spacing: 4) {
                    Image(systemName: item.category.icon)
                        .font(.system(size: 9))
                        .foregroundStyle(DS.Color.textSecondary)
                    Text(item.category.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DS.Color.textTertiary)
                        .tracking(0.6)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(DS.Color.surfaceRecessed, in: RoundedRectangle(cornerRadius: 4))

                Spacer()

                // Checkbox toggle
                Button {
                    if let idx = bucketItems.firstIndex(where: { $0.id == item.id }) {
                        bucketItems[idx].isAchieved.toggle()
                        bucketItems[idx].achievedYear = bucketItems[idx].isAchieved ? "2026" : nil
                        saveBucketItems()
                        if bucketItems[idx].isAchieved {
                            PlutoSoundEngine.shared.play(.summitPassport)
                        } else {
                            PlutoSoundEngine.shared.play(.checkmark)
                        }
                        Haptics.impact(.rigid)
                    }
                } label: {
                    Image(systemName: item.isAchieved ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundStyle(item.isAchieved ? DS.Color.success : DS.Color.textTertiary)
                }
                .buttonStyle(.plain)

                // Delete Button
                Button {
                    if let idx = bucketItems.firstIndex(where: { $0.id == item.id }) {
                        bucketItems.remove(at: idx)
                        saveBucketItems()
                        PlutoSoundEngine.shared.play(.deleteTrash)
                        Haptics.impact(.light)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Color.textTertiary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Delete Dream")
            }

            // Title
            Text(item.title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(item.isAchieved ? DS.Color.textSecondary : DS.Color.textPrimary)
                .strikethrough(item.isAchieved)
                .lineLimit(2)

            // Location / Notes with Pin Icon
            if !item.locationOrNotes.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 9))
                        .foregroundStyle(DS.Color.textTertiary)

                    Text(item.locationOrNotes)
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Color.textSecondary)
                        .lineLimit(1)
                }
            }

            Divider()

            // Footer: Horizon & Status Tag
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 9))
                        .foregroundStyle(DS.Color.textTertiary)
                    Text("Horizon: \(item.targetHorizon)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.Color.textSecondary)
                }

                Spacer()

                if item.isAchieved {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                        Text("Achieved \(item.achievedYear ?? "")")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(DS.Color.success)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DS.Color.success.opacity(0.12), in: Capsule())
                } else {
                    Text("Dream Active")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(DS.Color.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DS.Color.surfaceRecessed, in: Capsule())
                }
            }
        }
        .padding(DS.Space.lg)
        .background(DS.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .stroke(DS.Color.border.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: =====================================================================
// MARK: ⏳ LIFE 3: LIFE ERAS & CHRONOLOGY
// MARK: =====================================================================

private struct Life3LifeErasChronologyView: View {

    @AppStorage("user_current_age_v2") private var configuredAge: Int = 22
    @AppStorage("user_birth_year") private var birthYear: Int = 2004
    @AppStorage("user_target_lifespan_v3") private var targetLifespanYears: Int = 75

    private var currentAge: Int {
        max(1, configuredAge)
    }

    private var lifeElapsedFraction: Double {
        min(1.0, Double(currentAge) / Double(targetLifespanYears))
    }

    private struct LifeEraItem: Identifiable {
        let id: String
        let eraTitle: String
        let timeframe: String
        let coreTheme: String
        let keyMilestone: String
        let isActive: Bool
    }

    private static let sampleEras: [LifeEraItem] = [
        LifeEraItem(id: "1", eraTitle: "The Foundation & Exploration Era", timeframe: "2004 – 2022", coreTheme: "Curiosity, foundational schooling, early programming & philosophy.", keyMilestone: "First lines of code, core systems fascination & university entry.", isActive: false),
        LifeEraItem(id: "2", eraTitle: "The Builder & Sovereignty Era", timeframe: "2023 – 2028", coreTheme: "Deep focus on independent craft, local-first engineering, circadian health mastery.", keyMilestone: "Shipped PLUTO Sovereign OS local-first productivity powerhouse.", isActive: true),
        LifeEraItem(id: "3", eraTitle: "The Global Impact & Legacy Era", timeframe: "2029 – 2040", coreTheme: "Scaling ventures, global expeditions, mentoring, and enduring contributions.", keyMilestone: "Full geopolitical freedom & multi-generational impact.", isActive: false)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xl) {

            // Life Perspective Header Banner
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text("\(targetLifespanYears)-YEAR LIFE HORIZON (MEMENTO MORI)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(DS.Color.textTertiary)
                                .tracking(0.8)

                            // Horizon Preset Switcher Chips
                            HStack(spacing: 4) {
                                ForEach([70, 75, 80, 85, 90], id: \.self) { yrs in
                                    let isSelected = targetLifespanYears == yrs
                                    Button {
                                        targetLifespanYears = yrs
                                        PlutoSoundEngine.shared.play(.tabSwitch)
                                        Haptics.impact(.light)
                                    } label: {
                                        Text(yrs == 75 ? "\(yrs)y 🇮🇳" : "\(yrs)y")
                                            .font(.system(size: 9, weight: isSelected ? .bold : .medium))
                                            .foregroundStyle(isSelected ? Color.white : DS.Color.textTertiary)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(
                                                isSelected ? Color.orange.opacity(0.3) : Color.white.opacity(0.04),
                                                in: RoundedRectangle(cornerRadius: 4)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Text("Age \(currentAge) of \(targetLifespanYears) (\(String(format: "%.1f", lifeElapsedFraction * 100))% of Life Timeline)")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(DS.Color.textPrimary)
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Button {
                            if configuredAge > 1 {
                                configuredAge -= 1
                                PlutoSoundEngine.shared.play(.tabSwitch)
                                Haptics.impact(.light)
                            }
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(DS.Color.textSecondary)
                                .frame(width: 20, height: 20)
                                .background(DS.Color.surfaceRecessed, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Decrease Age")

                        Text("\(max(0, targetLifespanYears - currentAge)) years ahead")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DS.Color.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(DS.Color.surfaceRecessed, in: Capsule())

                        Button {
                            if configuredAge < targetLifespanYears {
                                configuredAge += 1
                                PlutoSoundEngine.shared.play(.tabSwitch)
                                Haptics.impact(.light)
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(DS.Color.textSecondary)
                                .frame(width: 20, height: 20)
                                .background(DS.Color.surfaceRecessed, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Increase Age")
                    }
                }

                // Perspective Life Bar
                GeometryReader { p in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(DS.Color.surfaceRecessed)
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(DS.Color.success)
                            .frame(width: max(0, p.size.width * CGFloat(lifeElapsedFraction)), height: 6)
                    }
                }
                .frame(height: 6)

                Text("Time is the ultimate non-renewable resource. Focus on what truly moves the needle.")
                    .font(DS.Text.caption)
                    .foregroundStyle(DS.Color.textTertiary)
            }
            .padding(DS.Space.xl)
            .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.card).stroke(DS.Color.border.opacity(0.4), lineWidth: 1))

            // Life Matrix
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                HStack {
                    Text("\(targetLifespanYears)-YEAR LIFE PERSPECTIVE MATRIX (1 BLOCK = 1 YEAR)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DS.Color.textTertiary)
                        .tracking(0.8)
                    Spacer()
                    Text("● Past (\(currentAge)) · ○ Future (\(max(0, targetLifespanYears - currentAge)))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DS.Color.textTertiary)
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 15),
                    spacing: 4
                ) {
                    ForEach(1...targetLifespanYears, id: \.self) { yr in
                        let isPast = yr < currentAge
                        let isCurrent = yr == currentAge
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                isCurrent ? DS.Color.success :
                                isPast ? Color(red: 0.28, green: 0.35, blue: 0.48) :
                                DS.Color.surfaceRecessed
                            )
                            .frame(height: 12)
                            .help("Year \(yr) (Age \(yr))")
                    }
                }
                .padding(DS.Space.lg)
                .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.card).stroke(DS.Color.border.opacity(0.4), lineWidth: 1))
            }

            // Life Eras & Chapters Timeline
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                Text("LIFE CHAPTERS & DEFINED ERAS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DS.Color.textTertiary)
                    .tracking(0.8)

                VStack(spacing: DS.Space.md) {
                    ForEach(Self.sampleEras) { era in
                        eraTimelineCard(era)
                    }
                }
            }
        }
    }

    private func eraTimelineCard(_ era: LifeEraItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(era.timeframe)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DS.Color.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DS.Color.surfaceRecessed, in: RoundedRectangle(cornerRadius: 4))

                Spacer()

                if era.isActive {
                    Text("Active Era")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DS.Color.success)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DS.Color.success.opacity(0.12), in: Capsule())
                }
            }

            Text(era.eraTitle)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(DS.Color.textPrimary)

            Text(era.coreTheme)
                .font(.system(size: 12))
                .foregroundStyle(DS.Color.textSecondary)

            Divider()

            HStack {
                Text("Key Milestone:")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DS.Color.textTertiary)

                Text(era.keyMilestone)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DS.Color.textPrimary)
            }
        }
        .padding(DS.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .stroke(DS.Color.border.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: =====================================================================
// MARK: 💎 LIFE 4: SELF-MASTERY & LIFE AUDITS
// MARK: =====================================================================

private struct Life4SelfMasteryAuditsView: View {

    @State private var energyScore: Double = 8
    @State private var focusScore: Double = 9
    @State private var clarityScore: Double = 8
    @State private var socialScore: Double = 7
    @State private var wealthScore: Double = 8

    @State private var weeklyReflection: String = ""
    @State private var auditSaved = false

    private struct MentalModelItem: Identifiable {
        let id: String
        let name: String
        let description: String
        let application: String
    }

    private static let mentalModels: [MentalModelItem] = [
        MentalModelItem(id: "1", name: "Inversion (Carl Jacobi)", description: "Instead of asking how to succeed, ask how you could completely fail — then meticulously avoid those traps.", application: "Avoid burnout, poor sleep, distractions, and emotional over-reactivity."),
        MentalModelItem(id: "2", name: "Second-Order Thinking", description: "First-order thinking asks 'What happens next?' Second-order thinking asks 'And then what?'", application: "Evaluate long-term consequences over instant comfort."),
        MentalModelItem(id: "3", name: "Pareto 80/20 Leverage", description: "80% of profound life results originate from 20% of critical vital leverage inputs.", application: "Double down on core strengths, eliminate non-essential commitments.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xl) {

            // Life Audit Studio Card
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("WEEKLY LIFE AUDIT & CALIBRATION")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(DS.Color.textTertiary)
                            .tracking(0.8)

                        Text("Self-Mastery Calibration")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(DS.Color.textPrimary)
                    }

                    Spacer()

                    Button {
                        auditSaved = true
                        Haptics.impact(.rigid)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            auditSaved = false
                        }
                    } label: {
                        Text(auditSaved ? "Audit Logged ✓" : "Record Audit")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DS.Color.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(DS.Color.surfaceRecessed, in: RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(DS.Color.border.opacity(0.5), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Divider()

                // 5 Sliders
                VStack(spacing: 10) {
                    auditSlider(title: "Vitality & Physical Energy", value: $energyScore)
                    auditSlider(title: "Deep Focus & Output Velocity", value: $focusScore)
                    auditSlider(title: "Mental Clarity & Emotional Calm", value: $clarityScore)
                    auditSlider(title: "Relationships & Deep Presence", value: $socialScore)
                    auditSlider(title: "Financial Discipline & Growth", value: $wealthScore)
                }

                Divider()

                // Reflection Note
                VStack(alignment: .leading, spacing: 6) {
                    Text("Key Insight or Calibration for Next Cycle:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.Color.textSecondary)

                    TextField("What single habit or system will unlock maximum leverage this week?…", text: $weeklyReflection)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(DS.Space.xl)
            .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.card).stroke(DS.Color.border.opacity(0.4), lineWidth: 1))

            // Mental Models & Wisdom Vault
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                Text("MENTAL MODELS & WISDOM VAULT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DS.Color.textTertiary)
                    .tracking(0.8)

                VStack(spacing: DS.Space.md) {
                    ForEach(Self.mentalModels) { model in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(model.name)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(DS.Color.textPrimary)

                                Spacer()
                            }

                            Text(model.description)
                                .font(.system(size: 11))
                                .foregroundStyle(DS.Color.textSecondary)
                                .lineSpacing(2)

                            Divider()

                            HStack {
                                Text("Life Application:")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(DS.Color.textTertiary)

                                Text(model.application)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(DS.Color.textPrimary)
                            }
                        }
                        .padding(DS.Space.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.card)
                                .stroke(DS.Color.border.opacity(0.4), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    private func auditSlider(title: String, value: Binding<Double>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DS.Color.textSecondary)
                .frame(width: 220, alignment: .leading)

            Slider(value: value, in: 1...10, step: 1)

            Text("\(Int(value.wrappedValue)) / 10")
                .font(.system(size: 12, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(DS.Color.textPrimary)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(DS.Space.md)
        .background(DS.Color.surfaceRecessed.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    }
}
