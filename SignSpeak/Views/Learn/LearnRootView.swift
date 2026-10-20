import SwiftUI

/// Provides access to camera sign practice, lesson chapters, fingerspelling drills, and quizzes.
public struct LearnRootView: View {
    @Bindable var deepLinkRouter: DeepLinkRouter

    @State private var isShowingCameraPractice = false
    #if DEBUG
    @State private var isShowingDatasetCapture = false
    #endif

    public init(deepLinkRouter: DeepLinkRouter) {
        self.deepLinkRouter = deepLinkRouter
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Learn Hub")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.brandNavy)

                        Text("Interactive sign language curriculum")
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

                // Featured Action Card: Real-time Camera Practice
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    HStack {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.brandTurquoise)

                        Text("AI PRACTICE MIRROR")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.brandTurquoise)
                            .tracking(0.8)

                        Spacer()

                        Text("On-Device Vision")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Real-Time Camera Practice")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.brandNavy)

                        Text("Receive instant on-device feedback on hand orientation, fingerspelling shape, and accuracy.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textSecondary)
                    }

                    Button {
                        isShowingCameraPractice = true
                    } label: {
                        HStack(spacing: 8) {
                            Spacer()
                            Image(systemName: "camera.fill")
                            Text("Start Camera Practice")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .frame(height: 50)
                        .background(Color.brandNavy, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(Theme.Spacing.m)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                .padding(.horizontal, Theme.Spacing.l)

                #if DEBUG
                // Developer Dataset Capture Utility
                Button {
                    isShowingDatasetCapture = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.badge.ellipsis")
                        Text("Dataset Capture Tool")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(Color.brandNavy)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.brandYellow.opacity(0.2), in: RoundedRectangle(cornerRadius: Theme.Radius.button))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.Spacing.l)
                #endif

                // Modules Grid
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    Text("Modules")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.brandNavy)
                        .padding(.horizontal, Theme.Spacing.l)

                    VStack(spacing: 12) {
                        moduleCard(
                            icon: "character.book.closed.fill",
                            color: Color.brandTurquoise,
                            title: "Alphabet Lessons (A–Z)",
                            description: "Master all 26 manual alphabet hand shapes",
                            badge: "Complete"
                        )

                        moduleCard(
                            icon: "hand.wave.fill",
                            color: Color.brandYellow,
                            title: "Essential Greetings",
                            description: "Hello, Thank You, Nice to meet you",
                            badge: "In Progress"
                        )

                        moduleCard(
                            icon: "cross.case.fill",
                            color: Color.danger,
                            title: "Emergency & Safety",
                            description: "Hospital, Help, Police, Allergy signs",
                            badge: "Crucial"
                        )
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                }
            }
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationDestination(isPresented: $isShowingCameraPractice) {
            CameraTestView()
        }
        #if DEBUG
        .navigationDestination(isPresented: $isShowingDatasetCapture) {
            DatasetCaptureView()
        }
        #endif
        .onChange(of: deepLinkRouter.activeDestination) { _, newDest in
            if case .practice = newDest {
                isShowingCameraPractice = true
                deepLinkRouter.activeDestination = nil
            }
        }
    }

    private func moduleCard(icon: String, color: Color, title: String, description: String, badge: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}

#Preview("Learn Root View") {
    NavigationStack {
        LearnRootView(deepLinkRouter: DeepLinkRouter())
    }
}
