import SwiftUI

/// Features the greeting hero, streak banner, daily practice sign, two-way communicator quick launch,
/// and learning journey categories.
public struct HomeRootView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Bindable var deepLinkRouter: DeepLinkRouter

    @State private var isShowingInbox = false
    @State private var isShowingCommunity = false
    @State private var isShowingSoundAlerts = false
    @State private var unreadNotificationCount = 0
    @State private var userProfile: UserProfile?
    @State private var isLearningJourneyExpanded: Bool = true
    @State private var isCommunityExpanded: Bool = true

    public init(deepLinkRouter: DeepLinkRouter) {
        self.deepLinkRouter = deepLinkRouter
    }

    private var isDeafRole: Bool {
        userProfile?.role == "deaf"
    }

    private var greetingByTimeOfDay: String {
        let hour = Calendar.current.component(.hour, from: dependencies.dateProvider.now)
        if hour >= 5 && hour < 12 {
            return "Good morning"
        } else if hour >= 12 && hour < 17 {
            return "Good afternoon"
        } else {
            return "Good evening"
        }
    }

    public var body: some View {
        ScrollView {
            if horizontalSizeClass == .regular {
                ipadDashboardContent
                    .padding(.bottom, Theme.Spacing.xl)
            } else {
                iphoneDashboardContent
                    .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .task {
            let userId = dependencies.authService.currentUserId ?? "guest"
            userProfile = try? await dependencies.userProfileRepository.fetchProfile(userId: userId)
            unreadNotificationCount = (try? await dependencies.inboxRepository.unreadCount(userId: userId)) ?? 0
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationDestination(isPresented: $isShowingInbox) {
            NotificationsInboxView()
        }
        .navigationDestination(isPresented: $isShowingCommunity) {
            CommunityFeedView()
        }
        .navigationDestination(isPresented: $isShowingSoundAlerts) {
            SoundAlertsHomeView()
        }
        .onChange(of: deepLinkRouter.activeDestination) { _, newDest in
            if newDest == .communicator {
                deepLinkRouter.selectedTab = .talk
                deepLinkRouter.activeDestination = .communicator
            } else if case .practice = newDest {
                deepLinkRouter.selectedTab = .learn
                deepLinkRouter.activeDestination = newDest
            } else if newDest == .inbox {
                isShowingInbox = true
                deepLinkRouter.activeDestination = nil
            } else if newDest == .community {
                isShowingCommunity = true
                deepLinkRouter.activeDestination = nil
            } else if newDest == .soundAlerts {
                isShowingSoundAlerts = true
                deepLinkRouter.activeDestination = nil
            }
        }
    }

    // MARK: - iPhone Dashboard Content (Linear Stack)
    private var iphoneDashboardContent: some View {
        VStack(spacing: Theme.Spacing.l) {
            headerBar
            greetingSection

            NavigationLink {
                StreakAndChallengesView()
            } label: {
                streakHeroCard
            }
            .buttonStyle(.plain)
            .hoverEffect(.lift)

            NavigationLink {
                AnalyticsView()
            } label: {
                HStack(spacing: 10) {
                    quickStatPill(icon: "flame.fill", iconColor: Color.brandYellow, value: "\(userProfile?.currentStreak ?? 7)", label: "DAYS STREAK")
                    quickStatPill(icon: "star.fill", iconColor: Color.brandYellow, value: "\(userProfile?.xp ?? 420)", label: "TOTAL XP")
                    quickStatPill(icon: "clock.fill", iconColor: Color.brandTurquoise, value: "\(userProfile?.dailyGoalMinutes ?? 10)m", label: "DAILY GOAL")
                }
            }
            .buttonStyle(.plain)
            .hoverEffect(.lift)
            .padding(.horizontal, Theme.Spacing.l)

            if isDeafRole {
                if userProfile?.soundAlertsEnabled ?? true {
                    soundAlertsPill
                        .hoverEffect(.lift)
                }

                communicatorCard
                    .hoverEffect(.lift)
                dailySignCard
                    .hoverEffect(.lift)
                communityHighlightsSection
                    .hoverEffect(.lift)
                learningJourneySection
            } else {
                dailySignCard
                    .hoverEffect(.lift)
                learningJourneySection
                communicatorCard
                    .hoverEffect(.lift)
                communityHighlightsSection
                    .hoverEffect(.lift)

                if userProfile?.soundAlertsEnabled == true {
                    soundAlertsPill
                        .hoverEffect(.lift)
                }
            }
        }
    }

    // MARK: - iPad Dashboard Content (Adaptive Multi-Column Grid)
    private var ipadDashboardContent: some View {
        VStack(spacing: Theme.Spacing.l) {
            headerBar
            greetingSection

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 20),
                    GridItem(.flexible(), spacing: 20)
                ],
                spacing: 20
            ) {
                // Left Column
                VStack(spacing: 20) {
                    NavigationLink {
                        StreakAndChallengesView()
                    } label: {
                        streakHeroCard
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.lift)

                    NavigationLink {
                        AnalyticsView()
                    } label: {
                        HStack(spacing: 10) {
                            quickStatPill(icon: "flame.fill", iconColor: Color.brandYellow, value: "\(userProfile?.currentStreak ?? 7)", label: "DAYS STREAK")
                            quickStatPill(icon: "star.fill", iconColor: Color.brandYellow, value: "\(userProfile?.xp ?? 420)", label: "TOTAL XP")
                            quickStatPill(icon: "clock.fill", iconColor: Color.brandTurquoise, value: "\(userProfile?.dailyGoalMinutes ?? 10)m", label: "DAILY GOAL")
                        }
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.lift)

                    dailySignCard
                        .hoverEffect(.lift)
                }

                // Right Column
                VStack(spacing: 20) {
                    if userProfile?.soundAlertsEnabled ?? true {
                        soundAlertsPill
                            .hoverEffect(.lift)
                    }

                    communicatorCard
                        .hoverEffect(.lift)

                    communityHighlightsSection
                        .hoverEffect(.lift)
                }
            }
            .padding(.horizontal, Theme.Spacing.l)

            learningJourneySection
                .padding(.horizontal, Theme.Spacing.l)
        }
    }

    // MARK: - Greeting Section
    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("\(greetingByTimeOfDay), \(userProfile?.displayName ?? "Learner")")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)

                Text("👋")
                    .font(.system(size: 26))

                Circle()
                    .fill(Color.brandTurquoise)
                    .frame(width: 8, height: 8)
            }

            Text("Ready for today's \(userProfile?.dailyGoalMinutes ?? 10)-minute sign practice?")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.l)
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack {
            // Logo & Brand Name
            HStack(spacing: 8) {
                AppLogoArtwork()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 0) {
                    Text("SignSpeak")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)

                    Text("Home")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.brandTurquoise)
                }
            }

            Spacer()

            // Streak Flame Counter
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.brandYellow)
                Text("7")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.brandYellow.opacity(0.18), in: Capsule())

            // Notification Bell Button with Badge
            NavigationLink {
                NotificationsInboxView()
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.textPrimary)
                        .frame(width: 34, height: 34)
                        .background(Color.cardBackground, in: Circle())

                    if unreadNotificationCount > 0 {
                        Circle()
                            .fill(Color.brandTurquoise)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().stroke(Color.appBackground, lineWidth: 1.5))
                            .offset(x: 1, y: -1)
                    }
                }
            }
            .buttonStyle(.plain)

            // User Avatar Button
            ProfileAvatarButton {
                deepLinkRouter.openProfile()
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.s)
    }

    // MARK: - Streak Card
    private var streakHeroCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 16/255, green: 40/255, blue: 74/255),
                            Color(red: 10/255, green: 26/255, blue: 50/255)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: Theme.Spacing.m) {
                HStack(alignment: .top) {
                    HStack(spacing: 12) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(Color.brandYellow)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1), in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("7-Day Streak!")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)

                            Text("You're on fire! Keep it up today.")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    }

                    Spacer()

                    Text("Top 5%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.brandTurquoise)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.brandTurquoise.opacity(0.18), in: Capsule())
                }

                // Days of week progress dots
                HStack {
                    ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                        VStack(spacing: 6) {
                            Text(day)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.6))

                            Circle()
                                .fill(Color.brandYellow)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.brandNavy)
                                )
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(Theme.Spacing.m)
        }
        .padding(.horizontal, Theme.Spacing.l)
    }

    private func quickStatPill(icon: String, iconColor: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(iconColor)
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
            }
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.textSecondary)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - Sound Alerts Status Pill
    private var soundAlertsPill: some View {
        Button {
            isShowingSoundAlerts = true
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.brandTurquoise.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "waveform")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.brandTurquoise)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sound Alerts • Listening")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)

                    Text("Tap to view active ambient alerts")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, 10)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, Theme.Spacing.l)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Daily Sign Card
    private var dailySignCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                Text("DAILY SIGN • ASL")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.brandTurquoise.opacity(0.2), in: Capsule())

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color.brandYellow)
                    Text("+25 XP")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Thank You")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)

                Text("Polite Expressions • 1 min")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
            }

            // Practice Now Button
            NavigationLink {
                CameraTestView()
            } label: {
                HStack(spacing: 8) {
                    Spacer()
                    Text("Practice Now")
                        .font(.system(size: 16, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                }
                .foregroundStyle(Color.onPrimary)
                .frame(height: 48)
                .background(Color.primaryFill, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.m)
        .background(
            LinearGradient(
                colors: [Color.brandTurquoise.opacity(0.12), Color.cardBackground],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: Theme.Radius.card)
        )
        .padding(.horizontal, Theme.Spacing.l)
    }

    // MARK: - Communicator Card
    private var communicatorCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.brandTurquoise)
                    .frame(width: 6, height: 6)
                Text("REAL-TIME ASSISTANT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.brandTurquoise)
                    .tracking(0.8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Two-Way Communicator")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                Text("Sign directly to iPhone camera for spoken audio transcription, or listen to transcribe voice to text instantly.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.8))
            }

            NavigationLink {
                CommunicatorLiveView(
                    mode: .faceToFaceSplit,
                    dominantHand: userProfile?.dominantHand == "left" ? .left : .right
                )
            } label: {
                HStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "person.wave.2.fill")
                    Text("Launch Communicator ✋")
                        .font(.system(size: 15, weight: .bold))
                    Spacer()
                }
                .foregroundStyle(Color(red: 11/255, green: 42/255, blue: 74/255))
                .frame(height: 48)
                .background(Color.brandYellow, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.m)
        .background(
            Color(red: 10/255, green: 52/255, blue: 70/255),
            in: RoundedRectangle(cornerRadius: Theme.Radius.card)
        )
        .padding(.horizontal, Theme.Spacing.l)
    }

    // MARK: - Learning Journey
    private var learningJourneySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "safari.fill")
                        .foregroundStyle(Color.brandTurquoise)
                    Text("Your Learning Journey")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                }

                Spacer()

                Button("See All →") {
                    deepLinkRouter.selectedTab = .learn
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.brandTurquoise)
            }

            // Chapter 1: Alphabet
            chapterRow(
                title: "ASL Alphabet Essentials",
                subtitle: "26 letters mastered • Foundation",
                progress: 1.0,
                badge: "100%"
            )

            // Chapter 2: Greetings
            chapterRow(
                title: "Everyday Greetings & Needs",
                subtitle: "13 of 20 signs practiced • Level 1",
                progress: 0.65,
                badge: "65%"
            )
        }
        .padding(.horizontal, Theme.Spacing.l)
    }

    private func chapterRow(title: String, subtitle: String, progress: Double, badge: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                Text(badge)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.brandTurquoise)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.brandTurquoise.opacity(0.12), in: Capsule())
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)

                    Capsule()
                        .fill(Color.brandTurquoise)
                        .frame(width: proxy.size.width * CGFloat(progress), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    // MARK: - Community Highlights Section
    private var communityHighlightsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "person.3.fill")
                        .foregroundStyle(Color.brandTurquoise)
                    Text("Community Highlights")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                }

                Spacer()

                Button {
                    withAnimation {
                        isCommunityExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isCommunityExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.textSecondary)
                }
            }

            if isCommunityExpanded {
                VStack(spacing: 10) {
                    // Highlight 1: Demonstration Clip
                    Button {
                        deepLinkRouter.activeDestination = .community
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.brandTurquoise.opacity(0.18))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.brandTurquoise)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Maya demonstrated 'Coffee' ☕️")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)
                                Text("34 reactions • Polite & Everyday ASL")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.textSecondary)
                            }

                            Spacer()

                            Text("Watch →")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.brandTurquoise)
                        }
                        .padding(Theme.Spacing.m)
                        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    // Highlight 2: Community Sign of the Day
                    communitySignOfTheDayCard
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
    }

    // MARK: - Community Sign of the Day
    private var communitySignOfTheDayCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("COMMUNITY SIGN OF THE DAY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.brandYellow)
                    .tracking(0.8)

                Spacer()

                Text("12 Clips")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.textSecondary)
            }

            Text("Connect 🤝")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            Text("Join learners sharing video variations for 'Connect'. Tap to view community submissions or submit your sign clip.")
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)

            Button("View Community Clip Wall →") {
                deepLinkRouter.activeDestination = .community
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color.brandTurquoise)
            .padding(.top, 2)
        }
        .padding(Theme.Spacing.m)
        .background(
            Color.brandTurquoise.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 12)
        )
    }
}

#Preview("Home Root View") {
    NavigationStack {
        HomeRootView(deepLinkRouter: DeepLinkRouter())
            .environment(\.dependencies, .preview)
    }
}
