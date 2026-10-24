import SwiftUI

/// Modal alert view presented when an ambient sound is classified (`63-sound-alert-doorbell` & `65-sound-alert-fire-emergency`).
public struct SoundAlertModalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dependencies) private var dependencies

    public let alert: SoundAlertRecord
    public let onDismiss: () -> Void
    public let onOpenCommunicator: (() -> Void)?
    public let onMute5Min: (() -> Void)?
    public let onCallEmergency: (() -> Void)?
    public let onNotifyContact: (() -> Void)?

    @State private var pulseScale: CGFloat = 1.0
    @State private var flashOpacity: Double = 0.2

    public init(
        alert: SoundAlertRecord,
        onDismiss: @escaping () -> Void,
        onOpenCommunicator: (() -> Void)? = nil,
        onMute5Min: (() -> Void)? = nil,
        onCallEmergency: (() -> Void)? = nil,
        onNotifyContact: (() -> Void)? = nil
    ) {
        self.alert = alert
        self.onDismiss = onDismiss
        self.onOpenCommunicator = onOpenCommunicator
        self.onMute5Min = onMute5Min
        self.onCallEmergency = onCallEmergency
        self.onNotifyContact = onNotifyContact
    }

    private var themeColor: Color {
        alert.isEmergency ? Color.danger : Color.brandYellow
    }

    private var backgroundColor: Color {
        alert.isEmergency ? Color(red: 0.25, green: 0.05, blue: 0.05) : Color(red: 0.15, green: 0.15, blue: 0.05)
    }

    public var body: some View {
        ZStack {
            // Background Flash / Glow
            Color.black.ignoresSafeArea()

            RoundedRectangle(cornerRadius: 32)
                .fill(themeColor.opacity(flashOpacity))
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.l) {
                // Top Dismiss Bar
                HStack {
                    Spacer()
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                    .accessibilityLabel("Dismiss alert")
                }
                .padding(.top, Theme.Spacing.m)

                Spacer()

                // Pulsing Icon
                ZStack {
                    Circle()
                        .fill(themeColor.opacity(0.25))
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulseScale)

                    Circle()
                        .fill(themeColor.opacity(0.4))
                        .frame(width: 104, height: 104)

                    Image(systemName: alert.type.icon)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(alert.isEmergency ? Color.white : Color.brandNavy)
                }

                // Alert Title & Subtitle
                VStack(spacing: 8) {
                    Text(alert.isEmergency ? "EMERGENCY SOUND DETECTED" : "SOUND ALERT DETECTED")
                        .font(.system(size: 13, weight: .black))
                        .tracking(1.5)
                        .foregroundStyle(themeColor)

                    Text(alert.type.title)
                        .font(.system(size: 32, weight: .heavy))
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.center)

                    Text(alert.type.subtitle)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }

                // Confidence & Time Badges
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                        Text("\(Int(alert.confidence * 100))% Confidence")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.15), in: Capsule())
                    .foregroundStyle(Color.white)

                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                        Text(alert.timestamp.formatted(date: .omitted, time: .shortened))
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.15), in: Capsule())
                    .foregroundStyle(Color.white.opacity(0.9))
                }

                if alert.isEmergency {
                    // Emergency notice box
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.danger)

                        Text("Check your immediate surroundings. If in danger, evacuate via the nearest stairs. Do not use elevators.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.9))
                    }
                    .padding(Theme.Spacing.m)
                    .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 14))
                }

                Spacer()

                // Action Buttons
                VStack(spacing: 12) {
                    if alert.isEmergency {
                        // Emergency primary actions
                        if let onCallEmergency {
                            Button {
                                onCallEmergency()
                            } label: {
                                HStack {
                                    Image(systemName: "phone.fill")
                                    Text("Call Emergency Services (911)")
                                }
                                .font(.system(size: 17, weight: .bold))
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(Color.danger, in: RoundedRectangle(cornerRadius: 16))
                                .foregroundStyle(Color.white)
                            }
                        }

                        if let onNotifyContact {
                            Button {
                                onNotifyContact()
                            } label: {
                                HStack {
                                    Image(systemName: "message.fill")
                                    Text("Notify Emergency Contact")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16))
                                .foregroundStyle(Color.white)
                            }
                        }

                        Button {
                            onDismiss()
                        } label: {
                            Text("I'm Safe")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.8))
                                .padding(.vertical, 8)
                        }
                    } else {
                        // Household / Routine alert actions
                        Button {
                            onDismiss()
                        } label: {
                            Text("Got It")
                                .font(.system(size: 17, weight: .bold))
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(Color.brandYellow, in: RoundedRectangle(cornerRadius: 16))
                                .foregroundStyle(Color.brandNavy)
                        }

                        if let onOpenCommunicator {
                            Button {
                                onOpenCommunicator()
                            } label: {
                                HStack {
                                    Image(systemName: "bubble.left.and.bubble.right.fill")
                                    Text("Open Communicator")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16))
                                .foregroundStyle(Color.white)
                            }
                        }

                        if let onMute5Min {
                            Button {
                                onMute5Min()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "bell.slash")
                                    Text("Mute for 5 Minutes")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.8))
                                .padding(.vertical, 6)
                            }
                        }
                    }
                }
                .padding(.bottom, Theme.Spacing.l)
            }
            .padding(.horizontal, Theme.Spacing.l)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulseScale = 1.2
                flashOpacity = alert.isEmergency ? 0.35 : 0.22
            }
        }
    }
}
