import SwiftUI

/// Main Sound Alerts hub matching design `61-sound-alerts-home`.
/// Displays live awareness radar pulse, category toggles, sensitivity chips, quick mute, and recent detections.
public struct SoundAlertsHomeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel: SoundAlertsViewModel
    @State private var radarRingScale1: CGFloat = 1.0
    @State private var radarRingOpacity1: Double = 0.6
    @State private var radarRingScale2: CGFloat = 1.0
    @State private var radarRingOpacity2: Double = 0.6

    public init(viewModel: SoundAlertsViewModel? = nil) {
        if let viewModel {
            _viewModel = State(initialValue: viewModel)
        } else {
            let vm = SoundAlertsViewModel(
                service: AppDependencies.live.soundAlertService,
                historyRepository: AppDependencies.live.soundAlertHistoryRepository
            )
            _viewModel = State(initialValue: vm)
        }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.l) {
                    // Hero Awareness Radar Card
                    awarenessHeroCard

                    // Quick Actions Row (Mute 5 min & Setup)
                    quickActionsRow

                    // Sound Categories
                    soundCategoriesSection

                    // Recent Alerts Card
                    recentAlertsSection

                    // Test Simulator Row
                    testSimulatorSection
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.s)
            }
            .background(Color.appBackground)
            .navigationTitle("Sound Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        viewModel.isShowingHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(Color.textPrimary)
                    }
                    .accessibilityLabel("Alert History")

                    Button {
                        viewModel.isShowingCustomise = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Color.textPrimary)
                    }
                    .accessibilityLabel("Customise Sound Alerts")
                }
            }
            .sheet(isPresented: $viewModel.isShowingHistory) {
                SoundAlertHistoryView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.isShowingCustomise) {
                SoundAlertCustomiseView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.isShowingSetup) {
                SoundAlertsSetupSheet(viewModel: viewModel)
            }
            .fullScreenCover(item: $viewModel.activeAlert) { alert in
                SoundAlertModalView(
                    alert: alert,
                    onDismiss: {
                        viewModel.dismissAlert()
                    },
                    onOpenCommunicator: {
                        viewModel.dismissAlert()
                        dismiss()
                        // Route to communicator tab
                        // Communicator is easily accessed
                    },
                    onMute5Min: {
                        viewModel.dismissAlert()
                        viewModel.muteFor5Minutes()
                    },
                    onCallEmergency: {
                        viewModel.callEmergencyServices()
                    },
                    onNotifyContact: {
                        viewModel.notifyEmergencyContact()
                    }
                )
            }
            .onAppear {
                viewModel.start()
                startRadarAnimation()
            }
        }
    }

    // MARK: - Awareness Radar Hero Card

    private var awarenessHeroCard: some View {
        VStack(spacing: Theme.Spacing.m) {
            ZStack {
                // Radar Pulsing Waves
                if viewModel.isListening && !reduceMotion {
                    Circle()
                        .stroke(Color.brandTurquoise.opacity(radarRingOpacity1), lineWidth: 2)
                        .frame(width: 120, height: 120)
                        .scaleEffect(radarRingScale1)

                    Circle()
                        .stroke(Color.brandTurquoise.opacity(radarRingOpacity2), lineWidth: 1.5)
                        .frame(width: 120, height: 120)
                        .scaleEffect(radarRingScale2)
                }

                // Central Ear/Waveform Bubble
                Circle()
                    .fill(
                        viewModel.isListening
                            ? Color.brandTurquoise.opacity(0.18)
                            : (viewModel.isMuted ? Color.brandYellow.opacity(0.18) : Color.cardBackground)
                    )
                    .frame(width: 96, height: 96)

                Image(systemName: viewModel.isMuted ? "bell.slash.fill" : (viewModel.isListening ? "waveform" : "waveform.slash"))
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(
                        viewModel.isListening
                            ? Color.brandTurquoise
                            : (viewModel.isMuted ? Color.brandYellow : Color.textSecondary)
                    )
            }
            .frame(height: 140)

            // Status Badge
            HStack(spacing: 8) {
                Circle()
                    .fill(
                        viewModel.isListening
                            ? Color.brandTurquoise
                            : (viewModel.isMuted ? Color.brandYellow : Color.textSecondary)
                    )
                    .frame(width: 8, height: 8)

                if viewModel.isMuted {
                    let mins = viewModel.remainingMuteSeconds / 60
                    let secs = viewModel.remainingMuteSeconds % 60
                    Text("Muted (\(mins):\(String(format: "%02d", secs)) remaining)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.brandYellow)
                } else if viewModel.isListening {
                    Text("Active • Ambient Awareness")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.brandTurquoise)
                } else {
                    Text("Listening Paused")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.appBackground.opacity(0.8), in: Capsule())

            Text("SignSpeak is monitoring ambient audio for \(viewModel.settings.enabledSounds.count) sound categories.")
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, Theme.Spacing.l)
        .padding(.horizontal, Theme.Spacing.m)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
    }

    // MARK: - Quick Actions Row

    private var quickActionsRow: some View {
        HStack(spacing: 12) {
            // Toggle Power
            Button {
                viewModel.toggleListening()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.settings.isListening ? "pause.fill" : "play.fill")
                    Text(viewModel.settings.isListening ? "Pause" : "Resume")
                }
                .font(.system(size: 14, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(Color.textPrimary)
            }

            // Mute / Unmute
            Button {
                if viewModel.isMuted {
                    viewModel.unmute()
                } else {
                    viewModel.muteFor5Minutes()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isMuted ? "bell.fill" : "bell.slash")
                    Text(viewModel.isMuted ? "Unmute" : "Mute 5m")
                }
                .font(.system(size: 14, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    viewModel.isMuted ? Color.brandYellow.opacity(0.2) : Color.cardBackground,
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .foregroundStyle(viewModel.isMuted ? Color.brandYellow : Color.textPrimary)
            }
        }
    }

    // MARK: - Sound Categories Section

    private var soundCategoriesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Text("MONITORED SOUNDS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.textSecondary)

                Spacer()

                Button("Setup") {
                    viewModel.isShowingSetup = true
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.brandTurquoise)
            }

            VStack(spacing: 10) {
                ForEach(SoundAlertType.allCases) { sound in
                    soundCard(sound)
                }
            }
        }
    }

    private func soundCard(_ sound: SoundAlertType) -> some View {
        let isEnabled = viewModel.settings.enabledSounds.contains(sound)
        let sensitivity = viewModel.settings.sensitivity(for: sound)
        let pattern = viewModel.settings.hapticPattern(for: sound)

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(sound.isUrgent ? Color.danger.opacity(0.15) : Color.brandTurquoise.opacity(0.15))
                    .frame(width: 42, height: 42)

                Image(systemName: sound.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(sound.isUrgent ? Color.danger : Color.brandTurquoise)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(sound.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.textPrimary)

                    if sound.isUrgent {
                        Text("EMERGENCY")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.danger, in: Capsule())
                    }
                }

                HStack(spacing: 6) {
                    Text(sensitivity.rawValue + " Sensitivity")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.textSecondary)

                    Text("•")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textSecondary)

                    Text(pattern.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.brandTurquoise)
                }
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

    // MARK: - Recent Alerts Section

    private var recentAlertsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Text("RECENT DETECTIONS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.textSecondary)

                Spacer()

                if !viewModel.history.isEmpty {
                    Button("See All (\(viewModel.history.count))") {
                        viewModel.isShowingHistory = true
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brandTurquoise)
                }
            }

            if viewModel.history.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.brandTurquoise)
                    Text("No alerts recently detected")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                }
                .padding(Theme.Spacing.m)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 14))
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.history.prefix(3)) { alert in
                        HStack(spacing: 12) {
                            Image(systemName: alert.type.icon)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(alert.isEmergency ? Color.danger : Color.brandYellow)
                                .frame(width: 28, height: 28)

                            Text(alert.type.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)

                            Spacer()

                            Text(alert.timestamp.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)

                            Text("\(Int(alert.confidence * 100))%")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.brandTurquoise)
                        }
                        .padding(.horizontal, Theme.Spacing.m)
                        .padding(.vertical, 10)
                        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                        .onTapGesture {
                            viewModel.activeAlert = alert
                        }
                    }
                }
            }
        }
    }

    // MARK: - Test Simulator Section

    private var testSimulatorSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("TEST ALERT SIMULATOR")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.textSecondary)

            HStack(spacing: 10) {
                Button {
                    viewModel.simulateAlert(.doorbell)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bell.fill")
                        Text("Doorbell")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(Color.brandYellow.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(Color.textPrimary)
                }

                Button {
                    viewModel.simulateAlert(.fireAlarm)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                        Text("Fire Alarm")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(Color.danger.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(Color.danger)
                }

                Button {
                    viewModel.simulateAlert(.knocking)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap.fill")
                        Text("Knock")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(Color.textPrimary)
                }
            }
        }
        .padding(.top, Theme.Spacing.s)
        .padding(.bottom, Theme.Spacing.l)
    }

    // MARK: - Radar Animation

    private func startRadarAnimation() {
        guard !reduceMotion else { return }

        withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
            radarRingScale1 = 1.9
            radarRingOpacity1 = 0.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                radarRingScale2 = 1.9
                radarRingOpacity2 = 0.0
            }
        }
    }
}
