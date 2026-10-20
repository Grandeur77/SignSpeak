import SwiftUI

/// Provides access to biometric locks, voice preferences, accessibility options, and privacy data.
public struct SettingsRootView: View {
    @Environment(AppRouter.self) private var router
    @Bindable var deepLinkRouter: DeepLinkRouter

    @AppStorage("isFaceIDLockEnabled") private var isFaceIDLockEnabled = false
    @State private var isShowingSignOutAlert = false

    public init(deepLinkRouter: DeepLinkRouter) {
        self.deepLinkRouter = deepLinkRouter
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Settings")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.brandNavy)

                        Text("Preferences and app security")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textSecondary)
                    }

                    Spacer()

                    ProfileAvatarButton {
                        deepLinkRouter.openProfile()
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.s)

                // Section 1: Security & Biometrics
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text("Security")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.textSecondary)
                        .padding(.horizontal, Theme.Spacing.l)

                    VStack(spacing: 0) {
                        Toggle(isOn: $isFaceIDLockEnabled) {
                            HStack(spacing: 12) {
                                Image(systemName: "faceid")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.brandTurquoise)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Face ID Lock")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.textPrimary)

                                    Text("Require Face ID to open SignSpeak")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.textSecondary)
                                }
                            }
                        }
                        .tint(Color.brandTurquoise)
                        .padding(Theme.Spacing.m)
                    }
                    .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                    .padding(.horizontal, Theme.Spacing.l)
                }

                // Section 2: Preferences
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text("Preferences")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.textSecondary)
                        .padding(.horizontal, Theme.Spacing.l)

                    VStack(spacing: 0) {
                        settingsRow(icon: "bell.badge.fill", color: Color.brandYellow, title: "Reminders & Notifications")
                        Divider().padding(.leading, 52)
                        settingsRow(icon: "waveform.badge.mic", color: Color.brandTurquoise, title: "Voice & Speech")
                        Divider().padding(.leading, 52)
                        settingsRow(icon: "figure.walk.motion", color: Color.brandNavy, title: "Accessibility")
                        Divider().padding(.leading, 52)
                        settingsRow(icon: "shield.checkerboard", color: Color.brandNavy, title: "Privacy & Data")
                    }
                    .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                    .padding(.horizontal, Theme.Spacing.l)
                }

                // Section 3: About & Support
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text("Support")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.textSecondary)
                        .padding(.horizontal, Theme.Spacing.l)

                    VStack(spacing: 0) {
                        settingsRow(icon: "questionmark.circle.fill", color: Color.textSecondary, title: "Help & About")
                    }
                    .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                    .padding(.horizontal, Theme.Spacing.l)
                }

                // Section 4: Sign Out
                Button(role: .destructive) {
                    isShowingSignOutAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                    }
                    .foregroundStyle(Color.danger)
                    .frame(height: 50)
                    .background(Color.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.Radius.button))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.s)
            }
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .alert("Sign Out", isPresented: $isShowingSignOutAlert) {
            Button("Sign Out", role: .destructive) {
                router.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out of SignSpeak?")
        }
    }

    private func settingsRow(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(Theme.Spacing.m)
    }
}

#Preview("Settings Root View") {
    NavigationStack {
        SettingsRootView(deepLinkRouter: DeepLinkRouter())
            .environment(
                AppRouter(
                    authService: StubAuthService(initialUserId: "user-1"),
                    userProfileRepository: StubUserProfileRepository(),
                    biometricAuthService: StubBiometricAuthService()
                )
            )
    }
}
