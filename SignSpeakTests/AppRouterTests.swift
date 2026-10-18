import Foundation
import Testing
@testable import SignSpeak

@Suite("AppRouter Navigation & Auth State Evaluation")
@MainActor
struct AppRouterTests {

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "test-app-router-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test("Unauthenticated user resolves to Welcome screen")
    func unauthenticatedUserResolvesToWelcome() async {
        let auth = MockAuthService(currentUserId: nil)
        let profileRepo = StubUserProfileRepository()
        let biometric = MockBiometricAuthService()
        let defaults = makeIsolatedDefaults()

        let router = AppRouter(
            authService: auth,
            userProfileRepository: profileRepo,
            biometricAuthService: biometric,
            dateProvider: SystemDateProvider(),
            userDefaults: defaults
        )

        #expect(router.currentRoute == .splash)
        await router.resolveInitialRoute(minimumSplashDuration: 0)
        #expect(router.currentRoute == .welcome)
    }

    @Test("New user with incomplete onboarding resolves to Onboarding screen")
    func newUserWithIncompleteOnboardingResolvesToOnboarding() async {
        let auth = MockAuthService(currentUserId: "new-user-1")
        let profile = UserProfile(id: "new-user-1", displayName: "Taylor", onboardingComplete: false)
        let profileRepo = StubUserProfileRepository(initialProfiles: [profile])
        let biometric = MockBiometricAuthService()
        let defaults = makeIsolatedDefaults()

        let router = AppRouter(
            authService: auth,
            userProfileRepository: profileRepo,
            biometricAuthService: biometric,
            userDefaults: defaults
        )

        await router.resolveInitialRoute(minimumSplashDuration: 0)
        #expect(router.currentRoute == .onboarding)
    }

    @Test("User with completed onboarding resolves directly to Main App")
    func existingUserWithCompletedOnboardingResolvesToMainApp() async {
        let auth = MockAuthService(currentUserId: "existing-user-1")
        let profile = UserProfile(id: "existing-user-1", displayName: "Alex", onboardingComplete: true)
        let profileRepo = StubUserProfileRepository(initialProfiles: [profile])
        let biometric = MockBiometricAuthService()
        let defaults = makeIsolatedDefaults()

        let router = AppRouter(
            authService: auth,
            userProfileRepository: profileRepo,
            biometricAuthService: biometric,
            userDefaults: defaults
        )

        await router.resolveInitialRoute(minimumSplashDuration: 0)
        #expect(router.currentRoute == .mainApp)
    }

    @Test("Biometric lock enabled blocks main app until Face ID unlock")
    func biometricLockEnabledRequiresAuthentication() async {
        let auth = MockAuthService(currentUserId: "secure-user-1")
        let profile = UserProfile(id: "secure-user-1", displayName: "Jordan", onboardingComplete: true)
        let profileRepo = StubUserProfileRepository(initialProfiles: [profile])
        let biometric = MockBiometricAuthService(isBiometricAvailable: true, authenticationResult: true)
        let defaults = makeIsolatedDefaults()
        defaults.set(true, forKey: "isFaceIDLockEnabled")

        let router = AppRouter(
            authService: auth,
            userProfileRepository: profileRepo,
            biometricAuthService: biometric,
            userDefaults: defaults
        )

        await router.resolveInitialRoute(minimumSplashDuration: 0)
        #expect(router.currentRoute == .faceIDLock)
        #expect(!router.isBiometricAuthenticated)

        // Attempt successful unlock
        let unlocked = await router.unlockWithBiometrics()
        #expect(unlocked)
        #expect(router.isBiometricAuthenticated)
        #expect(router.currentRoute == .mainApp)
    }

    @Test("Failed biometric unlock keeps Face ID lock active")
    func failedBiometricUnlockRetainsLock() async {
        let auth = MockAuthService(currentUserId: "secure-user-2")
        let profile = UserProfile(id: "secure-user-2", displayName: "Sam", onboardingComplete: true)
        let profileRepo = StubUserProfileRepository(initialProfiles: [profile])
        let biometric = MockBiometricAuthService(isBiometricAvailable: true, authenticationResult: false)
        let defaults = makeIsolatedDefaults()
        defaults.set(true, forKey: "isFaceIDLockEnabled")

        let router = AppRouter(
            authService: auth,
            userProfileRepository: profileRepo,
            biometricAuthService: biometric,
            userDefaults: defaults
        )

        await router.resolveInitialRoute(minimumSplashDuration: 0)
        #expect(router.currentRoute == .faceIDLock)

        let unlocked = await router.unlockWithBiometrics()
        #expect(!unlocked)
        #expect(!router.isBiometricAuthenticated)
        #expect(router.currentRoute == .faceIDLock)
    }

    @Test("Completing onboarding updates repository and transitions to Main App")
    func completeOnboardingUpdatesProfile() async throws {
        let auth = MockAuthService(currentUserId: "learner-100")
        let profile = UserProfile(id: "learner-100", displayName: "Morgan", onboardingComplete: false)
        let profileRepo = StubUserProfileRepository(initialProfiles: [profile])
        let biometric = MockBiometricAuthService()
        let defaults = makeIsolatedDefaults()

        let router = AppRouter(
            authService: auth,
            userProfileRepository: profileRepo,
            biometricAuthService: biometric,
            userDefaults: defaults
        )

        await router.resolveInitialRoute(minimumSplashDuration: 0)
        #expect(router.currentRoute == .onboarding)

        await router.completeOnboarding()
        #expect(router.currentRoute == .mainApp)

        let updated = try await profileRepo.fetchProfile(userId: "learner-100")
        #expect(updated?.onboardingComplete == true)
    }

    @Test("Guest sign-in logs in anonymously and transitions route")
    func continueAsGuestFlow() async {
        let auth = MockAuthService(currentUserId: nil)
        let profileRepo = StubUserProfileRepository()
        let biometric = MockBiometricAuthService()
        let defaults = makeIsolatedDefaults()

        let router = AppRouter(
            authService: auth,
            userProfileRepository: profileRepo,
            biometricAuthService: biometric,
            userDefaults: defaults
        )

        await router.resolveInitialRoute(minimumSplashDuration: 0)
        #expect(router.currentRoute == .welcome)

        await router.continueAsGuest()
        #expect(auth.currentUserId == "mock-guest-user")
        #expect(router.currentRoute == .onboarding)
    }

    @Test("Sign out resets biometric session and navigates to Welcome")
    func signOutResetsState() async {
        let auth = MockAuthService(currentUserId: "active-user")
        let profile = UserProfile(id: "active-user", displayName: "Casey", onboardingComplete: true)
        let profileRepo = StubUserProfileRepository(initialProfiles: [profile])
        let biometric = MockBiometricAuthService()
        let defaults = makeIsolatedDefaults()

        let router = AppRouter(
            authService: auth,
            userProfileRepository: profileRepo,
            biometricAuthService: biometric,
            userDefaults: defaults
        )

        await router.resolveInitialRoute(minimumSplashDuration: 0)
        #expect(router.currentRoute == .mainApp)
        router.isBiometricAuthenticated = true

        router.signOut()
        #expect(!router.isBiometricAuthenticated)
        #expect(router.currentRoute == .welcome)
        #expect(auth.currentUserId == nil)
    }
}
