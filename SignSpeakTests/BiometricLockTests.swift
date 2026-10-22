import Foundation
import Testing
@testable import SignSpeak

/// Controllable clock for lock timing tests.
final class TestClock: DateProviding, @unchecked Sendable {
    var now: Date
    var calendar: Calendar

    init(now: Date = Date(timeIntervalSince1970: 1_000_000), calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar
    }

    func advance(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}

@Suite("Biometric App Lock & Security (Step 3.10)")
@MainActor
struct BiometricLockTests {

    private func makeSUT(
        isLockEnabled: Bool = true,
        timeout: BiometricLockTimeout = .immediately,
        initialRoute: AppRoute = .mainApp,
        biometricAvailable: Bool = true,
        biometricType: BiometricType = .faceID
    ) -> (router: AppRouter, clock: TestClock, biometricService: MockBiometricAuthService, userDefaults: UserDefaults) {
        let clock = TestClock(now: Date(timeIntervalSince1970: 1_000_000))
        let userDefaults = UserDefaults(suiteName: "BiometricLockTests_\(UUID().uuidString)")!

        let authUser = AuthUser(id: "locked-user-1", email: "user@example.com", displayName: "Tester", isEmailVerified: true)
        let authService = MockAuthService(currentUser: authUser)

        let profile = UserProfile(id: "locked-user-1", displayName: "Tester", onboardingComplete: true)
        let userRepo = MockUserProfileRepository(initialProfiles: [profile])
        let publicRepo = MockPublicProfileRepository()
        let biometricService = MockBiometricAuthService(
            isBiometricAvailable: biometricAvailable,
            biometricType: biometricType,
            authenticationResult: true
        )

        let router = AppRouter(
            authService: authService,
            userProfileRepository: userRepo,
            publicProfileRepository: publicRepo,
            biometricAuthService: biometricService,
            dateProvider: clock,
            userDefaults: userDefaults,
            initialRoute: initialRoute
        )

        router.isBiometricLockEnabled = isLockEnabled
        router.lockTimeout = timeout
        router.isBiometricAuthenticated = true

        return (router, clock, biometricService, userDefaults)
    }

    // MARK: - Biometric Metadata Tests

    @Test("BiometricType displayName and iconName map properly across sensor types")
    func biometricTypeMetadata() {
        #expect(BiometricType.faceID.displayName == "Face ID")
        #expect(BiometricType.faceID.iconName == "faceid")

        #expect(BiometricType.touchID.displayName == "Touch ID")
        #expect(BiometricType.touchID.iconName == "touchid")

        #expect(BiometricType.none.displayName == "Passcode")
        #expect(BiometricType.none.iconName == "lock.fill")
    }

    // MARK: - Lock Timeout & Protected Feature Persistence Tests

    @Test("Lock timeout and feature flags persist correctly in UserDefaults")
    func lockPreferencesPersistence() {
        let (router, _, _, _) = makeSUT()

        #expect(router.lockTimeout == .immediately)
        router.lockTimeout = .oneMinute
        #expect(router.lockTimeout == .oneMinute)
        router.lockTimeout = .fiveMinutes
        #expect(router.lockTimeout == .fiveMinutes)

        #expect(router.protectConversationHistory == true)
        router.protectConversationHistory = false
        #expect(router.protectConversationHistory == false)

        #expect(router.protectPracticeHistory == true)
        router.protectPracticeHistory = false
        #expect(router.protectPracticeHistory == false)
    }

    // MARK: - Lock Timing & Background Return Tests

    @Test("Immediate timeout locks app upon returning from background")
    func immediateLockTiming() {
        let (router, clock, _, _) = makeSUT(timeout: .immediately)
        #expect(router.currentRoute == .mainApp)

        // App backgrounded
        router.handleAppBackgrounded()
        #expect(router.isPrivacyCoverActive == true)

        // Advance clock by 2 seconds
        clock.advance(by: 2.0)

        // Return to foreground
        router.handleAppForegrounded()
        #expect(router.isPrivacyCoverActive == false)
        #expect(router.currentRoute == .faceIDLock)
        #expect(router.isBiometricAuthenticated == false)
    }

    @Test("Delayed timeout remains unlocked when returning before timeout expires")
    func delayedTimeoutWithinGracePeriod() {
        let (router, clock, _, _) = makeSUT(timeout: .oneMinute)
        #expect(router.currentRoute == .mainApp)

        // App backgrounded
        router.handleAppBackgrounded()

        // Advance clock by 30 seconds (less than 60s timeout)
        clock.advance(by: 30.0)

        // Return to foreground
        router.handleAppForegrounded()
        #expect(router.currentRoute == .mainApp)
        #expect(router.isBiometricAuthenticated == true)
    }

    @Test("Delayed timeout locks app when returning after grace period expires")
    func delayedTimeoutAfterExpiration() {
        let (router, clock, _, _) = makeSUT(timeout: .oneMinute)
        #expect(router.currentRoute == .mainApp)

        // App backgrounded
        router.handleAppBackgrounded()

        // Advance clock by 65 seconds (exceeding 60s timeout)
        clock.advance(by: 65.0)

        // Return to foreground
        router.handleAppForegrounded()
        #expect(router.currentRoute == .faceIDLock)
        #expect(router.isBiometricAuthenticated == false)
    }

    // MARK: - Passcode Fallback & Unlock Tests

    @Test("Biometric unlock successfully resets lock state and destination")
    func biometricUnlockFlow() async {
        let (router, _, biometricService, _) = makeSUT(timeout: .immediately)

        router.currentRoute = .faceIDLock
        router.isBiometricAuthenticated = false

        let unlocked = await router.unlockWithBiometrics(allowPasscodeFallback: true)

        #expect(unlocked == true)
        #expect(biometricService.authenticateCallCount == 1)
        #expect(router.isBiometricAuthenticated == true)
        #expect(router.currentRoute == .mainApp)
    }
}
