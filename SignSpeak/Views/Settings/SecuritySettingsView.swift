import SwiftUI

/// Security & Biometric Protection settings screen (`53-security-face-id.png`).
public struct SecuritySettingsView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var isLockEnabled: Bool = false
    @State private var selectedTimeout: BiometricLockTimeout = .immediately
    @State private var protectConversations: Bool = true
    @State private var protectPractice: Bool = true
    @State private var showSavedBanner = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                // Header Hero
                VStack(spacing: Theme.Spacing.s) {
                    ZStack {
                        Circle()
                            .fill(Color.brandTurquoise.opacity(0.15))
                            .frame(width: 72, height: 72)

                        Image(systemName: router.biometricIcon)
                            .font(.system(size: 34, weight: .regular))
                            .foregroundStyle(Color.brandTurquoise)
                    }
                    .padding(.top, Theme.Spacing.s)

                    Text("Biometric Protection")
                        .font(.appLargeTitle)
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Keep your conversations, practice logs, and personal video gestures private on this device.")
                        .font(.appBody)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.m)
                }

                // Section 1: Biometric Master Toggle
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text("BIOMETRIC AUTHENTICATION")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.textSecondary)
                        .padding(.horizontal, Theme.Spacing.s)

                    VStack(spacing: 0) {
                        Toggle(isOn: $isLockEnabled) {
                            HStack(spacing: 12) {
                                Image(systemName: router.biometricIcon)
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.brandTurquoise)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Lock app with \(router.biometricName)")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.textPrimary)

                                    Text("Require authentication upon launch and return")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.textSecondary)
                                }
                            }
                        }
                        .tint(Color.brandTurquoise)
                        .padding(Theme.Spacing.m)
                    }
                    .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
                }

                // Section 2: Lock Timeout (shown only when lock is enabled)
                if isLockEnabled {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Text("REQUIRE \(router.biometricName.uppercased())")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.textSecondary)
                            .padding(.horizontal, Theme.Spacing.s)

                        VStack(spacing: 0) {
                            ForEach(BiometricLockTimeout.allCases) { timeout in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedTimeout = timeout
                                    }
                                } label: {
                                    HStack {
                                        Text(timeout.title)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(Color.textPrimary)

                                        Spacer()

                                        if selectedTimeout == timeout {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(Color.brandTurquoise)
                                        }
                                    }
                                    .padding(.horizontal, Theme.Spacing.m)
                                    .frame(height: 48)
                                }
                                .buttonStyle(.plain)

                                if timeout != BiometricLockTimeout.allCases.last {
                                    Divider()
                                        .padding(.leading, Theme.Spacing.m)
                                }
                            }
                        }
                        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))

                    // Section 3: Protected Features
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Text("PROTECTED FEATURES")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.textSecondary)
                            .padding(.horizontal, Theme.Spacing.s)

                        VStack(spacing: 0) {
                            // Conversation history toggle
                            Toggle(isOn: $protectConversations) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Protect conversation history")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.textPrimary)

                                    Text("Require \(router.biometricName) to view transcripts and past audio")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.textSecondary)
                                }
                            }
                            .tint(Color.brandTurquoise)
                            .padding(Theme.Spacing.m)

                            Divider()
                                .padding(.leading, Theme.Spacing.m)

                            // AI practice clips toggle
                            Toggle(isOn: $protectPractice) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Protect AI practice video clips")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.textPrimary)

                                    Text("Secures locally recorded gesture practice sessions")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.textSecondary)
                                }
                            }
                            .tint(Color.brandTurquoise)
                            .padding(Theme.Spacing.m)
                        }
                        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Section 4: Secure Enclave Card
                HStack(alignment: .top, spacing: Theme.Spacing.m) {
                    Image(systemName: "lock.shield.fill")
                        .font(.title2)
                        .foregroundStyle(Color.brandTurquoise)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("On-device biometric encryption")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.textPrimary)

                        Text("SignSpeak never transmits biometric signatures to cloud servers. Key verification remains isolated within Apple Secure Enclave.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                            .lineSpacing(2)
                    }
                }
                .padding(Theme.Spacing.m)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))

                // Save feedback banner
                if showSavedBanner {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.green)
                        Text("Security settings saved")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.cardBackground, in: Capsule())
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(Theme.Spacing.l)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Biometric Protection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveSettings()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.brandTurquoise)
            }
        }
        .onAppear {
            isLockEnabled = router.isBiometricLockEnabled
            selectedTimeout = router.lockTimeout
            protectConversations = router.protectConversationHistory
            protectPractice = router.protectPracticeHistory
        }
    }

    private func saveSettings() {
        router.isBiometricLockEnabled = isLockEnabled
        router.lockTimeout = selectedTimeout
        router.protectConversationHistory = protectConversations
        router.protectPracticeHistory = protectPractice

        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            showSavedBanner = true
        }

        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            dismiss()
        }
    }
}
