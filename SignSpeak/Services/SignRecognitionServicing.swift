import Foundation

/// State of sign recognition emitted to view models.
public enum RecognitionState: Sendable, Equatable {
    /// No hand detected in the camera frame.
    case noHand

    /// A hand is present, but confidence is below threshold or classification is background.
    case lowConfidence(label: String?, confidence: Double, runnerUp: SignCandidate? = nil)

    /// A candidate sign exceeds threshold and is actively held towards lock-in confirmation.
    /// `progress` is 0.0 ... 1.0.
    case detecting(label: String, confidence: Double, progress: Double, runnerUp: SignCandidate? = nil)

    /// A sign has maintained confidence >= threshold for the full hold duration (e.g. 1.0s).
    case recognized(label: String, confidence: Double, runnerUp: SignCandidate? = nil)

    /// The detected sign label, if any.
    public var label: String? {
        switch self {
        case .noHand:
            return nil
        case .lowConfidence(let label, _, _):
            return label
        case .detecting(let label, _, _, _):
            return label
        case .recognized(let label, _, _):
            return label
        }
    }

    /// Confidence score of the current evaluation (0.0 ... 1.0).
    public var confidence: Double {
        switch self {
        case .noHand:
            return 0.0
        case .lowConfidence(_, let confidence, _):
            return confidence
        case .detecting(_, let confidence, _, _):
            return confidence
        case .recognized(_, let confidence, _):
            return confidence
        }
    }

    /// Progress towards full recognition hold duration (0.0 ... 1.0).
    public var progress: Double {
        switch self {
        case .noHand, .lowConfidence:
            return 0.0
        case .detecting(_, _, let progress, _):
            return progress
        case .recognized:
            return 1.0
        }
    }

    /// Close runner-up candidate prediction if detected.
    public var runnerUp: SignCandidate? {
        switch self {
        case .noHand:
            return nil
        case .lowConfidence(_, _, let runnerUp):
            return runnerUp
        case .detecting(_, _, _, let runnerUp):
            return runnerUp
        case .recognized(_, _, let runnerUp):
            return runnerUp
        }
    }

    /// True if the sign has locked in successfully.
    public var isRecognized: Bool {
        if case .recognized = self { return true }
        return false
    }
}

/// Pipeline service coordinating camera input, hand pose detection, Core ML classification, and temporal stability.
public protocol SignRecognitionServicing: Sendable {
    /// Async stream of real-time recognition state transitions.
    var stateStream: AsyncStream<RecognitionState> { get }

    /// Current recognition state snapshot.
    var currentState: RecognitionState { get }

    /// Minimum confidence threshold (0.0 ... 1.0) required to initiate or advance confirmation hold.
    var confidenceThreshold: Double { get }

    /// Required hold duration (in seconds) to confirm a recognized sign.
    var holdDuration: TimeInterval { get }

    /// Starts processing camera frames through the recognition pipeline.
    func startRecognition() async

    /// Stops the recognition pipeline.
    func stopRecognition() async

    /// Resets stability state and hold timers.
    func reset()

    /// Evaluates a detected hand pose and returns the updated recognition state.
    @discardableResult
    func processPose(_ pose: HandPose?) -> RecognitionState
}

/// Fallback sign recognition service stub.
public final class StubSignRecognitionService: SignRecognitionServicing, @unchecked Sendable {
    public var stateStream: AsyncStream<RecognitionState> {
        AsyncStream { continuation in
            continuation.yield(self.currentState)
            continuation.finish()
        }
    }

    public var currentState: RecognitionState
    public var confidenceThreshold: Double
    public var holdDuration: TimeInterval

    public init(
        currentState: RecognitionState = .noHand,
        confidenceThreshold: Double = 0.85,
        holdDuration: TimeInterval = 1.0
    ) {
        self.currentState = currentState
        self.confidenceThreshold = confidenceThreshold
        self.holdDuration = holdDuration
    }

    public func startRecognition() async {}
    public func stopRecognition() async {}
    public func reset() {
        currentState = .noHand
    }

    @discardableResult
    public func processPose(_ pose: HandPose?) -> RecognitionState {
        currentState
    }
}


