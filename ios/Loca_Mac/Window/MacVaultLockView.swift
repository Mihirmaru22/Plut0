import SwiftUI

// MARK: - MacVaultLockView (Secure Enclave Biometric Lock Screen)

/// High-end minimalist lock screen presented when the user navigates to
/// protected sections (Private Journal, Life Blueprint) with Touch ID security enabled.
struct MacVaultLockView: View {

    let sectionTitle: String
    @ObservedObject private var vaultManager = LocaVaultAuthManager.shared
    @State private var isHovered: Bool = false

    var body: some View {
        VStack(spacing: DS.Space.xl) {
            Spacer()

            VStack(spacing: DS.Space.md) {
                // Biometric Badge
                ZStack {
                    Circle()
                        .fill(DS.Color.surfaceRecessed)
                        .frame(width: 72, height: 72)

                    Image(systemName: "touchid")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .overlay(Circle().stroke(DS.Color.border.opacity(0.6), lineWidth: 1))

                VStack(spacing: 4) {
                    Text("Secure Enclave Protected")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(DS.Color.textTertiary)

                    Text(sectionTitle)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(DS.Color.textPrimary)

                    Text("Touch ID or System Password required to decrypt this workspace.")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
            }

            // Unlock Action Button
            Button {
                vaultManager.authenticate(for: sectionTitle)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 11, weight: .bold))

                    Text("Unlock with \(vaultManager.biometryTypeString)")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
                .scaleEffect(isHovered ? 1.02 : 1.0)
            }
            .buttonStyle(.plain)
            .onHover { h in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    isHovered = h
                }
            }

            Spacer()

            // Footer Badge
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(DS.Color.textTertiary)

                Text("Apple Secure Enclave · On-Device Hardware Protection")
                    .font(.system(size: 10))
                    .foregroundStyle(DS.Color.textTertiary)
            }
            .padding(.bottom, DS.Space.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Color.background)
        .onAppear {
            vaultManager.authenticate(for: sectionTitle)
        }
    }
}
