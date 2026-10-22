import SwiftUI

/// Facilitates live conversation between deaf and hearing people with real-time speech and sign transcription.
public struct TalkRootView: View {
    @Bindable var deepLinkRouter: DeepLinkRouter

    @State private var isShowingLiveSession = false

    public init(deepLinkRouter: DeepLinkRouter) {
        self.deepLinkRouter = deepLinkRouter
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                // Header
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
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.s)

                // Hero Start Card
                VStack(spacing: Theme.Spacing.m) {
                    ZStack {
                        Circle()
                            .fill(Color.brandTurquoise.opacity(0.15))
                            .frame(width: 80, height: 80)

                        Image(systemName: "person.2.wave.2.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.brandTurquoise)
                    }

                    VStack(spacing: 4) {
                        Text("Start a Conversation")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.textPrimary)

                        Text("Place iPhone on table between speakers. Sign or speak freely — translation appears live for both people.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Theme.Spacing.m)
                    }

                    Button {
                        isShowingLiveSession = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "mic.fill")
                            Text("Launch Live Session")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(Color.onPrimary)
                        .frame(maxWidth: 300)
                        .frame(height: 52)
                        .background(Color.primaryFill, in: Capsule())
                        .shadow(color: Color.primaryFill.opacity(0.25), radius: 10, y: 5)
                    }
                    .buttonStyle(.plain)
                }
                .padding(Theme.Spacing.l)
                .frame(maxWidth: .infinity)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                .padding(.horizontal, Theme.Spacing.l)

                // Quick Phrases Section (39c)
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    HStack {
                        Text("Quick Phrases")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.textPrimary)

                        Spacer()

                        Text("Tap to speak or show")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                    }

                    VStack(spacing: 8) {
                        quickPhraseRow(text: "Hello! Nice to meet you.", category: "Greetings")
                        quickPhraseRow(text: "Could you please repeat that slower?", category: "Assistance")
                        quickPhraseRow(text: "I am deaf / hard of hearing.", category: "Intro")
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
            }
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationDestination(isPresented: $isShowingLiveSession) {
            CameraTestView()
        }
        .onChange(of: deepLinkRouter.activeDestination) { _, newDest in
            if newDest == .communicator {
                isShowingLiveSession = true
                deepLinkRouter.activeDestination = nil
            }
        }
    }

    private func quickPhraseRow(text: String, category: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textPrimary)

                Text(category)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.brandTurquoise)
            }

            Spacer()

            Image(systemName: "speaker.wave.2")
                .font(.system(size: 14))
                .foregroundStyle(Color.brandTurquoise)
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview("Talk Root View") {
    NavigationStack {
        TalkRootView(deepLinkRouter: DeepLinkRouter())
    }
}
