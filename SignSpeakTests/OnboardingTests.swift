import Foundation
import Testing
@testable import SignSpeak

@Suite("Onboarding and Permission Primers (Step 3.9)")
@MainActor
struct OnboardingTests {

    private func makeSUT(
        userId: String = "test-user-123",
        role: OnboardingRole = .learner,
        cameraGranted: Bool = true,
        notificationsGranted: Bool = true
    ) -> (
        viewModel: OnboardingViewModel,
        authService: MockAuthService,
        userProfileRepo: MockUserProfileRepository,
        publicProfileRepo: MockPublicProfileRepository,
        cameraService: MockCameraService,
        notificationService: MockNotificationService,
        router: AppRouter
    ) {
        let authUser = AuthUser(
            id: userId,
            email: "test@example.com",
            displayName: "Maya Angelou",
            isEmailVerified: true,
            isAnonymous: false
        )
        let authService = MockAuthService(currentUser: authUser)
        let userProfileRepo = MockUserProfileRepository()
        let publicProfileRepo = MockPublicProfileRepository()
        let cameraService = MockCameraService(authorizationState: cameraGranted ? .authorized : .denied)
        cameraService.requestAuthorizationResult = cameraGranted
        let notificationService = MockNotificationService(authorizationResult: notificationsGranted)
        let biometricService = MockBiometricAuthService(isBiometricAvailable: false)

        let router = AppRouter(
            authService: authService,
            userProfileRepository: userProfileRepo,
            publicProfileRepository: publicProfileRepo,
            biometricAuthService: biometricService,
            initialRoute: .onboarding
        )

        let viewModel = OnboardingViewModel(
            authService: authService,
            userProfileRepository: userProfileRepo,
            publicProfileRepository: publicProfileRepo,
            cameraService: cameraService,
            notificationService: notificationService,
            router: router
        )

        viewModel.selectedRole = role
        return (viewModel, authService, userProfileRepo, publicProfileRepo, cameraService, notificationService, router)
    }

    // MARK: - Initial State Tests

    @Test("OnboardingViewModel starts with carousel slide 1 and default values")
    func initialStateDefaultValues() {
        let (sut, _, _, _, _, _, _) = makeSUT()

        #expect(sut.currentStep == .carousel1)
        #expect(sut.selectedRole == .learner)
        #expect(sut.selectedDailyGoal == .regular)
        #expect(sut.selectedDailyGoal.minutes == 10)
        #expect(sut.activeDays == [1, 2, 3, 4, 5, 6, 7])
        #expect(sut.soundAlertsEnabled == true)
        #expect(sut.enabledSoundAlerts.count == SoundAlertType.allCases.count)
    }

    // MARK: - Progression Tests

    @Test("Learner role advances smoothly and finishes without sound alerts")
    func learnerProgressionBypassesSoundAlerts() async {
        let (sut, _, repo, _, _, _, router) = makeSUT(role: .learner)

        // 1. Carousel 1 -> 2
        sut.advance()
        #expect(sut.currentStep == .carousel2)

        // 2. Carousel 2 -> 3
        sut.advance()
        #expect(sut.currentStep == .carousel3)

        // 3. Carousel 3 -> Role
        sut.advance()
        #expect(sut.currentStep == .role)

        // 4. Role -> Daily Goal
        sut.advance()
        #expect(sut.currentStep == .dailyGoal)

        // 5. Daily Goal -> Camera
        sut.advance()
        #expect(sut.currentStep == .camera)

        // 6. Camera -> Microphone
        sut.advance()
        #expect(sut.currentStep == .microphone)

        // 7. Microphone -> Notifications
        sut.advance()
        #expect(sut.currentStep == .notifications)

        // 8. Notifications -> Completed (Learner skips sound alerts!)
        sut.advance()
        // Wait brief tick for async task completion
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(router.currentRoute == .mainApp)
        let savedProfile = repo.profiles["test-user-123"]
        #expect(savedProfile?.onboardingComplete == true)
        #expect(savedProfile?.role == "learner")
        #expect(savedProfile?.soundAlertsEnabled == false)
    }

    @Test("Deaf role advances into sound alerts setup before completing")
    func deafRoleRoutesToSoundAlerts() async {
        let (sut, _, repo, _, _, _, router) = makeSUT(role: .deaf)

        // Advance to notifications
        sut.currentStep = .notifications
        sut.selectedRole = .deaf

        // Advance from notifications -> should go to .soundAlerts
        sut.advance()
        #expect(sut.currentStep == .soundAlerts)

        // Advance from soundAlerts -> finishes onboarding
        sut.advance()
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(router.currentRoute == .mainApp)
        let savedProfile = repo.profiles["test-user-123"]
        #expect(savedProfile?.onboardingComplete == true)
        #expect(savedProfile?.role == "deaf")
        #expect(savedProfile?.soundAlertsEnabled == true)
    }

    // MARK: - Navigation Backwards Tests

    @Test("Go back traverses backwards through the steps correctly")
    func goBackNavigation() {
        let (sut, _, _, _, _, _, _) = makeSUT()

        sut.currentStep = .notifications
        sut.goBack()
        #expect(sut.currentStep == .microphone)

        sut.goBack()
        #expect(sut.currentStep == .camera)

        sut.goBack()
        #expect(sut.currentStep == .dailyGoal)

        sut.goBack()
        #expect(sut.currentStep == .role)

        sut.goBack()
        #expect(sut.currentStep == .carousel3)

        sut.goBack()
        #expect(sut.currentStep == .carousel2)

        sut.goBack()
        #expect(sut.currentStep == .carousel1)
    }

    // MARK: - Permission Primers Tests

    @Test("Request camera access invokes cameraService and advances")
    func cameraPermissionHandling() async {
        let (sut, _, _, _, _, _, _) = makeSUT()
        sut.currentStep = .camera

        await sut.requestCameraAccess()

        #expect(sut.isCameraAuthorized == true)
        #expect(sut.currentStep == .microphone)
    }

    @Test("Request notifications invokes notificationService and schedules reminder")
    func notificationPermissionHandling() async {
        let (sut, _, _, _, _, notifications, _) = makeSUT()
        sut.currentStep = .notifications

        // Set practice time to 20:45 (8:45 PM)
        let time = Calendar.current.date(from: DateComponents(hour: 20, minute: 45))!
        sut.practiceTime = time

        await sut.requestNotificationAccess()

        #expect(notifications.requestAuthorizationCallCount == 1)
        #expect(notifications.scheduledReminders.count == 1)
        #expect(notifications.scheduledReminders.first?.hour == 20)
        #expect(notifications.scheduledReminders.first?.minute == 45)
    }

    // MARK: - Skip Tests

    @Test("Skip completes onboarding immediately and persists profile")
    func skipOnboarding() async {
        let (sut, _, repo, _, _, _, router) = makeSUT()
        sut.currentStep = .carousel1

        sut.skip()
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(router.currentRoute == .mainApp)
        let profile = repo.profiles["test-user-123"]
        #expect(profile?.onboardingComplete == true)
    }

    // MARK: - Persistence & Sync Tests

    @Test("Complete persists custom role, daily goal, active days, and syncs to public profile")
    func completePersistsCustomChoices() async {
        let (sut, _, userRepo, publicRepo, _, _, router) = makeSUT()

        sut.selectedRole = .family
        sut.selectedDailyGoal = .serious // 15 min
        sut.activeDays = [1, 3, 5] // Mon, Wed, Fri
        sut.isNotificationsAuthorized = true

        await sut.complete()

        #expect(router.currentRoute == .mainApp)

        let userProfile = userRepo.profiles["test-user-123"]
        #expect(userProfile != nil)
        #expect(userProfile?.role == "family")
        #expect(userProfile?.dailyGoalMinutes == 15)
        #expect(userProfile?.onboardingComplete == true)
        #expect(userProfile?.reminderSettings?.enabled == true)
        #expect(userProfile?.reminderSettings?.activeDays == [1, 3, 5])

        #expect(publicRepo.syncCallCount >= 1)
        let publicProfile = publicRepo.publicProfiles["test-user-123"]
        #expect(publicProfile != nil)
        #expect(publicProfile?.role == "family")
    }
}
