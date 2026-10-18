import Foundation
import Testing
import CoreMedia
@testable import SignSpeak

@Suite("SignRecognitionService Pipeline & Mock Suite")
struct SignRecognitionServiceTests {
    private func makeSamplePose() -> HandPose {
        HandPose(
            joints: ["wrist": HandJoint(name: "wrist", position: CGPoint(x: 0.5, y: 0.5), confidence: 0.9)],
            confidence: 0.9
        )
    }

    private func makeSampleBuffer() -> CMSampleBuffer {
        var formatDesc: CMFormatDescription?
        CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: kCVPixelFormatType_32BGRA,
            width: 100,
            height: 100,
            extensions: nil,
            formatDescriptionOut: &formatDesc
        )

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: CMTime.zero,
            decodeTimeStamp: CMTime.invalid
        )

        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: nil,
            dataReady: false,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDesc,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )

        return sampleBuffer!
    }

    @Test("Service initializes with default and custom values")
    func serviceInitialization() {
        let mockCamera = MockCameraService(authorizationState: .authorized)
        let mockDetector = MockHandPoseDetector()
        let mockClassifier = MockSignClassifier()
        let clock = ControllableClock()

        let service = SignRecognitionService(
            cameraService: mockCamera,
            handPoseDetector: mockDetector,
            signClassifier: mockClassifier,
            confidenceThreshold: 0.85,
            holdDuration: 1.0,
            dateProvider: clock
        )

        #expect(service.currentState == .noHand)
        #expect(service.currentPose == nil)
        #expect(service.currentClassification == nil)
        #expect(service.confidenceThreshold == 0.85)
        #expect(service.holdDuration == 1.0)
    }

    @Test(
        "Pipeline ignores low confidence predictions and emits lowConfidence state",
        arguments: [0.10, 0.40, 0.70, 0.84]
    )
    func belowThresholdIgnoredInPipeline(confidence: Double) {
        let mockCamera = MockCameraService(authorizationState: .authorized)
        let samplePose = makeSamplePose()
        let mockDetector = MockHandPoseDetector(stubbedPose: samplePose)
        let mockClassifier = MockSignClassifier(
            stubbedResult: SignClassification(
                label: "A",
                confidence: confidence,
                candidates: [
                    SignCandidate(label: "A", confidence: confidence),
                    SignCandidate(label: "S", confidence: 0.05)
                ]
            )
        )
        let clock = ControllableClock()

        let service = SignRecognitionService(
            cameraService: mockCamera,
            handPoseDetector: mockDetector,
            signClassifier: mockClassifier,
            confidenceThreshold: 0.85,
            holdDuration: 1.0,
            dateProvider: clock
        )

        let state = service.processPose(samplePose)
        #expect(state == .lowConfidence(label: "A", confidence: confidence, runnerUp: SignCandidate(label: "S", confidence: 0.05)))
        #expect(!state.isRecognized)
        #expect(state.progress == 0.0)
        #expect(service.currentState == state)
    }

    @Test(
        "Pipeline exact threshold boundary determines lowConfidence vs detecting",
        arguments: [
            (0.849, false),
            (0.850, true),
            (0.920, true)
        ]
    )
    func exactThresholdBoundaryInPipeline(confidence: Double, shouldStartHold: Bool) {
        let mockCamera = MockCameraService(authorizationState: .authorized)
        let samplePose = makeSamplePose()
        let mockClassifier = MockSignClassifier(stubbedResult: SignClassification(label: "B", confidence: confidence))
        let clock = ControllableClock()

        let service = SignRecognitionService(
            cameraService: mockCamera,
            handPoseDetector: MockHandPoseDetector(stubbedPose: samplePose),
            signClassifier: mockClassifier,
            confidenceThreshold: 0.85,
            holdDuration: 1.0,
            dateProvider: clock
        )

        let state = service.processPose(samplePose)
        if shouldStartHold {
            #expect(state == .detecting(label: "B", confidence: confidence, progress: 0.0, runnerUp: nil))
            #expect(!state.isRecognized)
        } else {
            #expect(state == .lowConfidence(label: "B", confidence: confidence, runnerUp: nil))
            #expect(!state.isRecognized)
        }
    }

    @Test(
        "Pipeline hold duration progression: < 1.0s is detecting, >= 1.0s is recognized",
        arguments: [
            (0.0, false),
            (0.3, false),
            (0.6, false),
            (0.99, false),
            (1.0, true),
            (1.5, true)
        ]
    )
    func holdDurationProgressionInPipeline(holdSeconds: Double, expectedRecognized: Bool) {
        let mockCamera = MockCameraService(authorizationState: .authorized)
        let samplePose = makeSamplePose()
        let mockClassifier = MockSignClassifier(stubbedResult: SignClassification(label: "F", confidence: 0.94))
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 1000))

        let service = SignRecognitionService(
            cameraService: mockCamera,
            handPoseDetector: MockHandPoseDetector(stubbedPose: samplePose),
            signClassifier: mockClassifier,
            confidenceThreshold: 0.85,
            holdDuration: 1.0,
            dateProvider: clock
        )

        // Initial evaluation at t = 0
        _ = service.processPose(samplePose)

        // Advance controllable clock
        clock.advance(by: holdSeconds)
        let state = service.processPose(samplePose)

        if expectedRecognized {
            #expect(state.isRecognized)
            #expect(state.progress == 1.0)
            #expect(state == .recognized(label: "F", confidence: 0.94, runnerUp: nil))
        } else {
            #expect(!state.isRecognized)
            #expect(state.label == "F")
            #expect(abs(state.progress - holdSeconds) < 0.001)
        }
    }

    @Test("Label switching mid-hold resets the timer to 0.0s for the new sign in pipeline")
    func labelSwitchMidHoldResetsPipelineTimer() {
        let mockCamera = MockCameraService(authorizationState: .authorized)
        let samplePose = makeSamplePose()
        let mockClassifier = MockSignClassifier()
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 2000))

        let service = SignRecognitionService(
            cameraService: mockCamera,
            handPoseDetector: MockHandPoseDetector(stubbedPose: samplePose),
            signClassifier: mockClassifier,
            confidenceThreshold: 0.85,
            holdDuration: 1.0,
            dateProvider: clock
        )

        // Hold Sign A for 0.7s
        mockClassifier.stubbedResult = SignClassification(label: "A", confidence: 0.90)
        _ = service.processPose(samplePose)
        clock.advance(by: 0.7)
        let stateA = service.processPose(samplePose)
        #expect(stateA.label == "A")
        #expect(abs(stateA.progress - 0.7) < 0.001)
        #expect(!stateA.isRecognized)

        // Switch to Sign B -> timer resets for Sign B
        mockClassifier.stubbedResult = SignClassification(label: "B", confidence: 0.92)
        clock.advance(by: 0.05)
        let stateB0 = service.processPose(samplePose)
        #expect(stateB0.label == "B")
        #expect(abs(stateB0.progress - 0.0) < 0.001)

        // Hold Sign B for 0.5s -> progress is 0.5
        clock.advance(by: 0.5)
        let stateB1 = service.processPose(samplePose)
        #expect(stateB1.label == "B")
        #expect(abs(stateB1.progress - 0.5) < 0.001)
        #expect(!stateB1.isRecognized)

        // Hold Sign B for additional 0.5s (total 1.0s of B) -> recognized
        clock.advance(by: 0.5)
        let stateB2 = service.processPose(samplePose)
        #expect(stateB2.isRecognized)
        #expect(stateB2 == .recognized(label: "B", confidence: 0.92, runnerUp: nil))
    }

    @Test("No-hand resets pipeline to noHand state and resets hold timer")
    func noHandResetsPipeline() {
        let mockCamera = MockCameraService(authorizationState: .authorized)
        let samplePose = makeSamplePose()
        let mockClassifier = MockSignClassifier(stubbedResult: SignClassification(label: "L", confidence: 0.95))
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 3000))

        let service = SignRecognitionService(
            cameraService: mockCamera,
            handPoseDetector: MockHandPoseDetector(stubbedPose: samplePose),
            signClassifier: mockClassifier,
            confidenceThreshold: 0.85,
            holdDuration: 1.0,
            dateProvider: clock
        )

        // Hold L for 0.8s
        _ = service.processPose(samplePose)
        clock.advance(by: 0.8)
        let active = service.processPose(samplePose)
        #expect(abs(active.progress - 0.8) < 0.001)

        // Hand lost -> nil pose
        let noHand = service.processPose(nil)
        #expect(noHand == .noHand)
        #expect(service.currentState == .noHand)
        #expect(service.currentPose == nil)

        // Hand returns -> starts from 0.0s
        clock.advance(by: 0.1)
        let restarted = service.processPose(samplePose)
        #expect(restarted.label == "L")
        #expect(abs(restarted.progress - 0.0) < 0.001)
        #expect(!restarted.isRecognized)
    }

    @Test(
        "Background class is never recognized in pipeline regardless of confidence",
        arguments: [0.85, 0.95, 0.99, 1.00]
    )
    func backgroundClassNeverRecognizedInPipeline(confidence: Double) {
        let mockCamera = MockCameraService(authorizationState: .authorized)
        let samplePose = makeSamplePose()
        let mockClassifier = MockSignClassifier(stubbedResult: SignClassification(label: "Background", confidence: confidence))
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 4000))

        let service = SignRecognitionService(
            cameraService: mockCamera,
            handPoseDetector: MockHandPoseDetector(stubbedPose: samplePose),
            signClassifier: mockClassifier,
            confidenceThreshold: 0.85,
            holdDuration: 1.0,
            dateProvider: clock
        )

        _ = service.processPose(samplePose)
        clock.advance(by: 3.0)
        let state = service.processPose(samplePose)

        #expect(state == .lowConfidence(label: "Background", confidence: confidence, runnerUp: nil))
        #expect(!state.isRecognized)
        #expect(state.progress == 0.0)
    }

    @Test("Errors in detector and classifier propagate or reset pipeline gracefully")
    func errorPropagationAndGracefulHandling() async {
        let mockCamera = MockCameraService(authorizationState: .authorized)
        let samplePose = makeSamplePose()
        let mockDetector = MockHandPoseDetector(stubbedPose: samplePose)
        let mockClassifier = MockSignClassifier()

        let service = SignRecognitionService(
            cameraService: mockCamera,
            handPoseDetector: mockDetector,
            signClassifier: mockClassifier
        )

        // 1. Classifier throws predictionFailed error via evaluatePose
        mockClassifier.shouldThrowError = SignClassificationError.predictionFailed("CoreML inference failure")
        #expect(throws: SignClassificationError.predictionFailed("CoreML inference failure")) {
            try service.evaluatePose(samplePose)
        }

        // 2. processPose handles classifier error gracefully without throwing
        let gracefulPoseState = service.processPose(samplePose)
        #expect(gracefulPoseState == .noHand)

        // 3. Detector throws missingKeypoints via evaluateFrame
        let buffer = makeSampleBuffer()
        mockDetector.shouldThrowError = SignClassificationError.missingKeypoints
        await #expect(throws: SignClassificationError.missingKeypoints) {
            try await service.evaluateFrame(buffer)
        }

        // 4. processFrame handles detector error gracefully without throwing
        await service.processFrame(buffer)
        #expect(service.currentState == .noHand)
    }

    @Test("AsyncStream broadcasts sequential state transitions")
    func asyncStreamBroadcastsTransitions() async {
        let mockCamera = MockCameraService(authorizationState: .authorized)
        let samplePose = makeSamplePose()
        let mockClassifier = MockSignClassifier(stubbedResult: SignClassification(label: "F", confidence: 0.95))
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 5000))

        let service = SignRecognitionService(
            cameraService: mockCamera,
            handPoseDetector: MockHandPoseDetector(stubbedPose: samplePose),
            signClassifier: mockClassifier,
            confidenceThreshold: 0.85,
            holdDuration: 1.0,
            dateProvider: clock
        )

        var statesReceived: [RecognitionState] = []
        let stream = service.stateStream

        let streamTask = Task {
            for await state in stream {
                statesReceived.append(state)
                if state.isRecognized {
                    break
                }
            }
        }

        // Give stream time to register
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Emit detecting
        _ = service.processPose(samplePose)

        // Advance to recognized
        clock.advance(by: 1.0)
        _ = service.processPose(samplePose)

        _ = await streamTask.result
        #expect(!statesReceived.isEmpty)
        #expect(statesReceived.contains(where: { $0.isRecognized }))
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
