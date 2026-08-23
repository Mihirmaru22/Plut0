import SwiftUI

// MARK: - ExpeditionPassportModal

/// Interactive fullscreen inspection and export studio for Pluto's Expedition Passports.
/// Features a live 4-edition diplomatic theme switcher, interactive zooming canvas,
/// and 1-click vector PDF, 4K PNG, and GPX exports.
struct ExpeditionPassportModal: View {

    let trek: TrekRecord
    let onDismiss: () -> Void

    @State private var selectedTheme: PassportEditionTheme = .diplomaticIvory
    @State private var zoomScale: CGFloat = 0.85
    @State private var exportToastMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {

            // Top Action Toolbar
            toolbarHeader

            // Edition Selection Bar (4 Distinct Diplomatic & Archival Document Styles)
            editionSelectorBar

            Divider()

            // Main Preview Canvas with Zoom & Pan
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                VStack {
                    ExpeditionPassportDocumentView(trek: trek, theme: selectedTheme)
                        .scaleEffect(zoomScale)
                        .padding(32)
                        .shadow(color: Color.black.opacity(0.45), radius: 28, x: 0, y: 14)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(red: 0.10, green: 0.12, blue: 0.16))
        }
        .frame(minWidth: 940, idealWidth: 1000, maxWidth: .infinity, minHeight: 740, idealHeight: 840, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            if let msg = exportToastMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                    Text(msg)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.green.opacity(0.4), lineWidth: 1))
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - 4-Edition Selector Bar

    private var editionSelectorBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                HStack(spacing: 5) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(red: 0.78, green: 0.66, blue: 0.48))
                    Text("EDITION / AESTHETIC:")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(DS.Color.textTertiary)
                }

                // 4 Distinct Document Edition Chips
                HStack(spacing: 6) {
                    ForEach(PassportEditionTheme.allCases) { edition in
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                selectedTheme = edition
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: edition.icon)
                                    .font(.system(size: 10))

                                Text(edition.rawValue)
                                    .font(.system(size: 10.5, weight: selectedTheme == edition ? .bold : .medium))

                                Text(edition.shortTag)
                                    .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(selectedTheme == edition ? Color.white.opacity(0.2) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 3))
                            }
                            .foregroundStyle(selectedTheme == edition ? Color.white : DS.Color.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                selectedTheme == edition
                                    ? Color(red: 0.22, green: 0.30, blue: 0.42)
                                    : Color.white.opacity(0.04),
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(
                                        selectedTheme == edition
                                            ? Color(red: 0.78, green: 0.66, blue: 0.48).opacity(0.8)
                                            : Color.white.opacity(0.08),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DS.Space.lg)
            .padding(.vertical, 7)
        }
        .background(Color(red: 0.12, green: 0.14, blue: 0.18))
    }

    // MARK: - Toolbar Header

    private var toolbarHeader: some View {
        HStack(spacing: DS.Space.md) {
            HStack(spacing: 8) {
                Image(systemName: "compass.drawing")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 0.78, green: 0.66, blue: 0.48))

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(trek.name.uppercased()) EXPEDITION DOSSIER")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DS.Color.textPrimary)
                        .lineLimit(1)

                    Text("Official Himalayan & Alpine Summit Registry · 4 Sovereign Editions Available")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.Color.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Zoom Controls
            HStack(spacing: 4) {
                Button {
                    withAnimation(.spring(response: 0.2)) {
                        zoomScale = max(0.6, zoomScale - 0.15)
                    }
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Color.textSecondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)

                Text("\(Int(zoomScale * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(DS.Color.textPrimary)
                    .frame(width: 44)

                Button {
                    withAnimation(.spring(response: 0.2)) {
                        zoomScale = min(1.8, zoomScale + 0.15)
                    }
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Color.textSecondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)

                Button("Fit") {
                    withAnimation(.spring(response: 0.2)) {
                        zoomScale = 0.85
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(DS.Color.textSecondary)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }
            .padding(.horizontal, 6)
            .frame(height: 32)
            .background(DS.Color.surfaceRecessed, in: RoundedRectangle(cornerRadius: 8))

            Divider().frame(height: 20)

            // Export Actions
            HStack(spacing: 8) {
                // Copy Image
                Button {
                    let success = ExpeditionPassportPDFGenerator.copyImageToPasteboard(for: trek, theme: selectedTheme)
                    if success {
                        showToast("Copied \(selectedTheme.rawValue) Image to Clipboard")
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                        Text("Copy")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(DS.Color.textPrimary)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)

                // Export GPX
                Button {
                    ExpeditionPassportPDFGenerator.exportGPX(for: trek) { success in
                        if success {
                            showToast("GPX Trail Route Exported Successfully")
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "point.topleft.down.to.point.bottomright.filled.curvepath")
                            .font(.system(size: 11))
                        Text("Export GPX")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(DS.Color.textPrimary)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)

                // Export PNG
                Button {
                    ExpeditionPassportPDFGenerator.exportPNG(for: trek, theme: selectedTheme) { success in
                        if success {
                            showToast("4K \(selectedTheme.rawValue) Certificate Saved")
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "photo")
                            .font(.system(size: 11))
                        Text("Save PNG")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(DS.Color.textPrimary)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)

                // Export Vector PDF (Primary)
                Button {
                    ExpeditionPassportPDFGenerator.exportPDF(for: trek, theme: selectedTheme) { success in
                        if success {
                            showToast("Vector PDF Document Exported (\(selectedTheme.rawValue))")
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Save PDF")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(Color.black)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.82, green: 0.70, blue: 0.52), Color(red: 0.68, green: 0.56, blue: 0.38)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(red: 0.90, green: 0.80, blue: 0.65).opacity(0.6), lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
            }

            Divider().frame(height: 20)

            // Close
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(DS.Color.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, 10)
        .background(DS.Color.surface)
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            exportToastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                exportToastMessage = nil
            }
        }
    }
}
