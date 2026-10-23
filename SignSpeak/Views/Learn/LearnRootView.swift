import SwiftUI

/// Main learning hub for American Sign Language curriculum.
/// Matches design `25-learn-hub`.
/// Displays daily mastery goal, alphabet fingerspelling path card with progress ring,
/// words & phrases categories card with progress ring, and fast-track practice & review cards.
public struct LearnRootView: View {
    @Environment(\.dependencies) private var dependencies
    @Bindable var deepLinkRouter: DeepLinkRouter

    @State private var viewModel: LearnHubViewModel?
    @State private var isShowingCameraPractice = false
    @State private var navigatedDestination: String?

    #if DEBUG
    @State private var isShowingDatasetCapture = false
    #endif

    public init(deepLinkRouter: DeepLinkRouter) {
        self.deepLinkRouter = deepLinkRouter
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                // 1. Top Header Bar
                headerView
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.top, Theme.Spacing.s)

                // 2. Daily Mastery Goal Card
                dailyGoalCard
                    .padding(.horizontal, Theme.Spacing.l)

                // 3. Curriculum Cards (Alphabet & Words & Phrases)
                curriculumSection
                    .padding(.horizontal, Theme.Spacing.l)

                // 4. Practice & Review Fast Track Cards
                practiceAndReviewSection
                    .padding(.horizontal, Theme.Spacing.l)

                #if DEBUG
                // Developer Tools Section
                developerSection
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.top, Theme.Spacing.m)
                #endif

                Spacer(minLength: Theme.Spacing.xl)
            }
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .task {
            if viewModel == nil {
                let vm = LearnHubViewModel(
                    progressRepository: dependencies.progressRepository,
                    signCatalogService: dependencies.signCatalogService,
                    userProfileRepository: dependencies.userProfileRepository,
                    authService: dependencies.authService
                )
                viewModel = vm
                await vm.load()
            } else {
                await viewModel?.load()
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel?.isQuizPresented ?? false },
            set: { viewModel?.isQuizPresented = $0 }
        )) {
            speedRunQuizSheet
        }
        .sheet(isPresented: Binding(
            get: { viewModel?.isMistakesPracticePresented ?? false },
            set: { viewModel?.isMistakesPracticePresented = $0 }
        )) {
            reviewMistakesSheet
        }
        .sheet(isPresented: $isShowingCameraPractice) {
            CameraTestView()
        }
        #if DEBUG
        .sheet(isPresented: $isShowingDatasetCapture) {
            DatasetCaptureView()
        }
        #endif
        .onChange(of: deepLinkRouter.activeDestination) { _, newDest in
            handleDestination(newDest)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            // App Logo Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.brandTurquoise.opacity(0.14))
                    .frame(width: 40, height: 40)

                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.brandTurquoise)
            }

            Text("Learn Hub")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)

            Spacer()

            // Streak Pill
            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.brandYellow)

                Text("\(viewModel?.currentStreak ?? 7)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.brandYellow.opacity(0.18), in: Capsule())
            .accessibilityLabel("Current streak: \(viewModel?.currentStreak ?? 7) days")

            // Profile Button
            ProfileAvatarButton {
                deepLinkRouter.openProfile()
            }
        }
    }

    // MARK: - Daily Mastery Goal Card

    private var dailyGoalCard: some View {
        let metrics = viewModel?.metrics ?? LearnHubMetrics()

        return HStack(spacing: 14) {
            // Sparkle Icon Circle
            ZStack {
                Circle()
                    .fill(Color.brandTurquoise.opacity(0.14))
                    .frame(width: 44, height: 44)

                Image(systemName: "sparkles")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.brandTurquoise)
            }

            // Goal Title & Subtitle
            VStack(alignment: .leading, spacing: 3) {
                Text("Daily Mastery Goal")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Text("\(metrics.dailyGoalVerified) of \(metrics.dailyGoalTarget) signs verified today")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            // Progress Dots
            HStack(spacing: 6) {
                ForEach(0..<metrics.dailyGoalTarget, id: \.self) { index in
                    Circle()
                        .fill(index < metrics.dailyGoalVerified ? Color.brandTurquoise : Color.gray.opacity(0.25))
                        .frame(width: 9, height: 9)
                }
            }
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Daily Mastery Goal: \(metrics.dailyGoalVerified) of \(metrics.dailyGoalTarget) signs verified today")
    }

    // MARK: - Curriculum Cards

    private var curriculumSection: some View {
        let metrics = viewModel?.metrics ?? LearnHubMetrics()

        return VStack(spacing: 14) {
            // 1. Alphabet Card
            NavigationLink {
                FingerspellingPathView()
            } label: {
                curriculumCard(
                    title: "Alphabet",
                    subtitle: "\(metrics.alphabetTotal) letters · \(metrics.alphabetMastered) mastered",
                    badge: "Fingerspelling",
                    percentDone: Int(metrics.alphabetProgress * 100),
                    progress: metrics.alphabetProgress,
                    imageName: "sign_a",
                    tagLabel: "ASL"
                )
            }
            .buttonStyle(.plain)

            // 2. Words & Phrases Card
            NavigationLink {
                WordsPhrasesCategoriesView()
            } label: {
                curriculumCard(
                    title: "Words & Phrases",
                    subtitle: "\(metrics.wordsCategoriesCount) categories · \(metrics.wordsLearned) words learned",
                    badge: "Conversational",
                    percentDone: Int(metrics.wordsProgress * 100),
                    progress: metrics.wordsProgress,
                    imageName: "sign_hello",
                    tagLabel: "CORE"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func curriculumCard(
        title: String,
        subtitle: String,
        badge: String,
        percentDone: Int,
        progress: Double,
        imageName: String,
        tagLabel: String
    ) -> some View {
        HStack(spacing: 14) {
            // Thumbnail Image with Tag Overlay
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let _ = UIImage(named: imageName) {
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.brandNavy.opacity(0.08)
                            .overlay(
                                Image(systemName: "hand.raised.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(Color.brandTurquoise)
                            )
                    }
                }
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Tag Label Overlay (e.g. "ASL" / "CORE")
                Text(tagLabel)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.brandNavy.opacity(0.85), in: RoundedRectangle(cornerRadius: 4))
                    .padding(5)
            }

            // Info Column
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.textPrimary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textSecondary.opacity(0.6))
                }

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)

                HStack(spacing: 8) {
                    Text(badge)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.brandTurquoise)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.brandTurquoise.opacity(0.12), in: Capsule())

                    Text("\(percentDone)% done")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.brandTurquoise)
                }
                .padding(.top, 2)
            }

            Spacer()

            // Circular Progress Ring
            ProgressRingView(
                progress: progress,
                ringSize: 52,
                strokeWidth: 5,
                ringColor: Color.brandTurquoise
            )
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
    }

    // MARK: - Practice & Review Fast Track

    private var practiceAndReviewSection: some View {
        let metrics = viewModel?.metrics ?? LearnHubMetrics()

        return VStack(alignment: .leading, spacing: 12) {
            // Section Title
            HStack {
                Text("Practice & Review")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Text("FAST TRACK")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Color.textSecondary)
            }

            // Two Fast-Track Cards
            HStack(spacing: 12) {
                // Card 1: Quiz Yourself
                Button {
                    triggerHaptic()
                    viewModel?.startSpeedRun()
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        // Lightning Icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.brandYellow.opacity(0.22))
                                .frame(width: 38, height: 38)

                            Image(systemName: "bolt.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.brandYellow)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quiz yourself")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.textPrimary)

                            Text("Test your recognition speed")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 12)

                        HStack(spacing: 4) {
                            Text("Start speed run")
                                .font(.system(size: 13, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(Color.brandTurquoise)
                    }
                    .padding(Theme.Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 170)
                    .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.gray.opacity(0.12), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Quiz yourself: Test your recognition speed. Start speed run.")

                // Card 2: Review Mistakes
                Button {
                    triggerHaptic()
                    viewModel?.startMistakesReview()
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        // Exclamation Mark Icon with Badge
                        ZStack(alignment: .topTrailing) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.danger.opacity(0.12))
                                .frame(width: 38, height: 38)

                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.danger)

                            // Count Badge Overlay
                            if metrics.mistakesCount > 0 {
                                Text("\(metrics.mistakesCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.white)
                                    .frame(width: 17, height: 17)
                                    .background(Color.danger, in: Circle())
                                    .offset(x: 5, y: -5)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Review mistakes")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.textPrimary)

                            Text("\(metrics.mistakesCount) signs to polish")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                        }

                        Spacer(minLength: 12)

                        HStack(spacing: 4) {
                            Text("Quick practice")
                                .font(.system(size: 13, weight: .bold))
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(Color.textPrimary)
                    }
                    .padding(Theme.Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 170)
                    .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.gray.opacity(0.12), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Review mistakes: \(metrics.mistakesCount) signs to polish. Quick practice.")
            }
        }
    }

    // MARK: - Developer Tools

    #if DEBUG
    private var developerSection: some View {
        VStack(spacing: 10) {
            Button {
                isShowingCameraPractice = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera.viewfinder")
                    Text("AI Practice Mirror (Step 5.3 Preview)")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Color.brandTurquoise)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.brandTurquoise.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Button {
                isShowingDatasetCapture = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera.badge.ellipsis")
                    Text("Dataset Capture Tool")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }
    #endif

    // MARK: - Sheets

    private var speedRunQuizSheet: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.l) {
                ZStack {
                    Circle()
                        .fill(Color.brandYellow.opacity(0.2))
                        .frame(width: 80, height: 80)

                    Image(systemName: "bolt.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(Color.brandYellow)
                }
                .padding(.top, Theme.Spacing.xl)

                VStack(spacing: 8) {
                    Text("Speed Run Quiz")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)

                    Text("Full interactive quizzes with gesture timer and scoring arrive in Step 5.4!")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.l)
                }

                Spacer()

                Button("Dismiss") {
                    viewModel?.isQuizPresented = false
                }
                .font(.headline)
                .foregroundStyle(Color.brandTurquoise)
                .padding(.bottom, Theme.Spacing.l)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        viewModel?.isQuizPresented = false
                    }
                }
            }
        }
    }

    private var reviewMistakesSheet: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.l) {
                ZStack {
                    Circle()
                        .fill(Color.danger.opacity(0.15))
                        .frame(width: 80, height: 80)

                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.danger)
                }
                .padding(.top, Theme.Spacing.xl)

                VStack(spacing: 8) {
                    Text("Review Mistakes")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)

                    Text("\(viewModel?.metrics.mistakesCount ?? 3) signs targeted for extra practice to build muscle memory.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.l)
                }

                // List of mistake signs
                VStack(spacing: 8) {
                    ForEach(viewModel?.mistakeSigns ?? []) { sign in
                        HStack {
                            Text(sign.name)
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Text(sign.category)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                        }
                        .padding()
                        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)

                Spacer()

                Button("Dismiss") {
                    viewModel?.isMistakesPracticePresented = false
                }
                .font(.headline)
                .foregroundStyle(Color.brandTurquoise)
                .padding(.bottom, Theme.Spacing.l)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        viewModel?.isMistakesPracticePresented = false
                    }
                }
            }
        }
    }

    // MARK: - Navigation & Deep Links

    private func handleDestination(_ destination: DeepLinkDestination?) {
        guard let destination else { return }

        switch destination {
        case .practice:
            isShowingCameraPractice = true
            deepLinkRouter.activeDestination = nil

        default:
            break
        }
    }

    private func triggerHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

#Preview("Learn Hub") {
    NavigationStack {
        LearnRootView(deepLinkRouter: DeepLinkRouter())
            .environment(\.dependencies, .preview)
    }
}
