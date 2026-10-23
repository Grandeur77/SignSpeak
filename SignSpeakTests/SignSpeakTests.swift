import Foundation
import Testing
@testable import SignSpeak

/// Verification suite for AppDependencies container and service wiring.
@Suite("AppDependencies & Service Registry")
struct AppDependenciesTests {
    @Test("Live container builds every service instance")
    func liveContainerInstantiatesAllServices() {
        let live = AppDependencies.live

        #expect(live.dateProvider is SystemDateProvider)
        #expect(live.cameraService is CameraService)
        #expect(live.handPoseDetector is HandPoseDetector)
        #expect(live.signClassifier is SignClassifier)
        #expect(live.signRecognitionService is SignRecognitionService)
        #expect(live.authService is FirebaseAuthService)
        #expect(live.userProfileRepository is FirestoreProfileRepository)
        #expect(live.publicProfileRepository is FirestorePublicProfileRepository)
        #expect(live.avatarRepository is FirestoreAvatarRepository)
        #expect(live.progressRepository is FirestoreProgressRepository)
        #expect(live.biometricAuthService is LocalAuthenticationBiometricService)
        #expect(live.credentialVault is KeychainCredentialVault)
        #expect(live.notificationService is LiveNotificationService)
        #expect(live.speechRecognitionService is StubSpeechRecognitionService)
        #expect(live.speechSynthesisService is StubSpeechSynthesisService)
        #expect(live.conversationRepository is StubConversationRepository)
        #expect(live.communityRepository is StubCommunityRepository)
        #expect(live.signCatalogService is SignCatalogService)
        #expect(live.signRequestRepository is FirestoreSignRequestRepository)
        #expect(live.favouritesRepository is FirestoreFavouritesRepository)
    }

    @Test("Preview container populates mock data and fixed clock")
    func previewContainerConfiguredProperly() async throws {
        let preview = AppDependencies.preview

        #expect(preview.dateProvider is FixedDateProvider)
        #expect(preview.cameraService is StubCameraService)
        #expect(preview.handPoseDetector is StubHandPoseDetector)
        #expect(preview.signClassifier is StubSignClassifier)
        #expect(preview.signRecognitionService is StubSignRecognitionService)
        #expect(preview.authService is StubAuthService)
        #expect(preview.userProfileRepository is StubUserProfileRepository)
        #expect(preview.publicProfileRepository is StubPublicProfileRepository)
        #expect(preview.avatarRepository is StubAvatarRepository)
        #expect(preview.progressRepository is StubProgressRepository)
        #expect(preview.biometricAuthService is StubBiometricAuthService)
        #expect(preview.credentialVault is StubCredentialVault)
        #expect(preview.notificationService is StubNotificationService)
        #expect(preview.speechRecognitionService is StubSpeechRecognitionService)
        #expect(preview.speechSynthesisService is StubSpeechSynthesisService)
        #expect(preview.conversationRepository is StubConversationRepository)
        #expect(preview.communityRepository is StubCommunityRepository)
        #expect(preview.signCatalogService is SignCatalogService)
        #expect(preview.signRequestRepository is StubSignRequestRepository)
        #expect(preview.favouritesRepository is StubFavouritesRepository)

        #expect(preview.dateProvider.now == Date(timeIntervalSince1970: 1_790_812_800))
        #expect(preview.authService.currentUserId == "preview-user-123")

        let profile = try await preview.userProfileRepository.fetchProfile(userId: "preview-user-123")
        #expect(profile?.displayName == "Alex Rivera")
        #expect(profile?.currentStreak == 5)

        let posts = try await preview.communityRepository.fetchPosts()
        #expect(!posts.isEmpty)
        #expect(posts.first?.authorName == "Alex Rivera")
    }

    @Test("MockCameraService simulates permission denial without physical camera")
    func mockCameraServiceDenialFlow() async {
        let mockCamera = MockCameraService(authorizationState: .notDetermined)
        mockCamera.requestAuthorizationResult = false

        let granted = await mockCamera.requestAuthorization()
        #expect(!granted)
        #expect(mockCamera.authorizationState == .denied)
    }

    @Test("MockBiometricAuthService simulates biometric authentication gate")
    func mockBiometricAuthentication() async throws {
        let mockBiometric = MockBiometricAuthService(
            isBiometricAvailable: true,
            biometricType: .faceID,
            authenticationResult: true
        )

        let success = try await mockBiometric.authenticate(reason: "Unlock SignSpeak")
        #expect(success)
        #expect(mockBiometric.authenticateCallCount == 1)
    }
}
