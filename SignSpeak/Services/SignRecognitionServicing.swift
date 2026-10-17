import Foundation

/// State of sign recognition emitted to view models.
public enum RecognitionState: Sendable, Equatable {
    /// No hand detected in the camera frame.
    case noHand
    /// A hand is present and a candidate sign is actively being evaluated.
    case detecting(label: String, confidence: Double)
    /// A sign has passed the confidence threshold and stability hold duration.
    case recognized(label: String, confidence: Double)
}

/// Pipeline service coordinating camera input, hand pose detection, and classifier evaluation.
public protocol SignRecognitionServicing: Sendable {
    /// Async stream of real-time recognition state transitions.
    var stateStream: AsyncStream<RecognitionState> { get }

    /// Starts processing camera frames through the recognition pipeline.
    func startRecognition() async

    /// Stops the recognition pipeline.
    func stopRecognition() async
}

/// Fallback sign recognition service stub.
public final class StubSignRecognitionService: SignRecognitionServicing, @unchecked Sendable {
    public var stateStream: AsyncStream<RecognitionState> {
        AsyncStream { $0.finish() }
    }

    public init() {}
    public func startRecognition() async {}
    public func stopRecognition() async {}
}
