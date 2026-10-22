//
//  MockServices.swift
//  SignSpeakTests
//
//  ========================================================================================
//  # The SignSpeak Mock Pattern & Testing Architecture
//  ========================================================================================
//
//  ## Why Protocols and Dependency Injection?
//  SignSpeak relies heavily on iOS device hardware and cloud APIs:
//  1. AVFoundation Camera (capture session, camera authorization, physical lenses)
//  2. Vision Framework (neural hand pose keypoint extraction)
//  3. Core ML (on-device neural network sign classification)
//  4. Apple Speech Framework & AVSpeechSynthesizer (audio hardware, speech recognition)
//  5. LocalAuthentication (Face ID / Touch ID secure biometrics)
//  6. Firebase Authentication & Cloud Firestore (network latency, offline synchronization)
//
//  In automated testing and CI environments:
//  - The iOS Simulator has NO physical camera.
//  - Microphone and speech transcription can fail or produce non-deterministic results.
//  - Face ID requires manual simulator menu toggles.
//  - Live Firebase calls introduce network flakiness, latency, and shared state side-effects.
//
//  ## How the Pattern Works:
//  - Every service capability is declared as a protocol (e.g. `CameraServicing`, `AuthServicing`).
//  - Production code uses concrete implementations (`AVFoundationCameraService`, `FirebaseAuthService`).
//  - ViewModels receive protocols via initializer injection:
//      `init(cameraService: any CameraServicing = dependencies.cameraService)`
//  - Tests instantiate configurable Mock implementations below to:
//    a) Assert that specific methods were invoked (`#expect(mockAuth.didCallSignOut)`).
//    b) Simulate edge cases deterministically (e.g., camera permission denied, Face ID failure).
//    c) Inject controlled streams without real hardware or network calls.
//  ========================================================================================

import Foundation
import AVFoundation
import CoreMedia
@testable import SignSpeak

/// Configurable mock camera service for testing camera lifecycle and permission transitions.
public final class MockCameraService: CameraServicing, @unchecked Sendable {
    public var authorizationState: CameraAuthorizationState
    public var captureSession: AVCaptureSession?
    public var currentPosition: AVCaptureDevice.Position = .front
    public var requestAuthorizationResult: Bool = true
    public private(set) var startSessionCallCount = 0
    public private(set) var stopSessionCallCount = 0
    public private(set) var switchCameraCallCount = 0

    public var frameStreamContinuation: AsyncStream<CMSampleBuffer>.Continuation?
    public lazy var frameStream: AsyncStream<CMSampleBuffer> = {
        AsyncStream { [weak self] continuation in
            self?.frameStreamContinuation = continuation
        }
    }()

    public init(authorizationState: CameraAuthorizationState = .authorized) {
        self.authorizationState = authorizationState
    }

    public func requestAuthorization() async -> Bool {
        if requestAuthorizationResult {
            authorizationState = .authorized
        } else {
            authorizationState = .denied
        }
        return requestAuthorizationResult
    }

    public func startSession() async {
        startSessionCallCount += 1
    }

    public func stopSession() async {
        stopSessionCallCount += 1
    }

    public func switchCamera() async {
        switchCameraCallCount += 1
    }
}

/// Configurable mock authentication service for testing sign-in flows and session gates.
public final class MockAuthService: AuthServicing, @unchecked Sendable {
    private let lock = NSLock()
    private var _currentUser: AuthUser?
    private var continuations: [UUID: AsyncStream<AuthUser?>.Continuation] = [:]

    public var shouldThrowError: Error?

    // Spy call counters
    public private(set) var signUpCallCount = 0
    public private(set) var signInCallCount = 0
    public private(set) var signInAnonymouslyCallCount = 0
    public private(set) var signInWithGoogleCallCount = 0
    public private(set) var linkGoogleCallCount = 0
    public private(set) var signInWithAppleCallCount = 0
    public private(set) var linkAppleCallCount = 0
    public private(set) var upgradeGuestCallCount = 0
    public private(set) var sendPasswordResetCallCount = 0
    public private(set) var sendEmailVerificationCallCount = 0
    public private(set) var reauthenticateCallCount = 0
    public private(set) var reloadUserCallCount = 0
    public private(set) var signOutCallCount = 0
    public private(set) var deleteAccountCallCount = 0

    // Spy parameter captures
    public private(set) var lastSignUpName: String?
    public private(set) var lastSignUpEmail: String?
    public private(set) var lastSignInEmail: String?
    public private(set) var lastResetEmail: String?
    public private(set) var lastReauthenticatedPassword: String?
    public private(set) var lastGoogleIdToken: String?
    public private(set) var lastGoogleAccessToken: String?
    public private(set) var lastAppleIdToken: String?
    public private(set) var lastAppleRawNonce: String?
    public private(set) var lastAppleFullName: PersonNameComponents?

    public var currentUser: AuthUser? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _currentUser
        }
        set {
            notify(with: newValue)
        }
    }

    public var currentUserId: String? {
        get { currentUser?.id }
        set {
            if let newValue {
                currentUser = AuthUser(
                    id: newValue,
                    email: "\(newValue)@example.com",
                    displayName: "Mock User",
                    isEmailVerified: true,
                    isAnonymous: false
                )
            } else {
                currentUser = nil
            }
        }
    }

    public var userStream: AsyncStream<AuthUser?> {
        AsyncStream { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }

            let id = UUID()
            self.lock.lock()
            self.continuations[id] = continuation
            continuation.yield(self._currentUser)
            self.lock.unlock()

            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.lock()
                self.continuations.removeValue(forKey: id)
                self.lock.unlock()
            }
        }
    }

    public var authStateStream: AsyncStream<String?> {
        AsyncStream { continuation in
            let task = Task {
                for await user in self.userStream {
                    continuation.yield(user?.id)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public init(currentUserId: String? = nil, currentUser: AuthUser? = nil) {
        if let currentUser {
            self._currentUser = currentUser
        } else if let currentUserId {
            self._currentUser = AuthUser(
                id: currentUserId,
                email: "\(currentUserId)@example.com",
                displayName: "Mock User",
                isEmailVerified: true,
                isAnonymous: false
            )
        } else {
            self._currentUser = nil
        }
    }

    public func notify(with user: AuthUser?) {
        lock.lock()
        _currentUser = user
        let currentContinuations = Array(continuations.values)
        lock.unlock()

        for continuation in currentContinuations {
            continuation.yield(user)
        }
    }

    public func signUp(name: String, email: String, password: String) async throws -> AuthUser {
        signUpCallCount += 1
        lastSignUpName = name
        lastSignUpEmail = email
        if let error = shouldThrowError { throw error }

        let user = AuthUser(
            id: "mock-user-\(email)",
            email: email,
            displayName: name.isEmpty ? "New User" : name,
            isEmailVerified: false,
            isAnonymous: false
        )
        notify(with: user)
        return user
    }

    public func signIn(email: String, password: String) async throws -> AuthUser {
        signInCallCount += 1
        lastSignInEmail = email
        if let error = shouldThrowError { throw error }

        let user = AuthUser(
            id: "mock-user-\(email)",
            email: email,
            displayName: "Mock User",
            isEmailVerified: true,
            isAnonymous: false
        )
        notify(with: user)
        return user
    }

    public func signInAnonymously() async throws -> AuthUser {
        signInAnonymouslyCallCount += 1
        if let error = shouldThrowError { throw error }

        let user = AuthUser(
            id: "mock-guest-user",
            email: nil,
            displayName: "Guest",
            isEmailVerified: false,
            isAnonymous: true
        )
        notify(with: user)
        return user
    }

    public func signInWithGoogle() async throws -> AuthUser {
        signInWithGoogleCallCount += 1
        if let error = shouldThrowError { throw error }

        let user = AuthUser(
            id: "mock-google-user",
            email: "mock.google@example.com",
            displayName: "Google User",
            isEmailVerified: true,
            isAnonymous: false
        )
        notify(with: user)
        return user
    }

    public func signInWithGoogle(idToken: String, accessToken: String) async throws -> AuthUser {
        signInWithGoogleCallCount += 1
        lastGoogleIdToken = idToken
        lastGoogleAccessToken = accessToken
        if let error = shouldThrowError { throw error }

        let user = AuthUser(
            id: "mock-google-token-user",
            email: "google.token@example.com",
            displayName: "Google User",
            isEmailVerified: true,
            isAnonymous: false
        )
        notify(with: user)
        return user
    }

    public func linkGoogle(idToken: String, accessToken: String) async throws -> AuthUser {
        linkGoogleCallCount += 1
        lastGoogleIdToken = idToken
        lastGoogleAccessToken = accessToken
        if let error = shouldThrowError { throw error }

        guard let current = currentUser else {
            throw AuthError.noCurrentUser
        }

        let user = AuthUser(
            id: current.id,
            email: "google.linked@example.com",
            displayName: "Google User",
            isEmailVerified: true,
            isAnonymous: false
        )
        notify(with: user)
        return user
    }

    public func linkGoogle() async throws -> AuthUser {
        return try await linkGoogle(idToken: "mock-id-token", accessToken: "mock-access-token")
    }

    public func signInWithApple() async throws -> AuthUser {
        signInWithAppleCallCount += 1
        if let error = shouldThrowError { throw error }

        let user = AuthUser(
            id: "mock-apple-user",
            email: "mock.apple@example.com",
            displayName: "Apple User",
            isEmailVerified: true,
            isAnonymous: false
        )
        notify(with: user)
        return user
    }

    public func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws -> AuthUser {
        signInWithAppleCallCount += 1
        lastAppleIdToken = idToken
        lastAppleRawNonce = rawNonce
        lastAppleFullName = fullName
        if let error = shouldThrowError { throw error }

        let displayName = fullName.flatMap { PersonNameComponentsFormatter().string(from: $0) } ?? "Apple User"
        let user = AuthUser(
            id: "mock-apple-user",
            email: "mock.apple@example.com",
            displayName: displayName,
            isEmailVerified: true,
            isAnonymous: false
        )
        notify(with: user)
        return user
    }

    public func linkApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws -> AuthUser {
        linkAppleCallCount += 1
        lastAppleIdToken = idToken
        lastAppleRawNonce = rawNonce
        lastAppleFullName = fullName
        if let error = shouldThrowError { throw error }

        guard let current = currentUser else {
            throw AuthError.noCurrentUser
        }

        let displayName = fullName.flatMap { PersonNameComponentsFormatter().string(from: $0) } ?? "Apple User"
        let user = AuthUser(
            id: current.id,
            email: "apple.linked@example.com",
            displayName: displayName,
            isEmailVerified: true,
            isAnonymous: false
        )
        notify(with: user)
        return user
    }

    public func linkApple() async throws -> AuthUser {
        return try await linkApple(idToken: "mock-apple-id-token", rawNonce: "mock-raw-nonce", fullName: nil)
    }

    public func upgradeGuest(name: String, email: String, password: String) async throws -> AuthUser {
        upgradeGuestCallCount += 1
        if let error = shouldThrowError { throw error }

        let user = AuthUser(
            id: currentUser?.id ?? "mock-user-\(email)",
            email: email,
            displayName: name.isEmpty ? "Upgraded User" : name,
            isEmailVerified: false,
            isAnonymous: false
        )
        notify(with: user)
        return user
    }

    public func sendPasswordReset(email: String) async throws {
        sendPasswordResetCallCount += 1
        lastResetEmail = email
        if let error = shouldThrowError { throw error }
    }

    public func sendEmailVerification() async throws {
        sendEmailVerificationCallCount += 1
        if let error = shouldThrowError { throw error }
    }

    public func reauthenticate(password: String) async throws {
        reauthenticateCallCount += 1
        lastReauthenticatedPassword = password
        if let error = shouldThrowError { throw error }
    }

    public func reloadUser() async throws -> AuthUser? {
        reloadUserCallCount += 1
        if let error = shouldThrowError { throw error }

        guard let current = currentUser else { return nil }
        let updated = AuthUser(
            id: current.id,
            email: current.email,
            displayName: current.displayName,
            isEmailVerified: true,
            isAnonymous: current.isAnonymous
        )
        notify(with: updated)
        return updated
    }

    public func signOut() throws {
        signOutCallCount += 1
        if let error = shouldThrowError { throw error }
        notify(with: nil)
    }

    public func deleteAccount() async throws {
        deleteAccountCallCount += 1
        if let error = shouldThrowError { throw error }
        notify(with: nil)
    }
}

/// Configurable mock biometric service for testing Face ID and Touch ID authentication gates.
public final class MockBiometricAuthService: BiometricAuthServicing, @unchecked Sendable {
    public var isBiometricAvailable: Bool
    public var biometricType: BiometricType
    public var authenticationResult: Bool
    public var shouldThrowError: Error?
    public private(set) var authenticateCallCount = 0

    public init(
        isBiometricAvailable: Bool = true,
        biometricType: BiometricType = .faceID,
        authenticationResult: Bool = true
    ) {
        self.isBiometricAvailable = isBiometricAvailable
        self.biometricType = biometricType
        self.authenticationResult = authenticationResult
    }

    public func authenticate(reason: String) async throws -> Bool {
        authenticateCallCount += 1
        if let error = shouldThrowError { throw error }
        return authenticationResult
    }
}

/// Configurable mock speech synthesis service for asserting that correct sign translations are spoken.
public final class MockSpeechSynthesisService: SpeechSynthesisServicing, @unchecked Sendable {
    public var isSpeaking: Bool = false
    public private(set) var spokenUtterances: [String] = []
    public private(set) var stopSpeakingCallCount = 0

    public init() {}

    public func speak(text: String, voiceLanguage: String?) async throws {
        spokenUtterances.append(text)
        isSpeaking = true
    }

    public func stopSpeaking() {
        stopSpeakingCallCount += 1
        isSpeaking = false
    }
}

/// Configurable mock hand pose detector for testing gesture recognition and tracking states.
public final class MockHandPoseDetector: HandPoseDetecting, @unchecked Sendable {
    private let lock = NSLock()
    public var confidenceThreshold: Float = 0.3
    public var stubbedPose: HandPose?
    public var shouldThrowError: Error?
    private var _detectPoseCallCount = 0

    public var detectPoseCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _detectPoseCallCount
    }

    public init(stubbedPose: HandPose? = nil) {
        self.stubbedPose = stubbedPose
    }

    public nonisolated func detectPose(in sampleBuffer: CMSampleBuffer) async throws -> HandPose? {
        lock.lock()
        _detectPoseCallCount += 1
        let error = shouldThrowError
        let result = stubbedPose
        lock.unlock()

        if let error { throw error }
        return result
    }
}

/// Configurable mock sign classifier for testing inference results and error handling.
public final class MockSignClassifier: SignClassifying, @unchecked Sendable {
    public var stubbedResult: SignClassification?
    public var shouldThrowError: Error?
    public private(set) var classifyCallCount = 0

    public init(stubbedResult: SignClassification? = nil) {
        self.stubbedResult = stubbedResult
    }

    public func classify(pose: HandPose) throws -> SignClassification? {
        classifyCallCount += 1
        if let error = shouldThrowError { throw error }
        return stubbedResult
    }
}

/// Configurable mock sign recognition service for testing recognition lifecycle and state transitions.
public final class MockSignRecognitionService: SignRecognitionServicing, @unchecked Sendable {
    public var currentState: RecognitionState
    public var confidenceThreshold: Double
    public var holdDuration: TimeInterval
    public private(set) var startRecognitionCallCount = 0
    public private(set) var stopRecognitionCallCount = 0
    public private(set) var resetCallCount = 0

    public var continuation: AsyncStream<RecognitionState>.Continuation?
    public lazy var stateStream: AsyncStream<RecognitionState> = {
        AsyncStream { [weak self] continuation in
            self?.continuation = continuation
            continuation.yield(self?.currentState ?? .noHand)
        }
    }()

    public init(
        initialState: RecognitionState = .noHand,
        confidenceThreshold: Double = 0.85,
        holdDuration: TimeInterval = 1.0
    ) {
        self.currentState = initialState
        self.confidenceThreshold = confidenceThreshold
        self.holdDuration = holdDuration
    }

    public func emitState(_ state: RecognitionState) {
        currentState = state
        continuation?.yield(state)
    }

    public func startRecognition() async {
        startRecognitionCallCount += 1
    }

    public func stopRecognition() async {
        stopRecognitionCallCount += 1
    }

    public func reset() {
        resetCallCount += 1
        currentState = .noHand
        continuation?.yield(.noHand)
    }

    @discardableResult
    public func processPose(_ pose: HandPose?) -> RecognitionState {
        currentState
    }
}

/// Controllable mock clock for deterministic time manipulation in tests.
public final class ControllableClock: DateProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var _now: Date
    public var calendar: Calendar

    public var now: Date {
        lock.lock()
        defer { lock.unlock() }
        return _now
    }

    public init(now: Date = Date(timeIntervalSince1970: 1000), calendar: Calendar = .current) {
        self._now = now
        self.calendar = calendar
    }

    public func advance(by seconds: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        _now = _now.addingTimeInterval(seconds)
    }

    public func set(to date: Date) {
        lock.lock()
        defer { lock.unlock() }
        _now = date
    }
}

/// Configurable mock credential vault for testing Face ID storage, retrieval, and invalidation.
public final class MockCredentialVault: CredentialVaultProtocol, @unchecked Sendable {
    private let lock = NSLock()
    public var storedEmail: String?
    public var storedPassword: String?
    public var shouldThrowError: Error?
    public var shouldThrowErrorOnRetrieve: Error?
    public var shouldThrowErrorOnSave: Error?
    public var shouldThrowErrorOnClear: Error?
    public var shouldCancel: Bool = false
    public private(set) var saveCallCount = 0
    public private(set) var retrieveCallCount = 0
    public private(set) var clearCallCount = 0

    public var hasStoredCredentials: Bool {
        lock.lock()
        defer { lock.unlock() }
        return storedEmail != nil && storedPassword != nil
    }

    public init(storedEmail: String? = nil, storedPassword: String? = nil) {
        self.storedEmail = storedEmail
        self.storedPassword = storedPassword
    }

    public func saveCredentials(email: String, password: String) throws {
        lock.lock()
        defer { lock.unlock() }
        saveCallCount += 1
        if let error = shouldThrowErrorOnSave ?? shouldThrowError { throw error }
        self.storedEmail = email
        self.storedPassword = password
    }

    public func retrieveCredentials(promptReason: String) async throws -> (email: String, password: String)? {
        lock.lock()
        defer { lock.unlock() }
        retrieveCallCount += 1
        if shouldCancel { throw CancellationError() }
        if let error = shouldThrowErrorOnRetrieve ?? shouldThrowError { throw error }
        guard let email = storedEmail, let password = storedPassword else {
            return nil
        }
        return (email: email, password: password)
    }

    public func clearCredentials() throws {
        lock.lock()
        defer { lock.unlock() }
        clearCallCount += 1
        storedEmail = nil
        storedPassword = nil
        if let error = shouldThrowErrorOnClear { throw error }
    }
}

/// Configurable mock private profile repository for testing profile fetching, saving, streak updates, and creation.
public final class MockUserProfileRepository: UserProfileRepository, @unchecked Sendable {
    private let lock = NSLock()
    public var profiles: [String: UserProfile] = [:]
    public var shouldThrowError: Error?
    public private(set) var fetchCallCount = 0
    public private(set) var saveCallCount = 0
    public private(set) var updateStreakCallCount = 0
    public private(set) var createProfileIfNeededCallCount = 0

    public init(initialProfiles: [UserProfile] = []) {
        for profile in initialProfiles {
            profiles[profile.id] = profile
        }
    }

    public func fetchProfile(userId: String) async throws -> UserProfile? {
        lock.lock()
        defer { lock.unlock() }
        fetchCallCount += 1
        if let error = shouldThrowError { throw error }
        return profiles[userId]
    }

    public func saveProfile(_ profile: UserProfile) async throws {
        lock.lock()
        defer { lock.unlock() }
        saveCallCount += 1
        if let error = shouldThrowError { throw error }
        profiles[profile.id] = profile
    }

    public func updateStreak(userId: String, streak: Int) async throws {
        lock.lock()
        defer { lock.unlock() }
        updateStreakCallCount += 1
        if let error = shouldThrowError { throw error }
        profiles[userId]?.currentStreak = streak
    }

    @discardableResult
    public func createProfileIfNeeded(userId: String, displayName: String, email: String?) async throws -> UserProfile {
        lock.lock()
        defer { lock.unlock() }
        createProfileIfNeededCallCount += 1
        if let error = shouldThrowError { throw error }
        if let existing = profiles[userId] {
            return existing
        }
        let cleanName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let newProfile = UserProfile(
            id: userId,
            displayName: cleanName.isEmpty ? "Learner" : cleanName,
            email: email
        )
        profiles[userId] = newProfile
        return newProfile
    }
}

/// Configurable mock public profile repository for testing public profile synchronization and social cards.
public final class MockPublicProfileRepository: PublicProfileRepository, @unchecked Sendable {
    private let lock = NSLock()
    public var publicProfiles: [String: PublicProfile] = [:]
    public var shouldThrowError: Error?
    public private(set) var fetchCallCount = 0
    public private(set) var saveCallCount = 0
    public private(set) var syncCallCount = 0

    public init(initialProfiles: [PublicProfile] = []) {
        for profile in initialProfiles {
            publicProfiles[profile.id] = profile
        }
    }

    public func fetchPublicProfile(userId: String) async throws -> PublicProfile? {
        lock.lock()
        defer { lock.unlock() }
        fetchCallCount += 1
        if let error = shouldThrowError { throw error }
        return publicProfiles[userId]
    }

    public func savePublicProfile(_ profile: PublicProfile) async throws {
        lock.lock()
        defer { lock.unlock() }
        saveCallCount += 1
        if let error = shouldThrowError { throw error }
        publicProfiles[profile.id] = profile
    }

    public func syncFromPrivateProfile(_ profile: UserProfile) async throws {
        lock.lock()
        defer { lock.unlock() }
        syncCallCount += 1
        if let error = shouldThrowError { throw error }
        let existing = publicProfiles[profile.id]
        let publicProfile = PublicProfile(
            id: profile.id,
            displayName: profile.displayName,
            role: profile.role,
            level: profile.level,
            currentStreak: profile.currentStreak,
            avatarUpdatedAt: existing?.avatarUpdatedAt,
            followerCount: existing?.followerCount ?? 0,
            followingCount: existing?.followingCount ?? 0
        )
        publicProfiles[profile.id] = publicProfile
    }
}

/// Configurable mock avatar repository for testing image resizing, persistence, and deletion.
public final class MockAvatarRepository: AvatarRepository, @unchecked Sendable {
    private let lock = NSLock()
    public var avatars: [String: UserAvatar] = [:]
    public var shouldThrowError: Error?
    public private(set) var fetchCallCount = 0
    public private(set) var saveCallCount = 0
    public private(set) var deleteCallCount = 0

    public init(initialAvatars: [UserAvatar] = []) {
        for avatar in initialAvatars {
            avatars[avatar.id] = avatar
        }
    }

    public func fetchAvatar(userId: String) async throws -> UserAvatar? {
        lock.lock()
        defer { lock.unlock() }
        fetchCallCount += 1
        if let error = shouldThrowError { throw error }
        return avatars[userId]
    }

    public func saveAvatar(userId: String, imageData: Data) async throws -> UserAvatar {
        lock.lock()
        defer { lock.unlock() }
        saveCallCount += 1
        if let error = shouldThrowError { throw error }
        let base64 = AvatarImageHelper.processAvatar(from: imageData) ?? imageData.base64EncodedString()
        let avatar = UserAvatar(id: userId, jpegBase64: base64, updatedAt: Date())
        avatars[userId] = avatar
        return avatar
    }

    public func deleteAvatar(userId: String) async throws {
        lock.lock()
        defer { lock.unlock() }
        deleteCallCount += 1
        if let error = shouldThrowError { throw error }
        avatars.removeValue(forKey: userId)
    }
}





