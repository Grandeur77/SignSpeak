import Foundation
import CoreML
import os

/// Production Core ML sign classifier wrapping `StaticSignClassifier`.
/// Evaluates raw 3x21 MLMultiArray hand pose keypoints, returns the top predicted sign,
/// and outputs confidence distributions for runner-up candidates.
public final class SignClassifier: SignClassifying, @unchecked Sendable {
    private let model: StaticSignClassifier

    /// Produces an optimized MLModelConfiguration with Neural Engine and GPU acceleration.
    public static func defaultConfiguration() -> MLModelConfiguration {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        configuration.allowLowPrecisionAccumulationOnGPU = true
        return configuration
    }

    /// Initializes the classifier with an optional preconfigured Core ML model configuration.
    public init(configuration: MLModelConfiguration = SignClassifier.defaultConfiguration()) throws {
        do {
            self.model = try StaticSignClassifier(configuration: configuration)
            AppLogger.recognition.info("StaticSignClassifier initialized with computeUnits=.all and GPU low precision accumulation.")
        } catch {
            AppLogger.recognition.error("StaticSignClassifier initialization failed: \(error.localizedDescription)")
            throw SignClassificationError.modelInitializationFailed(error.localizedDescription)
        }
    }

    /// Initializer allowing injection of an existing model instance.
    init(model: StaticSignClassifier) {
        self.model = model
    }

    /// Classifies a detected hand pose by passing its MLMultiArray keypoints to the Core ML model.
    public func classify(pose: HandPose) throws -> SignClassification? {
        guard let keypoints = pose.keypointsMultiArray else {
            throw SignClassificationError.missingKeypoints
        }

        do {
            let output = try model.prediction(poses: keypoints)
            let probabilities = output.labelProbabilities

            // Sort candidate predictions descending by confidence
            let sortedCandidates = probabilities
                .sorted(by: { $0.value > $1.value })
                .map { SignCandidate(label: $0.key, confidence: $0.value) }

            let topLabel = output.label
            let topConfidence = probabilities[topLabel] ?? 0.0

            return SignClassification(
                label: topLabel,
                confidence: topConfidence,
                candidates: Array(sortedCandidates.prefix(3))
            )
        } catch {
            throw SignClassificationError.predictionFailed(error.localizedDescription)
        }
    }
}
