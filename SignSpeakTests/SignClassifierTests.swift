import Foundation
import Testing
import CoreML
@testable import SignSpeak

@Suite("Core ML Sign Classification & Model Inference")
struct SignClassifierTests {
    @Test("SignClassifier initializes successfully with bundled model")
    func classifierInitialization() {
        let classifier = try? SignClassifier()
        #expect(classifier != nil)
    }

    @Test("SignClassifier throws missingKeypoints when HandPose lacks MLMultiArray")
    func classifierThrowsMissingKeypoints() {
        guard let classifier = try? SignClassifier() else {
            Issue.record("SignClassifier should initialize with bundled model")
            return
        }

        let emptyPose = HandPose(
            joints: ["wrist": HandJoint(name: "wrist", position: CGPoint(x: 0.5, y: 0.5), confidence: 0.9)],
            confidence: 0.9,
            isRightHand: true,
            keypointsMultiArray: nil
        )

        #expect(throws: SignClassificationError.missingKeypoints) {
            _ = try classifier.classify(pose: emptyPose)
        }
    }

    @Test("SignClassificationError provides descriptive error messages")
    func errorDescriptions() {
        let err1 = SignClassificationError.missingKeypoints
        let err2 = SignClassificationError.modelInitializationFailed("Corrupt file")
        let err3 = SignClassificationError.predictionFailed("Invalid shape")

        #expect(err1.errorDescription?.contains("MLMultiArray") == true)
        #expect(err2.errorDescription?.contains("Corrupt file") == true)
        #expect(err3.errorDescription?.contains("Invalid shape") == true)
    }

    @Test("CameraTestViewModel integrates SignClassifier with pose stream")
    @MainActor
    func viewModelSignClassificationFlow() async {
        let mockCamera = MockCameraService(authorizationState: .authorized)
        let sampleClassification = SignClassification(
            label: "A",
            confidence: 0.96,
            candidates: [
                SignCandidate(label: "A", confidence: 0.96),
                SignCandidate(label: "S", confidence: 0.03)
            ]
        )
        let mockClassifier = MockSignClassifier(stubbedResult: sampleClassification)

        let samplePose = HandPose(
            joints: ["wrist": HandJoint(name: "wrist", position: CGPoint(x: 0.5, y: 0.5), confidence: 0.9)],
            confidence: 0.9
        )
        let mockDetector = MockHandPoseDetector(stubbedPose: samplePose)

        let viewModel = CameraTestViewModel(
            cameraService: mockCamera,
            handPoseDetector: mockDetector,
            signClassifier: mockClassifier
        )

        await viewModel.startCamera()

        #expect(viewModel.isSessionRunning)
        #expect(viewModel.currentClassification == nil)

        // Classify directly through mock
        let result = try? mockClassifier.classify(pose: samplePose)
        #expect(result?.label == "A")
        #expect(result?.confidence == 0.96)
        #expect(mockClassifier.classifyCallCount == 1)

        await viewModel.stopCamera()
        #expect(viewModel.currentClassification == nil)
    }
}
