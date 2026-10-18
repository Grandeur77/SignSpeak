import Foundation
import CoreMedia

/// Production sign recognition coordinator pipeline.
/// Pipes camera frames -> Vision Hand Pose -> Core ML Classifier -> Stability Filter.
/// Emits state transitions over an `AsyncStream<RecognitionState>`.
public final class SignRecognitionService: SignRecognitionServicing, @unchecked Sendable {
    private let cameraService: any CameraServicing
    private let handPoseDetector: any HandPoseDetecting
    private let signClassifier: any SignClassifying
    private let stabilityFilter: StabilityFilter
    private let lock = NSLock()

    private var activeTask: Task<Void, Never>?
    private var continuations: [UUID: AsyncStream<RecognitionState>.Continuation] = [:]
    private var _currentState: RecognitionState = .noHand
    private var _currentPose: HandPose?
    private var _currentClassification: SignClassification?

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

    public var confidenceThreshold: Double {
        stabilityFilter.confidenceThreshold
    }

    public var holdDuration: TimeInterval {
        stabilityFilter.holdDuration
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

    private func removeContinuation(for id: UUID) {
        lock.lock()
        continuations.removeValue(forKey: id)
        lock.unlock()
    }

    public init(
        cameraService: any CameraServicing,
        handPoseDetector: any HandPoseDetecting,
        signClassifier: any SignClassifying,
        stabilityFilter: StabilityFilter? = nil,
        confidenceThreshold: Double = 0.85,
        holdDuration: TimeInterval = 1.0,
        dateProvider: any DateProviding = SystemDateProvider()
    ) {
        self.cameraService = cameraService
        self.handPoseDetector = handPoseDetector
        self.signClassifier = signClassifier
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

        activeTask = Task { [weak self] in
            guard let self else { return }
            for await sampleBuffer in self.cameraService.frameStream {
                if Task.isCancelled { break }
                await self.processFrame(sampleBuffer)
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

    /// Evaluates a detected pose directly, propagating any classifier error.
    @discardableResult
    public func evaluatePose(_ pose: HandPose?) throws -> RecognitionState {
        let classification: SignClassification?
        if let pose {
            classification = try signClassifier.classify(pose: pose)
        } else {
            classification = nil
        }

        let newState = stabilityFilter.process(classification: classification)
        broadcast(state: newState, pose: pose, classification: classification)
        return newState
    }

    private func broadcast(state: RecognitionState, pose: HandPose?, classification: SignClassification?) {
        lock.lock()
        _currentState = state
        _currentPose = pose
        _currentClassification = classification
        let targets = Array(continuations.values)
        lock.unlock()

        for continuation in targets {
            continuation.yield(state)
        }
    }

    private func stopPipeline() {
        activeTask?.cancel()
        activeTask = nil
    }
}
