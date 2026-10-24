import SwiftUI
import UIKit

/// Screen 55: Accessibility Settings view (`55-accessibility`).
/// Controls haptic recognition feedback, vibration strength, visual sound alert flashes,
/// high contrast, reduce motion, dynamic text size preview, and left-handed signing mode.
public struct AccessibilitySettingsView: View {
    @Environment(\.accessibilityPreferences) private var preferences
    @Environment(\.dismiss) private var dismiss

    @State private var showingResetAlert = false
    @State private var isSimulatingFlash = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                // Flash simulation overlay if testing
                if isSimulatingFlash {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.brandYellow.opacity(0.35))
                        .frame(height: 48)
                        .overlay {
                            HStack(spacing: 8) {
                                Image(systemName: "bolt.fill")
                                    .foregroundStyle(Color.brandYellow)
                                Text("Visual Flash Alert Test")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.textPrimary)
                            }
                        }
                        .transition(.opacity)
                }

                // MARK: - Section 1: Feedback & Haptics
                hapticsSection

                // MARK: - Section 2: Visual Alerts
                visualAlertsSection

                // MARK: - Section 3: Display & Motion
                displayAndMotionSection

                // MARK: - Section 4: Dynamic Text Size & Preview
                textSizeSection

                // MARK: - Section 5: Signing Ergonomics (Left Handed Mode)
                leftHandedSection

                // MARK: - Reset to Defaults
                Button(role: .destructive) {
                    showingResetAlert = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset Accessibility Defaults")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.danger)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.plain)
                .padding(.top, Theme.Spacing.s)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.m)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Accessibility")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reset Accessibility Defaults?", isPresented: $showingResetAlert) {
            Button("Reset", role: .destructive) {
                preferences.resetToDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will restore default haptic vibration, contrast, motion, and right-handed signing settings.")
        }
    }

    // MARK: - Section 1: Haptics & Vibration
    private var hapticsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("FEEDBACK & HAPTICS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.textSecondary)
                .tracking(0.8)

            VStack(spacing: 0) {
                Toggle(isOn: Bindable(preferences).hapticFeedbackEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recognition Haptic Feedback")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Text("Vibrate subtly when a sign is recognized with high confidence")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .tint(Color.brandTurquoise)
                .padding(Theme.Spacing.m)

                Divider().padding(.leading, Theme.Spacing.m)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Alert Vibration Strength")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                            Text("Intensity for sound alert notifications")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                        }

                        Spacer()

                        Button {
                            preferences.triggerTestHaptic()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "iphone.radiowaves.left.and.right")
                                Text("Test")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.brandTurquoise)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.brandTurquoise.opacity(0.12), in: Capsule())
                        }
                    }

                    Picker("Vibration Strength", selection: Bindable(preferences).alertVibrationStrength) {
                        ForEach(AlertVibrationStrength.allCases) { strength in
                            Text(strength.rawValue).tag(strength)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(Theme.Spacing.m)
            }
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
    }

    // MARK: - Section 2: Visual Alerts
    private var visualAlertsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("VISUAL AWARENESS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.textSecondary)
                .tracking(0.8)

            VStack(spacing: 0) {
                Toggle(isOn: Bindable(preferences).flashScreenOnSoundAlerts) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Flash Screen on Sound Alerts")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Text("Briefly illuminates display border when alarms or sirens are detected")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .tint(Color.brandTurquoise)
                .padding(Theme.Spacing.m)

                Divider().padding(.leading, Theme.Spacing.m)

                HStack {
                    Text("Preview Flash Notification")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textPrimary)

                    Spacer()

                    Button("Preview Flash") {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isSimulatingFlash = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isSimulatingFlash = false
                            }
                        }
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.brandYellow)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.brandYellow.opacity(0.12), in: Capsule())
                }
                .padding(Theme.Spacing.m)
            }
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
    }

    // MARK: - Section 3: Display & Motion
    private var displayAndMotionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("DISPLAY & MOTION OVERRIDES")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.textSecondary)
                .tracking(0.8)

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "circle.lefthalf.filled")
                            .foregroundStyle(Color.brandTurquoise)
                        Text("High Contrast")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                    }

                    Picker("High Contrast", selection: Bindable(preferences).highContrastOverride) {
                        ForEach(ContrastPreference.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(Theme.Spacing.m)

                Divider().padding(.leading, Theme.Spacing.m)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "figure.walk.motion")
                            .foregroundStyle(Color.brandTurquoise)
                        Text("Reduce Motion")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                    }

                    Picker("Reduce Motion", selection: Bindable(preferences).reduceMotionOverride) {
                        ForEach(MotionPreference.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(Theme.Spacing.m)
            }
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
    }

    // MARK: - Section 4: Dynamic Text Size
    private var textSizeSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("TEXT SIZE & READING")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.textSecondary)
                .tracking(0.8)

            VStack(spacing: Theme.Spacing.m) {
                // Live preview card
                VStack(alignment: .leading, spacing: 6) {
                    Text("LIVE TEXT PREVIEW")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.brandTurquoise)
                        .tracking(0.8)

                    Text("The quick brown fox signs ASL with clarity and confidence.")
                        .font(.system(size: 15 * preferences.textSizeMultiplier, weight: .medium))
                        .foregroundStyle(Color.textPrimary)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.m)
                .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 10))

                // Multiplier slider
                HStack(spacing: 12) {
                    Image(systemName: "textformat.size.smaller")
                        .foregroundStyle(Color.textSecondary)

                    Slider(
                        value: Bindable(preferences).textSizeMultiplier,
                        in: 0.8...1.4,
                        step: 0.1
                    )
                    .tint(Color.brandTurquoise)

                    Image(systemName: "textformat.size.larger")
                        .foregroundStyle(Color.textSecondary)
                }

                HStack {
                    Text("Scale: \(Int(preferences.textSizeMultiplier * 100))%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)

                    Spacer()

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape.fill")
                            Text("Open iOS Settings")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.brandTurquoise)
                    }
                }
            }
            .padding(Theme.Spacing.m)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
    }

    // MARK: - Section 5: Signing Ergonomics (Left Handed Mode)
    private var leftHandedSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("SIGNING ERGONOMICS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.textSecondary)
                .tracking(0.8)

            VStack(spacing: Theme.Spacing.m) {
                Toggle(isOn: Bindable(preferences).leftHandedMode) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.raised.fill")
                                .foregroundStyle(Color.brandYellow)
                            Text("Left-Handed Signing Mode")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                        }
                        Text("Mirrors viewfinder overlay, flips recognition landmarks, and mirrors demonstration videos.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .tint(Color.brandTurquoise)

                // Visual Indicator
                HStack(spacing: 12) {
                    handIndicator(isLeft: true, isActive: preferences.leftHandedMode)
                    handIndicator(isLeft: false, isActive: !preferences.leftHandedMode)
                }
            }
            .padding(Theme.Spacing.m)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
    }

    private func handIndicator(isLeft: Bool, isActive: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isLeft ? "hand.point.left.fill" : "hand.point.right.fill")
                .font(.system(size: 16))
                .foregroundStyle(isActive ? Color.brandNavy : Color.textSecondary)

            Text(isLeft ? "Left Hand" : "Right Hand")
                .font(.system(size: 13, weight: isActive ? .bold : .medium))
                .foregroundStyle(isActive ? Color.brandNavy : Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 38)
        .background(
            isActive ? Color.brandYellow : Color.appBackground,
            in: RoundedRectangle(cornerRadius: 8)
        )
    }
}

#Preview("Accessibility Settings") {
    NavigationStack {
        AccessibilitySettingsView()
            .environment(\.accessibilityPreferences, AccessibilityPreferences())
    }
}
