import SwiftUI

/// Customization sheet for sound detection thresholds, haptics, and emergency contacts (`66-sound-alerts-customise`).
public struct SoundAlertCustomiseView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: SoundAlertsViewModel

    @State private var emergencyName: String = ""
    @State private var emergencyPhone: String = ""

    public init(viewModel: SoundAlertsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Section: Visual & Torch Feedback
                Section {
                    Toggle(isOn: $viewModel.settings.flashScreen) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Flash Screen")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)
                                Text("Display high-contrast visual flash on alert")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.textSecondary)
                            }
                        } icon: {
                            Image(systemName: "iphone.radiowaves.left.and.right")
                                .foregroundStyle(Color.brandTurquoise)
                        }
                    }

                    Toggle(isOn: $viewModel.settings.flashTorch) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Flash Camera Light")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)
                                Text("Flashes device LED torch when alert triggers")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.textSecondary)
                            }
                        } icon: {
                            Image(systemName: "flashlight.on.fill")
                                .foregroundStyle(Color.brandYellow)
                        }
                    }
                } header: {
                    Text("Visual Notifications")
                        .font(.system(size: 13, weight: .bold))
                }

                // Section: Per-Sound Sensitivity & Haptics
                Section {
                    ForEach(SoundAlertType.allCases) { sound in
                        soundCustomisationRow(sound)
                    }
                } header: {
                    Text("Sound Sensitivity & Haptics")
                        .font(.system(size: 13, weight: .bold))
                } footer: {
                    Text("High sensitivity detects faint sounds faster but may trigger in busy environments.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }

                // Section: Emergency Contact
                Section {
                    TextField("Contact Name (e.g. Maya)", text: $emergencyName)
                        .textContentType(.name)
                        .autocorrectionDisabled()

                    TextField("Phone Number", text: $emergencyPhone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)

                    if !emergencyPhone.isEmpty {
                        Button {
                            viewModel.notifyEmergencyContact()
                        } label: {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Test Emergency SMS")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.brandTurquoise)
                        }
                    }
                } header: {
                    Text("Emergency Contact")
                        .font(.system(size: 13, weight: .bold))
                } footer: {
                    Text("In a fire alarm or siren emergency, you can tap one button to send your emergency contact an alert SMS.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .navigationTitle("Customise Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        viewModel.settings.emergencyContactName = emergencyName.isEmpty ? nil : emergencyName
                        viewModel.settings.emergencyContactPhone = emergencyPhone.isEmpty ? nil : emergencyPhone
                        dismiss()
                    }
                }
            }
            .onAppear {
                emergencyName = viewModel.settings.emergencyContactName ?? ""
                emergencyPhone = viewModel.settings.emergencyContactPhone ?? ""
            }
        }
    }

    private func soundCustomisationRow(_ sound: SoundAlertType) -> some View {
        let isEnabled = viewModel.settings.enabledSounds.contains(sound)
        let sensitivity = viewModel.settings.sensitivity(for: sound)
        let pattern = viewModel.settings.hapticPattern(for: sound)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(sound.isUrgent ? Color.danger.opacity(0.15) : Color.brandTurquoise.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: sound.icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(sound.isUrgent ? Color.danger : Color.brandTurquoise)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(sound.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.textPrimary)

                    Text(sound.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { _ in viewModel.toggleSound(sound) }
                ))
                .labelsHidden()
            }

            if isEnabled {
                Divider()
                    .padding(.vertical, 2)

                // Sensitivity Selector
                HStack {
                    Text("Sensitivity:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.textSecondary)

                    Spacer()

                    Picker("Sensitivity", selection: Binding(
                        get: { sensitivity },
                        set: { viewModel.setSensitivity($0, for: sound) }
                    )) {
                        ForEach(SoundAlertSensitivity.allCases) { sens in
                            Text(sens.rawValue).tag(sens)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }

                // Haptic Pattern Selector & Test Button
                HStack {
                    Text("Vibration:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.textSecondary)

                    Spacer()

                    Picker("Pattern", selection: Binding(
                        get: { pattern },
                        set: { viewModel.setHapticPattern($0, for: sound) }
                    )) {
                        ForEach(HapticPattern.allCases) { pat in
                            Text(pat.rawValue).tag(pat)
                        }
                    }
                    .pickerStyle(.menu)

                    Button {
                        viewModel.testHapticPattern(pattern)
                    } label: {
                        Image(systemName: "waveform")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.brandTurquoise)
                            .padding(6)
                            .background(Color.brandTurquoise.opacity(0.12), in: Circle())
                    }
                    .accessibilityLabel("Test \(pattern.rawValue) vibration")
                }
            }
        }
        .padding(.vertical, 6)
    }
}
