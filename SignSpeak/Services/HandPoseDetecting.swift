import Foundation
import CoreMedia
import CoreGraphics

/// Single detected hand landmark joint with normalized position and confidence.
public struct HandJoint: Sendable, Equatable, Hashable {
    public let name: String
    public let position: CGPoint
    public let confidence: Float

    public init(name: String, position: CGPoint, confidence: Float) {
        self.name = name
        self.position = position
        self.confidence = confidence
    }
}

/// Normalized 21-joint skeletal pose detected from a video frame.
public struct HandPose: Sendable, Equatable {
    public let joints: [HandJoint]
    public let confidence: Float
    public let isRightHand: Bool

    public init(joints: [HandJoint], confidence: Float, isRightHand: Bool) {
        self.joints = joints
        self.confidence = confidence
        self.isRightHand = isRightHand
    }
}

/// Protocol abstracting Vision hand pose detection.
public protocol HandPoseDetecting: Sendable {
    /// Detects a hand pose from a camera sample buffer frame.
    func detectPose(in sampleBuffer: CMSampleBuffer) async throws -> HandPose?
}

/// Fallback hand pose detector stub.
public struct StubHandPoseDetector: HandPoseDetecting {
    public init() {}
    public func detectPose(in sampleBuffer: CMSampleBuffer) async throws -> HandPose? {
        nil
    }
}
