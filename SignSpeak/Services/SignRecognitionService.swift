import Foundation
import CoreMedia
import QuartzCore
import os

/// Production sign recognition coordinator pipeline.
/// Pipes camera frames -> Vision Hand Pose -> Combined Static/Motion Classifiers -> Stability Filter.
/// Dynamically arbitrates between static hand-pose model and temporal motion model based on movement displacement.
/// Emits state transitions over an `AsyncStream<RecognitionState>`.
public final class SignRecognitionService: SignRecognitionServicing, @unchecked Sendable {
    private let cameraService: any CameraServicing
    private let handPoseDetector: any HandPoseDetecting
    private let signClassifier: any SignClassifying
    private let motionSignClassifier: (any MotionSignClassifying)?
    private let motionWindowBuffer: MotionWindowBuffer
    public let motionDisplacementThreshold: Double
    public let motionInferenceStride: Int
    private let stabilityFilter: StabilityFilter
    private let dateProvider: any DateProviding
    private let lock = NSLock()

    private var activeTask: Task<Void, Never>?
    private var continuations: [UUID: AsyncStream<RecognitionState>.Continuation] = [:]
    private var _currentState: RecognitionState = .noHand
    private var _currentPose: HandPose?
    private var _currentClassification: SignClassification?
    private var frameCount: Int = 0
    private var isProcessingFrame: Bool = false
    private var lastProcessedFrameTimestamp: TimeInterval = 0
    public var minFrameInterval: TimeInterval = 0.045 // ~22 fps maximum inference rate (Phase 15.2)

    public var currentState: RecognitionState {
        lock.lock()
        defer { lock.unlock() }
        return _currentState
    }

    public var currentPose: HandPose? {
        lock.lock()
        defer { lock.unlock() }
        return _currentPose
    }

    public var currentClassification: SignClassification? {
        lock.lock()
        defer { lock.unlock() }
        return _currentClassification
    }

    public var currentModelSource: RecognitionModelSource {
        lock.lock()
        defer { lock.unlock() }
        return _currentClassification?.modelSource ?? .none
    }

    public var confidenceThreshold: Double {
        stabilityFilter.confidenceThreshold
    }

    public var holdDuration: TimeInterval {
        stabilityFilter.holdDuration
    }

    public var motionDisplacement: Double {
        motionWindowBuffer.movementDisplacement
    }

    public var stateStream: AsyncStream<RecognitionState> {
        AsyncStream { continuation in
            let id = UUID()
            self.lock.lock()
            self.continuations[id] = continuation
            let current = self._currentState
            self.lock.unlock()

            // Emit initial state snapshot immediately
            continuation.yield(current)

            continuation.onTermination = { [weak self] _ in
                self?.removeContinuation(for: id)
            }
        }
    }

    nonisolated private func removeContinuation(for id: UUID) {
        lock.lock()
        continuations.removeValue(forKey: id)
        lock.unlock()
    }

    public init(
        cameraService: any CameraServicing,
        handPoseDetector: any HandPoseDetecting,
        signClassifier: any SignClassifying,
        motionSignClassifier: (any MotionSignClassifying)? = nil,
        motionWindowBuffer: MotionWindowBuffer = MotionWindowBuffer(targetFrameRate: 30.0, windowSize: 45),
        stabilityFilter: StabilityFilter? = nil,
        confidenceThreshold: Double = 0.85,
        holdDuration: TimeInterval = 1.0,
        motionDisplacementThreshold: Double = 0.15,
        motionInferenceStride: Int = 3,
        dateProvider: any DateProviding = SystemDateProvider()
    ) {
        self.cameraService = cameraService
        self.handPoseDetector = handPoseDetector
        self.signClassifier = signClassifier
        self.motionSignClassifier = motionSignClassifier
        self.motionWindowBuffer = motionWindowBuffer
        self.motionDisplacementThreshold = motionDisplacementThreshold
        self.motionInferenceStride = motionInferenceStride
        self.dateProvider = dateProvider
        self.stabilityFilter = stabilityFilter ?? StabilityFilter(
            confidenceThreshold: confidenceThreshold,
            holdDuration: holdDuration,
            dateProvider: dateProvider
        )
    }

    deinit {
        activeTask?.cancel()
        for continuation in continuations.values {
            continuation.finish()
        }
    }

    public func startRecognition() async {
        stopPipeline()
        AppLogger.recognition.info("Sign recognition pipeline started (frame rate throttled to ~22 fps max)")

        activeTask = Task { [weak self] in
            guard let self else { return }
            for await sampleBuffer in self.cameraService.frameStream {
                if Task.isCancelled { break }
                let now = CACurrentMediaTime()
                if now - self.lastProcessedFrameTimestamp < self.minFrameInterval {
                    continue // Frame skipped to conserve CPU and energy (Phase 15.2)
                }
                if self.isProcessingFrame {
                    continue // Drop frame when previous inference is in-flight
                }
                self.isProcessingFrame = true
                self.lastProcessedFrameTimestamp = now
                await self.processFrame(sampleBuffer)
                self.isProcessingFrame = false
            }
        }
    }

    public func stopRecognition() async {
        stopPipeline()
        reset()
    }

    public func reset() {
        lock.lock()
        stabilityFilter.reset()
        motionWindowBuffer.reset()
        frameCount = 0
        _currentState = .noHand
        _currentPose = nil
        _currentClassification = nil
        let targets = Array(continuations.values)
        lock.unlock()

        for continuation in targets {
            continuation.yield(.noHand)
        }
    }

    /// Evaluates an individual frame, catching errors and resetting gracefully for continuous camera streaming.
    public func processFrame(_ sampleBuffer: CMSampleBuffer) async {
        do {
            _ = try await evaluateFrame(sampleBuffer)
        } catch {
            let newState = stabilityFilter.process(classification: nil)
            broadcast(state: newState, pose: nil, classification: nil)
        }
    }

    /// Evaluates an individual frame, propagating errors thrown by detector or classifier.
    @discardableResult
    public func evaluateFrame(_ sampleBuffer: CMSampleBuffer) async throws -> RecognitionState {
        let pose = try await handPoseDetector.detectPose(in: sampleBuffer)
        return try evaluatePose(pose)
    }

    /// Evaluates a detected pose directly, handling errors gracefully.
    @discardableResult
    public func processPose(_ pose: HandPose?) -> RecognitionState {
        do {
            return try evaluatePose(pose)
        } catch {
            let newState = stabilityFilter.process(classification: nil)
            broadcast(state: newState, pose: pose, classification: nil)
            return newState
        }
    }

    /// Evaluates a detected pose with combined static & motion classifier arbitration.
    @discardableResult
    public func evaluatePose(_ pose: HandPose?) throws -> RecognitionState {
        let classification: SignClassification?

        if let pose {
            let timestamp = dateProvider.now.timeIntervalSince1970
            motionWindowBuffer.append(pose: pose, timestamp: timestamp)
            frameCount += 1

            let displacement = motionWindowBuffer.movementDisplacement
            var motionClassification: SignClassification? = nil

            // 1. Evaluate motion sequence model when movement is detected and buffer is filled
            if displacement >= motionDisplacementThreshold,
               motionWindowBuffer.isFull,
               (frameCount % motionInferenceStride == 0),
               let motionClassifier = motionSignClassifier {
                motionClassification = try? motionClassifier.classify(window: motionWindowBuffer.keypointWindow)
            }

            // 2. Arbitration: Motion wins when movement exceeds threshold and returns high confidence
            if let motionResult = motionClassification, motionResult.confidence >= (confidenceThreshold * 0.9) {
                classification = SignClassification(
                    label: motionResult.label,
                    confidence: motionResult.confidence,
                    candidates: motionResult.candidates,
                    modelSource: .motionModel
                )
            } else {
                // Static model wins
                if let staticResult = try signClassifier.classify(pose: pose) {
                    classification = SignClassification(
                        label: staticResult.label,
                        confidence: staticResult.confidence,
                        candidates: staticResult.candidates,
                        modelSource: .staticModel
                    )
                } else {
                    classification = nil
                }
            }
        } else {
            motionWindowBuffer.reset()
            classification = nil
        }

        let newState = stabilityFilter.process(classification: classification)
        broadcast(state: newState, pose: pose, classification: classification)
        return newState
    }

    private func broadcast(state: RecognitionState, pose: HandPose?, classification: SignClassification?) {
        lock.lock()
        let previous = _currentState
        _currentState = state
        _currentPose = pose
        _currentClassification = classification
        let targets = Array(continuations.values)
        lock.unlock()

        if previous != state {
            switch state {
            case .recognized(let sign, let confidence, _):
                AppLogger.recognition.info("Sign recognized: \(sign, privacy: .public) (\(Int(confidence * 100))%)")
            case .detecting(let sign, _, let progress, _):
                AppLogger.recognition.debug("Sign detecting: \(sign, privacy: .public) (\(Int(progress * 100))%)")
            case .lowConfidence:
                AppLogger.recognition.debug("Low confidence hand gesture")
            case .noHand:
                AppLogger.recognition.debug("No hand visible")
            }
        }

        for continuation in targets {
            continuation.yield(state)
        }
    }

    private func stopPipeline() {
        activeTask?.cancel()
        activeTask = nil
    }
}
