import SwiftUI
import SwiftData
import MapKit

// MARK: - TravelFilter

enum TravelFilter: String, CaseIterable, Identifiable {
    case all             = "All"
    case visited         = "Visited 🏆"
    case unvisited       = "Unexplored"
    case northern        = "North"
    case western         = "West"
    case southern        = "South"
    case eastern         = "East"
    case unionTerritory  = "UTs"

    var id: String { rawValue }
}

// MARK: - MapPolygonRing (Stable Identifiable Boundary for 100% Persistence)

private struct MapPolygonRing: Identifiable {
    let id: String
    let coordinates: [CLLocationCoordinate2D]
    let isSelected: Bool
}

// MARK: - MacTravelAtlasCanvas (60 FPS Fast Cartographic Travel Atlas)

struct MacTravelAtlasCanvas: View {

    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<TravelRecord> { $0.archivedAt == nil }, sort: \TravelRecord.name)
    private var activeStates: [TravelRecord]

    // Persistent Selection (Stored in UserDefaults so selection & colors never get lost)
    @AppStorage("mac_travel_selected_state_code_v5") private var savedSelectedStateCode: String = "RJ"
    @State private var selectedFilter: TravelFilter = .all
    @State private var searchText: String = ""
    @State private var isSearchOpen: Bool = true

    // Cached Precomputed Polygon Rings for 60 FPS buttery-smooth map panning
    @State private var cachedTerritoryRings: [MapPolygonRing] = []

    // Cartographic Color Hierarchy (Laser Cyan Selected · Warm Saffron Gold Visited)
    private let selectedAccent = Color(red: 0.0, green: 0.88, blue: 1.0) // Laser Cyan (#00E0FF)
    private let visitedAccent  = Color(red: 1.0, green: 0.70, blue: 0.0) // Saffron Gold (#FFB300)

    // MapKit Camera Position
    @State private var mapCameraPosition: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 22.5, longitude: 80.0),
            distance: 3_600_000,
            heading: 0,
            pitch: 0
        )
    )

    // Computed Active Selection (Non-mutating via @AppStorage)
    private var selectedState: TravelRecord? {
        get {
            activeStates.first(where: { $0.stateCode == savedSelectedStateCode }) ?? activeStates.first
        }
        nonmutating set {
            if let code = newValue?.stateCode {
                savedSelectedStateCode = code
            } else {
                savedSelectedStateCode = ""
            }
        }
    }

    // Filtered States for Drawer List
    private var filteredStates: [TravelRecord] {
        activeStates.filter { state in
            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = q.isEmpty ||
                state.name.localizedCaseInsensitiveContains(q) ||
                state.capital.localizedCaseInsensitiveContains(q) ||
                state.stateCode.localizedCaseInsensitiveContains(q) ||
                state.topAttractions.contains(where: { $0.localizedCaseInsensitiveContains(q) })

            guard matchesSearch else { return false }

            switch selectedFilter {
            case .all:            return true
            case .visited:        return state.isVisited
            case .unvisited:      return !state.isVisited
            case .northern:       return state.zone == .northern
            case .western:        return state.zone == .western
            case .southern:       return state.zone == .southern
            case .eastern:        return state.zone == .eastern || state.zone == .northEast
            case .unionTerritory: return state.zone == .unionTerritory
            }
        }
    }

    private var visitedStates: [TravelRecord] {
        activeStates.filter { $0.isVisited }
    }

    private var visitedStatesCount: Int {
        visitedStates.count
    }

    private var explorationPercentage: Double {
        activeStates.isEmpty ? 0 : (Double(visitedStatesCount) / Double(activeStates.count)) * 100.0
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1. Minimal Top Bar
            topBar

            Divider().opacity(0.12)

            // 2. Map Canvas & Overlays (Native Apple Maps Titles & 120 FPS GPU Rendering)
            ZStack(alignment: .topLeading) {
                mapView

                // Left: Search & Filter State Directory Drawer
                if isSearchOpen {
                    floatingSearchDrawer
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .padding(14)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            TravelSeeder.seedIfNeeded(context: modelContext)
            rebuildTerritoryCache()
        }
        .onChange(of: savedSelectedStateCode) {
            rebuildTerritoryCache()
        }
        .onChange(of: visitedStatesCount) {
            rebuildTerritoryCache()
        }
    }

    // MARK: - Rebuild Cached Boundaries (Called Only on State/Selection Changes)

    private func rebuildTerritoryCache() {
        var rings: [MapPolygonRing] = []
        let loader = GeoJSONBoundaryLoader.shared
        let selectedCode = selectedState?.stateCode

        // 1. Persistent Visited State Boundaries (Warm Saffron Gold)
        for state in visitedStates {
            if state.stateCode != selectedCode {
                let stateRings = loader.outerRings(for: state.stateCode)
                for (idx, coords) in stateRings.enumerated() {
                    rings.append(MapPolygonRing(id: "\(state.stateCode)_v_\(idx)", coordinates: coords, isSelected: false))
                }
            }
        }

        // 2. Currently Selected State (Laser Cyan - Top Layer)
        if let selected = selectedState {
            let stateRings = loader.outerRings(for: selected.stateCode)
            for (idx, coords) in stateRings.enumerated() {
                rings.append(MapPolygonRing(id: "\(selected.stateCode)_sel_\(idx)", coordinates: coords, isSelected: true))
            }
        }

        cachedTerritoryRings = rings
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "tram.fill.tunnel")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(selectedAccent)

            VStack(alignment: .leading, spacing: 1) {
                Text("Travel Atlas & Transit Odyssey")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white)

                Text("\(visitedStatesCount) / \(activeStates.count) Explored · \(Int(explorationPercentage))% Complete · Public Transit View")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(DS.Theme.textSecondary)
            }

            Spacer()

            // State Directory Drawer Toggle
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isSearchOpen.toggle()
                }
                Haptics.impact(.light)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: isSearchOpen ? "xmark" : "list.bullet")
                        .font(.system(size: 11, weight: .bold))
                    Text(isSearchOpen ? "Close States" : "State Directory (\(activeStates.count))")
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .foregroundStyle(isSearchOpen ? selectedAccent : Color.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSearchOpen ? selectedAccent.opacity(0.15) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(isSearchOpen ? selectedAccent.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(DS.Theme.surface)
    }

    // MARK: - Native Apple Maps Public Transport View (120 FPS Performance)

    private var mapView: some View {
        GeometryReader { proxy in
            if proxy.size.width > 0 && proxy.size.height > 0 {
                Map(position: $mapCameraPosition) {
                    // Pre-cached Polygon Rings (Single combined MapPolygon for 120 FPS performance)
                    ForEach(cachedTerritoryRings) { ring in
                        MapPolygon(coordinates: ring.coordinates)
                            .foregroundStyle(ring.isSelected ? selectedAccent.opacity(0.35) : visitedAccent.opacity(0.20))
                            .stroke(
                                ring.isSelected ? selectedAccent : visitedAccent.opacity(0.85),
                                lineWidth: ring.isSelected ? 3.0 : 1.6
                            )
                    }
                }
                .mapStyle(
                    .standard(
                        elevation: .flat,
                        emphasis: .muted,
                        pointsOfInterest: .including([.publicTransport, .airport, .marina]),
                        showsTraffic: false
                    )
                )
                .edgesIgnoringSafeArea(.all)
            } else {
                Color.clear
            }
        }
    }

    // MARK: - Floating Search & Filter Drawer

    private var floatingSearchDrawer: some View {
        VStack(spacing: 8) {
            // Header: Title + Progress Summary
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("State Explorer")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white)
                    Text("\(visitedStatesCount) of \(activeStates.count) Explored (\(Int(explorationPercentage))%)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(visitedAccent)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isSearchOpen = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DS.Theme.textTertiary)
                        .padding(4)
                        .background(Color.white.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
            }

            // Quick Progress Bar
            GeometryReader { gp in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [visitedAccent, Color(red: 1.0, green: 0.85, blue: 0.2)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, gp.size.width * CGFloat(explorationPercentage / 100.0)))
                }
            }
            .frame(height: 4)

            // Search Input with Quick Clear
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Theme.textTertiary)

                TextField("Search states, capitals, codes...", text: $searchText)
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
            .padding(8)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(DS.Theme.border, lineWidth: 1))

            // Filter Pills (All / Visited / Unexplored / Zones)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(TravelFilter.allCases) { filter in
                        let isSelected = selectedFilter == filter
                        Button {
                            withAnimation(.easeInOut(duration: 0.12)) {
                                selectedFilter = filter
                            }
                        } label: {
                            Text(filterTitle(filter))
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? Color.black : DS.Theme.textSecondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    isSelected ? selectedAccent : Color.white.opacity(0.04),
                                    in: RoundedRectangle(cornerRadius: 4)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider().opacity(0.12)

            // Results List with Direct 1-Click Checkboxes
            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(filteredStates) { state in
                        let isSelected = selectedState?.id == state.id
                        HStack(spacing: 6) {
                            // Direct 1-Click Visited Toggle Checkbox
                            Button {
                                toggleVisited(state)
                            } label: {
                                Image(systemName: state.isVisited ? "checkmark.seal.fill" : "circle")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(state.isVisited ? visitedAccent : Color.white.opacity(0.35))
                                    .frame(width: 22, height: 22)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(state.isVisited ? "Mark as unexplored" : "Mark as visited")

                            // State Name & Capital (Click to zoom on map & inspect)
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    selectedState = state
                                    mapCameraPosition = .camera(
                                        MapCamera(
                                            centerCoordinate: state.coordinate,
                                            distance: 1_200_000,
                                            heading: 0,
                                            pitch: 0
                                        )
                                    )
                                }
                                Haptics.impact(.light)
                            } label: {
                                HStack(spacing: 6) {
                                    VStack(alignment: .leading, spacing: 1) {
                                        HStack(spacing: 4) {
                                            Text(state.name)
                                                .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                                                .foregroundStyle(Color.white)
                                            Text(state.stateCode)
                                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                .foregroundStyle(selectedAccent.opacity(0.85))
                                        }
                                        Text(state.capital)
                                            .font(.system(size: 9.5))
                                            .foregroundStyle(DS.Theme.textSecondary)
                                    }

                                    Spacer()

                                    if state.isVisited {
                                        Text("Visited")
                                            .font(.system(size: 8.5, weight: .bold))
                                            .foregroundStyle(visitedAccent)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1.5)
                                            .background(visitedAccent.opacity(0.18), in: RoundedRectangle(cornerRadius: 3))
                                    }
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(
                            isSelected ? selectedAccent.opacity(0.16) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 5)
                        )
                    }
                }
            }
            .frame(maxHeight: 380)
        }
        .padding(10)
        .frame(width: 300)
        .machinedCard(cornerRadius: 10, accent: selectedAccent)
    }

    private func filterTitle(_ filter: TravelFilter) -> String {
        switch filter {
        case .all:
            return "All (\(activeStates.count))"
        case .visited:
            return "Visited (\(visitedStatesCount))"
        case .unvisited:
            return "Unexplored (\(activeStates.count - visitedStatesCount))"
        case .northern:
            return "North"
        case .western:
            return "West"
        case .southern:
            return "South"
        case .eastern:
            return "East"
        case .unionTerritory:
            return "UTs"
        }
    }

    private func toggleVisited(_ state: TravelRecord) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            if state.isVisited {
                state.status = .wishlist
                state.dateVisited = nil
                PlutoSoundEngine.shared.play(.deleteTrash)
            } else {
                state.status = .visited
                state.dateVisited = Date.now
                PlutoSoundEngine.shared.play(.completePop)
                Haptics.notify(.success)
            }
            try? modelContext.save()
            rebuildTerritoryCache()
        }
    }
}
