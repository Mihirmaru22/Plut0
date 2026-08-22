import SwiftUI
import AppKit
import PDFKit

/// Vector PDF certificate and passport exporter for completed Winter Arc / Ghost seasons.
@MainActor
public enum WinterArcPassportPDFGenerator {

    public static func renderCertificateImage(season: GhostSeason, streak: Int, rank: GhostRank, totalGhostDays: Int) -> NSImage? {
        let view = WinterArcCertificateView(season: season, streak: streak, rank: rank, totalGhostDays: totalGhostDays)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.5
        return renderer.nsImage
    }

    public static func exportCertificatePDF(season: GhostSeason, streak: Int, rank: GhostRank, totalGhostDays: Int, completion: ((Bool) -> Void)? = nil) {
        let panel = NSSavePanel()
        panel.title = "Export Winter Arc Sovereign Passport PDF"
        panel.prompt = "Save Certificate"
        let sanitizedName = season.name.replacingOccurrences(of: " ", with: "_")
        panel.nameFieldStringValue = "\(sanitizedName)_Sovereign_Passport.pdf"
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true

        panel.begin { response in
            guard response == .OK, let targetURL = panel.url else {
                completion?(false)
                return
            }

            if let image = renderCertificateImage(season: season, streak: streak, rank: rank, totalGhostDays: totalGhostDays),
               let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {

                let pdfDoc = PDFDocument()
                if let pageImage = NSImage(data: pngData),
                   let pdfPage = PDFPage(image: pageImage) {
                    pdfDoc.insert(pdfPage, at: 0)
                    let success = pdfDoc.write(to: targetURL)
                    if success {
                        Haptics.notification(.success)
                    }
                    completion?(success)
                    return
                }
            }
            completion?(false)
        }
    }
}

// MARK: - Certificate Document View

private struct WinterArcCertificateView: View {
    let season: GhostSeason
    let streak: Int
    let rank: GhostRank
    let totalGhostDays: Int

    private static let df: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        ZStack {
            // Obsidian Parchment Background
            Color(red: 0.05, green: 0.05, blue: 0.07)

            VStack(spacing: 24) {
                // Crest
                ZStack {
                    Circle()
                        .stroke(Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.4), lineWidth: 2)
                        .frame(width: 80, height: 80)

                    Image(systemName: rank.glyph)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
                }

                // Title
                VStack(spacing: 6) {
                    Text("SOVEREIGN GHOST PASSPORT")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .tracking(3.0)

                    Text(season.name.uppercased())
                        .font(.system(size: 26, weight: .black, design: .serif))
                        .foregroundStyle(Color.white)
                        .tracking(1.5)

                    Text("ATTESTATION OF COMPLETE DISCIPLINE & SILENCE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
                        .tracking(1.8)
                }

                Divider().background(Color.white.opacity(0.15))

                // Stats Grid
                HStack(spacing: 32) {
                    statBlock(label: "FINAL RANK", value: rank.rawValue.uppercased(), color: Color(red: 0.0, green: 0.85, blue: 1.0))
                    statBlock(label: "STREAK CONQUERED", value: "\(streak) DAYS", color: Color.orange)
                    statBlock(label: "GHOST DAYS SEALED", value: "\(totalGhostDays) DAYS", color: Color.white)
                }
                .padding(.vertical, 8)

                Divider().background(Color.white.opacity(0.15))

                // Covenant Seal & Device Fingerprint
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("AUTHENTICATED ON-DEVICE")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.5))
                        Text(season.deviceID)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.8))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text("SEALED DATE")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.5))
                        Text(Self.df.string(from: Date()))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.8))
                    }
                }
            }
            .padding(44)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                    .padding(12)
            )
        }
        .frame(width: 650, height: 500)
    }

    private func statBlock(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
                .tracking(1.0)
            Text(value)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(color)
        }
    }
}
