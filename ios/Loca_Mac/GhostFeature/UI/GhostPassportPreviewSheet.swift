import SwiftUI
import PDFKit
import AppKit

/// Native PDFKit preview modal for the 4-page A4 Sovereign Passport Booklet.
public struct GhostPassportPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let passportData: WinterArcPassportData
    @State private var pdfDocument: PDFDocument? = nil
    @State private var isLoading: Bool = true

    public init(passportData: WinterArcPassportData) {
        self.passportData = passportData
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.richtext.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(DS.Theme.amber)
                        Text("PASSPORT BOOKLET PREVIEW")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(DS.Theme.amber)
                            .tracking(1.5)
                    }
                    Text(passportData.season.name + " · 4-Page A4 Vector Booklet")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DS.Theme.textPrimary)
                }

                Spacer()

                HStack(spacing: 10) {
                    Button {
                        exportToDisk()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 11))
                            Text("Save PDF...")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(DS.Theme.canvas)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(DS.Theme.amber, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)

                    Button("Close") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(DS.Theme.textSecondary)
                        .font(.system(size: 12))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(DS.Theme.surface)

            Divider().opacity(0.12)

            // PDF Content View
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Rendering 4-page vector booklet...")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DS.Theme.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let doc = pdfDocument {
                PDFKitRepresentedView(document: doc)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Failed to render PDF booklet.")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Theme.coral)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 680, height: 740)
        .background(DS.Theme.canvas)
        .onAppear { renderDocument() }
    }

    private func renderDocument() {
        isLoading = true
        Task {
            let data = WinterArcPassportPDFGenerator.generatePDFData(data: passportData)
            let doc = PDFDocument(data: data)
            await MainActor.run {
                self.pdfDocument = doc
                self.isLoading = false
            }
        }
    }

    private func exportToDisk() {
        WinterArcPassportPDFGenerator.exportBookletPDF(data: passportData) { success in
            if success {
                dismiss()
            }
        }
    }
}

// MARK: - PDFKitRepresentedView (macOS AppKit Bridge)

private struct PDFKitRepresentedView: NSViewRepresentable {
    let document: PDFDocument

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = NSColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0)
        return pdfView
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.document = document
    }
}
