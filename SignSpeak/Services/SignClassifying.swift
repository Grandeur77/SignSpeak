import Foundation
import CoreML

/// Candidate sign with confidence score.
public struct SignCandidate: Sendable, Equatable {
    public let label: String
    public let confidence: Double

    public init(label: String, confidence: Double) {
        self.label = label
        self.confidence = confidence
    }
}

/// Origin model producing the classification.
public enum RecognitionModelSource: String, Sendable, Equatable {
    case staticModel = "Static Model"
    case motionModel = "Motion Model"
    case none = "None"
}

/// Prediction output from the Core ML hand-sign classifier.
public struct SignClassification: Sendable, Equatable {
    public let label: String
    public let confidence: Double
    public let candidates: [SignCandidate]
    public let modelSource: RecognitionModelSource

    public init(
        label: String,
        confidence: Double,
        candidates: [SignCandidate] = [],
        modelSource: RecognitionModelSource = .staticModel
    ) {
        self.label = label
        self.confidence = confidence
        self.candidates = candidates
        self.modelSource = modelSource
    }
}

/// Errors thrown by Core ML sign classification.
public enum SignClassificationError: LocalizedError, Equatable {
    case modelInitializationFailed(String)
    case missingKeypoints
    case predictionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .modelInitializationFailed(let reason):
            return "Failed to load Sign Classifier model: \(reason)"
        case .missingKeypoints:
            return "The detected hand pose does not contain raw MLMultiArray keypoints."
        case .predictionFailed(let reason):
            return "Sign classification failed: \(reason)"
        }
    }
}

/// Protocol abstracting Core ML classification of hand landmarks.
public protocol SignClassifying: Sendable {
    /// Classifies a detected hand pose into an ASL sign label.
    func classify(pose: HandPose) throws -> SignClassification?
}

/// Fallback sign classifier stub.
public struct StubSignClassifier: SignClassifying {
    public var stubbedResult: SignClassification?

    public nonisolated init(stubbedResult: SignClassification? = nil) {
        self.stubbedResult = stubbedResult
    }

    public func classify(pose: HandPose) throws -> SignClassification? {
        stubbedResult
    }
}

/// Protocol for dynamic motion sign classification from temporal sequences of hand poses.
public protocol MotionSignClassifying: Sendable {
    /// Frame rate expected by the action classifier (typically 30.0 fps).
    var targetFrameRate: Double { get }
    /// Number of sequential frames required in the temporal prediction window (e.g. 45 frames = 1.5s).
    var predictionWindow: Int { get }
    /// Evaluates a sliding temporal window of HandPose keypoints (MLMultiArray) and outputs the predicted action.
    func classify(window: [MLMultiArray]) throws -> SignClassification?
}

/// Fallback motion sign classifier stub.
public struct StubMotionSignClassifier: MotionSignClassifying {
    public var targetFrameRate: Double
    public var predictionWindow: Int
    public var stubbedResult: SignClassification?

    public init(
        targetFrameRate: Double = 30.0,
        predictionWindow: Int = 45,
        stubbedResult: SignClassification? = nil
    ) {
        self.targetFrameRate = targetFrameRate
        self.predictionWindow = predictionWindow
        self.stubbedResult = stubbedResult
    }

    public func classify(window: [MLMultiArray]) throws -> SignClassification? {
        stubbedResult
    }
}
