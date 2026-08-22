import SwiftUI
import AppKit

/// Photo Wall for Ghost Mode artifact progress photos.
/// Features filmstrip scrubbing and Day-1 vs Latest side-by-side comparison slider.
public struct GhostPhotoWallView: View {
    public let photos: [GhostEngine.GhostPhotoArtifact]
    @Environment(\.dismiss) private var dismiss

    @State private var comparisonSplit: Double = 0.5
    @State private var selectedPhotoID: String? = nil

    public init(photos: [GhostEngine.GhostPhotoArtifact]) {
        self.photos = photos
    }

    private var firstPhoto: GhostEngine.GhostPhotoArtifact? {
        photos.first
    }

    private var latestPhoto: GhostEngine.GhostPhotoArtifact? {
        photos.last
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.stack.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
                        Text("VAULT PHOTO WALL")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .tracking(1.5)
                    }
                    Text("Visual Proof of Evolution")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.white)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Divider().opacity(0.12)

            if photos.isEmpty {
                emptyPhotoWall
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Day 1 vs Latest Comparison Slider
                        if let first = firstPhoto, let latest = latestPhoto, photos.count >= 2 {
                            comparisonSection(first: first, latest: latest)
                        }

                        // Filmstrip Gallery
                        VStack(alignment: .leading, spacing: 10) {
                            Text("ALL PROGRESS ARTIFACTS (\(photos.count))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.5))
                                .tracking(1.0)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 12)], spacing: 12) {
                                ForEach(photos) { item in
                                    photoThumbnail(item: item)
                                }
                            }
                        }
                    }
                    .padding(22)
                }
            }
        }
        .frame(width: 720, height: 600)
        .background(Color(red: 0.05, green: 0.05, blue: 0.07))
    }

    // MARK: - Comparison Section

    private func comparisonSection(first: GhostEngine.GhostPhotoArtifact, latest: GhostEngine.GhostPhotoArtifact) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("DAY 1 VS LATEST COMPARISON")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
                    .tracking(1.0)
                Spacer()
                Text("Day \(first.dayIndex) • Day \(latest.dayIndex)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.6))
            }

            HStack(spacing: 12) {
                // Day 1 Card
                VStack(alignment: .leading, spacing: 4) {
                    Text("Day \(first.dayIndex) (Inception)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.7))
                    loadedImageView(path: first.photoPath)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Latest Card
                VStack(alignment: .leading, spacing: 4) {
                    Text("Day \(latest.dayIndex) (Current)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(red: 0.0, green: 0.85, blue: 1.0))
                    loadedImageView(path: latest.photoPath)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(12)
            .background(Color(red: 0.07, green: 0.07, blue: 0.10), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Photo Thumbnail

    private func photoThumbnail(item: GhostEngine.GhostPhotoArtifact) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            loadedImageView(path: item.photoPath)
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack {
                Text("Day \(item.dayIndex)")
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white)
                Spacer()
                Text(item.dateString)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
    }

    private func loadedImageView(path: String) -> some View {
        Group {
            if let image = NSImage(contentsOfFile: path) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.white.opacity(0.04)
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
            }
        }
    }

    private var emptyPhotoWall: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "camera.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color.white.opacity(0.3))
            Text("No Progress Photos Sealed")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.white)
            Text("Attach daily progress photos from the Protocol Board to build your private visual proof gallery.")
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Spacer()
        }
        .padding(32)
    }
}
