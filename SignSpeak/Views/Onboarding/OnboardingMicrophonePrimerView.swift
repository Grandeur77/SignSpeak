import SwiftUI

public struct OnboardingMicrophonePrimerView: View {
    @Bindable var viewModel: OnboardingViewModel

    public init(viewModel: OnboardingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                // Top Bar
                HStack {
                    Button {
                        viewModel.goBack()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.appBody)
                        .foregroundStyle(Color.textSecondary)
                    }

                    Spacer()

                    Button("Skip") {
                        viewModel.skip()
                    }
                    .font(.appBody)
                    .foregroundStyle(Color.textSecondary)
                }
                .padding(.horizontal, Theme.Spacing.s)

                // Header Stepper
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.brandTurquoise)
                            .frame(width: 8, height: 8)
                        Text("STEP 3 OF 3 • PERMISSIONS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.brandTurquoise)
                            .tracking(1.0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.brandTurquoise.opacity(0.12), in: Capsule())

                    Text("Hear what's around you")
                        .font(.appLargeTitle)
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)

                    Text("SignSpeak uses your microphone to transcribe live speech and notify you of critical environmental sounds in real time.")
                        .font(.appBody)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.m)
                }

                // Acoustic Engine Card Preview
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(Color.brandTurquoise.opacity(0.18), lineWidth: 1)
                        )

                    VStack(spacing: Theme.Spacing.m) {
                        HStack {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.brandTurquoise)
                                    .frame(width: 6, height: 6)
                                Text("ACOUSTIC ENGINE")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.brandTurquoise)
                                    .tracking(0.8)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.brandTurquoise.opacity(0.12), in: Capsule())

                            Spacer()

                            Text("Two-way talk ready")
                                .font(.caption2)
                                .foregroundStyle(Color.textSecondary)
                        }

                        // Speech Bubble Preview
                        HStack {
                            Image(systemName: "quote.opening")
                                .font(.caption)
                                .foregroundStyle(Color.brandTurquoise)
                            Text("\"Good morning! How can I help you today?\"")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                        }
                        .padding(Theme.Spacing.m)
                        .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 12))

                        // Detected Environmental Sound Pills
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "bell.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Color.brandYellow)
                                Text("Doorbell detected")
                                    .font(.caption2.bold())
                                    .foregroundStyle(Color.textPrimary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.appBackground, in: Capsule())

                            HStack(spacing: 4) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Color.brandTurquoise)
                                Text("Knocking at door")
                                    .font(.caption2.bold())
                                    .foregroundStyle(Color.textPrimary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.appBackground, in: Capsule())

                            Spacer()
                        }
                    }
                    .padding(Theme.Spacing.m)
                }
                .frame(minHeight: 180)

                // Feature Highlights
                VStack(spacing: Theme.Spacing.m) {
                    featureRow(
                        icon: "captions.bubble.fill",
                        title: "Turn speech into text",
                        description: "Read spoken words in real time as live captions during face-to-face conversations."
                    )

                    featureRow(
                        icon: "waveform.badge.magnifyingglass",
                        title: "Critical sound recognition",
                        description: "Get visual cues and haptic taps when doorbells, fire alarms, sirens, or knocks occur."
                    )
                }

                // Privacy Guarantee Card
                HStack(alignment: .top, spacing: Theme.Spacing.m) {
                    Image(systemName: "lock.shield.fill")
                        .font(.title2)
                        .foregroundStyle(Color.brandTurquoise)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Audio is processed on your iPhone and never uploaded")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.textPrimary)

                        Text("Powered entirely by the Apple Neural Engine. No raw audio, voice recordings, or transcripts leave this device.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                            .lineSpacing(2)
                    }
                }
                .padding(Theme.Spacing.m)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))

                // Action Buttons
                VStack(spacing: Theme.Spacing.s) {
                    Button {
                        Task {
                            await viewModel.requestMicrophoneAccess()
                        }
                    } label: {
                        HStack(spacing: Theme.Spacing.s) {
                            Image(systemName: "mic.fill")
                            Text("Allow Microphone")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.onPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.primaryFill, in: RoundedRectangle(cornerRadius: 14))
                    }

                    Button("Not now") {
                        withAnimation {
                            viewModel.advance()
                        }
                    }
                    .font(.appBody)
                    .foregroundStyle(Color.textSecondary)
                    .frame(minHeight: Theme.minTapTarget)
                }
                .padding(.top, Theme.Spacing.s)
            }
            .padding(Theme.Spacing.l)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            ZStack {
                Circle()
                    .fill(Color.brandTurquoise.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.brandTurquoise)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                    .lineSpacing(2)
            }
            Spacer()
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
    }
}
