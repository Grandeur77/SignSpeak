import Foundation
import CoreMedia
import CoreGraphics
import Vision
import CoreML
import QuartzCore

/// Production implementation of HandPoseDetecting using Apple's Vision framework (`VNDetectHumanHandPoseRequest`).
/// Analyzes CMSampleBuffer frames, filters low-confidence joints, generates Create ML-compatible keypoint arrays,
/// and throttles detection to ~15 fps for smooth, power-efficient on-device processing.
public final class HandPoseDetector: HandPoseDetecting, @unchecked Sendable {
    public let confidenceThreshold: Float
    private let targetFrameRate: Double
    private let minInterval: TimeInterval
    private let lock = NSLock()

    private let visionQueue = DispatchQueue(label: "com.mileesha.SignSpeak.vision.handPose", qos: .userInteractive)
    private var lastExecutionTime: TimeInterval = 0
    private var lastResult: HandPose?

    public init(confidenceThreshold: Float = 0.3, targetFrameRate: Double = 15.0) {
        self.confidenceThreshold = confidenceThreshold
        self.targetFrameRate = targetFrameRate
        self.minInterval = 1.0 / max(1.0, targetFrameRate)
    }

    /// Detects a single hand pose from a camera video frame.
    /// Throttles detection to ~15 fps and extracts the 21 anatomical joints and MLMultiArray.
    public nonisolated func detectPose(in sampleBuffer: CMSampleBuffer) async throws -> HandPose? {
        let currentTime = CACurrentMediaTime()
        lock.lock()
        if currentTime - lastExecutionTime < minInterval {
            // Return cached result during throttling interval to maintain smooth UI
            let cached = lastResult
            lock.unlock()
            return cached
        }
        lastExecutionTime = currentTime
        lock.unlock()

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HandPose?, Error>) in
            visionQueue.async { [weak self, sampleBuffer] in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }

                _ = sampleBuffer // retain buffer for pixelBuffer lifetime
                do {
                    let pose = try self.performDetection(on: pixelBuffer)
                    self.lock.lock()
                    self.lastExecutionTime = CACurrentMediaTime()
                    self.lastResult = pose
                    self.lock.unlock()
                    continuation.resume(returning: pose)
                } catch {
                    self.lock.lock()
                    self.lastResult = nil
                    self.lock.unlock()
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Vision Pipeline

    private func performDetection(on pixelBuffer: CVPixelBuffer) throws -> HandPose? {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first else {
            return nil
        }

        let recognizedPoints = try observation.recognizedPoints(.all)
        var validJoints: [String: HandJoint] = [:]

        for (jointKey, point) in recognizedPoints {
            let jointName = jointKey.rawValue.rawValue
            if point.confidence >= confidenceThreshold {
                validJoints[jointName] = HandJoint(
                    name: jointName,
                    position: CGPoint(x: point.location.x, y: point.location.y),
                    confidence: point.confidence
                )
            }
        }

        // Require at least 4 valid joints to qualify as a detected hand
        guard validJoints.count >= 4 else {
            return nil
        }

        let multiArray = try? observation.keypointsMultiArray()
        let isRightHand = (observation.chirality == .right || observation.chirality == .unknown)

        return HandPose(
            joints: validJoints,
            confidence: observation.confidence,
            isRightHand: isRightHand,
            keypointsMultiArray: multiArray
        )
    }
}
