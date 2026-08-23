import SwiftUI
import MapKit
import AppKit

// MARK: - TrekAnnotation

final class TrekAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let trek: TrekRecord

    init(trek: TrekRecord) {
        self.trek = trek
        self.coordinate = trek.coordinate
        self.title = trek.name
        self.subtitle = "\(trek.formattedElevation) · \(trek.region)"
        super.init()
    }
}

// MARK: - FogOfWarPolygon

final class FogOfWarPolygon: MKPolygon {}

// MARK: - MountainRangeOverlayPolygon

final class MountainRangeOverlayPolygon: MKPolygon {
    var massifID: String = ""
    var isConquered: Bool = false
    var isSelected: Bool = false
}

// MARK: - TrekTrailPolyline

final class TrekTrailPolyline: MKPolyline {
    var trekID: UUID = UUID()
    var isConquered: Bool = false
    var isSelected: Bool = false
}

// MARK: - TrekScrubAnnotation

final class TrekScrubAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        super.init()
    }
}

// MARK: - TrekScrubCrosshairAnnotationView

final class TrekScrubCrosshairAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "TrekScrubCrosshairAnnotationView"

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        self.frame = NSRect(x: 0, y: 0, width: 24, height: 24)
        self.canShowCallout = false
        self.wantsLayer = true
        self.displayPriority = .required
        setupLayers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayers() {
        guard let layer = self.layer else { return }
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }

        // Outer Glowing Pulse Ring
        let ringLayer = CALayer()
        ringLayer.frame = CGRect(x: 2, y: 2, width: 20, height: 20)
        ringLayer.cornerRadius = 10
        ringLayer.borderWidth = 2.0
        ringLayer.borderColor = NSColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.9).cgColor
        ringLayer.backgroundColor = NSColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.2).cgColor
        ringLayer.shadowColor = NSColor.cyan.cgColor
        ringLayer.shadowRadius = 6.0
        ringLayer.shadowOpacity = 0.8
        layer.addSublayer(ringLayer)

        // Center Solid Core
        let coreLayer = CALayer()
        coreLayer.frame = CGRect(x: 8, y: 8, width: 8, height: 8)
        coreLayer.cornerRadius = 4
        coreLayer.backgroundColor = NSColor.white.cgColor
        layer.addSublayer(coreLayer)
    }
}

// MARK: - MacTrekMapView (NSViewRepresentable)

/// Native AppKit MKMapView wrapper delivering precision camera controls, custom
/// illuminated summit badges, glowing beacon rings, GPX trail polylines, elevation scrub crosshair, and Fog-of-War hole-punching overlays.
struct MacTrekMapView: NSViewRepresentable {

    let treks: [TrekRecord]
    let selectedTrek: TrekRecord?
    var scrubCoordinate: CLLocationCoordinate2D? = nil
    var isFlyingTrail: Bool = false
    var onFinishFlyTrail: () -> Void = {}
    let onSelectTrek: (TrekRecord) -> Void

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        mapView.wantsLayer = true
        mapView.layer?.masksToBounds = true
        mapView.delegate = context.coordinator
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.showsPitchControl = true
        mapView.showsZoomControls = true

        // Configure 3D realistic satellite imagery on macOS 14+
        let config = MKHybridMapConfiguration(elevationStyle: .realistic)
        config.pointOfInterestFilter = .excludingAll
        config.showsTraffic = false
        mapView.preferredConfiguration = config

        // Register custom annotations
        mapView.register(TrekAnnotationView.self, forAnnotationViewWithReuseIdentifier: TrekAnnotationView.reuseIdentifier)
        mapView.register(TrekScrubCrosshairAnnotationView.self, forAnnotationViewWithReuseIdentifier: TrekScrubCrosshairAnnotationView.reuseIdentifier)

        // Set initial camera over world
        let initialCoord = CLLocationCoordinate2D(latitude: 30.0, longitude: 15.0)
        let camera = MKMapCamera(lookingAtCenter: initialCoord, fromDistance: 16_000_000, pitch: 40, heading: 0)
        mapView.setCamera(camera, animated: false)

        return mapView
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self

        // 1. Update Annotations
        let currentAnnotations = mapView.annotations.compactMap { $0 as? TrekAnnotation }
        let currentIDs = Set(currentAnnotations.map { $0.trek.id })
        let newIDs = Set(treks.map { $0.id })

        if currentIDs != newIDs || currentAnnotations.count != treks.count {
            mapView.removeAnnotations(currentAnnotations)
            let newAnnotations = treks.map { TrekAnnotation(trek: $0) }
            mapView.addAnnotations(newAnnotations)
        } else {
            for annotation in currentAnnotations {
                if let view = mapView.view(for: annotation) as? TrekAnnotationView {
                    view.updateVisuals(isSelected: annotation.trek.id == selectedTrek?.id)
                }
            }
        }

        // 2. Update Elevation Chart Scrub Crosshair (aa4)
        if let scrubCoord = scrubCoordinate {
            if let existing = mapView.annotations.first(where: { $0 is TrekScrubAnnotation }) as? TrekScrubAnnotation {
                existing.coordinate = scrubCoord
            } else {
                mapView.addAnnotation(TrekScrubAnnotation(coordinate: scrubCoord))
            }
        } else {
            let scrubAnnotations = mapView.annotations.filter { $0 is TrekScrubAnnotation }
            if !scrubAnnotations.isEmpty {
                mapView.removeAnnotations(scrubAnnotations)
            }
        }

        // 3. Update Fog of War, Auras, and GPX Trail Overlays (Only when conquered set or selected trek changes)
        let conqueredIDs = treks.filter { $0.status == .conquered }.map { $0.id.uuidString }.sorted().joined(separator: ",")
        let currentSig = "\(conqueredIDs)_\(selectedTrek?.id.uuidString ?? "")"
        if currentSig != context.coordinator.lastOverlaysSignature {
            context.coordinator.lastOverlaysSignature = currentSig
            updateMapOverlays(mapView: mapView)
        }

        // 4. Handle Active Trail Flyover
        if isFlyingTrail, let selectedTrek, selectedTrek.hasGPXTrack {
            let coords = selectedTrek.trailCoordinates
            if coords.count >= 2 {
                performTrailFlyover(mapView: mapView, coords: coords)
            }
            return
        }

        // 4. Fly Camera to Selected Trek
        if let selectedTrek, selectedTrek.id != context.coordinator.lastSelectedID {
            context.coordinator.lastSelectedID = selectedTrek.id

            // If selected trek has a GPX trail, frame the whole trail
            let trailCoords = selectedTrek.trailCoordinates
            if trailCoords.count >= 2 {
                let poly = MKPolyline(coordinates: trailCoords, count: trailCoords.count)
                let rect = poly.boundingMapRect
                let edgePadding = NSEdgeInsets(top: 80, left: 80, bottom: 80, right: 380) // Leave space for detail card
                mapView.setVisibleMapRect(rect, edgePadding: edgePadding, animated: true)
            } else {
                let camera = MKMapCamera(
                    lookingAtCenter: selectedTrek.coordinate,
                    fromDistance: 95_000,
                    pitch: 55,
                    heading: 10
                )
                mapView.setCamera(camera, animated: true)
            }

            if let targetAnnotation = mapView.annotations.first(where: { ($0 as? TrekAnnotation)?.trek.id == selectedTrek.id }) {
                mapView.selectAnnotation(targetAnnotation, animated: true)
            }
        }
    }

    private func performTrailFlyover(mapView: MKMapView, coords: [CLLocationCoordinate2D]) {
        guard coords.count >= 2 else { return }

        // Start at Trailhead with immersive 3D terrain pitch
        let start = coords.first!
        let cameraStart = MKMapCamera(lookingAtCenter: start, fromDistance: 14_000, pitch: 65, heading: 0)
        mapView.setCamera(cameraStart, animated: true)

        let stepCount = min(5, coords.count)
        let strideStep = max(1, coords.count / stepCount)

        for stepIndex in 1..<stepCount {
            let ptIndex = min(coords.count - 1, stepIndex * strideStep)
            let pt = coords[ptIndex]
            let prevPt = coords[max(0, ptIndex - 1)]

            // Compute path bearing heading
            let dLon = (pt.longitude - prevPt.longitude) * .pi / 180.0
            let lat1 = prevPt.latitude * .pi / 180.0
            let lat2 = pt.latitude * .pi / 180.0
            let y = sin(dLon) * cos(lat2)
            let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
            let heading = (atan2(y, x) * 180.0 / .pi + 360.0).truncatingRemainder(dividingBy: 360.0)

            DispatchQueue.main.asyncAfter(deadline: .now() + Double(stepIndex) * 1.5) {
                let camera = MKMapCamera(lookingAtCenter: pt, fromDistance: 12_000, pitch: 65, heading: heading)
                mapView.setCamera(camera, animated: true)
            }
        }

        // Finish at summit with panoramic framing
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(stepCount) * 1.5) {
            if let last = coords.last {
                let summitCamera = MKMapCamera(lookingAtCenter: last, fromDistance: 28_000, pitch: 50, heading: 20)
                mapView.setCamera(summitCamera, animated: true)
            }
            self.onFinishFlyTrail()
        }
    }

    private func updateMapOverlays(mapView: MKMapView) {
        mapView.removeOverlays(mapView.overlays)

        let conqueredTreks = treks.filter { $0.status == .conquered }

        // 1. Fog of War & Radiant Aura Overlays
        if !conqueredTreks.isEmpty {
            let worldCoordinates: [CLLocationCoordinate2D] = [
                CLLocationCoordinate2D(latitude: 85.0, longitude: -179.99),
                CLLocationCoordinate2D(latitude: 85.0, longitude: 179.99),
                CLLocationCoordinate2D(latitude: -85.0, longitude: 179.99),
                CLLocationCoordinate2D(latitude: -85.0, longitude: -179.99)
            ]

            var interiorHoles: [MKPolygon] = []
            var auraCircles: [MKCircle] = []

            for trek in conqueredTreks {
                let radius = max(20_000, trek.revealRadiusMeters ?? 45_000)

                // 1. Summit Peak Hole
                let summitHole = Self.createCirclePolygon(center: trek.coordinate, radiusMeters: radius, pointCount: 32)
                interiorHoles.append(summitHole)

                // 2. Trail Corridor Hole Punching (4.2)
                if trek.hasGPXTrack {
                    let corridorHoles = Self.createTrailCorridorHoles(coords: trek.trailCoordinates, corridorRadiusMeters: 5_000)
                    interiorHoles.append(contentsOf: corridorHoles)
                }

                let aura = MKCircle(center: trek.coordinate, radius: radius)
                auraCircles.append(aura)
            }

            let fogPolygon = FogOfWarPolygon(
                coordinates: worldCoordinates,
                count: worldCoordinates.count,
                interiorPolygons: interiorHoles
            )

            mapView.addOverlay(fogPolygon, level: .aboveRoads)
            for circle in auraCircles {
                mapView.addOverlay(circle, level: .aboveRoads)
            }
        }

        // 2. Mountain Range Geopolitical Massif Polygons
        for massif in MountainRangeBoundaryData.allRanges {
            let coords = massif.coordinates
            guard coords.count >= 3 else { continue }
            let poly = MountainRangeOverlayPolygon(coordinates: coords, count: coords.count)
            poly.massifID = massif.id

            // Check if any trek within this massif is conquered
            let hasConqueredTrekInMassif = treks.contains { trek in
                trek.status == .conquered &&
                (trek.region.localizedCaseInsensitiveContains(massif.stateName) ||
                 massif.rawCoordinates.contains { abs($0.0 - trek.latitude) < 0.35 && abs($0.1 - trek.longitude) < 0.35 })
            }

            poly.isConquered = hasConqueredTrekInMassif
            poly.isSelected = selectedTrek.map { trek in
                abs(massif.centerLatitude - trek.latitude) < 0.5 && abs(massif.centerLongitude - trek.longitude) < 0.5
            } ?? false

            mapView.addOverlay(poly, level: .aboveRoads)
        }

        // 3. GPX Trail Ridge Polylines with 60fps downsampling optimization
        for trek in treks where trek.hasGPXTrack {
            let coords = trek.trailCoordinates
            guard coords.count >= 2 else { continue }

            let renderCoords: [CLLocationCoordinate2D]
            if coords.count > 2000 {
                let strideStep = max(1, coords.count / 1500)
                var sampled = stride(from: 0, to: coords.count, by: strideStep).map { coords[$0] }
                if let last = coords.last, sampled.last?.latitude != last.latitude || sampled.last?.longitude != last.longitude {
                    sampled.append(last)
                }
                renderCoords = sampled
            } else {
                renderCoords = coords
            }

            let polyline = TrekTrailPolyline(coordinates: renderCoords, count: renderCoords.count)
            polyline.trekID = trek.id
            polyline.isConquered = trek.status == .conquered
            polyline.isSelected = trek.id == selectedTrek?.id
            mapView.addOverlay(polyline, level: .aboveRoads)
        }
    }

    /// Generates a smooth circular polygon for interior hole punching.
    static func createCirclePolygon(center: CLLocationCoordinate2D, radiusMeters: Double, pointCount: Int = 32) -> MKPolygon {
        let latDelta = radiusMeters / 111_000.0
        let lonDelta = radiusMeters / (111_000.0 * max(0.1, cos(center.latitude * .pi / 180.0)))
        var points: [CLLocationCoordinate2D] = []

        let n = max(8, pointCount)
        for i in 0..<n {
            let angle = Double(i) * (2.0 * .pi / Double(n))
            let ptLat = center.latitude + latDelta * sin(angle)
            let ptLon = center.longitude + lonDelta * cos(angle)
            points.append(CLLocationCoordinate2D(latitude: ptLat, longitude: ptLon))
        }

        return MKPolygon(coordinates: points, count: points.count)
    }

    /// Generates illuminated corridor hole polygons along an entire hiking route.
    static func createTrailCorridorHoles(coords: [CLLocationCoordinate2D], corridorRadiusMeters: Double = 5000.0) -> [MKPolygon] {
        guard coords.count >= 2 else { return [] }

        // Sample along trail to ensure smooth 60fps polygon rendering
        var sampledPoints: [CLLocationCoordinate2D] = []
        let step = max(1, coords.count / 32)

        for i in stride(from: 0, to: coords.count, by: step) {
            sampledPoints.append(coords[i])
        }
        if let last = coords.last, sampledPoints.last?.latitude != last.latitude {
            sampledPoints.append(last)
        }

        return sampledPoints.map { pt in
            createCirclePolygon(center: pt, radiusMeters: corridorRadiusMeters, pointCount: 12)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MacTrekMapView
        var lastSelectedID: UUID?
        var lastOverlaysSignature: String = ""

        init(parent: MacTrekMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let scrubAnnotation = annotation as? TrekScrubAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: TrekScrubCrosshairAnnotationView.reuseIdentifier,
                    for: annotation
                ) as? TrekScrubCrosshairAnnotationView ?? TrekScrubCrosshairAnnotationView(annotation: annotation, reuseIdentifier: TrekScrubCrosshairAnnotationView.reuseIdentifier)
                view.annotation = scrubAnnotation
                return view
            }

            guard let trekAnnotation = annotation as? TrekAnnotation else { return nil }

            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: TrekAnnotationView.reuseIdentifier,
                for: annotation
            ) as? TrekAnnotationView ?? TrekAnnotationView(annotation: annotation, reuseIdentifier: TrekAnnotationView.reuseIdentifier)

            view.annotation = trekAnnotation
            let isSelected = trekAnnotation.trek.id == parent.selectedTrek?.id
            view.updateVisuals(isSelected: isSelected)
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let trekAnnotation = view.annotation as? TrekAnnotation else { return }
            DispatchQueue.main.async {
                self.parent.onSelectTrek(trekAnnotation.trek)
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let trail = overlay as? TrekTrailPolyline {
                let renderer = MKPolylineRenderer(polyline: trail)
                if trail.isSelected {
                    renderer.strokeColor = NSColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 1.0) // Radiant Neon Cyan
                    renderer.lineWidth = 4.5
                } else if trail.isConquered {
                    renderer.strokeColor = NSColor(red: 0.0, green: 0.85, blue: 0.95, alpha: 0.85) // Conquered Cyan
                    renderer.lineWidth = 3.2
                } else {
                    renderer.strokeColor = NSColor(red: 0.75, green: 0.5, blue: 1.0, alpha: 0.75) // Wishlist Violet
                    renderer.lineWidth = 2.8
                }
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            } else if let massif = overlay as? MountainRangeOverlayPolygon {
                let renderer = MKPolygonRenderer(polygon: massif)
                if massif.isSelected {
                    renderer.fillColor = NSColor(red: 1.0, green: 0.75, blue: 0.0, alpha: 0.18) // Subtle Amber Massif Glow
                    renderer.strokeColor = NSColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0)
                    renderer.lineWidth = 2.5
                } else if massif.isConquered {
                    renderer.fillColor = NSColor(red: 0.0, green: 0.85, blue: 0.45, alpha: 0.12) // Subtle Conquered Emerald
                    renderer.strokeColor = NSColor(red: 0.2, green: 0.9, blue: 0.5, alpha: 0.85)
                    renderer.lineWidth = 1.8
                } else {
                    renderer.fillColor = NSColor.clear // Clear to showcase satellite photography
                    renderer.strokeColor = NSColor(white: 1.0, alpha: 0.28)
                    renderer.lineWidth = 1.0
                    renderer.lineDashPattern = [5, 4]
                }
                return renderer
            } else if let fog = overlay as? FogOfWarPolygon {
                let renderer = MKPolygonRenderer(polygon: fog)
                renderer.fillColor = NSColor(red: 0.05, green: 0.07, blue: 0.11, alpha: 0.20) // Light Cinematic Satellite Fog
                return renderer
            } else if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.06)
                renderer.strokeColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.7)
                renderer.lineWidth = 1.5
                renderer.lineDashPattern = [5, 4]
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - TrekAnnotationView

final class TrekAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "TrekAnnotationView"

    private let badgeLayer = CALayer()
    private let iconImageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupViews()
    }

    private func setupViews() {
        canShowCallout = false
        clusteringIdentifier = "summitCluster"
        frame = NSRect(x: 0, y: 0, width: 44, height: 44)
        wantsLayer = true

        badgeLayer.frame = bounds
        badgeLayer.cornerRadius = 22
        badgeLayer.masksToBounds = false
        badgeLayer.shadowRadius = 8
        badgeLayer.shadowOpacity = 0.6
        badgeLayer.shadowOffset = CGSize(width: 0, height: 3)
        if let layer {
            layer.addSublayer(badgeLayer)
        }

        iconImageView.frame = NSRect(x: 10, y: 10, width: 24, height: 24)
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconImageView)
    }

    func updateVisuals(isSelected: Bool) {
        guard let trekAnnotation = annotation as? TrekAnnotation else { return }
        let trek = trekAnnotation.trek
        let isConquered = trek.status == .conquered

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        if isConquered {
            // Radiant Cyan / Amber Summit Beacon
            badgeLayer.backgroundColor = NSColor(red: 0.05, green: 0.12, blue: 0.22, alpha: 0.95).cgColor
            badgeLayer.borderColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0).cgColor
            badgeLayer.borderWidth = isSelected ? 3.0 : 2.0
            badgeLayer.shadowColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.8).cgColor

            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .bold)
            let img = NSImage(systemSymbolName: "trophy.fill", accessibilityDescription: "Conquered")?.withSymbolConfiguration(config)
            iconImageView.image = img
            iconImageView.contentTintColor = NSColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 1.0)
        } else {
            // Muted Slate Translucent Wishlist Pin
            badgeLayer.backgroundColor = NSColor(red: 0.12, green: 0.14, blue: 0.18, alpha: 0.85).cgColor
            badgeLayer.borderColor = NSColor(white: 0.5, alpha: 0.4).cgColor
            badgeLayer.borderWidth = isSelected ? 2.5 : 1.0
            badgeLayer.shadowColor = NSColor.black.cgColor

            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            let img = NSImage(systemSymbolName: "mappin.and.ellipse", accessibilityDescription: "Wishlist")?.withSymbolConfiguration(config)
            iconImageView.image = img
            iconImageView.contentTintColor = NSColor(white: 0.7, alpha: 1.0)
        }

        let scale: CGFloat = isSelected ? 1.25 : 1.0
        self.layer?.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        CATransaction.commit()
    }
}
