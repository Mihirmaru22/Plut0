import SwiftUI
import SwiftData
import Combine

// MARK: - AppleWatchTrekSyncModal

/// Interactive Apple Watch & HealthKit workout synchronization modal studio.
/// Allows explorers to discover outdoor hiking workouts, extract biometric heart rate / calorie curves,
/// and bind workouts to Pluto's mountain summits.
struct AppleWatchTrekSyncModal: View {

    let allTreks: [TrekRecord]
    let onDismiss: () -> Void

    @ObservedObject private var syncEngine = TrekHealthKitSyncEngine.shared
    @State private var selectedTrekForLinking: TrekRecord? = nil
    @State private var linkingWorkout: AppleWatchHikingWorkout? = nil
    @State private var toastMessage: String? = nil

    private var linkedCount: Int {
        syncEngine.detectedWorkouts.filter(\.isLinked).count
    }

    private var totalCalories: Double {
        syncEngine.detectedWorkouts.map(\.activeCalories).reduce(0, +)
    }

    private var totalDistance: Double {
        syncEngine.detectedWorkouts.map(\.distanceKm).reduce(0, +)
    }

    var body: some View {
        VStack(spacing: 0) {

            // Top Header Bar
            headerBar

            Divider()

            ScrollView {
                VStack(spacing: DS.Space.xl) {

                    // Overview Hero Stats
                    overviewHeroCard

                    // Action Controls Bar
                    actionsBar

                    // Workouts List
                    VStack(alignment: .leading, spacing: DS.Space.md) {
                        HStack {
                            Text("Detected Apple Watch Workouts")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundStyle(DS.Color.textTertiary)
                            Spacer()
                            Text("\(syncEngine.detectedWorkouts.count) Workouts Found")
                                .font(DS.Text.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                        }

                        if syncEngine.detectedWorkouts.isEmpty {
                            emptyWorkoutsView
                        } else {
                            ForEach(syncEngine.detectedWorkouts) { workout in
                                workoutCard(workout: workout)
                            }
                        }
                    }
                }
                .padding(DS.Space.xl)
            }
        }
        .frame(width: 820, height: 640)
        .background(DS.Color.background)
        .overlay(alignment: .bottom) {
            if let msg = toastMessage {
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
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: DS.Space.md) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 32, height: 32)
                    Image(systemName: "applewatch")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.orange)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Apple Watch & HealthKit Expedition Sync")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DS.Color.textPrimary)
                    Text("Auto-import heart rate telemetry, calories, and actual vertical ascent")
                        .font(DS.Text.caption)
                        .foregroundStyle(DS.Color.textTertiary)
                }
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(DS.Color.textSecondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, DS.Space.xl)
        .padding(.vertical, DS.Space.md)
        .background(DS.Color.surface)
    }

    // MARK: - Overview Hero Card

    private var overviewHeroCard: some View {
        HStack(spacing: DS.Space.lg) {
            overviewPill(
                title: "DETECTED HIKES",
                value: "\(syncEngine.detectedWorkouts.count)",
                icon: "applewatch",
                color: Color.orange
            )

            overviewPill(
                title: "LINKED TO SUMMITS",
                value: "\(linkedCount) / \(syncEngine.detectedWorkouts.count)",
                icon: "link.circle.fill",
                color: Color.cyan
            )

            overviewPill(
                title: "TOTAL ENERGY",
                value: "\(Int(totalCalories).formatted()) kcal",
                icon: "flame.fill",
                color: Color.red
            )

            overviewPill(
                title: "TOTAL DISTANCE",
                value: String(format: "%.1f km", totalDistance),
                icon: "figure.hiking",
                color: Color.green
            )
        }
    }

    private func overviewPill(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Color.textPrimary)
                Text(title)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(DS.Color.textTertiary)
                    .tracking(0.6)
            }
            Spacer()
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity)
        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Action Controls Bar

    private var actionsBar: some View {
        HStack(spacing: DS.Space.md) {
            // Scan Button
            Button {
                Task {
                    await syncEngine.scanAppleWatchWorkouts(treks: allTreks)
                    showToast("Apple Watch scan completed")
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: syncEngine.isScanning ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .rotationEffect(.degrees(syncEngine.isScanning ? 360 : 0))
                        .animation(syncEngine.isScanning ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: syncEngine.isScanning)
                    Text(syncEngine.isScanning ? "Scanning Watch..." : "Scan Apple Watch")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.orange)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.orange.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(syncEngine.isScanning)

            // Auto-Match All
            Button {
                let matched = syncEngine.autoMatchAll(treks: allTreks)
                showToast("Auto-linked \(matched) workouts to mountain summits")
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("Auto-Match All to Peaks")
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.cyan, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            Spacer()

            if let date = syncEngine.lastSyncDate {
                Text("Last Sync: \(date.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(DS.Color.textTertiary)
            }
        }
    }

    // MARK: - Workout Card

    private func workoutCard(workout: AppleWatchHikingWorkout) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(workout.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DS.Color.textPrimary)

                        Text(workout.activityTypeName.uppercased())
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(Color.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15), in: Capsule())
                    }

                    Text(workout.startDate.formatted(date: .abbreviated, time: .shortened))
                        .font(DS.Text.caption)
                        .foregroundStyle(DS.Color.textTertiary)
                }

                Spacer()

                // Link Action
                if workout.isLinked, let linkedName = workout.linkedTrekName {
                    HStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Color.cyan)
                            Text("Linked: \(linkedName)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.cyan)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))

                        if let matchingTrek = allTreks.first(where: { $0.name == linkedName }) {
                            Button("Unlink") {
                                syncEngine.unbind(trek: matchingTrek)
                                showToast("Unlinked workout from \(linkedName)")
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.red)
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    Menu {
                        ForEach(allTreks) { trek in
                            Button(trek.name) {
                                syncEngine.bind(workout: workout, to: trek)
                                showToast("Linked workout to \(trek.name)")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                            Text("Link to Summit...")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.cyan, in: RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Biometric Metric Badges
            HStack(spacing: DS.Space.md) {
                // Heart Rate
                metricCapsule(
                    icon: "heart.fill",
                    label: "\(Int(workout.avgHeartRate)) bpm avg",
                    subtext: "Max \(Int(workout.maxHeartRate)) bpm",
                    color: Color.red
                )

                // Calories
                metricCapsule(
                    icon: "flame.fill",
                    label: workout.formattedCalories,
                    subtext: "Active Energy",
                    color: Color.orange
                )

                // Duration
                metricCapsule(
                    icon: "clock.fill",
                    label: workout.formattedDuration,
                    subtext: "Moving Time",
                    color: Color.cyan
                )

                // Distance
                metricCapsule(
                    icon: "figure.hiking",
                    label: workout.formattedDistance,
                    subtext: "Trail Length",
                    color: Color.green
                )

                // Ascent
                metricCapsule(
                    icon: "arrow.up.right",
                    label: "+\(Int(workout.elevationGainMeters))m",
                    subtext: "Vertical Climb",
                    color: Color.purple
                )
            }
        }
        .padding(DS.Space.lg)
        .background(
            workout.isLinked ? Color.white.opacity(0.05) : DS.Color.surface,
            in: RoundedRectangle(cornerRadius: DS.Radius.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .stroke(workout.isLinked ? Color.cyan.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func metricCapsule(icon: String, label: String, subtext: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Color.textPrimary)
                Text(subtext)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(DS.Color.textTertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Empty State

    private var emptyWorkoutsView: some View {
        VStack(spacing: DS.Space.md) {
            Image(systemName: "applewatch")
                .font(.system(size: 40))
                .foregroundStyle(DS.Color.textTertiary)
            Text("No Outdoor Hiking Workouts Found")
                .font(DS.Text.heading)
                .foregroundStyle(DS.Color.textPrimary)
            Text("Complete a Hiking or Climbing workout on your Apple Watch to sync biometrics.")
                .font(DS.Text.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                toastMessage = nil
            }
        }
    }
}
