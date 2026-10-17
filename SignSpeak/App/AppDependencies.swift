import SwiftUI

/// Central dependency-injection container for the SignSpeak app.
/// The root application configures `AppDependencies.live`; previews and tests use `.preview` or dedicated mocks.
/// View models receive their services explicitly through their initialisers.
nonisolated struct AppDependencies: Sendable {
    var dateProvider: any DateProviding
    var cameraService: any CameraServicing
    var handPoseDetector: any HandPoseDetecting
    var signClassifier: any SignClassifying
    var signRecognitionService: any SignRecognitionServicing
    var authService: any AuthServicing
    var userProfileRepository: any UserProfileRepository
    var progressRepository: any ProgressRepository
    var biometricAuthService: any BiometricAuthServicing
    var notificationService: any NotificationServicing
    var speechRecognitionService: any SpeechRecognitionServicing
    var speechSynthesisService: any SpeechSynthesisServicing
    var conversationRepository: any ConversationRepository
    var communityRepository: any CommunityRepository

    /// Production dependency container.
    static let live = AppDependencies(
        dateProvider: SystemDateProvider(),
        cameraService: CameraService(),
        handPoseDetector: StubHandPoseDetector(),
        signClassifier: StubSignClassifier(),
        signRecognitionService: StubSignRecognitionService(),
        authService: StubAuthService(),
        userProfileRepository: StubUserProfileRepository(),
        progressRepository: StubProgressRepository(),
        biometricAuthService: StubBiometricAuthService(),
        notificationService: StubNotificationService(),
        speechRecognitionService: StubSpeechRecognitionService(),
        speechSynthesisService: StubSpeechSynthesisService(),
        conversationRepository: StubConversationRepository(),
        communityRepository: StubCommunityRepository()
    )

    /// In-memory preview dependency container populated with realistic mock data.
    static let preview = AppDependencies(
        dateProvider: FixedDateProvider(now: Date(timeIntervalSince1970: 1_790_812_800)), // 1 Oct 2026
        cameraService: StubCameraService(),
        handPoseDetector: StubHandPoseDetector(),
        signClassifier: StubSignClassifier(),
        signRecognitionService: StubSignRecognitionService(),
        authService: StubAuthService(initialUserId: "preview-user-123"),
        userProfileRepository: StubUserProfileRepository(initialProfiles: [
            UserProfile(
                id: "preview-user-123",
                displayName: "Alex Rivera",
                email: "alex@example.com",
                role: "learner",
                dailyGoalMinutes: 15,
                currentStreak: 5,
                xp: 450,
                level: 3
            )
        ]),
        progressRepository: StubProgressRepository(),
        biometricAuthService: StubBiometricAuthService(isBiometricAvailable: true, biometricType: .faceID),
        notificationService: StubNotificationService(),
        speechRecognitionService: StubSpeechRecognitionService(),
        speechSynthesisService: StubSpeechSynthesisService(),
        conversationRepository: StubConversationRepository(),
        communityRepository: StubCommunityRepository(initialPosts: [
            CommunityPost(
                authorId: "preview-user-123",
                authorName: "Alex Rivera",
                body: "Completed the Alphabet chapter today! 🎉",
                likeCount: 6
            )
        ])
    )
}

extension EnvironmentValues {
    @Entry var dependencies: AppDependencies = .live
}
