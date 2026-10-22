#if DEBUG
import Foundation
import Testing
import CoreML
import CoreGraphics
@testable import SignSpeak

@Suite("Motion Sign Classifier & Window Buffer (Step 2.2)")
@MainActor
struct MotionClassifierTests {
    @Test("MotionSignClassifier initializes with 30 fps and 45-frame window")
    func classifierConfiguration() {
        let classifier = MotionSignClassifier(targetFrameRate: 30.0, predictionWindow: 45)

        #expect(classifier.targetFrameRate == 30.0)
        #expect(classifier.predictionWindow == 45)
    }

    @Test("Classifier throws clear error when model is not bundled")
    func unbundledModelThrowsInitializationError() {
        let classifier = MotionSignClassifier()

        // When MotionSignClassifier.mlmodel is not yet in the bundle, classify throws
        if !classifier.isModelLoaded {
            #expect(throws: SignClassificationError.self) {
                try classifier.classify(window: [])
            }
        }
    }

    @Test("StubMotionSignClassifier returns expected dynamic action classification")
    func stubMotionClassifierEvaluation() throws {
        let expected = SignClassification(
            label: "Hello",
            confidence: 0.94,
            candidates: [SignCandidate(label: "Hello", confidence: 0.94), SignCandidate(label: "J", confidence: 0.04)]
        )
        let stub = StubMotionSignClassifier(targetFrameRate: 30.0, predictionWindow: 45, stubbedResult: expected)

        let result = try stub.classify(window: [])
        #expect(result == expected)
        #expect(result?.label == "Hello")
        #expect(result?.confidence == 0.94)
    }

    @Test("MotionWindowBuffer maintains sliding window size of 45 frames")
    func windowBufferCapacityAndSliding() throws {
        let buffer = MotionWindowBuffer(targetFrameRate: 30.0, windowSize: 45)
        #expect(!buffer.isFull)
        #expect(buffer.count == 0)

        // Generate synthetic dummy poses
        for i in 0..<60 {
            let timestamp = Double(i) * (1.0 / 30.0)
            let pose = makeDummyPose(wristX: 0.5, wristY: 0.5)
            buffer.append(pose: pose, timestamp: timestamp)
        }

        #expect(buffer.isFull)
        #expect(buffer.count == 45)
        #expect(buffer.keypointWindow.count == 45)
    }

    @Test("MotionWindowBuffer drops frames arriving faster than rate limit")
    func windowBufferRateLimiting() {
        let buffer = MotionWindowBuffer(targetFrameRate: 30.0, windowSize: 45)

        let pose = makeDummyPose(wristX: 0.5, wristY: 0.5)
        let accepted1 = buffer.append(pose: pose, timestamp: 1.000)
        #expect(accepted1)

        // Frame arrived 2 ms later (way too fast for 30 fps = 33.3ms)
        let accepted2 = buffer.append(pose: pose, timestamp: 1.002)
        #expect(!accepted2)
        #expect(buffer.count == 1)

        // Frame arrived 35 ms later (correct for 30 fps)
        let accepted3 = buffer.append(pose: pose, timestamp: 1.035)
        #expect(accepted3)
        #expect(buffer.count == 2)
    }

    @Test("MotionWindowBuffer resets on no-hand detection")
    func windowBufferResetOnNoHand() {
        let buffer = MotionWindowBuffer(targetFrameRate: 30.0, windowSize: 45)

        for i in 0..<10 {
            let pose = makeDummyPose(wristX: 0.5, wristY: 0.5)
            buffer.append(pose: pose, timestamp: Double(i) * 0.035)
        }
        #expect(buffer.count == 10)

        buffer.reset()
        #expect(buffer.count == 0)
        #expect(!buffer.isFull)
    }

    @Test("MotionWindowBuffer calculates movement displacement accurately")
    func windowBufferMovementDisplacement() {
        let buffer = MotionWindowBuffer(targetFrameRate: 30.0, windowSize: 10)

        // Static hand: wrist stays still at (0.5, 0.5)
        for i in 0..<10 {
            let pose = makeDummyPose(wristX: 0.5, wristY: 0.5)
            buffer.append(pose: pose, timestamp: Double(i) * 0.035)
        }
        #expect(buffer.movementDisplacement == 0.0)

        buffer.reset()

        // Moving hand: wrist moves along X axis (e.g. waving / signing J)
        for i in 0..<10 {
            let x = 0.2 + (Double(i) * 0.05)
            let pose = makeDummyPose(wristX: x, wristY: 0.5)
            buffer.append(pose: pose, timestamp: Double(i) * 0.035)
        }
        #expect(buffer.movementDisplacement > 0.4)
    }

    @Test("SignRecognitionService arbitrates: static sign wins when hand is stationary")
    func staticModelWinsWhenStationary() throws {
        let mockCamera = MockCameraService()
        let mockDetector = MockHandPoseDetector()
        let staticResult = SignClassification(label: "A", confidence: 0.92, modelSource: .staticModel)
        let mockStaticClassifier = MockSignClassifier(stubbedResult: staticResult)

        let motionResult = SignClassification(label: "J", confidence: 0.95, modelSource: .motionModel)
        let mockMotionClassifier = MockMotionSignClassifier(stubbedResult: motionResult)

        let dateProvider = ControllableClock()
        let service = SignRecognitionService(
            cameraService: mockCamera,
            handPoseDetector: mockDetector,
            signClassifier: mockStaticClassifier,
            motionSignClassifier: mockMotionClassifier,
            motionWindowBuffer: MotionWindowBuffer(targetFrameRate: 30.0, windowSize: 10),
            motionDisplacementThreshold: 0.15,
            dateProvider: dateProvider
        )

        // Stationary hand poses
        var lastState: RecognitionState = .noHand
        for _ in 0..<15 {
            let pose = makeDummyPose(wristX: 0.5, wristY: 0.5)
            dateProvider.advance(by: 0.035)
            lastState = service.processPose(pose)
        }

        #expect(mockStaticClassifier.classifyCallCount > 0)
        #expect(mockMotionClassifier.classifyCallCount == 0) // Motion classifier skipped because displacement is 0.0
        #expect(lastState.label == "A")
        #expect(service.currentModelSource == RecognitionModelSource.staticModel)
    }

    @Test("SignRecognitionService arbitrates: motion sign wins when hand movement exceeds threshold")
    func motionModelWinsWhenMoving() throws {
        let mockCamera = MockCameraService()
        let mockDetector = MockHandPoseDetector()
        let staticResult = SignClassification(label: "I", confidence: 0.88, modelSource: .staticModel)
        let mockStaticClassifier = MockSignClassifier(stubbedResult: staticResult)

        let motionResult = SignClassification(label: "J", confidence: 0.95, modelSource: .motionModel)
        let mockMotionClassifier = MockMotionSignClassifier(stubbedResult: motionResult)

        let dateProvider = ControllableClock()
        let service = SignRecognitionService(
            cameraService: mockCamera,
            handPoseDetector: mockDetector,
            signClassifier: mockStaticClassifier,
            motionSignClassifier: mockMotionClassifier,
            motionWindowBuffer: MotionWindowBuffer(targetFrameRate: 30.0, windowSize: 10),
            motionDisplacementThreshold: 0.15,
            motionInferenceStride: 1,
            dateProvider: dateProvider
        )

        // Moving hand poses (displacement > 0.15)
        var lastState: RecognitionState = .noHand
        for i in 0..<15 {
            let x = 0.2 + (Double(i) * 0.04)
            let pose = makeDummyPose(wristX: x, wristY: 0.5)
            dateProvider.advance(by: 0.035)
            lastState = service.processPose(pose)
        }

        #expect(mockMotionClassifier.classifyCallCount > 0)
        #expect(lastState.label == "J")
        #expect(service.currentModelSource == RecognitionModelSource.motionModel)
    }

    // MARK: - Helper

    private func makeDummyPose(wristX: Double, wristY: Double) -> HandPose {
        let dummyMultiArray = try! MLMultiArray(shape: [3, 21], dataType: .float32)
        var joints: [String: HandJoint] = [:]

        joints["wrist"] = HandJoint(
            name: "wrist",
            position: CGPoint(x: wristX, y: wristY),
            confidence: 0.95
        )
        joints["index_tip"] = HandJoint(
            name: "index_tip",
            position: CGPoint(x: wristX, y: wristY + 0.2),
            confidence: 0.95
        )

        return HandPose(
            joints: joints,
            confidence: 0.95,
            isRightHand: true,
            keypointsMultiArray: dummyMultiArray
        )
    }
}
#endif
