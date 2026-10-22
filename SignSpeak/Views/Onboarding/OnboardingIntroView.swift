import SwiftUI

/// Introduces the camera-based learning model, private on-device vision, and offers
/// progression to the next step or immediate completion.
public struct OnboardingIntroView: View {
    @Bindable var router: AppRouter
    public var onContinue: (() -> Void)?

    public init(router: AppRouter, onContinue: (() -> Void)? = nil) {
        self.router = router
        self.onContinue = onContinue
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Navigation / Skip
            HStack {
                Spacer()
                Button("Skip") {
                    Task {
                        await router.completeOnboarding()
                    }
                }
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Color.textSecondary)
                .frame(minHeight: Theme.minTapTarget)
                .padding(.horizontal, Theme.Spacing.m)
            }

            Spacer()

            // Main Illustration Card (Hand pose skeleton)
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.06), radius: 16, y: 8)

                VStack(spacing: Theme.Spacing.m) {
                    // Header badges
                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.brandTurquoise)
                                .frame(width: 6, height: 6)
                            Text("SIGN RECOGNITION")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.brandTurquoise)
                                .tracking(0.8)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.brandTurquoise.opacity(0.12), in: Capsule())

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11))
                            Text("On-Device AI")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.top, Theme.Spacing.m)

                    Spacer()

                    // Stylized Skeleton Hand
                    ZStack {
                        // Hand silhouette
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 100))
                            .foregroundStyle(Color.brandTurquoise.opacity(0.15))

                        // Tracking keypoint circles & connections
                        Image(systemName: "waveform.path.badge.plus")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.brandTurquoise)
                    }

                    // Recognition Pill
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.brandYellow)

                        Text("ASL Letter 'B' • 98%")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.brandNavy, in: Capsule())

                    // Footer stats
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.metering.matrix")
                                .font(.system(size: 11))
                            Text("Real-time vision")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(Color.textSecondary)

                        Spacer()

                        Text("Tracking 21 Points")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.brandTurquoise)
                    }
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.bottom, Theme.Spacing.m)
                }
            }
            .frame(height: 290)
            .padding(.horizontal, Theme.Spacing.l)

            Spacer()

            // Step Indicator Badge & Text
            VStack(spacing: Theme.Spacing.s) {
                Text("STEP 1 OF 3 • SMART LEARNING")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.brandTurquoise)
                    .tracking(1.0)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.brandTurquoise.opacity(0.12), in: Capsule())

                Text("Learn with your camera")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text("Master sign language with instant, private AI feedback on your hand shape and motion.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.l)
            }
            .padding(.top, Theme.Spacing.m)

            // Page Indicator Dots
            HStack(spacing: 8) {
                Capsule()
                    .fill(Color.brandYellow)
                    .frame(width: 24, height: 6)

                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)

                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
            .padding(.vertical, Theme.Spacing.l)

            // Primary Next Button
            Button {
                if let onContinue {
                    onContinue()
                } else {
                    Task {
                        await router.completeOnboarding()
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Spacer()
                    Text("Next")
                        .font(.system(size: 17, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                }
                .foregroundStyle(Color.onPrimary)
                .frame(height: 52)
                .background(Color.primaryFill, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }
}

#Preview("Onboarding Intro - 10-onboarding-1-learn") {
    OnboardingIntroView(
        router: AppRouter(
            authService: StubAuthService(initialUserId: "new-user"),
            userProfileRepository: StubUserProfileRepository(),
            biometricAuthService: StubBiometricAuthService(),
            initialRoute: .onboarding
        )
    )
}
