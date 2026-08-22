import SwiftUI
import SwiftData
import MapKit

// MARK: - TravelFilter

enum TravelFilter: String, CaseIterable, Identifiable {
    case all             = "All"
    case visited         = "Visited 🏆"
    case wishlist        = "Wishlist 📍"
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
    @State private var isSearchOpen: Bool = false

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
            let matchesSearch = searchText.isEmpty ||
                state.name.localizedCaseInsensitiveContains(searchText) ||
                state.capital.localizedCaseInsensitiveContains(searchText) ||
                state.stateCode.localizedCaseInsensitiveContains(searchText)

            guard matchesSearch else { return false }

            switch selectedFilter {
            case .all:            return true
            case .visited:        return state.isVisited
            case .wishlist:       return !state.isVisited
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

            // 2. Map Canvas & Overlays (Native Apple Maps Titles & 60 FPS GPU Rendering)
            ZStack(alignment: .topLeading) {
                mapView

                // Left: Search & Filter State Directory Drawer
                if isSearchOpen {
                    floatingSearchDrawer
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .padding(14)
                }

                // Bottom-Trailing: Floating State Inspector Card
                if let state = selectedState {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            cleanStateInspector(state: state)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .padding(16)
                        }
                    }
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

        // 1. Persistent Visited State Boundaries (Warm Saffron Gold)
        for state in visitedStates {
            if state.stateCode != selectedState?.stateCode {
                let stateRings = GeoJSONBoundaryLoader.shared.outerRings(for: state.stateCode)
                for (idx, coords) in stateRings.enumerated() {
                    rings.append(MapPolygonRing(id: "\(state.stateCode)_v_\(idx)", coordinates: coords, isSelected: false))
                }
            }
        }

        // 2. Currently Selected State (Laser Cyan - Top Layer)
        if let selected = selectedState {
            let stateRings = GeoJSONBoundaryLoader.shared.outerRings(for: selected.stateCode)
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

    // MARK: - Native Apple Maps Public Transport View (60 FPS Performance)

    private var mapView: some View {
        Map(position: $mapCameraPosition) {
            // Pre-cached Polygon Rings (Zero allocation per frame)
            ForEach(cachedTerritoryRings) { ring in
                MapPolygon(coordinates: ring.coordinates)
                    .foregroundStyle(ring.isSelected ? selectedAccent.opacity(0.30) : visitedAccent.opacity(0.20))

                MapPolygon(coordinates: ring.coordinates)
                    .foregroundStyle(Color.clear)
                    .stroke(
                        ring.isSelected ? selectedAccent : visitedAccent.opacity(0.85),
                        style: StrokeStyle(
                            lineWidth: ring.isSelected ? 3.5 : 1.8,
                            lineCap: .round,
                            lineJoin: .round
                        )
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
    }

    // MARK: - Floating Search & Filter Drawer

    private var floatingSearchDrawer: some View {
        VStack(spacing: 8) {
            // Search Input
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Theme.textTertiary)

                TextField("Search states, capitals...", text: $searchText)
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

            // Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(TravelFilter.allCases) { filter in
                        let isSelected = selectedFilter == filter
                        Button {
                            withAnimation(.easeInOut(duration: 0.12)) {
                                selectedFilter = filter
                            }
                        } label: {
                            Text(filter.rawValue)
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

            // Results List
            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(filteredStates) { state in
                        let isSelected = selectedState?.id == state.id
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                selectedState = state
                                // Smoothly pan camera to selected state
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
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(state.isVisited ? visitedAccent : Color.white.opacity(0.35))
                                    .frame(width: 6, height: 6)

                                Text(state.name)
                                    .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                                    .foregroundStyle(Color.white)

                                Spacer()

                                if state.isVisited {
                                    Text("Visited")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(visitedAccent)
                                } else {
                                    Text(state.capital)
                                        .font(.system(size: 10))
                                        .foregroundStyle(DS.Theme.textSecondary)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5.5)
                            .background(
                                isSelected ? selectedAccent.opacity(0.18) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 320)
        }
        .padding(10)
        .frame(width: 270)
        .machinedCard(cornerRadius: 10, accent: selectedAccent)
    }

    // MARK: - Clean Floating State Inspector Card

    private func cleanStateInspector(state: TravelRecord) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            // Header: Name + Code + Visited Status + Close
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(state.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.white)

                        Text("(\(state.stateCode))")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(selectedAccent)

                        if state.isVisited {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(visitedAccent)
                        }
                    }

                    Text("Capital: \(state.capital) · \(state.zone.title)")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Theme.textSecondary)
                }

                Spacer()

                Button {
                    withAnimation(.easeOut(duration: 0.12)) {
                        savedSelectedStateCode = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(DS.Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }

            Divider().opacity(0.12)

            // Best Season & Language
            HStack(spacing: 6) {
                if !state.bestSeason.isEmpty {
                    infoBox(label: "BEST SEASON", value: state.bestSeason, accent: selectedAccent)
                }
                if !state.officialLanguage.isEmpty {
                    infoBox(label: "LANGUAGE", value: state.officialLanguage, accent: Color.white.opacity(0.85))
                }
            }

            // Top Attractions Pills
            if !state.topAttractions.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("TOP ATTRACTIONS")
                        .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.Theme.textTertiary)

                    Text(state.topAttractions.prefix(3).joined(separator: " • "))
                        .font(.system(size: 10.5))
                        .foregroundStyle(DS.Theme.textSecondary)
                        .lineLimit(2)
                }
            }

            Divider().opacity(0.12)

            // Toggle Visited Button (Instantly paints/unpaints territory gold on the map)
            Button {
                toggleVisited(state)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: state.isVisited ? "arrow.uturn.backward" : "checkmark.seal.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(state.isVisited ? "Mark as Wishlist" : "Mark as Visited 🏆")
                        .font(.system(size: 11.5, weight: .bold))
                }
                .foregroundStyle(state.isVisited ? Color.white : Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    state.isVisited ? Color.white.opacity(0.10) : visitedAccent,
                    in: RoundedRectangle(cornerRadius: 6)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 290)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DS.Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(selectedAccent.opacity(0.40), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 12, x: 0, y: 6)
    }

    private func infoBox(label: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.Theme.textTertiary)
            Text(value)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(accent)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(5)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 4))
    }

    private func toggleVisited(_ state: TravelRecord) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            if state.isVisited {
                state.status = .wishlist
                state.dateVisited = nil
            } else {
                state.status = .visited
                state.dateVisited = Date.now
                Haptics.notify(.success)
            }
            try? modelContext.save()
            rebuildTerritoryCache()
        }
    }
}
