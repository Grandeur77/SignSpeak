import Foundation

/// Prediction output from the Core ML hand-sign classifier.
public struct SignClassification: Sendable, Equatable {
    public let label: String
    public let confidence: Double

    public init(label: String, confidence: Double) {
        self.label = label
        self.confidence = confidence
    }
}

/// Protocol abstracting Core ML classification of hand landmarks.
public protocol SignClassifying: Sendable {
    /// Classifies a detected hand pose into an ASL sign label.
    func classify(pose: HandPose) throws -> SignClassification?
}

/// Fallback sign classifier stub.
public struct StubSignClassifier: SignClassifying {
    public init() {}
    public func classify(pose: HandPose) throws -> SignClassification? {
        nil
    }
}
