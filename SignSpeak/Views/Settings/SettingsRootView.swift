import SwiftUI

/// Screen 52: Settings Root view (`52-settings`).
/// Includes profile card and sections Account, Practice, Communicator, Awareness,
/// Accessibility, Security, Support, Sign Out alert (`58-sign-out-alert`),
/// and Delete Account (`56-delete-account`), with current values on each row and real bundle version.
public struct SettingsRootView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityPreferences) private var accessibilityPreferences
    @Bindable var deepLinkRouter: DeepLinkRouter

    @State private var userProfile: UserProfile?
    @State private var isShowingSignOutAlert = false

    public init(deepLinkRouter: DeepLinkRouter) {
        self.deepLinkRouter = deepLinkRouter
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                // MARK: - Header
                headerBar

                // MARK: - Profile Card
                profileCard

                // MARK: - Section 1: Account
                accountSection

                // MARK: - Section 2: Practice & Learning
                practiceSection

                // MARK: - Section 3: Communicator
                communicatorSection

                // MARK: - Section 4: Accessibility
                accessibilitySection

                // MARK: - Section 5: Security & Privacy
                securityAndPrivacySection

                // MARK: - Section 6: Support & About
                supportSection

                #if DEBUG
                // Developer Tools (DEBUG only)
                developerToolsSection
                #endif

                // MARK: - Section 7: Account Actions (Sign Out & Delete)
                accountActionsSection

                // MARK: - Footer: App Version
                versionFooter
            }
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .task {
            let uid = dependencies.authService.currentUserId ?? "guest"
            userProfile = try? await dependencies.userProfileRepository.fetchProfile(userId: uid)
        }
        .alert("Sign Out", isPresented: $isShowingSignOutAlert) {
            Button("Sign Out", role: .destructive) {
                router.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out of SignSpeak?")
        }
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Settings")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)

                Text("Preferences, security & account")
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
    }

    // MARK: - Profile Card
    private var profileCard: some View {
        Button {
            deepLinkRouter.openProfile()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.brandTurquoise, Color.brandNavy],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 54)

                    Text(String(userProfile?.displayName.prefix(1) ?? "M"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(userProfile?.displayName ?? "Maya")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.textPrimary)

                        Text("Level 3")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.brandNavy)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.brandYellow, in: Capsule())
                    }

                    Text(userProfile?.email ?? "learner@example.com")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("View Profile")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.brandTurquoise)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.brandTurquoise)
                }
            }
            .padding(Theme.Spacing.m)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            .padding(.horizontal, Theme.Spacing.l)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section 1: Account
    private var accountSection: some View {
        sectionBlock(title: "ACCOUNT") {
            Button {
                deepLinkRouter.openProfile()
            } label: {
                settingsRowWithDetail(
                    icon: "person.crop.circle.fill",
                    color: Color.brandTurquoise,
                    title: "Profile & Personal Details",
                    value: userProfile?.role.capitalized ?? "Learner"
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 52)

            NavigationLink {
                RemindersSettingsView()
            } label: {
                settingsRowWithDetail(
                    icon: "bell.badge.fill",
                    color: Color.brandYellow,
                    title: "Reminders & Notifications",
                    value: "Active"
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Section 2: Practice & Learning
    private var practiceSection: some View {
        sectionBlock(title: "PRACTICE & AWARENESS") {
            Button {
                deepLinkRouter.openProfile()
            } label: {
                settingsRowWithDetail(
                    icon: "clock.fill",
                    color: Color.brandTurquoise,
                    title: "Daily Practice Goal",
                    value: "\(userProfile?.dailyGoalMinutes ?? 10) mins/day"
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 52)

            NavigationLink {
                AccessibilitySettingsView()
            } label: {
                settingsRowWithDetail(
                    icon: "hand.raised.fill",
                    color: Color.brandYellow,
                    title: "Dominant Hand",
                    value: (userProfile?.dominantHand == "left" || accessibilityPreferences.leftHandedMode) ? "Left Hand" : "Right Hand"
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 52)

            HStack(spacing: 12) {
                Image(systemName: "waveform.path.badge.plus")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.brandTurquoise)
                    .frame(width: 28, height: 28)

                Text("Sound Alerts Awareness")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Text(userProfile?.soundAlertsEnabled == true ? "Active" : "Disabled")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(userProfile?.soundAlertsEnabled == true ? Color.brandTurquoise : Color.textSecondary)
            }
            .padding(Theme.Spacing.m)
        }
    }

    // MARK: - Section 3: Communicator
    private var communicatorSection: some View {
        sectionBlock(title: "COMMUNICATOR & SPEECH") {
            NavigationLink {
                VoiceAndSpeechSettingsView()
            } label: {
                settingsRowWithDetail(
                    icon: "waveform.badge.mic",
                    color: Color.brandTurquoise,
                    title: "Voice & Speech Preferences",
                    value: "Samantha • 1.0x"
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Section 4: Accessibility
    private var accessibilitySection: some View {
        sectionBlock(title: "ACCESSIBILITY") {
            NavigationLink {
                AccessibilitySettingsView()
            } label: {
                settingsRowWithDetail(
                    icon: "figure.walk.motion",
                    color: Color.brandNavy,
                    title: "Accessibility Options",
                    value: accessibilityPreferences.hapticFeedbackEnabled ? "Haptics: On" : "Standard"
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Section 5: Security & Privacy
    private var securityAndPrivacySection: some View {
        sectionBlock(title: "SECURITY & PRIVACY") {
            NavigationLink {
                SecuritySettingsView()
            } label: {
                settingsRowWithDetail(
                    icon: router.biometricIcon,
                    color: Color.brandTurquoise,
                    title: "Biometric Security & \(router.biometricName)",
                    value: router.isBiometricLockEnabled ? "ON" : "Off"
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 52)

            NavigationLink {
                PrivacyAndDataView()
            } label: {
                settingsRowWithDetail(
                    icon: "lock.shield.fill",
                    color: Color.brandTurquoise,
                    title: "Privacy & Data Controls",
                    value: "100% On-Device"
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Section 6: Support & About
    private var supportSection: some View {
        sectionBlock(title: "SUPPORT & RESOURCES") {
            NavigationLink {
                HelpAndAboutView()
            } label: {
                settingsRowWithDetail(
                    icon: "questionmark.circle.fill",
                    color: Color.brandYellow,
                    title: "Help, FAQ & About",
                    value: "v\(appVersion)"
                )
            }
            .buttonStyle(.plain)
        }
    }

    #if DEBUG
    // MARK: - Developer Tools
    private var developerToolsSection: some View {
        sectionBlock(title: "DEVELOPER TOOLS (DEBUG)") {
            NavigationLink {
                DatasetCaptureView()
            } label: {
                settingsRowWithDetail(
                    icon: "camera.badge.ellipsis",
                    color: Color.brandYellow,
                    title: "Dataset Capture Tool",
                    value: "Photos & Clips"
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 52)

            NavigationLink {
                CameraTestView()
            } label: {
                settingsRowWithDetail(
                    icon: "hand.raised.viewfinder",
                    color: Color.brandTurquoise,
                    title: "Recognition Lab",
                    value: "Pose & Classifier"
                )
            }
            .buttonStyle(.plain)
        }
    }
    #endif

    // MARK: - Section 7: Account Actions
    private var accountActionsSection: some View {
        VStack(spacing: 12) {
            // Sign Out Button
            Button {
                isShowingSignOutAlert = true
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                }
                .foregroundStyle(Color.textPrimary)
                .frame(height: 50)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
            }
            .buttonStyle(.plain)

            // Delete Account Link
            NavigationLink {
                DeleteAccountView()
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "trash")
                    Text("Delete Account")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                }
                .foregroundStyle(Color.danger)
                .frame(height: 48)
                .background(Color.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.Radius.button))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.s)
    }

    // MARK: - Footer: Version
    private var versionFooter: some View {
        VStack(spacing: 4) {
            Text("SignSpeak v\(appVersion) (Build \(appBuild))")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.textSecondary)

            Text("Designed for Deaf & Hearing Learners • WFD Heritage")
                .font(.system(size: 11))
                .foregroundStyle(Color.textSecondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.m)
    }

    // MARK: - Helper Builders
    private func sectionBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.textSecondary)
                .tracking(0.8)
                .padding(.horizontal, Theme.Spacing.l)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            .padding(.horizontal, Theme.Spacing.l)
        }
    }

    private func settingsRowWithDetail(icon: String, color: Color, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.textPrimary)

            Spacer()

            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)

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
            .environment(\.accessibilityPreferences, AccessibilityPreferences())
    }
}
