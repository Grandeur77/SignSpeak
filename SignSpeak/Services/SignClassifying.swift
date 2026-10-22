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

/// Prediction output from the Core ML hand-sign classifier.
public struct SignClassification: Sendable, Equatable {
    public let label: String
    public let confidence: Double
    public let candidates: [SignCandidate]

    public init(label: String, confidence: Double, candidates: [SignCandidate] = []) {
        self.label = label
        self.confidence = confidence
        self.candidates = candidates
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
