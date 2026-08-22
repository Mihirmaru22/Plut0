import SwiftUI
import SwiftData
import MapKit

// MARK: - MacLogPeakModal (Executive Expedition Logging Modal)

struct MacLogPeakModal: View {

    @Environment(\.modelContext) private var modelContext
    let onDismiss: () -> Void
    let onPeakCreated: (TrekRecord) -> Void

    @State private var name: String = ""
    @State private var region: String = "Himalayas"
    @State private var country: String = "India"
    @State private var elevationMetersText: String = "4500"
    @State private var elevationGainText: String = "1200"
    @State private var distanceKmText: String = "14.5"
    @State private var latitudeText: String = "30.5000"
    @State private var longitudeText: String = "79.5000"
    @State private var status: TrekStatus = .conquered
    @State private var difficulty: TrekDifficulty = .moderate
    @State private var dateConquered: Date = Date()
    @State private var personalNotes: String = ""
    @State private var rating: Int = 5

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DS.Theme.amber)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Log Expedition Peak")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white)

                    Text("Record a new summit conquest or expedition target")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Theme.textSecondary)
                }

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(DS.Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(DS.Theme.surface)

            Divider().opacity(0.15)

            // Form Content
            ScrollView {
                VStack(spacing: 16) {
                    // Peak Identity
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PEAK IDENTITY")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(DS.Theme.textTertiary)

                        HStack(spacing: 10) {
                            inputField(label: "Peak Name", placeholder: "e.g. Kalsubai Peak", text: $name)
                            inputField(label: "Region / Range", placeholder: "e.g. Sahyadri", text: $region)
                            inputField(label: "Country", placeholder: "e.g. India", text: $country)
                        }
                    }

                    // Altitude & Geometry
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ALTITUDE & TELEMETRY")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(DS.Theme.textTertiary)

                        HStack(spacing: 10) {
                            inputField(label: "Elevation (m)", placeholder: "4500", text: $elevationMetersText)
                            inputField(label: "Elevation Gain (m)", placeholder: "1200", text: $elevationGainText)
                            inputField(label: "Distance (km)", placeholder: "14.5", text: $distanceKmText)
                        }

                        HStack(spacing: 10) {
                            inputField(label: "Latitude", placeholder: "30.5000", text: $latitudeText)
                            inputField(label: "Longitude", placeholder: "79.5000", text: $longitudeText)
                        }
                    }

                    // Status & Difficulty
                    VStack(alignment: .leading, spacing: 6) {
                        Text("EXPEDITION CLASSIFICATION")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(DS.Theme.textTertiary)

                        HStack(spacing: 14) {
                            // Status Picker
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Status")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(DS.Theme.textSecondary)

                                Picker("", selection: $status) {
                                    Text("Conquered 🏆").tag(TrekStatus.conquered)
                                    Text("Wishlist 📍").tag(TrekStatus.wishlist)
                                    Text("In Progress ⏳").tag(TrekStatus.inProgress)
                                }
                                .pickerStyle(.segmented)
                            }

                            // Difficulty Picker
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Difficulty")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(DS.Theme.textSecondary)

                                Picker("", selection: $difficulty) {
                                    ForEach(TrekDifficulty.allCases, id: \.self) { diff in
                                        Text(diff.title).tag(diff)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                    }

                    // Date Conquered
                    if status == .conquered {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("SUMMIT DATE")
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(DS.Theme.textTertiary)

                            DatePicker("Summit Date", selection: $dateConquered, displayedComponents: [.date])
                                .datePickerStyle(.field)
                                .font(.system(size: 12))
                        }
                    }

                    // Personal Notes
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SUMMIT JOURNAL & NOTES")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(DS.Theme.textTertiary)

                        TextEditor(text: $personalNotes)
                            .font(.system(size: 12))
                            .frame(height: 70)
                            .padding(6)
                            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(DS.Theme.border, lineWidth: 1))
                    }
                }
                .padding(20)
            }

            Divider().opacity(0.15)

            // Footer Actions
            HStack {
                Button("Cancel") {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.Theme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)

                Spacer()

                Button {
                    savePeak()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Log Peak to Atlas")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7.5)
                    .background(DS.Theme.amber, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1.0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(DS.Theme.surface)
        }
        .frame(width: 520, height: 500)
        .background(DS.Theme.card)
    }

    private func inputField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DS.Theme.textSecondary)

            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(DS.Theme.border, lineWidth: 1))
        }
    }

    private func savePeak() {
        let elevation = Double(elevationMetersText) ?? 3000.0
        let gain = Double(elevationGainText)
        let dist = Double(distanceKmText)
        let lat = Double(latitudeText) ?? 30.5
        let lon = Double(longitudeText) ?? 79.5

        let newPeak = TrekRecord(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            region: region.trimmingCharacters(in: .whitespacesAndNewlines),
            country: country.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: lat,
            longitude: lon,
            elevationMeters: elevation,
            trailDistanceKm: dist,
            elevationGainMeters: gain,
            status: status,
            difficulty: difficulty,
            dateConquered: status == .conquered ? dateConquered : nil,
            rating: rating,
            personalNotes: personalNotes
        )

        modelContext.insert(newPeak)
        try? modelContext.save()
        Haptics.notify(.success)
        onPeakCreated(newPeak)
        onDismiss()
    }
}
