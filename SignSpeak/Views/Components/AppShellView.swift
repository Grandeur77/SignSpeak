import SwiftUI

/// Structured sidebar navigation destinations for iPad regular width layout.
public enum iPadSidebarDestination: String, CaseIterable, Identifiable, Hashable, Sendable {
    // Main
    case home
    case talk

    // Curriculum
    case learn
    case signs

    // Awareness & Community
    case community
    case soundAlerts
    case inbox

    // Preferences
    case settings
    case profile

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .home: return "Home"
        case .talk: return "Communicator"
        case .learn: return "Learn"
        case .signs: return "Signs Directory"
        case .community: return "Community"
        case .soundAlerts: return "Sound Alerts"
        case .inbox: return "Notifications"
        case .settings: return "Settings"
        case .profile: return "My Profile"
        }
    }

    public var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .talk: return "bubble.left.and.bubble.right.fill"
        case .learn: return "sparkles"
        case .signs: return "book.closed.fill"
        case .community: return "person.3.fill"
        case .soundAlerts: return "waveform.badge.magnifyingglass"
        case .inbox: return "bell.fill"
        case .settings: return "gearshape.fill"
        case .profile: return "person.crop.circle"
        }
    }
}

/// Adaptive application shell switching between TabView on iPhone (compact)
/// and NavigationSplitView with categorized sidebar and badges on iPad (regular width)
/// per Apple HIG and Phase 14 specifications.
public struct AppShellView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var deepLinkRouter: DeepLinkRouter
    @State private var sidebarSelection: iPadSidebarDestination? = .home
    @State private var userProfile: UserProfile?
    @State private var unreadNotificationCount: Int = 0

    @MainActor
    public init(deepLinkRouter: DeepLinkRouter? = nil) {
        self._deepLinkRouter = State(initialValue: deepLinkRouter ?? DeepLinkRouter())
    }

    public var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                ipadSplitShell
            } else {
                iphoneTabShell
            }
        }
        .environment(deepLinkRouter)
        .sheet(isPresented: $deepLinkRouter.isPresentingProfile) {
            ProfileView()
        }
        .onOpenURL { url in
            deepLinkRouter.handle(url: url)
        }
        .background {
            keyboardShortcutsBackground
        }
        .task {
            let uid = dependencies.authService.currentUserId ?? "guest"
            userProfile = try? await dependencies.userProfileRepository.fetchProfile(userId: uid)
            unreadNotificationCount = (try? await dependencies.inboxRepository.unreadCount(userId: uid)) ?? 0
        }
        .onChange(of: deepLinkRouter.selectedTab) { _, newTab in
            syncSidebarWithTab(newTab)
        }
        .onChange(of: sidebarSelection) { _, newSelection in
            if let newSelection {
                selectDestination(newSelection)
            }
        }
        .onChange(of: deepLinkRouter.activeDestination) { _, newDest in
            handleDeepLinkDestination(newDest)
        }
    }

    // MARK: - iPhone Compact Shell (TabView)

    private var iphoneTabShell: some View {
        TabView(selection: $deepLinkRouter.selectedTab) {
            NavigationStack {
                HomeRootView(deepLinkRouter: deepLinkRouter)
            }
            .tabItem {
                Label(AppTab.home.title, systemImage: AppTab.home.iconName)
            }
            .tag(AppTab.home)

            NavigationStack {
                LearnRootView(deepLinkRouter: deepLinkRouter)
            }
            .tabItem {
                Label(AppTab.learn.title, systemImage: AppTab.learn.iconName)
            }
            .tag(AppTab.learn)

            NavigationStack {
                TalkRootView(deepLinkRouter: deepLinkRouter)
            }
            .tabItem {
                Label(AppTab.talk.title, systemImage: AppTab.talk.iconName)
            }
            .tag(AppTab.talk)

            NavigationStack {
                SignsRootView(deepLinkRouter: deepLinkRouter)
            }
            .tabItem {
                Label(AppTab.signs.title, systemImage: AppTab.signs.iconName)
            }
            .tag(AppTab.signs)

            NavigationStack {
                SettingsRootView(deepLinkRouter: deepLinkRouter)
            }
            .tabItem {
                Label(AppTab.settings.title, systemImage: AppTab.settings.iconName)
            }
            .tag(AppTab.settings)
        }
        .tint(Color.brandTurquoise)
    }

    // MARK: - iPad Regular Shell (NavigationSplitView Sidebar)

    private var ipadSplitShell: some View {
        NavigationSplitView {
            List(selection: $sidebarSelection) {
                // Section 0: User Profile Header
                userProfileHeaderSection

                // Section 1: Main
                Section("Main") {
                    sidebarRow(
                        destination: .home,
                        badgeText: "🔥 \(userProfile?.currentStreak ?? 7)d",
                        badgeColor: Color.brandYellow
                    )

                    sidebarRow(
                        destination: .talk,
                        badgeText: "Live",
                        badgeColor: Color.brandTurquoise
                    )
                }

                // Section 2: Curriculum
                Section("Curriculum") {
                    sidebarRow(
                        destination: .learn,
                        badgeText: "\(userProfile?.dailyGoalMinutes ?? 10)m goal",
                        badgeColor: Color.brandTurquoise.opacity(0.8)
                    )

                    sidebarRow(
                        destination: .signs,
                        badgeText: "500+ Signs",
                        badgeColor: Color.gray.opacity(0.4)
                    )
                }

                // Section 3: Awareness & Community
                Section("Awareness & Community") {
                    sidebarRow(
                        destination: .community,
                        badgeText: "Feed",
                        badgeColor: Color.brandTurquoise
                    )

                    sidebarRow(
                        destination: .soundAlerts,
                        badgeText: (userProfile?.soundAlertsEnabled ?? true) ? "Active" : "Off",
                        badgeColor: (userProfile?.soundAlertsEnabled ?? true) ? Color.brandTurquoise : Color.gray
                    )

                    sidebarRow(
                        destination: .inbox,
                        badgeText: unreadNotificationCount > 0 ? "\(unreadNotificationCount) new" : nil,
                        badgeColor: Color.brandYellow
                    )
                }

                // Section 4: Preferences
                Section("Preferences") {
                    sidebarRow(
                        destination: .settings,
                        badgeText: nil,
                        badgeColor: .clear
                    )

                    sidebarRow(
                        destination: .profile,
                        badgeText: nil,
                        badgeColor: .clear
                    )
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("SignSpeak")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileAvatarButton {
                        deepLinkRouter.openProfile()
                    }
                    .hoverEffect(.highlight)
                }
            }
        } detail: {
            detailContent(for: sidebarSelection ?? .home)
        }
    }

    // MARK: - User Profile Header

    private var userProfileHeaderSection: some View {
        Button {
            deepLinkRouter.openProfile()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.brandTurquoise, Color.brandNavy],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Text(userProfile?.displayName.prefix(1).uppercased() ?? "M")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(userProfile?.displayName ?? "Learner")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.textPrimary)

                    HStack(spacing: 6) {
                        Text(userProfile?.role == "deaf" ? "Deaf Role" : "ASL Learner")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.textSecondary)

                        Circle()
                            .fill(Color.brandTurquoise)
                            .frame(width: 4, height: 4)

                        Text("Level \(max(1, (userProfile?.xp ?? 420) / 100))")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.brandTurquoise)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
    }

    // MARK: - Sidebar Row Helper

    private func sidebarRow(
        destination: iPadSidebarDestination,
        badgeText: String?,
        badgeColor: Color
    ) -> some View {
        Button {
            selectDestination(destination)
        } label: {
            HStack {
                Label(destination.title, systemImage: destination.iconName)
                    .font(.system(size: 15, weight: sidebarSelection == destination ? .bold : .medium))
                    .foregroundStyle(sidebarSelection == destination ? Color.brandTurquoise : Color.textPrimary)

                Spacer()

                if let badgeText {
                    Text(badgeText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(badgeColor, in: Capsule())
                }
            }
            .contentShape(Rectangle())
        }
        .tag(destination)
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
    }

    // MARK: - Detail Content Router

    @ViewBuilder
    private func detailContent(for destination: iPadSidebarDestination) -> some View {
        switch destination {
        case .home:
            NavigationStack {
                HomeRootView(deepLinkRouter: deepLinkRouter)
            }
        case .talk:
            NavigationStack {
                TalkRootView(deepLinkRouter: deepLinkRouter)
            }
        case .learn:
            NavigationStack {
                LearnRootView(deepLinkRouter: deepLinkRouter)
            }
        case .signs:
            NavigationStack {
                SignsRootView(deepLinkRouter: deepLinkRouter)
            }
        case .community:
            NavigationStack {
                CommunityFeedView()
            }
        case .soundAlerts:
            NavigationStack {
                SoundAlertsHomeView()
            }
        case .inbox:
            NavigationStack {
                NotificationsInboxView()
            }
        case .settings:
            NavigationStack {
                SettingsRootView(deepLinkRouter: deepLinkRouter)
            }
        case .profile:
            NavigationStack {
                ProfileView()
            }
        }
    }

    // MARK: - Keyboard Shortcuts (iPad Step 14.1)

    private var keyboardShortcutsBackground: some View {
        Group {
            Button("Home") { selectDestination(.home) }
                .keyboardShortcut("1", modifiers: .command)
            Button("Learn") { selectDestination(.learn) }
                .keyboardShortcut("2", modifiers: .command)
            Button("Talk") { selectDestination(.talk) }
                .keyboardShortcut("3", modifiers: .command)
            Button("Communicator") { selectDestination(.talk) }
                .keyboardShortcut("k", modifiers: .command)
            Button("Signs") { selectDestination(.signs) }
                .keyboardShortcut("4", modifiers: .command)
            Button("Search Signs") { selectDestination(.signs) }
                .keyboardShortcut("f", modifiers: .command)
            Button("Community") { selectDestination(.community) }
                .keyboardShortcut("5", modifiers: .command)
            Button("Sound Alerts") { selectDestination(.soundAlerts) }
                .keyboardShortcut("6", modifiers: .command)
            Button("Inbox") { selectDestination(.inbox) }
                .keyboardShortcut("7", modifiers: .command)
            Button("Settings") { selectDestination(.settings) }
                .keyboardShortcut("8", modifiers: .command)
            Button("Settings Shortcut") { selectDestination(.settings) }
                .keyboardShortcut(",", modifiers: .command)
            Button("Profile") { selectDestination(.profile) }
                .keyboardShortcut("p", modifiers: .command)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }

    private func selectDestination(_ destination: iPadSidebarDestination) {
        sidebarSelection = destination
        switch destination {
        case .home: deepLinkRouter.selectedTab = .home
        case .talk: deepLinkRouter.selectedTab = .talk
        case .learn: deepLinkRouter.selectedTab = .learn
        case .signs: deepLinkRouter.selectedTab = .signs
        case .settings: deepLinkRouter.selectedTab = .settings
        case .profile: deepLinkRouter.openProfile()
        default: break
        }
    }

    private func syncSidebarWithTab(_ tab: AppTab) {
        switch tab {
        case .home: sidebarSelection = .home
        case .learn: sidebarSelection = .learn
        case .talk: sidebarSelection = .talk
        case .signs: sidebarSelection = .signs
        case .settings: sidebarSelection = .settings
        }
    }

    private func handleDeepLinkDestination(_ dest: DeepLinkDestination?) {
        guard let dest else { return }
        switch dest {
        case .tab(let tab):
            syncSidebarWithTab(tab)
        case .communicator, .speakPhrase:
            sidebarSelection = .talk
        case .practice:
            sidebarSelection = .learn
        case .signDetail, .signsSearch:
            sidebarSelection = .signs
        case .soundAlerts:
            sidebarSelection = .soundAlerts
        case .inbox:
            sidebarSelection = .inbox
        case .community:
            sidebarSelection = .community
        case .profile:
            sidebarSelection = .profile
        }
    }
}
