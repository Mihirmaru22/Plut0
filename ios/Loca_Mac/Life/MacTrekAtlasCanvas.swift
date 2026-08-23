import SwiftUI
import SwiftData
import MapKit
import UniformTypeIdentifiers

// MARK: - TrekFilter

enum TrekFilter: String, CaseIterable, Identifiable {
    case all          = "All"
    case conquered    = "Conquered 🏆"
    case unclimbed    = "Unclimbed"
    case himalayas    = "Himalayas"
    case westernGhats = "Western Ghats"
    case gujarat      = "Gujarat"
    case maharashtra  = "Maharashtra"

    var id: String { rawValue }
}

// MARK: - MacTrekAtlasCanvas (Clean Minimalist Mountain Atlas)

struct MacTrekAtlasCanvas: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrekRecord.elevationMeters, order: .reverse) private var allTreks: [TrekRecord]

    @State private var selectedTrek: TrekRecord? = nil
    @State private var searchText: String = ""
    @State private var selectedFilter: TrekFilter = .all
    @State private var isLogModalPresented: Bool = false
    @State private var isTrophyCabinetPresented: Bool = false
    @State private var passportTrek: TrekRecord? = nil
    @State private var showResetDialog: Bool = false

    // Filtered Treks
    private var activeTreks: [TrekRecord] {
        allTreks.filter { !$0.isArchived }
    }

    private var filteredTreks: [TrekRecord] {
        activeTreks.filter { trek in
            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = q.isEmpty
                || trek.name.localizedCaseInsensitiveContains(q)
                || trek.region.localizedCaseInsensitiveContains(q)
                || trek.country.localizedCaseInsensitiveContains(q)

            guard matchesSearch else { return false }

            switch selectedFilter {
            case .all:
                return true
            case .conquered:
                return trek.status == .conquered
            case .unclimbed:
                return trek.status != .conquered
            case .himalayas:
                return trek.region.localizedCaseInsensitiveContains("Himalaya") ||
                       trek.region.localizedCaseInsensitiveContains("Uttarakhand") ||
                       trek.region.localizedCaseInsensitiveContains("Ladakh") ||
                       trek.region.localizedCaseInsensitiveContains("Sikkim") ||
                       trek.region.localizedCaseInsensitiveContains("Himachal") ||
                       trek.region.localizedCaseInsensitiveContains("Nepal") ||
                       trek.elevationMeters >= 3000
            case .westernGhats:
                return trek.region.localizedCaseInsensitiveContains("Western Ghats") ||
                       trek.region.localizedCaseInsensitiveContains("Maharashtra") ||
                       trek.region.localizedCaseInsensitiveContains("Sahyadri") ||
                       trek.region.localizedCaseInsensitiveContains("Karnataka") ||
                       trek.region.localizedCaseInsensitiveContains("Kerala")
            case .gujarat:
                return trek.region.localizedCaseInsensitiveContains("Gujarat") ||
                       trek.region.localizedCaseInsensitiveContains("Junagadh") ||
                       trek.region.localizedCaseInsensitiveContains("Pavagadh") ||
                       trek.region.localizedCaseInsensitiveContains("Girnar")
            case .maharashtra:
                return trek.region.localizedCaseInsensitiveContains("Maharashtra") ||
                       trek.region.localizedCaseInsensitiveContains("Sahyadri") ||
                       trek.region.localizedCaseInsensitiveContains("Kalsubai")
            }
        }
    }

    private var conqueredTreks: [TrekRecord] {
        activeTreks.filter { $0.status == .conquered }
    }

    private var totalAscendedMeters: Int {
        conqueredTreks.reduce(0) { $0 + Int($1.elevationMeters) }
    }

    var body: some View {
        VStack(spacing: 0) {

            // 1. Clean Top Header
            topHeaderBar

            Divider().opacity(0.12)

            // 2. 2-Pane Workspace (Directory List + Unobstructed Map Canvas)
            HSplitView {
                // Left Column: Mountain Directory & Search
                VStack(spacing: 0) {
                    searchAndFilterHeader
                    Divider().opacity(0.12)
                    peakListScrollView

                    // Selected Peak Inline Dossier in Directory Drawer
                    if let selected = selectedTrek {
                        selectedPeakInlineDossier(trek: selected)
                    }
                }
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)
                .background(DS.Theme.sidebar)

                // Right Column: Topo / 3D Satellite Map (Clean & Unobstructed)
                MacTrekMapView(
                    treks: filteredTreks,
                    selectedTrek: selectedTrek,
                    scrubCoordinate: nil,
                    isFlyingTrail: false,
                    onFinishFlyTrail: {},
                    onSelectTrek: { trek in
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            selectedTrek = trek
                        }
                        Haptics.impact(.light)
                    }
                )
                .edgesIgnoringSafeArea(.all)
                .frame(minWidth: 440, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(item: $passportTrek) { trek in
            ExpeditionPassportModal(trek: trek, onDismiss: { passportTrek = nil })
                .frame(minWidth: 940, idealWidth: 1000, minHeight: 740, idealHeight: 840)
        }
        .sheet(isPresented: $isTrophyCabinetPresented) {
            MountaineerTrophyCabinetModal(conqueredTreks: conqueredTreks, allTreks: activeTreks, onDismiss: { isTrophyCabinetPresented = false })
                .frame(minWidth: 780, idealWidth: 840, minHeight: 560, idealHeight: 620)
        }
        .sheet(isPresented: $isLogModalPresented) {
            MacLogPeakModal(
                onDismiss: { isLogModalPresented = false },
                onPeakCreated: { newPeak in
                    selectedTrek = newPeak
                }
            )
        }
        .onAppear {
            TrekSeeder.seedIfNeeded(context: modelContext)
            if selectedTrek == nil {
                selectedTrek = activeTreks.first(where: { $0.name == "Mount Everest" }) ?? activeTreks.first
            }
        }
    }

    // MARK: - Top Header Bar

    private var topHeaderBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(DS.Theme.amber)

            VStack(alignment: .leading, spacing: 1) {
                Text("Mountain Atlas")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white)

                Text("\(conqueredTreks.count) of \(activeTreks.count) Conquered · \(totalAscendedMeters.formatted())m Ascent")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(DS.Theme.textSecondary)
            }

            Spacer()

            // Reset Mountain Data Button
            Button {
                showResetDialog = true
                Haptics.impact(.light)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10, weight: .bold))
                    Text("Reset Data")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(Color.red.opacity(0.85))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.red.opacity(0.20), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .confirmationDialog("Reset Mountain Data?", isPresented: $showResetDialog, titleVisibility: .visible) {
                Button("Reset All Peaks to Unclimbed", role: .destructive) {
                    TrekSeeder.resetAllTreks(context: modelContext)
                    PlutoSoundEngine.shared.play(.deleteTrash)
                    Haptics.notify(.success)
                }
                Button("Reseed Default Mountain Catalog", role: .destructive) {
                    TrekSeeder.reseedAllTreks(context: modelContext)
                    PlutoSoundEngine.shared.play(.completePop)
                    Haptics.notify(.success)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Choose whether to mark all peaks as unclimbed (0 summits) or completely reseed the clean mountain catalog.")
            }

            // Trophies Button
            Button {
                isTrophyCabinetPresented = true
                Haptics.impact(.light)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 11))
                    Text("Trophies (\(conqueredTreks.count))")
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .foregroundStyle(Color.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Log Peak Action
            Button {
                isLogModalPresented = true
                Haptics.impact(.light)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Log Peak")
                        .font(.system(size: 11.5, weight: .bold))
                }
                .foregroundStyle(Color.black)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(DS.Theme.amber, in: RoundedRectangle(cornerRadius: 6))
                .shadow(color: DS.Theme.amber.opacity(0.35), radius: 5, x: 0, y: 1)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(DS.Theme.surface)
    }

    // MARK: - Search & Filter Header

    private var searchAndFilterHeader: some View {
        VStack(spacing: 8) {
            // Search Field with Quick Clear
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Theme.textTertiary)

                TextField("Search peaks, ranges, regions...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))

                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5.5)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(DS.Theme.border, lineWidth: 1))

            // Filter Pills (All / Conquered / Unclimbed / Ranges)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(TrekFilter.allCases) { filter in
                        let isSelected = selectedFilter == filter
                        Button {
                            withAnimation(.easeInOut(duration: 0.12)) {
                                selectedFilter = filter
                            }
                            Haptics.impact(.light)
                        } label: {
                            Text(filterTitle(filter))
                                .font(.system(size: 10.5, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? Color.black : DS.Theme.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3.5)
                                .background(
                                    isSelected ? DS.Theme.amber : Color.white.opacity(0.04),
                                    in: RoundedRectangle(cornerRadius: 4)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(10)
    }

    private func filterTitle(_ filter: TrekFilter) -> String {
        switch filter {
        case .all:
            return "All (\(activeTreks.count))"
        case .conquered:
            return "Conquered (\(conqueredTreks.count))"
        case .unclimbed:
            return "Unclimbed (\(activeTreks.count - conqueredTreks.count))"
        default:
            return filter.rawValue
        }
    }

    // MARK: - Peak Directory ScrollView with Direct 1-Click Toggles

    private var peakListScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                if filteredTreks.isEmpty {
                    Text("No mountain peaks found")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Theme.textTertiary)
                        .padding(.top, 30)
                } else {
                    ForEach(filteredTreks) { trek in
                        let isSelected = selectedTrek?.id == trek.id
                        let isConquered = trek.status == .conquered

                        HStack(spacing: 8) {
                            // Direct 1-Click Conquered Toggle Checkbox / Trophy
                            Button {
                                toggleTrekStatus(trek)
                            } label: {
                                Image(systemName: isConquered ? "trophy.fill" : "circle")
                                    .font(.system(size: 12.5, weight: .bold))
                                    .foregroundStyle(isConquered ? DS.Theme.amber : Color.white.opacity(0.35))
                                    .frame(width: 24, height: 24)
                                    .background(
                                        isConquered ? DS.Theme.amber.opacity(0.18) : Color.white.opacity(0.04),
                                        in: RoundedRectangle(cornerRadius: 5)
                                    )
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(isConquered ? "Mark as unclimbed" : "Mark as conquered 🏆")

                            // Mountain Info (Click row to zoom on 3D map)
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    selectedTrek = trek
                                }
                                Haptics.impact(.light)
                            } label: {
                                HStack(spacing: 6) {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(trek.name)
                                            .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                            .foregroundStyle(Color.white)
                                            .lineLimit(1)

                                        Text("\(trek.region), \(trek.country)")
                                            .font(.system(size: 10))
                                            .foregroundStyle(DS.Theme.textSecondary)
                                            .lineLimit(1)
                                    }

                                    Spacer(minLength: 4)

                                    VStack(alignment: .trailing, spacing: 1) {
                                        Text("\(Int(trek.elevationMeters).formatted()) m")
                                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                            .foregroundStyle(isConquered ? DS.Theme.amber : DS.Theme.textSecondary)

                                        if isConquered {
                                            Text("Conquered")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundStyle(DS.Theme.amber)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .machinedCard(isHovered: false, isSelected: isSelected, cornerRadius: 6, accent: DS.Theme.amber)
                    }
                }
            }
            .padding(6)
        }
    }

    // MARK: - Inline Selected Peak Dossier in Left Column

    private func selectedPeakInlineDossier(trek: TrekRecord) -> some View {
        let isConquered = trek.status == .conquered

        return VStack(alignment: .leading, spacing: 6) {
            Divider().opacity(0.12)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(trek.name)
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(Color.white)
                        if isConquered {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(DS.Theme.amber)
                        }
                    }

                    Text("\(Int(trek.elevationMeters).formatted()) m · \(trek.difficulty.title) · \(trek.region)")
                        .font(.system(size: 9.5))
                        .foregroundStyle(DS.Theme.textSecondary)
                }

                Spacer()

                // Expedition Passport Button
                Button {
                    passportTrek = trek
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "book.pages.fill")
                            .font(.system(size: 10))
                        Text("Passport")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.white.opacity(0.10), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.02))
    }

    private func toggleTrekStatus(_ trek: TrekRecord) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            if trek.status == .conquered {
                trek.status = .wishlist
                trek.dateConquered = nil
                PlutoSoundEngine.shared.play(.deleteTrash)
            } else {
                trek.status = .conquered
                trek.dateConquered = Date.now
                PlutoSoundEngine.shared.play(.completePop)
                Haptics.notify(.success)
            }
            try? modelContext.save()
        }
    }
}
