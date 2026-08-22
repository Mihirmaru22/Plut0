import SwiftUI
import SwiftData
import MapKit
import UniformTypeIdentifiers

// MARK: - TrekFilter

enum TrekFilter: String, CaseIterable, Identifiable {
    case all          = "All"
    case himalayas    = "Himalayas"
    case westernGhats = "Western Ghats"
    case gujarat      = "Gujarat"
    case maharashtra  = "Maharashtra"
    case conquered    = "Conquered 🏆"
    case wishlist     = "Wishlist 📍"

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

    // Filtered Treks
    private var activeTreks: [TrekRecord] {
        allTreks.filter { !$0.isArchived }
    }

    private var filteredTreks: [TrekRecord] {
        activeTreks.filter { trek in
            let matchesSearch = searchText.isEmpty
                || trek.name.localizedCaseInsensitiveContains(searchText)
                || trek.region.localizedCaseInsensitiveContains(searchText)
                || trek.country.localizedCaseInsensitiveContains(searchText)

            guard matchesSearch else { return false }

            switch selectedFilter {
            case .all:
                return true
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
            case .conquered:
                return trek.status == .conquered
            case .wishlist:
                return trek.status == .wishlist
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

            // 2. 2-Pane Workspace (Directory List + Map Canvas)
            HSplitView {
                // Left Column: Mountain Directory
                VStack(spacing: 0) {
                    searchAndFilterHeader
                    Divider().opacity(0.12)
                    peakListScrollView
                }
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)
                .background(DS.Theme.sidebar)

                // Right Column: Topo Map & Floating Peak Inspector
                ZStack(alignment: .bottomTrailing) {
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

                    // Clean Floating Peak Inspector Card
                    if let trek = selectedTrek {
                        cleanPeakInspector(trek: trek)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(16)
                    }
                }
                .frame(minWidth: 440, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(item: $passportTrek) { trek in
            ExpeditionPassportModal(trek: trek, onDismiss: { passportTrek = nil })
                .frame(minWidth: 700, minHeight: 600)
        }
        .sheet(isPresented: $isTrophyCabinetPresented) {
            MountaineerTrophyCabinetModal(conqueredTreks: conqueredTreks, allTreks: activeTreks, onDismiss: { isTrophyCabinetPresented = false })
                .frame(minWidth: 640, minHeight: 520)
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

                Text("\(conqueredTreks.count) Conquered · \(totalAscendedMeters.formatted())m Total Ascent")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(DS.Theme.textSecondary)
            }

            Spacer()

            // Trophies Button
            Button {
                isTrophyCabinetPresented = true
                Haptics.impact(.light)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 11))
                    Text("Trophies")
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
            // Search Field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Theme.textTertiary)

                TextField("Search peaks, ranges...", text: $searchText)
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

            // Filter Pills
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
                            Text(filter.rawValue)
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

    // MARK: - Peak Directory ScrollView

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

                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                selectedTrek = trek
                            }
                            Haptics.impact(.light)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isConquered ? "trophy.fill" : "mountain.2")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(isConquered ? DS.Theme.amber : DS.Theme.textTertiary)
                                    .frame(width: 22, height: 22)
                                    .background(
                                        isConquered ? DS.Theme.amber.opacity(0.15) : Color.white.opacity(0.04),
                                        in: RoundedRectangle(cornerRadius: 4)
                                    )

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

                                Text("\(Int(trek.elevationMeters).formatted()) m")
                                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(isConquered ? DS.Theme.cyan : DS.Theme.textSecondary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 3))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .machinedCard(isHovered: false, isSelected: isSelected, cornerRadius: 6, accent: DS.Theme.amber)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(6)
        }
    }

    // MARK: - Clean Floating Peak Inspector Card

    private func cleanPeakInspector(trek: TrekRecord) -> some View {
        let isConquered = trek.status == .conquered

        return VStack(alignment: .leading, spacing: 10) {
            // Header: Title, Region, Close Button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(trek.name)
                            .font(.system(size: 14.5, weight: .bold))
                            .foregroundStyle(Color.white)

                        if isConquered {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(DS.Theme.amber)
                        }
                    }

                    Text("\(trek.region), \(trek.country)")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Theme.textSecondary)
                }

                Spacer()

                Button {
                    withAnimation(.easeOut(duration: 0.12)) {
                        selectedTrek = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(DS.Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }

            Divider().opacity(0.12)

            // Clean 3-Metric Row (Altitude, Gain, Difficulty)
            HStack(spacing: 6) {
                metricBox(label: "ALTITUDE", value: "\(Int(trek.elevationMeters).formatted()) m", accent: DS.Theme.cyan)
                if let gain = trek.formattedGain {
                    metricBox(label: "VERT GAIN", value: gain, accent: DS.Theme.violet)
                }
                metricBox(label: "DIFFICULTY", value: trek.difficulty.title, accent: DS.Theme.amber)
            }

            Divider().opacity(0.12)

            // Action Buttons
            HStack(spacing: 8) {
                Button {
                    passportTrek = trek
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "book.pages.fill")
                            .font(.system(size: 10.5))
                        Text("Passport")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.10), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    toggleTrekStatus(trek)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isConquered ? "arrow.uturn.backward" : "trophy.fill")
                            .font(.system(size: 10.5, weight: .bold))
                        Text(isConquered ? "Mark Wishlist" : "Conquer 🏆")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(isConquered ? Color.white : Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        isConquered ? Color.white.opacity(0.10) : DS.Theme.amber,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 290)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DS.Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(DS.Theme.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 12, x: 0, y: 6)
    }

    private func metricBox(label: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.Theme.textTertiary)
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(accent)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(5)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 4))
    }

    private func toggleTrekStatus(_ trek: TrekRecord) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            if trek.status == .conquered {
                trek.status = .wishlist
                trek.dateConquered = nil
            } else {
                trek.status = .conquered
                trek.dateConquered = Date.now
                Haptics.notify(.success)
            }
            try? modelContext.save()
        }
    }

    private func createNewPeak() {
        let newPeak = TrekRecord(
            name: "New Peak",
            region: "Himalayas",
            country: "India",
            latitude: 30.5,
            longitude: 79.5,
            elevationMeters: 4500,
            status: .wishlist,
            difficulty: .moderate
        )
        modelContext.insert(newPeak)
        try? modelContext.save()
        selectedTrek = newPeak
    }
}
