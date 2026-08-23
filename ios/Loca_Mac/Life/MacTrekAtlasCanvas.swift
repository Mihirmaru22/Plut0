import SwiftUI
import SwiftData
import MapKit
import UniformTypeIdentifiers

// MARK: - TrekFilter (Comprehensive State & Regional Categorization)

enum TrekFilter: String, CaseIterable, Identifiable {
    case all             = "All"
    case conquered       = "Conquered 🏆"
    case unclimbed       = "Unclimbed"
    case gujarat         = "🦁 Gujarat"
    case maharashtra     = "🚩 Maharashtra"
    case uttarakhand     = "🏔️ Uttarakhand"
    case himachal        = "❄️ Himachal"
    case ladakh          = "🐪 Ladakh & J&K"
    case rajasthan       = "🦚 Rajasthan"
    case sikkim          = "🌸 Sikkim & NE"
    case southIndia      = "🌿 South India"
    case sevenSummits    = "🌍 Seven Summits"

    var id: String { rawValue }
}

// MARK: - MacTrekAtlasCanvas (Unobstructed Fullscreen Map with Floating Drawer)

struct MacTrekAtlasCanvas: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrekRecord.elevationMeters, order: .reverse) private var allTreks: [TrekRecord]

    @State private var selectedTrek: TrekRecord? = nil
    @State private var targetCamera: MKMapCamera? = nil
    @State private var cameraToken: String = ""
    @State private var searchText: String = ""
    @State private var selectedFilter: TrekFilter = .all
    @State private var isDirectoryOpen: Bool = false
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
            case .gujarat:
                return trek.region.localizedCaseInsensitiveContains("Gujarat") ||
                       trek.region.localizedCaseInsensitiveContains("Junagadh") ||
                       trek.region.localizedCaseInsensitiveContains("Pavagadh") ||
                       trek.region.localizedCaseInsensitiveContains("Girnar") ||
                       trek.region.localizedCaseInsensitiveContains("Kutch") ||
                       trek.region.localizedCaseInsensitiveContains("Bhavnagar") ||
                       trek.region.localizedCaseInsensitiveContains("Dang")
            case .maharashtra:
                return trek.region.localizedCaseInsensitiveContains("Maharashtra") ||
                       trek.region.localizedCaseInsensitiveContains("Sahyadri") ||
                       trek.region.localizedCaseInsensitiveContains("Kalsubai") ||
                       trek.region.localizedCaseInsensitiveContains("Pune") ||
                       trek.region.localizedCaseInsensitiveContains("Nashik") ||
                       trek.region.localizedCaseInsensitiveContains("Raigad") ||
                       trek.region.localizedCaseInsensitiveContains("Satara")
            case .uttarakhand:
                return trek.region.localizedCaseInsensitiveContains("Uttarakhand") ||
                       trek.region.localizedCaseInsensitiveContains("Garhwal") ||
                       trek.region.localizedCaseInsensitiveContains("Kumaon") ||
                       trek.region.localizedCaseInsensitiveContains("Gangotri") ||
                       trek.region.localizedCaseInsensitiveContains("Nanda Devi")
            case .himachal:
                return trek.region.localizedCaseInsensitiveContains("Himachal") ||
                       trek.region.localizedCaseInsensitiveContains("Manali") ||
                       trek.region.localizedCaseInsensitiveContains("Spiti") ||
                       trek.region.localizedCaseInsensitiveContains("Kinnaur") ||
                       trek.region.localizedCaseInsensitiveContains("Kullu")
            case .ladakh:
                return trek.region.localizedCaseInsensitiveContains("Ladakh") ||
                       trek.region.localizedCaseInsensitiveContains("Kashmir") ||
                       trek.region.localizedCaseInsensitiveContains("Zanskar") ||
                       trek.region.localizedCaseInsensitiveContains("Hemis") ||
                       trek.region.localizedCaseInsensitiveContains("Leh")
            case .rajasthan:
                return trek.region.localizedCaseInsensitiveContains("Rajasthan") ||
                       trek.region.localizedCaseInsensitiveContains("Aravalli") ||
                       trek.region.localizedCaseInsensitiveContains("Mount Abu") ||
                       trek.region.localizedCaseInsensitiveContains("Sirohi")
            case .sikkim:
                return trek.region.localizedCaseInsensitiveContains("Sikkim") ||
                       trek.region.localizedCaseInsensitiveContains("Nagaland") ||
                       trek.region.localizedCaseInsensitiveContains("Meghalaya") ||
                       trek.region.localizedCaseInsensitiveContains("Arunachal")
            case .southIndia:
                return trek.region.localizedCaseInsensitiveContains("Kerala") ||
                       trek.region.localizedCaseInsensitiveContains("Karnataka") ||
                       trek.region.localizedCaseInsensitiveContains("Tamil Nadu") ||
                       trek.region.localizedCaseInsensitiveContains("Nilgiris") ||
                       trek.region.localizedCaseInsensitiveContains("Chikkamagaluru") ||
                       trek.region.localizedCaseInsensitiveContains("Idukki")
            case .sevenSummits:
                return trek.country != "India" ||
                       trek.region.localizedCaseInsensitiveContains("Nepal") ||
                       trek.region.localizedCaseInsensitiveContains("Tanzania") ||
                       trek.region.localizedCaseInsensitiveContains("France") ||
                       trek.region.localizedCaseInsensitiveContains("Switzerland") ||
                       trek.region.localizedCaseInsensitiveContains("Japan") ||
                       trek.region.localizedCaseInsensitiveContains("Russia") ||
                       trek.region.localizedCaseInsensitiveContains("Alaska") ||
                       trek.region.localizedCaseInsensitiveContains("Argentina")
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

            // 1. Clean Top Header Bar
            topHeaderBar

            Divider().opacity(0.12)

            // 2. Fullscreen Unobstructed Map with Floating Drawer & Dossier Pill
            ZStack(alignment: .topLeading) {
                // Topo / 3D Satellite Map Canvas
                MacTrekMapView(
                    treks: filteredTreks,
                    selectedTrek: selectedTrek,
                    targetCamera: targetCamera,
                    cameraToken: cameraToken,
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Floating Mountain Directory Drawer (Shown only when opened)
                if isDirectoryOpen {
                    floatingPeakDirectoryDrawer
                        .padding(.top, 14)
                        .padding(.leading, 14)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .zIndex(10)
                }

                // Floating Selected Peak Dossier Banner (Shown when drawer is closed)
                if !isDirectoryOpen, let selected = selectedTrek {
                    floatingSelectedPeakBanner(trek: selected)
                        .padding(.bottom, 20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(5)
                }
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
            // Peak Explorer Drawer Toggle
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    isDirectoryOpen.toggle()
                }
                Haptics.impact(.light)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isDirectoryOpen ? "sidebar.left" : "mountain.2.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(isDirectoryOpen ? "Hide Directory" : "Peak Directory (\(filteredTreks.count))")
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .foregroundStyle(isDirectoryOpen ? Color.black : Color.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5.5)
                .background(
                    isDirectoryOpen ? DS.Theme.amber : Color.white.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isDirectoryOpen ? Color.clear : Color.white.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

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

    // MARK: - Floating Peak Directory Drawer

    private var floatingPeakDirectoryDrawer: some View {
        VStack(spacing: 0) {
            // Drawer Header with Close Button
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "mountain.2.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DS.Theme.amber)
                    Text("PEAK DIRECTORY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white)
                        .tracking(0.6)

                    Text("(\(filteredTreks.count))")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.Theme.textSecondary)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        isDirectoryOpen = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(DS.Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Search Field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Theme.textTertiary)

                TextField("Search peaks, regions, states...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))

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
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(DS.Theme.border, lineWidth: 1))
            .padding(.horizontal, 10)
            .padding(.bottom, 6)

            // State & Region Filter Pills (Horizontal Scroll)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(TrekFilter.allCases) { filter in
                        let isSelected = selectedFilter == filter
                        Button {
                            withAnimation(.easeInOut(duration: 0.12)) {
                                selectedFilter = filter
                                targetCamera = cameraForFilter(filter)
                                cameraToken = UUID().uuidString
                            }
                            Haptics.impact(.light)
                        } label: {
                            Text(filterTitle(filter))
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? Color.black : DS.Theme.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3.5)
                                .background(
                                    isSelected ? DS.Theme.amber : Color.white.opacity(0.05),
                                    in: RoundedRectangle(cornerRadius: 4)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
            }
            .padding(.bottom, 8)

            Divider().opacity(0.12)

            // Mountain Peaks List
            ScrollView {
                LazyVStack(spacing: 4) {
                    if filteredTreks.isEmpty {
                        Text("No mountain peaks found")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Theme.textTertiary)
                            .padding(.top, 24)
                    } else {
                        ForEach(filteredTreks) { trek in
                            peakRow(trek: trek)
                        }
                    }
                }
                .padding(6)
            }

            // Inline Dossier at Bottom of Drawer (if a peak is selected)
            if let selected = selectedTrek {
                selectedPeakInlineDossier(trek: selected)
            }
        }
        .frame(width: 330)
        .frame(maxHeight: 560)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.08, green: 0.09, blue: 0.12).opacity(0.94))
                .shadow(color: Color.black.opacity(0.55), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
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

    private func cameraForFilter(_ filter: TrekFilter) -> MKMapCamera {
        switch filter {
        case .gujarat:
            return MKMapCamera(
                lookingAtCenter: CLLocationCoordinate2D(latitude: 21.5222, longitude: 70.5771),
                fromDistance: 450_000,
                pitch: 52,
                heading: 10
            )
        case .maharashtra:
            return MKMapCamera(
                lookingAtCenter: CLLocationCoordinate2D(latitude: 19.3000, longitude: 73.8000),
                fromDistance: 480_000,
                pitch: 54,
                heading: 15
            )
        case .uttarakhand:
            return MKMapCamera(
                lookingAtCenter: CLLocationCoordinate2D(latitude: 30.5000, longitude: 79.4000),
                fromDistance: 380_000,
                pitch: 58,
                heading: 25
            )
        case .himachal:
            return MKMapCamera(
                lookingAtCenter: CLLocationCoordinate2D(latitude: 32.2500, longitude: 77.3000),
                fromDistance: 380_000,
                pitch: 58,
                heading: 20
            )
        case .ladakh:
            return MKMapCamera(
                lookingAtCenter: CLLocationCoordinate2D(latitude: 34.1526, longitude: 77.5771),
                fromDistance: 480_000,
                pitch: 56,
                heading: 15
            )
        case .rajasthan:
            return MKMapCamera(
                lookingAtCenter: CLLocationCoordinate2D(latitude: 24.6500, longitude: 72.7800),
                fromDistance: 320_000,
                pitch: 48,
                heading: 5
            )
        case .sikkim:
            return MKMapCamera(
                lookingAtCenter: CLLocationCoordinate2D(latitude: 27.5330, longitude: 88.5122),
                fromDistance: 360_000,
                pitch: 58,
                heading: 30
            )
        case .southIndia:
            return MKMapCamera(
                lookingAtCenter: CLLocationCoordinate2D(latitude: 11.5000, longitude: 76.5000),
                fromDistance: 520_000,
                pitch: 50,
                heading: 0
            )
        case .sevenSummits:
            return MKMapCamera(
                lookingAtCenter: CLLocationCoordinate2D(latitude: 27.9881, longitude: 86.9250),
                fromDistance: 2_800_000,
                pitch: 48,
                heading: 15
            )
        case .conquered, .unclimbed, .all:
            return MKMapCamera(
                lookingAtCenter: CLLocationCoordinate2D(latitude: 23.5, longitude: 79.0),
                fromDistance: 3_800_000,
                pitch: 38,
                heading: 0
            )
        }
    }

    // MARK: - Peak Row Item

    private func peakRow(trek: TrekRecord) -> some View {
        let isSelected = selectedTrek?.id == trek.id
        let isConquered = trek.status == .conquered

        return HStack(spacing: 8) {
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

            // Mountain Info (Click row to select & focus)
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    selectedTrek = trek
                }
                Haptics.impact(.light)
            } label: {
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(trek.name)
                            .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(Color.white)
                            .lineLimit(1)

                        Text("\(trek.region), \(trek.country)")
                            .font(.system(size: 9.5))
                            .foregroundStyle(DS.Theme.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(Int(trek.elevationMeters).formatted()) m")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(isConquered ? DS.Theme.amber : DS.Theme.textSecondary)

                        if isConquered {
                            Text("Conquered")
                                .font(.system(size: 7.5, weight: .bold))
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
        .padding(.vertical, 2)
        .machinedCard(isHovered: false, isSelected: isSelected, cornerRadius: 6, accent: DS.Theme.amber)
    }

    // MARK: - Inline Selected Peak Dossier (Inside Drawer)

    private func selectedPeakInlineDossier(trek: TrekRecord) -> some View {
        let isConquered = trek.status == .conquered

        return VStack(alignment: .leading, spacing: 6) {
            Divider().opacity(0.12)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(trek.name)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.white)
                            .lineLimit(1)

                        if isConquered {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 10.5))
                                .foregroundStyle(DS.Theme.amber)
                        }
                    }

                    Text("\(Int(trek.elevationMeters).formatted()) m · \(trek.difficulty.title) · \(trek.region)")
                        .font(.system(size: 9.5))
                        .foregroundStyle(DS.Theme.textSecondary)
                        .lineLimit(1)
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
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.03))
    }

    // MARK: - Floating Selected Peak Banner (When Drawer is Closed)

    private func floatingSelectedPeakBanner(trek: TrekRecord) -> some View {
        let isConquered = trek.status == .conquered

        return HStack(spacing: 12) {
            // Trophy / Status Indicator
            Image(systemName: isConquered ? "trophy.fill" : "mountain.2.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isConquered ? DS.Theme.amber : Color.white.opacity(0.7))

            // Peak Title & Stats
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(trek.name)
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(Color.white)

                    if isConquered {
                        Text("CONQUERED")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(DS.Theme.amber)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(DS.Theme.amber.opacity(0.18), in: Capsule())
                    }
                }

                Text("\(Int(trek.elevationMeters).formatted()) m · \(trek.difficulty.title) · \(trek.region)")
                    .font(.system(size: 10))
                    .foregroundStyle(DS.Theme.textSecondary)
            }

            // Expedition Passport Action
            Button {
                passportTrek = trek
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 10))
                    Text("Passport")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.15), lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Dismiss Selection Button
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    selectedTrek = nil
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(DS.Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Clear selection")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.08, green: 0.09, blue: 0.12).opacity(0.92))
                .shadow(color: Color.black.opacity(0.5), radius: 14, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Toggle Status

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
