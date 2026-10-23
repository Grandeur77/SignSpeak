import SwiftUI

/// Communicator start dashboard (design `38-communicator-start`).
/// Serves as the launchpad for real-time two-way translation between deaf and hearing people.
/// Offers conversation mode selection (Face-to-Face Split Screen vs Show Text to Others),
/// Quick Phrases shortcuts, biometric-protected Conversation History, and Gesture Calibration.
public struct TalkRootView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(AppRouter.self) private var router
    @Bindable var deepLinkRouter: DeepLinkRouter

    @State private var viewModel = CommunicatorStartViewModel()

    public init(deepLinkRouter: DeepLinkRouter) {
        self.deepLinkRouter = deepLinkRouter
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                // Header Bar
                headerBar

                // Hero Start Card
                heroStartCard

                // Conversation Modes Section
                conversationModesSection

                // Shortcuts & Tools Section
                shortcutsSection
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationDestination(isPresented: $viewModel.isShowingLiveSession) {
            CommunicatorLiveView(
                mode: viewModel.selectedMode,
                dominantHand: viewModel.dominantHand
            )
        }
        .sheet(isPresented: $viewModel.isShowingCalibration) {
            GestureCalibrationView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isShowingQuickPhrases) {
            QuickPhrasesSheet()
        }
        .sheet(isPresented: $viewModel.isShowingHistory) {
            ConversationHistorySheet()
        }
        .onChange(of: deepLinkRouter.activeDestination) { _, newDest in
            if newDest == .communicator {
                viewModel.startConversation()
                deepLinkRouter.activeDestination = nil
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Communicator")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)

                Text("Real-time two-way translation")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            ProfileAvatarButton {
                deepLinkRouter.openProfile()
            }
        }
        .padding(.top, Theme.Spacing.s)
    }

    // MARK: - Hero Start Card

    private var heroStartCard: some View {
        VStack(spacing: Theme.Spacing.m) {
            ZStack {
                Circle()
                    .fill(Color.brandTurquoise.opacity(0.15))
                    .frame(width: 76, height: 76)

                Image(systemName: "person.2.wave.2.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.brandTurquoise)
            }

            VStack(spacing: 6) {
                Text("Start a Conversation")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)

                Text("Place iPhone on table between speakers. Sign or speak freely — translations appear live for both people.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.m)

                // Active Mode Badge
                HStack(spacing: 6) {
                    Image(systemName: viewModel.selectedMode.iconName)
                        .font(.system(size: 11))
                    Text(viewModel.selectedMode.title)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color.brandTurquoise)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.brandTurquoise.opacity(0.12), in: Capsule())
                .padding(.top, 4)
            }

            // Primary Launch Button
            Button {
                viewModel.startConversation()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Launch Conversation")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(Color(red: 11/255, green: 42/255, blue: 74/255))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.brandTurquoise, in: Capsule())
                .shadow(color: Color.brandTurquoise.opacity(0.3), radius: 10, y: 5)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Conversation Modes Section

    private var conversationModesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("CONVERSATION MODES")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, Theme.Spacing.s)

            VStack(spacing: 12) {
                ForEach(ConversationMode.allCases) { mode in
                    let isSelected = viewModel.selectedMode == mode

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.selectMode(mode)
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isSelected ? Color.brandTurquoise.opacity(0.2) : Color.cardBackground.opacity(0.8))
                                    .frame(width: 44, height: 44)

                                Image(systemName: mode.iconName)
                                    .font(.system(size: 20))
                                    .foregroundStyle(isSelected ? Color.brandTurquoise : Color.textSecondary)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(mode.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.textPrimary)

                                    Text(mode.badgeText)
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(isSelected ? Color.brandTurquoise : Color.textSecondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1)
                                        .background(
                                            (isSelected ? Color.brandTurquoise : Color.textSecondary).opacity(0.12),
                                            in: Capsule()
                                        )
                                }

                                Text(mode.subtitle)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.textSecondary)
                                    .lineSpacing(2)
                            }

                            Spacer()

                            // Radio Indicator
                            ZStack {
                                Circle()
                                    .strokeBorder(isSelected ? Color.brandTurquoise : Color.textSecondary.opacity(0.3), lineWidth: 2)
                                    .frame(width: 20, height: 20)

                                if isSelected {
                                    Circle()
                                        .fill(Color.brandTurquoise)
                                        .frame(width: 10, height: 10)
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding(Theme.Spacing.m)
                        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(isSelected ? Color.brandTurquoise : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Shortcuts & Tools Section

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("SHORTCUTS & TOOLS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, Theme.Spacing.s)

            VStack(spacing: 0) {
                // 1. Quick Phrases Shortcut
                Button {
                    viewModel.isShowingQuickPhrases = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.brandYellow.opacity(0.15))
                                .frame(width: 38, height: 38)

                            Image(systemName: "bolt.bubble.fill")
                                .font(.system(size: 17))
                                .foregroundStyle(Color.brandYellow)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quick Phrases")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)

                            Text("Pre-saved emergency, order & assistance cards")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(Theme.Spacing.m)
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 58)

                // 2. Conversation History Shortcut (with Lock Badge)
                let isProtected = viewModel.isHistoryProtected(
                    isBiometricLockEnabled: router.isBiometricLockEnabled,
                    protectConversations: router.protectConversationHistory
                )

                Button {
                    Task {
                        await viewModel.requestOpenHistory(
                            isBiometricLockEnabled: router.isBiometricLockEnabled,
                            protectConversations: router.protectConversationHistory,
                            biometricService: dependencies.biometricAuthService
                        )
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.brandTurquoise.opacity(0.15))
                                .frame(width: 38, height: 38)

                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 17))
                                .foregroundStyle(Color.brandTurquoise)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Conversation History")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)

                                if isProtected && !viewModel.isHistoryUnlocked {
                                    HStack(spacing: 3) {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 9))
                                        Text(router.biometricName.uppercased())
                                            .font(.system(size: 9, weight: .bold))
                                    }
                                    .foregroundStyle(Color.brandYellow)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color.brandYellow.opacity(0.15), in: Capsule())
                                }
                            }

                            Text(isProtected && !viewModel.isHistoryUnlocked
                                ? "Requires \(router.biometricName) to view transcripts"
                                : "Review past conversations and saved messages")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                        }

                        Spacer()

                        Image(systemName: isProtected && !viewModel.isHistoryUnlocked ? "lock.fill" : "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isProtected && !viewModel.isHistoryUnlocked ? Color.brandYellow : Color.textSecondary)
                    }
                    .padding(Theme.Spacing.m)
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 58)

                // 3. Gesture Calibration Shortcut
                Button {
                    viewModel.isShowingCalibration = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.brandNavy.opacity(0.15))
                                .frame(width: 38, height: 38)

                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 17))
                                .foregroundStyle(Color.brandNavy)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Gesture Calibration")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)

                                Text(viewModel.dominantHand.title)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color.brandTurquoise)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color.brandTurquoise.opacity(0.12), in: Capsule())
                            }

                            Text("Dominant hand & camera lighting check")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(Theme.Spacing.m)
                }
                .buttonStyle(.plain)
            }
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview("Talk Root View") {
    NavigationStack {
        TalkRootView(deepLinkRouter: DeepLinkRouter())
            .environment(
                AppRouter(
                    authService: StubAuthService(initialUserId: "user-1"),
                    userProfileRepository: StubUserProfileRepository(),
                    biometricAuthService: StubBiometricAuthService()
                )
            )
    }
}
