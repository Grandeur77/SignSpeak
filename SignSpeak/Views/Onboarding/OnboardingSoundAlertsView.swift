import SwiftUI

public struct OnboardingSoundAlertsView: View {
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
                        Text("ONBOARDING SETUP • STEP 3 OF 4")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.brandTurquoise)
                            .tracking(1.0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.brandTurquoise.opacity(0.12), in: Capsule())

                    Text("Never miss an important sound")
                        .font(.appLargeTitle)
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)

                    Text("SignSpeak can listen for sounds around you and alert you instantly with high-visibility flashes and distinct vibration pulses.")
                        .font(.appBody)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.m)
                }

                // Alert Sync Banner
                HStack(spacing: 8) {
                    Image(systemName: "flashlight.on.fill")
                        .foregroundStyle(Color.brandYellow)
                    Text("Camera flash + Haptic alert synced")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.s)
                .background(Color.cardBackground, in: Capsule())

                // Sound Alert Items List
                VStack(spacing: Theme.Spacing.m) {
                    ForEach(SoundAlertType.allCases) { alert in
                        soundAlertRow(alert)
                    }
                }

                // Privacy Guarantee
                HStack(alignment: .top, spacing: Theme.Spacing.m) {
                    Image(systemName: "lock.shield.fill")
                        .font(.title2)
                        .foregroundStyle(Color.brandTurquoise)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Audio is analyzed privately on your device")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.textPrimary)

                        Text("Microphones never record or upload your personal conversations. Sound analysis runs exclusively on the on-device Neural Engine.")
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
                        viewModel.soundAlertsEnabled = true
                        Task {
                            await viewModel.complete()
                        }
                    } label: {
                        HStack(spacing: Theme.Spacing.s) {
                            Image(systemName: "waveform.and.person.filled")
                            Text("Turn On Sound Alerts")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.onPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.primaryFill, in: RoundedRectangle(cornerRadius: 14))
                    }

                    Button("Skip for now") {
                        viewModel.soundAlertsEnabled = false
                        Task {
                            await viewModel.complete()
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

    private func soundAlertRow(_ alert: SoundAlertType) -> some View {
        let isEnabled = viewModel.enabledSoundAlerts.contains(alert)

        return HStack(spacing: Theme.Spacing.m) {
            ZStack {
                Circle()
                    .fill(alert.isUrgent ? Color.red.opacity(0.15) : Color.brandTurquoise.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: alert.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(alert.isUrgent ? Color.red : Color.brandTurquoise)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(alert.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)

                    if alert.isUrgent {
                        Text("Urgent")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red, in: Capsule())
                    }
                }

                Text(alert.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { newValue in
                    if newValue {
                        viewModel.enabledSoundAlerts.insert(alert)
                    } else {
                        viewModel.enabledSoundAlerts.remove(alert)
                    }
                }
            ))
            .labelsHidden()
            .tint(Color.brandTurquoise)
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
    }
}
