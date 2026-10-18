import Foundation
import Testing
import CoreMedia
@testable import SignSpeak

@Suite("Sign Recognition Coordinator & Practice Flow")
struct SignRecognitionServiceTests {
    @Test("Service initializes with correct configuration and initial state")
    func serviceInitialization() {
        let mockCamera = MockCameraService(authorizationState: .authorized)
        let mockDetector = MockHandPoseDetector()
        let mockClassifier = MockSignClassifier()

        let service = SignRecognitionService(
            cameraService: mockCamera,
            handPoseDetector: mockDetector,
            signClassifier: mockClassifier,
            confidenceThreshold: 0.85,
            holdDuration: 1.0
        )

        #expect(service.currentState == .noHand)
        #expect(service.currentPose == nil)
        #expect(service.currentClassification == nil)
        #expect(service.confidenceThreshold == 0.85)
        #expect(service.holdDuration == 1.0)
    }

    @Test("Processing nil pose results in noHand state")
    func processNilPose() {
        let mockCamera = MockCameraService(authorizationState: .authorized)
        let mockDetector = MockHandPoseDetector()
        let mockClassifier = MockSignClassifier()

        let service = SignRecognitionService(
            cameraService: mockCamera,
            handPoseDetector: mockDetector,
            signClassifier: mockClassifier
        )

        let state = service.processPose(nil)
        #expect(state == .noHand)
        #expect(service.currentState == .noHand)
        #expect(service.currentPose == nil)
        #expect(service.currentClassification == nil)
    }

    @Test("Processing valid pose coordinates classifier and stability filter")
    func processValidPose() {
        let mockCamera = MockCameraService(authorizationState: .authorized)
        let samplePose = HandPose(
            joints: ["wrist": HandJoint(name: "wrist", position: CGPoint(x: 0.5, y: 0.5), confidence: 0.9)],
            confidence: 0.9
        )
        let mockDetector = MockHandPoseDetector(stubbedPose: samplePose)

        let expectedClassification = SignClassification(
            label: "F",
            confidence: 0.94,
            candidates: [
                SignCandidate(label: "F", confidence: 0.94),
                SignCandidate(label: "E", confidence: 0.05)
            ]
        )
        let mockClassifier = MockSignClassifier(stubbedResult: expectedClassification)

        let service = SignRecognitionService(
            cameraService: mockCamera,
            handPoseDetector: mockDetector,
            signClassifier: mockClassifier
        )

        let state = service.processPose(samplePose)
        #expect(state == .detecting(label: "F", confidence: 0.94, progress: 0.0, runnerUp: SignCandidate(label: "E", confidence: 0.05)))
        #expect(service.currentState == state)
        #expect(service.currentPose == samplePose)
        #expect(service.currentClassification == expectedClassification)
    }

    @Test("Reset clears pose, classification, and emits noHand")
    func resetClearsState() async {
        let mockCamera = MockCameraService(authorizationState: .authorized)
        let samplePose = HandPose(
            joints: ["wrist": HandJoint(name: "wrist", position: CGPoint(x: 0.5, y: 0.5), confidence: 0.9)],
            confidence: 0.9
        )
        let mockClassifier = MockSignClassifier(stubbedResult: SignClassification(label: "A", confidence: 0.95))

        let service = SignRecognitionService(
            cameraService: mockCamera,
            handPoseDetector: MockHandPoseDetector(stubbedPose: samplePose),
            signClassifier: mockClassifier
        )

        _ = service.processPose(samplePose)
        #expect(service.currentPose != nil)

        service.reset()
        #expect(service.currentState == .noHand)
        #expect(service.currentPose == nil)
        #expect(service.currentClassification == nil)
    }

    @Test("SignPracticeHint library provides correct feedback for target F and mistake E")
    func practiceFeedbackLibrary() {
        let feedbackFE = SignPracticeHint.feedback(target: "F", detected: "E")
        #expect(feedbackFE.title == "Not quite — looks like \"E\"")
        #expect(feedbackFE.subtitle.contains("index finger"))
        #expect(feedbackFE.correction.contains("OK"))

        let feedbackGeneric = SignPracticeHint.feedback(target: "F", detected: nil)
        #expect(feedbackGeneric.title.contains("F"))
    }

    @Test("CameraTestViewModel coordinates target matching and progression")
    @MainActor
    func viewModelPracticeProgression() {
        let mockCamera = MockCameraService(authorizationState: .authorized)
        let mockRecognition = MockSignRecognitionService(initialState: .noHand)

        let viewModel = CameraTestViewModel(
            cameraService: mockCamera,
            signRecognitionService: mockRecognition,
            practiceTargets: ["A", "B", "F"],
            initialTargetIndex: 2 // Target is "F"
        )

        #expect(viewModel.currentTargetSign == "F")
        #expect(viewModel.progressStepText == "3 / 3")
        #expect(!viewModel.isTargetMatched)

        // Simulate recognition of target sign "F"
        mockRecognition.emitState(.recognized(label: "F", confidence: 0.95, runnerUp: nil))
        viewModel.recognitionState = mockRecognition.currentState
        #expect(viewModel.isTargetMatched)
        #expect(viewModel.currentPrecision == 0.95)
        #expect(viewModel.holdProgress == 1.0)

        // Advance to next sign
        viewModel.nextSign()
        #expect(viewModel.currentTargetSign == "A")
        #expect(viewModel.progressStepText == "1 / 3")
        #expect(!viewModel.isTargetMatched)

        // Skip sign
        viewModel.skipSign()
        #expect(viewModel.currentTargetSign == "B")
    }
}
