import SwiftUI

/// Setup sheet explaining on-device privacy and allowing initial sound selection (`62-sound-alerts-setup`).
public struct SoundAlertsSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: SoundAlertsViewModel

    public init(viewModel: SoundAlertsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.l) {
                    // Hero Icon
                    ZStack {
                        Circle()
                            .fill(Color.brandTurquoise.opacity(0.15))
                            .frame(width: 88, height: 88)

                        Image(systemName: "ear.and.waveform")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(Color.brandTurquoise)
                    }
                    .padding(.top, Theme.Spacing.m)

                    VStack(spacing: 8) {
                        Text("Never Miss an Important Sound")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                            .multilineTextAlignment(.center)

                        Text("SignSpeak listens for critical environmental sounds and alerts you instantly with distinct vibrations and visual cues.")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Theme.Spacing.m)
                    }

                    // Privacy Shield Card
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.brandTurquoise)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("100% On-Device & Private")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.textPrimary)

                            Text("Audio stream analysis happens entirely on your device. Audio is never recorded, stored, or uploaded.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                    .padding(Theme.Spacing.m)
                    .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, Theme.Spacing.m)

                    // Sound List
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Text("SOUNDS TO DETECT")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.textSecondary)
                            .padding(.horizontal, Theme.Spacing.m)

                        ForEach(SoundAlertType.allCases) { sound in
                            soundRow(sound)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.m)

                    Spacer(minLength: 24)

                    // Action Buttons
                    VStack(spacing: 12) {
                        Button {
                            viewModel.settings.isListening = true
                            viewModel.start()
                            dismiss()
                        } label: {
                            Text("Turn On Sound Alerts")
                                .font(.system(size: 17, weight: .bold))
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(Color.brandTurquoise, in: RoundedRectangle(cornerRadius: 16))
                                .foregroundStyle(Color.brandNavy)
                        }

                        Button {
                            dismiss()
                        } label: {
                            Text("Maybe Later")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.textSecondary)
                                .padding(.vertical, 6)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.bottom, Theme.Spacing.l)
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Sound Alerts Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func soundRow(_ sound: SoundAlertType) -> some View {
        let isEnabled = viewModel.settings.enabledSounds.contains(sound)

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(sound.isUrgent ? Color.danger.opacity(0.15) : Color.brandTurquoise.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: sound.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(sound.isUrgent ? Color.danger : Color.brandTurquoise)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(sound.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Text(sound.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { _ in viewModel.toggleSound(sound) }
            ))
            .labelsHidden()
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 14))
    }
}
