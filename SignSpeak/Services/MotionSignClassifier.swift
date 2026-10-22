import Foundation
import CoreML

/// Production classifier for dynamic ASL motion signs (J, Z, Hello, ThankYou, Please, etc.).
/// Evaluates a temporal window of hand pose keypoint arrays at 30 fps using Create ML Hand Action models.
public final class MotionSignClassifier: MotionSignClassifying, @unchecked Sendable {
    public let targetFrameRate: Double
    public let predictionWindow: Int

    private let model: MLModel?
    private let modelURL: URL?

    public init(
        targetFrameRate: Double = 30.0,
        predictionWindow: Int = 45,
        model: MLModel? = nil,
        configuration: MLModelConfiguration = MLModelConfiguration()
    ) {
        self.targetFrameRate = targetFrameRate
        self.predictionWindow = predictionWindow

        if let model {
            self.model = model
            self.modelURL = nil
        } else {
            // Check bundle for MotionSignClassifier compiled or raw resource
            if let compiledURL = Bundle.main.url(forResource: "MotionSignClassifier", withExtension: "mlmodelc") {
                self.model = try? MLModel(contentsOf: compiledURL, configuration: configuration)
                self.modelURL = compiledURL
            } else if let sourceURL = Bundle.main.url(forResource: "MotionSignClassifier", withExtension: "mlmodel"),
                      let compiledURL = try? MLModel.compileModel(at: sourceURL) {
                self.model = try? MLModel(contentsOf: compiledURL, configuration: configuration)
                self.modelURL = compiledURL
            } else {
                self.model = nil
                self.modelURL = nil
            }
        }
    }

    /// Returns true if a compiled Core ML model was located and loaded into memory.
    public var isModelLoaded: Bool {
        model != nil
    }

    /// Evaluates a sliding temporal window of hand-pose keypoints and outputs the predicted action.
    public func classify(window: [MLMultiArray]) throws -> SignClassification? {
        guard let model else {
            throw SignClassificationError.modelInitializationFailed(
                "MotionSignClassifier.mlmodel not found in bundle. Train the model in Create ML and drag it into Resources/ML/."
            )
        }

        guard window.count >= predictionWindow else {
            return nil
        }

        // Slice to exact prediction window length
        let activeWindow = Array(window.suffix(predictionWindow))

        do {
            // Concatenate keypoints into the expected temporal shape: [1, predictionWindow, 3, 21] or [predictionWindow, 3, 21]
            guard let firstArray = activeWindow.first else { return nil }
            let keypointShape = firstArray.shape.map { $0.intValue }

            var combinedShape: [NSNumber] = []
            if keypointShape.count == 2 {
                // Shape: [3, 21] -> Window Shape: [1, predictionWindow, 3, 21]
                combinedShape = [1, NSNumber(value: predictionWindow), NSNumber(value: keypointShape[0]), NSNumber(value: keypointShape[1])]
            } else {
                combinedShape = [1, NSNumber(value: predictionWindow), 3, 21]
            }

            let multiArray = try MLMultiArray(shape: combinedShape, dataType: .float32)
            let frameStride = 3 * 21

            for (frameIndex, keypoints) in activeWindow.enumerated() {
                let baseOffset = frameIndex * frameStride
                let count = min(frameStride, keypoints.count)
                for i in 0..<count {
                    let val = keypoints[i].floatValue
                    multiArray[baseOffset + i] = NSNumber(value: val)
                }
            }

            // Inspect model input feature names (Create ML typically names it "poses" or "keypoints")
            let inputName = model.modelDescription.inputDescriptionsByName.keys.first ?? "poses"
            let featureValue = MLFeatureValue(multiArray: multiArray)
            let featureProvider = try MLDictionaryFeatureProvider(dictionary: [inputName: featureValue])

            let prediction = try model.prediction(from: featureProvider)

            // Extract output label and probability distribution
            if let labelProbabilities = prediction.featureValue(for: "labelProbabilities")?.dictionaryValue as? [String: Double] {
                let sortedCandidates = labelProbabilities
                    .sorted(by: { $0.value > $1.value })
                    .map { SignCandidate(label: $0.key, confidence: $0.value) }

                let topLabel = prediction.featureValue(for: "label")?.stringValue ?? sortedCandidates.first?.label ?? "Background"
                let topConfidence = labelProbabilities[topLabel] ?? (sortedCandidates.first?.confidence ?? 0.0)

                return SignClassification(
                    label: topLabel,
                    confidence: topConfidence,
                    candidates: Array(sortedCandidates.prefix(3))
                )
            } else if let label = prediction.featureValue(for: "label")?.stringValue {
                return SignClassification(label: label, confidence: 0.90, candidates: [SignCandidate(label: label, confidence: 0.90)])
            }

            return nil
        } catch {
            throw SignClassificationError.predictionFailed(error.localizedDescription)
        }
    }
}
