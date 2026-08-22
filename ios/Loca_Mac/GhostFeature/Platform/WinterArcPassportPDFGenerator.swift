import Foundation
import AppKit
import CoreGraphics
import UniformTypeIdentifiers

// MARK: - WinterArcPassportData

public struct WinterArcPassportData: Sendable {
    public let season: GhostSeason
    public let streakStatus: GhostEngine.StreakStatus
    public let ridgePoints: [GhostRidgePoint]
    public let days: [GhostDay]
    public let receipts: [GhostReceipt]
    public let photos: [GhostEngine.GhostPhotoArtifact]
    public let darkHours: GhostEngine.DarkHoursSummary
    public let evolution: GhostEngine.GhostEvolutionReport
    public let callsign: String
    public let serial: String

    public init(
        season: GhostSeason,
        streakStatus: GhostEngine.StreakStatus,
        ridgePoints: [GhostRidgePoint] = [],
        days: [GhostDay] = [],
        receipts: [GhostReceipt] = [],
        photos: [GhostEngine.GhostPhotoArtifact] = [],
        darkHours: GhostEngine.DarkHoursSummary = GhostEngine.DarkHoursSummary(),
        evolution: GhostEngine.GhostEvolutionReport = GhostEngine.GhostEvolutionReport(),
        callsign: String? = nil
    ) {
        self.season = season
        self.streakStatus = streakStatus
        self.ridgePoints = ridgePoints
        self.days = days
        self.receipts = receipts
        self.photos = photos
        self.darkHours = darkHours
        self.evolution = evolution

        let resolvedCallsign = (callsign?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? callsign!
            : "SOVEREIGN OPERATOR"
        self.callsign = resolvedCallsign

        // Format Serial: WA26-{device4}-{season4}
        let cleanDevice = season.deviceID.filter { $0.isLetter || $0.isNumber }.uppercased()
        let dev4 = String((cleanDevice + "MAC1").prefix(4))
        let cleanSeason = season.id.filter { $0.isLetter || $0.isNumber }.uppercased()
        let sea4 = String((cleanSeason + "9A3F").prefix(4))
        self.serial = "WA26-\(dev4)-\(sea4)"
    }
}

// MARK: - WinterArcMRZEngine

public enum WinterArcMRZEngine {
    
    /// Encodes passport metadata into two 44-character ICAO-style Machine Readable Zone lines.
    public static func encode(
        callsign: String,
        serial: String,
        doctrine: GhostDoctrine,
        expiryDate: Date,
        ghostDays: Int
    ) -> (line1: String, line2: String) {
        let df = DateFormatter()
        df.dateFormat = "yyMMdd"
        let expStr = df.string(from: expiryDate)

        // Line 1: P<PLT + CALLSIGN sanitized + padding to 44
        let cleanCallsign = callsign.uppercased().map { ($0.isLetter || $0.isNumber) ? $0 : "<" }
        var line1 = "P<PLT" + String(cleanCallsign)
        if line1.count > 44 {
            line1 = String(line1.prefix(44))
        } else {
            line1 = line1.padding(toLength: 44, withPad: "<", startingAt: 0)
        }

        // Line 2: SERIAL + DOCTRINE + EXPIRY + GHOSTDAYS + padding to 44
        let cleanSerial = serial.replacingOccurrences(of: "-", with: "").uppercased()
        let docTag = (doctrine == .hard) ? "HARD" : "ARCD"
        let daysTag = String(format: "%03d", min(999, max(0, ghostDays)))

        var line2 = "\(cleanSerial)<<\(docTag)<\(expStr)<<\(daysTag)"
        if line2.count > 44 {
            line2 = String(line2.prefix(44))
        } else {
            line2 = line2.padding(toLength: 44, withPad: "<", startingAt: 0)
        }

        return (line1, line2)
    }

    /// Decodes MRZ lines back into structural data for round-trip validation.
    public static func decode(line1: String, line2: String) -> (callsign: String, serial: String, doctrine: String, expiry: String, ghostDays: Int)? {
        guard line1.count == 44, line2.count == 44, line1.hasPrefix("P<PLT") else { return nil }

        let callsignRaw = String(line1.dropFirst(5)).replacingOccurrences(of: "<", with: " ").trimmingCharacters(in: .whitespaces)
        let parts = line2.components(separatedBy: "<").filter { !$0.isEmpty }

        guard parts.count >= 4 else { return nil }
        let serial = parts[0]
        let doctrine = parts[1]
        let expiry = parts[2]
        let ghostDays = Int(parts[3]) ?? 0

        return (callsignRaw, serial, doctrine, expiry, ghostDays)
    }
}

// MARK: - WinterArcPassportPDFGenerator (4-Page A4 Vector Booklet)

@MainActor
public enum WinterArcPassportPDFGenerator {

    public static let a4Width: CGFloat = 595.28  // 210mm in points
    public static let a4Height: CGFloat = 841.89 // 297mm in points
    public static let a4Rect = CGRect(x: 0, y: 0, width: a4Width, height: a4Height)

    // MARK: - Export PDF via NSSavePanel

    public static func exportBookletPDF(data: WinterArcPassportData, completion: ((Bool) -> Void)? = nil) {
        let panel = NSSavePanel()
        panel.title = "Export Winter Arc Sovereign Passport Booklet"
        panel.prompt = "Save Passport Booklet"
        let sanitizedName = data.season.name.replacingOccurrences(of: " ", with: "_")
        panel.nameFieldStringValue = "\(sanitizedName)_Sovereign_Passport_Booklet.pdf"
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true

        panel.begin { response in
            guard response == .OK, let targetURL = panel.url else {
                completion?(false)
                return
            }

            let pdfData = generatePDFData(data: data)
            do {
                try pdfData.write(to: targetURL)
                Haptics.notification(.success)
                completion?(true)
            } catch {
                completion?(false)
            }
        }
    }

    // MARK: - PDF Generation Pipeline

    public static func generatePDFData(data: WinterArcPassportData) -> Data {
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
            return Data()
        }

        var mediaBox = a4Rect
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }

        // PAGE 1: COVER
        context.beginPage(mediaBox: &mediaBox)
        drawCoverPage(context: context, rect: a4Rect, data: data)
        context.endPage()

        // PAGE 2: IDENTITY
        context.beginPage(mediaBox: &mediaBox)
        drawIdentityPage(context: context, rect: a4Rect, data: data)
        context.endPage()

        // PAGE 3: VISAS & ENTRIES
        context.beginPage(mediaBox: &mediaBox)
        drawVisasPage(context: context, rect: a4Rect, data: data)
        context.endPage()

        // PAGE 4: THE RECORD
        context.beginPage(mediaBox: &mediaBox)
        drawRecordPage(context: context, rect: a4Rect, data: data)
        context.endPage()

        context.closePDF()
        return pdfData as Data
    }

    // MARK: - Page 1: Cover

    private static func drawCoverPage(context: CGContext, rect: CGRect, data: WinterArcPassportData) {
        drawPageBackground(context: context, rect: rect)
        drawGuillochePattern(context: context, center: CGPoint(x: rect.midX, y: rect.height * 0.55), radius: 140, layers: 3)

        // Outer Border Double Line
        context.saveGState()
        context.setStrokeColor(cyanColor(alpha: 0.35).cgColor)
        context.setLineWidth(1.5)
        context.stroke(rect.insetBy(dx: 28, dy: 28))
        context.setLineWidth(0.6)
        context.stroke(rect.insetBy(dx: 33, dy: 33))
        context.restoreGState()

        // Top Emblem & Tracked Caps
        let topCenter = CGPoint(x: rect.midX, y: rect.height - 90)
        drawText(
            "PLUTO SOVEREIGN OPERATING SYSTEM",
            at: topCenter,
            font: .monospacedSystemFont(ofSize: 8.5, weight: .bold),
            color: cyanColor(alpha: 0.6),
            alignment: .center,
            tracking: 3.0
        )

        // Large Passport Title
        drawText(
            "SOVEREIGN GHOST PASSPORT",
            at: CGPoint(x: rect.midX, y: rect.height - 130),
            font: .systemFont(ofSize: 20, weight: .black),
            color: .white,
            alignment: .center,
            tracking: 3.5
        )

        // Season Serif Subtitle
        drawText(
            data.season.name.uppercased(),
            at: CGPoint(x: rect.midX, y: rect.height - 158),
            font: NSFont(name: "NewYork-Medium", size: 14) ?? .systemFont(ofSize: 14, weight: .semibold),
            color: orangeColor(alpha: 0.9),
            alignment: .center,
            tracking: 2.0
        )

        // Central Ghost Emblem with Microtext Ring
        let emblemCenter = CGPoint(x: rect.midX, y: rect.height * 0.52)
        drawCentralEmblem(context: context, center: emblemCenter, radius: 85, rank: data.streakStatus.rank)

        // Biometric Chip Glyph
        let chipRect = CGRect(x: rect.midX - 28, y: rect.height * 0.28, width: 56, height: 42)
        drawBiometricChip(context: context, rect: chipRect)

        // Serial Number
        drawText(
            data.serial,
            at: CGPoint(x: rect.midX, y: rect.height * 0.22),
            font: .monospacedSystemFont(ofSize: 12, weight: .bold),
            color: cyanColor(alpha: 0.95),
            alignment: .center,
            tracking: 2.5
        )

        // Footer
        drawText(
            "NO CLOUD · NO WITNESSES · AUTHENTICATED ON-DEVICE",
            at: CGPoint(x: rect.midX, y: 50),
            font: .monospacedSystemFont(ofSize: 8, weight: .bold),
            color: NSColor(white: 0.5, alpha: 1.0),
            alignment: .center,
            tracking: 2.0
        )
    }

    // MARK: - Page 2: Identity

    private static func drawIdentityPage(context: CGContext, rect: CGRect, data: WinterArcPassportData) {
        drawPageBackground(context: context, rect: rect)
        drawGuillochePattern(context: context, center: CGPoint(x: rect.midX, y: rect.height * 0.5), radius: 180, layers: 2)

        // Header
        drawHeaderBanner(title: "OFFICIAL SOVEREIGN IDENTITY COVENANT", pageNo: "02", rect: rect)

        // Photo Area (3:4 Ratio)
        let photoRect = CGRect(x: 44, y: rect.height - 290, width: 125, height: 166)
        drawHolderPhoto(context: context, rect: photoRect, photos: data.photos)

        // Fields Grid
        let leftX: CGFloat = 190
        let rightX: CGFloat = 380
        var currentY: CGFloat = rect.height - 145
        let spacing: CGFloat = 36

        drawField(label: "PASSPORT NO.", value: data.serial, at: CGPoint(x: leftX, y: currentY))
        drawField(label: "CURRENT RANK", value: data.streakStatus.rank.rawValue.uppercased(), at: CGPoint(x: rightX, y: currentY), valueColor: orangeColor())

        currentY -= spacing
        drawField(label: "BEARER CALLSIGN", value: data.callsign.uppercased(), at: CGPoint(x: leftX, y: currentY))
        drawField(label: "PROTOCOL KIND", value: data.season.protocolKind.title.uppercased(), at: CGPoint(x: rightX, y: currentY))

        currentY -= spacing
        let df = DateFormatter()
        df.dateStyle = .medium
        drawField(label: "ISSUED DATE", value: df.string(from: data.season.signedAt).uppercased(), at: CGPoint(x: leftX, y: currentY))
        drawField(label: "EXPIRY DATE", value: "31 DEC 2026", at: CGPoint(x: rightX, y: currentY))

        currentY -= spacing
        drawField(label: "GOVERNING DOCTRINE", value: data.season.doctrine.title.uppercased(), at: CGPoint(x: leftX, y: currentY))
        drawField(label: "ISSUING AUTHORITY", value: "\(data.season.deviceID.uppercased()) / PLUTO", at: CGPoint(x: rightX, y: currentY))

        // Digital Signature Script
        let sigY: CGFloat = rect.height - 350
        drawField(label: "DIGITAL COVENANT SIGNATURE", value: "", at: CGPoint(x: 44, y: sigY))
        drawText(
            data.callsign,
            at: CGPoint(x: 44, y: sigY - 24),
            font: NSFont(name: "SnellRoundhand-Bold", size: 22) ?? .systemFont(ofSize: 20, weight: .medium),
            color: cyanColor(alpha: 0.9)
        )
        drawText(
            "Cryptographic Fingerprint: SHA256-\(data.season.id.prefix(16).uppercased())",
            at: CGPoint(x: 44, y: sigY - 42),
            font: .monospacedSystemFont(ofSize: 8, weight: .regular),
            color: NSColor(white: 0.45, alpha: 1.0)
        )

        // MRZ Box at Bottom
        let mrzRect = CGRect(x: 36, y: 48, width: rect.width - 72, height: 75)
        drawMRZBox(context: context, rect: mrzRect, data: data)
    }

    // MARK: - Page 3: Visas & Entries

    private static func drawVisasPage(context: CGContext, rect: CGRect, data: WinterArcPassportData) {
        drawPageBackground(context: context, rect: rect)
        drawGuillochePattern(context: context, center: CGPoint(x: rect.midX, y: rect.height * 0.6), radius: 160, layers: 2)

        drawHeaderBanner(title: "PROTOCOL VISA STAMPS & 120-DAY ENTRY LEDGER", pageNo: "03", rect: rect)

        // 7 Visa Stamps Grid (3 Columns)
        let stampRanks: [(GhostRank, Int)] = [
            (.uninitiated, 0),
            (.apparition, 1),
            (.shadow, 7),
            (.phantom, 21),
            (.wraith, 45),
            (.specter, 75),
            (.sovereign, 120)
        ]

        let startX: CGFloat = 90
        let startY: CGFloat = rect.height - 180
        let colWidth: CGFloat = 145
        let rowHeight: CGFloat = 120

        for (idx, item) in stampRanks.enumerated() {
            let row = idx / 3
            let col = idx % 3
            let center = CGPoint(x: startX + CGFloat(col) * colWidth + 50, y: startY - CGFloat(row) * rowHeight)

            let isEarned = data.streakStatus.totalGhostDays >= item.1 || data.streakStatus.bestStreak >= item.1
            let jitter: CGFloat = CGFloat((idx % 3 == 0 ? -4 : (idx % 2 == 0 ? 5 : -2)))

            drawRankStamp(
                context: context,
                center: center,
                radius: 46,
                rank: item.0,
                threshold: item.1,
                isEarned: isEarned,
                jitterDeg: jitter
            )
        }

        // 120-Square Entry Strip at Bottom
        let stripRect = CGRect(x: 44, y: 60, width: rect.width - 88, height: 160)
        drawEntryGridStrip(context: context, rect: stripRect, data: data)
    }

    // MARK: - Page 4: The Record

    private static func drawRecordPage(context: CGContext, rect: CGRect, data: WinterArcPassportData) {
        drawPageBackground(context: context, rect: rect)
        drawGuillochePattern(context: context, center: CGPoint(x: rect.midX, y: rect.height * 0.5), radius: 170, layers: 2)

        drawHeaderBanner(title: "THE RECORD • MOUNTAIN RIDGE & PROOF OF SILENCE", pageNo: "04", rect: rect)

        if data.streakStatus.totalGhostDays == 0 {
            // Day 0 Grace State
            drawDayZeroGraceHero(context: context, rect: rect)
        } else {
            // 1. Vector Ridge Chart
            let ridgeRect = CGRect(x: 44, y: rect.height - 300, width: rect.width - 88, height: 160)
            drawVectorRidge(context: context, rect: ridgeRect, points: data.ridgePoints)

            // 2. Three Ring Micro-Arc Gauges
            let gaugeY: CGFloat = rect.height - 390
            let bodyPct = data.evolution.bodyAdherence
            let mindPct = data.evolution.mindAdherence
            let silPct = data.evolution.silenceAdherence

            drawMicroArcGauge(context: context, center: CGPoint(x: 120, y: gaugeY), radius: 30, percentage: bodyPct, color: ColorHex.red, label: "BODY FORGE")
            drawMicroArcGauge(context: context, center: CGPoint(x: rect.midX, y: gaugeY), radius: 30, percentage: mindPct, color: ColorHex.blue, label: "MIND SYNTH")
            drawMicroArcGauge(context: context, center: CGPoint(x: rect.width - 120, y: gaugeY), radius: 30, percentage: silPct, color: ColorHex.cyan, label: "SILENCE DEEP")

            // 3. Totals Metric Bar
            let metricY: CGFloat = rect.height - 490
            let totalSilenceHours = Double(data.darkHours.weekMinutes) / 60.0
            drawMetricPill(title: "TOTAL SILENCE", value: "\(String(format: "%.1f", totalSilenceHours)) Hours", at: CGPoint(x: 110, y: metricY))
            drawMetricPill(title: "LONGEST STRETCH", value: "\(data.darkHours.longestStretchMinutes) Mins", at: CGPoint(x: rect.midX, y: metricY))
            drawMetricPill(title: "GHOST DAYS SEALED", value: "\(data.streakStatus.totalGhostDays) Days", at: CGPoint(x: rect.width - 110, y: metricY))

            // 4. 3-Frame Photo Strip
            let photoStripRect = CGRect(x: 44, y: rect.height - 660, width: rect.width - 88, height: 110)
            draw3FramePhotoStrip(context: context, rect: photoStripRect, photos: data.photos)

            // 5. Completion Sovereign Stamp
            if data.streakStatus.totalGhostDays >= data.season.totalDays || data.streakStatus.rank == .sovereign {
                drawSovereignCompletionSeal(context: context, center: CGPoint(x: rect.midX, y: 95), radius: 48)
            }
        }
    }

    // MARK: - Drawing Components

    private static func drawPageBackground(context: CGContext, rect: CGRect) {
        context.setFillColor(NSColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1.0).cgColor)
        context.fill(rect)
    }

    private static func drawGuillochePattern(context: CGContext, center: CGPoint, radius: CGFloat, layers: Int) {
        context.saveGState()
        context.setLineWidth(0.3)

        for l in 0..<layers {
            let k: CGFloat = CGFloat(6 * (l + 1))
            let a: CGFloat = CGFloat(10 + l * 6)
            let phi: CGFloat = CGFloat(l) * (.pi / 4.0)

            context.setStrokeColor(cyanColor(alpha: 0.06 + CGFloat(l) * 0.02).cgColor)
            context.beginPath()

            let steps = 360
            for i in 0...steps {
                let theta = (CGFloat(i) / CGFloat(steps)) * 2.0 * .pi
                let r = radius + a * sin(k * theta + phi)
                let x = center.x + r * cos(theta)
                let y = center.y + r * sin(theta)

                if i == 0 {
                    context.move(to: CGPoint(x: x, y: y))
                } else {
                    context.addLine(to: CGPoint(x: x, y: y))
                }
            }
            context.closePath()
            context.strokePath()
        }
        context.restoreGState()
    }

    private static func drawCentralEmblem(context: CGContext, center: CGPoint, radius: CGFloat, rank: GhostRank) {
        context.saveGState()

        // Double Circle
        context.setStrokeColor(cyanColor(alpha: 0.7).cgColor)
        context.setLineWidth(1.8)
        context.addArc(center: center, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
        context.strokePath()

        context.setStrokeColor(cyanColor(alpha: 0.3).cgColor)
        context.setLineWidth(0.8)
        context.addArc(center: center, radius: radius - 6, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
        context.strokePath()

        // Central Glyph Text
        drawText(
            rank.glyph.uppercased(),
            at: CGPoint(x: center.x, y: center.y - 10),
            font: .systemFont(ofSize: 28, weight: .black),
            color: cyanColor(alpha: 0.9),
            alignment: .center
        )

        drawText(
            rank.rawValue.uppercased(),
            at: CGPoint(x: center.x, y: center.y - 28),
            font: .monospacedSystemFont(ofSize: 9, weight: .bold),
            color: orangeColor(alpha: 0.9),
            alignment: .center,
            tracking: 1.5
        )

        context.restoreGState()
    }

    private static func drawBiometricChip(context: CGContext, rect: CGRect) {
        context.saveGState()
        context.setFillColor(NSColor(red: 0.12, green: 0.14, blue: 0.18, alpha: 1.0).cgColor)
        context.setStrokeColor(orangeColor(alpha: 0.8).cgColor)
        context.setLineWidth(1.0)

        let path = CGPath(roundedRect: rect, cornerWidth: 5, cornerHeight: 5, transform: nil)
        context.addPath(path)
        context.drawPath(using: .fillStroke)

        // Chip Pin Traces
        context.setStrokeColor(orangeColor(alpha: 0.6).cgColor)
        context.setLineWidth(0.8)
        context.move(to: CGPoint(x: rect.minX + 10, y: rect.minY))
        context.addLine(to: CGPoint(x: rect.minX + 10, y: rect.maxY))
        context.move(to: CGPoint(x: rect.maxX - 10, y: rect.minY))
        context.addLine(to: CGPoint(x: rect.maxX - 10, y: rect.maxY))
        context.move(to: CGPoint(x: rect.minX, y: rect.midY))
        context.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        context.strokePath()

        context.restoreGState()
    }

    private static func drawHolderPhoto(context: CGContext, rect: CGRect, photos: [GhostEngine.GhostPhotoArtifact]) {
        context.saveGState()
        context.setStrokeColor(cyanColor(alpha: 0.4).cgColor)
        context.setLineWidth(1.0)
        context.stroke(rect)

        if let firstPhoto = photos.first,
           let image = NSImage(contentsOfFile: firstPhoto.photoPath),
           let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.saveGState()
            context.clip(to: rect)
            context.draw(cgImage, in: rect)
            context.restoreGState()
        } else {
            // Silhouette vector fallback
            drawVectorSilhouette(context: context, rect: rect)
        }
        context.restoreGState()
    }

    private static func drawVectorSilhouette(context: CGContext, rect: CGRect) {
        context.saveGState()
        context.setFillColor(NSColor(white: 0.08, alpha: 1.0).cgColor)
        context.fill(rect)

        let center = CGPoint(x: rect.midX, y: rect.midY)
        // Hooded circle head
        context.setFillColor(cyanColor(alpha: 0.3).cgColor)
        context.addArc(center: CGPoint(x: center.x, y: center.y + 15), radius: 24, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
        context.fillPath()

        // Shoulders arc
        context.addArc(center: CGPoint(x: center.x, y: center.y - 30), radius: 45, startAngle: 0, endAngle: .pi, clockwise: false)
        context.fillPath()

        drawText("AUTHENTICATED", at: CGPoint(x: center.x, y: rect.minY + 10), font: .monospacedSystemFont(ofSize: 7, weight: .bold), color: cyanColor(alpha: 0.5), alignment: .center, tracking: 1.0)
        context.restoreGState()
    }

    private static func drawRankStamp(
        context: CGContext,
        center: CGPoint,
        radius: CGFloat,
        rank: GhostRank,
        threshold: Int,
        isEarned: Bool,
        jitterDeg: CGFloat
    ) {
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: jitterDeg * (.pi / 180.0))

        let color = isEarned ? (threshold >= 75 ? orangeColor(alpha: 0.9) : cyanColor(alpha: 0.9)) : NSColor(white: 0.25, alpha: 0.4)

        // Outer Ring
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(isEarned ? 1.5 : 0.8)
        if !isEarned {
            context.setLineDash(phase: 0, lengths: [3, 3])
        }
        context.addArc(center: .zero, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
        context.strokePath()

        // Inner Ring
        context.setLineWidth(0.6)
        context.addArc(center: .zero, radius: radius - 4, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
        context.strokePath()

        if isEarned {
            drawText(rank.rawValue.uppercased(), at: CGPoint(x: 0, y: 12), font: .systemFont(ofSize: 8, weight: .bold), color: color, alignment: .center)
            drawText("DAY \(threshold)", at: CGPoint(x: 0, y: 0), font: .monospacedSystemFont(ofSize: 9, weight: .black), color: color, alignment: .center)
            drawText("SEALED", at: CGPoint(x: 0, y: -14), font: .monospacedSystemFont(ofSize: 7, weight: .bold), color: color, alignment: .center, tracking: 1.0)
        } else {
            drawText("PENDING", at: CGPoint(x: 0, y: 4), font: .monospacedSystemFont(ofSize: 8, weight: .bold), color: NSColor(white: 0.35, alpha: 0.6), alignment: .center, tracking: 1.0)
            drawText("DAY \(threshold)", at: CGPoint(x: 0, y: -10), font: .monospacedSystemFont(ofSize: 7.5, weight: .medium), color: NSColor(white: 0.3, alpha: 0.6), alignment: .center)
        }

        context.restoreGState()
    }

    private static func drawEntryGridStrip(context: CGContext, rect: CGRect, data: WinterArcPassportData) {
        context.saveGState()
        drawText("120-DAY CHRONOLOGICAL ENTRY MATRIX", at: CGPoint(x: rect.minX, y: rect.maxY + 8), font: .monospacedSystemFont(ofSize: 8.5, weight: .bold), color: cyanColor(alpha: 0.7), tracking: 1.0)

        let daysMap = Dictionary(uniqueKeysWithValues: data.days.map { ($0.dateString, $0) })
        let calendar = Calendar.current
        let today = Date()

        let cols = 20
        let rows = 6
        let boxSize: CGFloat = 16
        let spacing: CGFloat = 4

        for r in 0..<rows {
            for c in 0..<cols {
                let idx = r * cols + c
                if idx >= 120 { break }

                let x = rect.minX + CGFloat(c) * (boxSize + spacing)
                let y = rect.maxY - 20 - CGFloat(r) * (boxSize + spacing)
                let boxRect = CGRect(x: x, y: y, width: boxSize, height: boxSize)

                let targetDate = calendar.date(byAdding: .day, value: idx, to: data.season.startDate) ?? data.season.startDate
                let dateStr = GhostEngine.dateString(from: targetDate)
                let record = daysMap[dateStr]
                let isGhost = record?.ghostDay ?? false
                let isPast = targetDate < today && !calendar.isDateInToday(targetDate)

                if isGhost {
                    context.setFillColor(cyanColor(alpha: 0.85).cgColor)
                    context.fill(boxRect)
                } else if isPast {
                    context.setFillColor(NSColor(white: 0.12, alpha: 1.0).cgColor)
                    context.fill(boxRect)
                    context.setStrokeColor(NSColor(white: 0.25, alpha: 1.0).cgColor)
                    context.setLineWidth(0.6)
                    context.stroke(boxRect)
                } else {
                    context.setStrokeColor(NSColor(white: 0.18, alpha: 0.8).cgColor)
                    context.setLineWidth(0.5)
                    context.stroke(boxRect)
                }
            }
        }
        context.restoreGState()
    }

    private static func drawVectorRidge(context: CGContext, rect: CGRect, points: [GhostRidgePoint]) {
        guard !points.isEmpty else { return }
        context.saveGState()

        drawText("ALPINE SEASON RIDGE PROFILE", at: CGPoint(x: rect.minX, y: rect.maxY + 8), font: .monospacedSystemFont(ofSize: 8.5, weight: .bold), color: cyanColor(alpha: 0.7), tracking: 1.0)

        let minAlt = (points.map(\.elevationMeters).min() ?? 800) * 0.95
        let maxAlt = (points.map(\.elevationMeters).max() ?? 5000) * 1.05

        let path = CGMutablePath()
        let count = points.count

        for (idx, pt) in points.enumerated() {
            let x = rect.minX + (CGFloat(idx) / CGFloat(max(1, count - 1))) * rect.width
            let normY = (pt.elevationMeters - minAlt) / max(1.0, (maxAlt - minAlt))
            let y = rect.minY + CGFloat(normY) * rect.height

            if idx == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.setStrokeColor(cyanColor(alpha: 0.9).cgColor)
        context.setLineWidth(1.8)
        context.addPath(path)
        context.strokePath()

        // Summit Flag
        if let last = points.last {
            let summitX = rect.maxX
            let normY = (last.elevationMeters - minAlt) / max(1.0, (maxAlt - minAlt))
            let summitY = rect.minY + CGFloat(normY) * rect.height
            drawText("🏁 SUMMIT", at: CGPoint(x: summitX - 10, y: summitY + 8), font: .monospacedSystemFont(ofSize: 8, weight: .bold), color: orangeColor())
        }

        context.restoreGState()
    }

    private static func drawMicroArcGauge(context: CGContext, center: CGPoint, radius: CGFloat, percentage: Double, color: NSColor, label: String) {
        context.saveGState()
        // Background Circle
        context.setStrokeColor(NSColor(white: 0.15, alpha: 0.6).cgColor)
        context.setLineWidth(3.0)
        context.addArc(center: center, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
        context.strokePath()

        // Active Arc
        let startAngle: CGFloat = -.pi / 2.0
        let endAngle: CGFloat = startAngle + (CGFloat(percentage) / 100.0) * 2.0 * .pi

        context.setStrokeColor(color.cgColor)
        context.setLineWidth(3.0)
        context.setLineCap(.round)
        context.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        context.strokePath()

        // Percentage Text
        drawText("\(Int(percentage))%", at: CGPoint(x: center.x, y: center.y - 4), font: .monospacedSystemFont(ofSize: 10, weight: .bold), color: .white, alignment: .center)
        drawText(label, at: CGPoint(x: center.x, y: center.y - radius - 14), font: .monospacedSystemFont(ofSize: 7.5, weight: .bold), color: color, alignment: .center)
        context.restoreGState()
    }

    private static func draw3FramePhotoStrip(context: CGContext, rect: CGRect, photos: [GhostEngine.GhostPhotoArtifact]) {
        context.saveGState()
        drawText("EVIDENCE ARTIFACT STRIP (DAY 1 · MID · CURRENT)", at: CGPoint(x: rect.minX, y: rect.maxY + 8), font: .monospacedSystemFont(ofSize: 8.5, weight: .bold), color: cyanColor(alpha: 0.7), tracking: 1.0)

        let frameWidth = (rect.width - 24) / 3.0
        for i in 0..<3 {
            let frameRect = CGRect(x: rect.minX + CGFloat(i) * (frameWidth + 12), y: rect.minY, width: frameWidth, height: rect.height)
            context.setStrokeColor(NSColor(white: 0.2, alpha: 1.0).cgColor)
            context.setLineWidth(0.8)
            context.stroke(frameRect)

            let photo = (i == 0) ? photos.first : (i == 1 ? (photos.count > 2 ? photos[photos.count / 2] : nil) : photos.last)
            if let p = photo, let img = NSImage(contentsOfFile: p.photoPath), let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                context.saveGState()
                context.clip(to: frameRect)
                context.draw(cg, in: frameRect)
                context.restoreGState()
            } else {
                drawText("FRAME \(i + 1)", at: CGPoint(x: frameRect.midX, y: frameRect.midY), font: .monospacedSystemFont(ofSize: 8, weight: .medium), color: NSColor(white: 0.3, alpha: 1.0), alignment: .center)
            }
        }
        context.restoreGState()
    }

    private static func drawSovereignCompletionSeal(context: CGContext, center: CGPoint, radius: CGFloat) {
        context.saveGState()
        context.setStrokeColor(orangeColor(alpha: 0.9).cgColor)
        context.setLineWidth(2.0)
        context.addArc(center: center, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
        context.strokePath()

        drawText("★ SOVEREIGN ARC CONQUERED ★", at: CGPoint(x: center.x, y: center.y + 6), font: .systemFont(ofSize: 7.5, weight: .black), color: orangeColor(), alignment: .center, tracking: 1.0)
        drawText("100% DISCIPLINE SEALED", at: CGPoint(x: center.x, y: center.y - 10), font: .monospacedSystemFont(ofSize: 7, weight: .bold), color: .white, alignment: .center)
        context.restoreGState()
    }

    private static func drawDayZeroGraceHero(context: CGContext, rect: CGRect) {
        let center = CGPoint(x: rect.midX, y: rect.height * 0.55)
        drawText(
            "AWAITING FIRST ENTRY",
            at: center,
            font: .systemFont(ofSize: 22, weight: .black),
            color: cyanColor(alpha: 0.9),
            alignment: .center,
            tracking: 3.0
        )
        drawText(
            "The winter covenant has been sealed. Ascend the Season Ridge upon your first closed ring.",
            at: CGPoint(x: center.x, y: center.y - 28),
            font: .systemFont(ofSize: 11, weight: .regular),
            color: NSColor(white: 0.6, alpha: 1.0),
            alignment: .center
        )
    }

    private static func drawMRZBox(context: CGContext, rect: CGRect, data: WinterArcPassportData) {
        context.saveGState()
        context.setFillColor(NSColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1.0).cgColor)
        context.setStrokeColor(cyanColor(alpha: 0.3).cgColor)
        context.setLineWidth(0.8)

        let path = CGPath(roundedRect: rect, cornerWidth: 4, cornerHeight: 4, transform: nil)
        context.addPath(path)
        context.drawPath(using: .fillStroke)

        let (line1, line2) = WinterArcMRZEngine.encode(
            callsign: data.callsign,
            serial: data.serial,
            doctrine: data.season.doctrine,
            expiryDate: data.season.endDate,
            ghostDays: data.streakStatus.totalGhostDays
        )

        drawText(line1, at: CGPoint(x: rect.minX + 12, y: rect.maxY - 28), font: .monospacedSystemFont(ofSize: 10, weight: .medium), color: cyanColor(alpha: 0.95))
        drawText(line2, at: CGPoint(x: rect.minX + 12, y: rect.maxY - 50), font: .monospacedSystemFont(ofSize: 10, weight: .medium), color: cyanColor(alpha: 0.95))
        context.restoreGState()
    }

    private static func drawHeaderBanner(title: String, pageNo: String, rect: CGRect) {
        let y = rect.height - 48
        drawText(title, at: CGPoint(x: 44, y: y), font: .monospacedSystemFont(ofSize: 9, weight: .bold), color: cyanColor(alpha: 0.8), tracking: 1.2)
        drawText("PAGE \(pageNo) OF 04", at: CGPoint(x: rect.width - 44, y: y), font: .monospacedSystemFont(ofSize: 9, weight: .bold), color: NSColor(white: 0.45, alpha: 1.0), alignment: .right)
    }

    private static func drawField(label: String, value: String, at point: CGPoint, valueColor: NSColor = .white) {
        drawText(label, at: point, font: .monospacedSystemFont(ofSize: 7.5, weight: .bold), color: NSColor(white: 0.45, alpha: 1.0), tracking: 1.0)
        drawText(value, at: CGPoint(x: point.x, y: point.y - 14), font: .systemFont(ofSize: 11, weight: .bold), color: valueColor)
    }

    private static func drawMetricPill(title: String, value: String, at point: CGPoint) {
        drawText(title, at: point, font: .monospacedSystemFont(ofSize: 8, weight: .bold), color: cyanColor(alpha: 0.6), alignment: .center, tracking: 1.0)
        drawText(value, at: CGPoint(x: point.x, y: point.y - 16), font: .monospacedSystemFont(ofSize: 13, weight: .black), color: .white, alignment: .center)
    }

    private static func drawText(
        _ text: String,
        at point: CGPoint,
        font: NSFont,
        color: NSColor,
        alignment: NSTextAlignment = .left,
        tracking: CGFloat = 0.0
    ) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment

        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        if tracking > 0 {
            attrs[.kern] = tracking
        }

        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let size = attrStr.size()

        var drawPoint = point
        if alignment == .center {
            drawPoint.x = point.x - size.width / 2.0
        } else if alignment == .right {
            drawPoint.x = point.x - size.width
        }

        attrStr.draw(at: drawPoint)
    }

    // MARK: - Color Constants

    private static func cyanColor(alpha: CGFloat = 1.0) -> NSColor {
        NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: alpha)
    }

    private static func orangeColor(alpha: CGFloat = 1.0) -> NSColor {
        NSColor(red: 1.0, green: 0.55, blue: 0.15, alpha: alpha)
    }

    private enum ColorHex {
        static let red = NSColor(red: 0.90, green: 0.30, blue: 0.18, alpha: 1.0)
        static let blue = NSColor(red: 0.24, green: 0.39, blue: 0.87, alpha: 1.0)
        static let cyan = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
    }
}
