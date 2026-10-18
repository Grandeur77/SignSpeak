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
    public var currentUserId: String?
    public var shouldThrowError: Error?
    public private(set) var signOutCallCount = 0
    public private(set) var deleteAccountCallCount = 0

    public init(currentUserId: String? = nil) {
        self.currentUserId = currentUserId
    }

    public var authStateStream: AsyncStream<String?> {
        AsyncStream { continuation in
            continuation.yield(self.currentUserId)
            continuation.finish()
        }
    }

    public func signIn(email: String, password: String) async throws -> String {
        if let error = shouldThrowError { throw error }
        let uid = "mock-user-\(email)"
        currentUserId = uid
        return uid
    }

    public func signUp(email: String, password: String) async throws -> String {
        if let error = shouldThrowError { throw error }
        let uid = "mock-user-\(email)"
        currentUserId = uid
        return uid
    }

    public func signInAnonymously() async throws -> String {
        if let error = shouldThrowError { throw error }
        let uid = "mock-guest-user"
        currentUserId = uid
        return uid
    }

    public func signInWithGoogle() async throws -> String {
        if let error = shouldThrowError { throw error }
        let uid = "mock-google-user"
        currentUserId = uid
        return uid
    }

    public func signOut() throws {
        if let error = shouldThrowError { throw error }
        signOutCallCount += 1
        currentUserId = nil
    }

    public func deleteAccount() async throws {
        if let error = shouldThrowError { throw error }
        deleteAccountCallCount += 1
        currentUserId = nil
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
