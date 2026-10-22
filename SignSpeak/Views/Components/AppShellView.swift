import SwiftUI

/// Adaptive application shell switching between TabView on iPhone (compact)
/// and NavigationSplitView on iPad (regular width) per Apple HIG and Step 3.2.
public struct AppShellView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var deepLinkRouter: DeepLinkRouter

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
            ProfileSheetView()
        }
        .onOpenURL { url in
            deepLinkRouter.handle(url: url)
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
            List(AppTab.allCases, selection: Binding(
                get: { deepLinkRouter.selectedTab },
                set: { if let tab = $0 { deepLinkRouter.selectedTab = tab } }
            )) { tab in
                Label(tab.title, systemImage: tab.iconName)
                    .tag(tab)
                    .foregroundStyle(deepLinkRouter.selectedTab == tab ? Color.brandTurquoise : Color.textPrimary)
            }
            .navigationTitle("SignSpeak")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileAvatarButton {
                        deepLinkRouter.openProfile()
                    }
                }
            }
        } detail: {
            detailContent(for: deepLinkRouter.selectedTab)
        }
    }

    @ViewBuilder
    private func detailContent(for tab: AppTab) -> some View {
        switch tab {
        case .home:
            NavigationStack {
                HomeRootView(deepLinkRouter: deepLinkRouter)
            }
        case .learn:
            NavigationStack {
                LearnRootView(deepLinkRouter: deepLinkRouter)
            }
        case .talk:
            NavigationStack {
                TalkRootView(deepLinkRouter: deepLinkRouter)
            }
        case .signs:
            NavigationStack {
                SignsRootView(deepLinkRouter: deepLinkRouter)
            }
        case .settings:
            NavigationStack {
                SettingsRootView(deepLinkRouter: deepLinkRouter)
            }
        }
    }
}

#Preview("iPhone Shell") {
    AppShellView()
        .environment(\.dependencies, .preview)
        .environment(
            AppRouter(
                authService: StubAuthService(initialUserId: "user-1"),
                userProfileRepository: StubUserProfileRepository(),
                biometricAuthService: StubBiometricAuthService()
            )
        )
}
