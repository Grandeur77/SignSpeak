import SwiftUI

/// Root visual container of the application.
/// Dynamically switches between the Launch Splash, Welcome/Auth, Onboarding, Face ID Lock,
/// and the Main App Shell as decided by the central `AppRouter`.
public struct AppRootView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var router: AppRouter?

    public init() {}

    public var body: some View {
        Group {
            if let router {
                rootContent(for: router)
                    .environment(router)
            } else {
                SplashView()
            }
        }
        .task {
            if router == nil {
                let newRouter = AppRouter(
                    authService: dependencies.authService,
                    userProfileRepository: dependencies.userProfileRepository,
                    biometricAuthService: dependencies.biometricAuthService,
                    credentialVault: dependencies.credentialVault,
                    dateProvider: dependencies.dateProvider
                )
                router = newRouter
                await newRouter.resolveInitialRoute()
            }
        }
    }

    @ViewBuilder
    private func rootContent(for router: AppRouter) -> some View {
        ZStack {
            switch router.currentRoute {
            case .splash:
                SplashView()
                    .transition(.opacity)

            case .welcome:
                AuthContainerView(
                    viewModel: AuthViewModel(
                        authService: dependencies.authService,
                        biometricAuthService: dependencies.biometricAuthService,
                        credentialVault: dependencies.credentialVault
                    )
                )
                .transition(.asymmetric(insertion: .opacity, removal: .opacity))

            case .onboarding:
                OnboardingIntroView(router: router)
                    .transition(.move(edge: .trailing).combined(with: .opacity))

            case .faceIDLock:
                FaceIDLockView(router: router)
                    .transition(.opacity)

            case .mainApp:
                AppShellView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: router.currentRoute)
    }
}

#Preview("AppRootView - Signed Out") {
    AppRootView()
        .environment(\.dependencies, .preview)
}
