import SwiftUI

/// Presented when biometric lock is enabled in Settings, protecting sign transcripts and learner data.
public struct FaceIDLockView: View {
    @Bindable var router: AppRouter
    @State private var isAuthenticating = false
    @State private var authFailed = false

    public init(router: AppRouter) {
        self.router = router
    }

    public var body: some View {
        ZStack {
            // Dark navy background
            LinearGradient(
                colors: [
                    Color(red: 10/255, green: 22/255, blue: 40/255),
                    Color(red: 6/255, green: 14/255, blue: 28/255)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Subtle background waves
            VStack {
                Spacer()
                ZStack(alignment: .bottom) {
                    WaveShape(phase: 1.5, amplitude: 18, frequency: 1.1)
                        .fill(Color.brandNavy.opacity(0.5))
                        .frame(height: 120)

                    WaveShape(phase: 2.8, amplitude: 14, frequency: 1.3)
                        .fill(Color.brandTurquoise.opacity(0.25))
                        .frame(height: 70)
                }
                .ignoresSafeArea(edges: .bottom)
            }

            // Main Content
            VStack(spacing: Theme.Spacing.l) {
                Spacer()

                // Small App Logo
                AppLogoArtwork()
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color.black.opacity(0.3), radius: 8, y: 4)

                Spacer()

                // Concentric Biometric Radar Rings
                ZStack {
                    // Outer Ring 1
                    Circle()
                        .strokeBorder(Color.brandTurquoise.opacity(0.15), lineWidth: 1.5)
                        .frame(width: 170, height: 170)

                    // Outer Ring 2 with glow
                    Circle()
                        .strokeBorder(Color.brandTurquoise.opacity(0.35), lineWidth: 2)
                        .frame(width: 140, height: 140)
                        .background(
                            Circle()
                                .fill(Color.brandTurquoise.opacity(0.08))
                        )

                    // Corner alignment ticks
                    BiometricCornerTicks()
                        .frame(width: 180, height: 180)
                        .foregroundStyle(Color.brandTurquoise.opacity(0.7))

                    // Center Face ID Glyph
                    Image(systemName: "faceid")
                        .font(.system(size: 60, weight: .light))
                        .foregroundStyle(Color.brandTurquoise)
                        .shadow(color: Color.brandTurquoise.opacity(0.5), radius: 10)
                }
                .padding(.vertical, Theme.Spacing.m)

                // Headings
                VStack(spacing: Theme.Spacing.s) {
                    Text("SignSpeak is Locked")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .accessibilityAddTraits(.isHeader)

                    Text("Biometric authentication required to access private sign transcripts and learner data.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.l)

                    // Privacy Assurance Pill
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.brandTurquoise)

                        Text("Protected with Face ID")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08), in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.top, Theme.Spacing.xs)
                }

                if authFailed {
                    Text("Authentication failed. Please try again.")
                        .font(.caption)
                        .foregroundStyle(Color.brandYellow)
                }

                Spacer()

                // Actions
                VStack(spacing: Theme.Spacing.m) {
                    // Unlock with Face ID Button
                    Button {
                        triggerUnlock()
                    } label: {
                        HStack(spacing: 8) {
                            if isAuthenticating {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Image(systemName: "faceid")
                                    .font(.system(size: 20, weight: .medium))
                                Text("Unlock with Face ID")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .foregroundStyle(Color.brandNavy)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.brandTurquoise, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
                    }
                    .buttonStyle(.plain)
                    .disabled(isAuthenticating)
                    .accessibilityLabel("Unlock with Face ID")

                    // Fallback Button
                    Button {
                        triggerUnlock()
                    } label: {
                        Text("Use iPhone Passcode")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(minHeight: Theme.minTapTarget)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .onAppear {
            triggerUnlock()
        }
    }

    private func triggerUnlock() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        authFailed = false

        Task {
            let success = await router.unlockWithBiometrics()
            isAuthenticating = false
            if !success {
                authFailed = true
            }
        }
    }
}

/// Symmetrical corner tick marks for Face ID visual target.
private struct BiometricCornerTicks: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let tickLen: CGFloat = 16
            let cornerInset: CGFloat = 8

            Path { path in
                // Top-Left
                path.move(to: CGPoint(x: cornerInset, y: cornerInset + tickLen))
                path.addLine(to: CGPoint(x: cornerInset, y: cornerInset))
                path.addLine(to: CGPoint(x: cornerInset + tickLen, y: cornerInset))

                // Top-Right
                path.move(to: CGPoint(x: w - cornerInset - tickLen, y: cornerInset))
                path.addLine(to: CGPoint(x: w - cornerInset, y: cornerInset))
                path.addLine(to: CGPoint(x: w - cornerInset, y: cornerInset + tickLen))

                // Bottom-Left
                path.move(to: CGPoint(x: cornerInset, y: h - cornerInset - tickLen))
                path.addLine(to: CGPoint(x: cornerInset, y: h - cornerInset))
                path.addLine(to: CGPoint(x: cornerInset + tickLen, y: h - cornerInset))

                // Bottom-Right
                path.move(to: CGPoint(x: w - cornerInset - tickLen, y: h - cornerInset))
                path.addLine(to: CGPoint(x: w - cornerInset, y: h - cornerInset))
                path.addLine(to: CGPoint(x: w - cornerInset, y: h - cornerInset - tickLen))
            }
            .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
    }
}

#Preview("Face ID Lock - 59-face-id-lock") {
    FaceIDLockView(
        router: AppRouter(
            authService: StubAuthService(initialUserId: "preview-user"),
            userProfileRepository: StubUserProfileRepository(),
            biometricAuthService: StubBiometricAuthService(isBiometricAvailable: true, biometricType: .faceID),
            initialRoute: .faceIDLock
        )
    )
}
