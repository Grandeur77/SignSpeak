import Foundation
import CoreMedia
import CoreGraphics
import Vision
import CoreML

/// Connection between two skeletal hand joints.
public struct BonePair: Sendable, Hashable {
    public let startJoint: String
    public let endJoint: String

    public init(_ startJoint: String, _ endJoint: String) {
        self.startJoint = startJoint
        self.endJoint = endJoint
    }
}

/// Single detected hand landmark joint with normalized position (0...1, bottom-left origin) and confidence.
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

/// Normalized 21-joint skeletal pose detected from a video frame, including raw keypoints MLMultiArray.
public struct HandPose: @unchecked Sendable, Equatable {
    public let joints: [String: HandJoint]
    public let confidence: Float
    public let isRightHand: Bool
    public let keypointsMultiArray: MLMultiArray?

    public var allJoints: [HandJoint] {
        Array(joints.values)
    }

    public init(
        joints: [String: HandJoint],
        confidence: Float,
        isRightHand: Bool = true,
        keypointsMultiArray: MLMultiArray? = nil
    ) {
        self.joints = joints
        self.confidence = confidence
        self.isRightHand = isRightHand
        self.keypointsMultiArray = keypointsMultiArray
    }

    public func joint(named name: String) -> HandJoint? {
        joints[name]
    }

    public static func == (lhs: HandPose, rhs: HandPose) -> Bool {
        lhs.confidence == rhs.confidence &&
        lhs.isRightHand == rhs.isRightHand &&
        lhs.joints == rhs.joints
    }

    /// Standard anatomical bone connections for the 21 Vision hand joints.
    public static let standardBones: [BonePair] = [
        // Thumb
        BonePair(VNHumanHandPoseObservation.JointName.wrist.rawValue.rawValue, VNHumanHandPoseObservation.JointName.thumbCMC.rawValue.rawValue),
        BonePair(VNHumanHandPoseObservation.JointName.thumbCMC.rawValue.rawValue, VNHumanHandPoseObservation.JointName.thumbMP.rawValue.rawValue),
        BonePair(VNHumanHandPoseObservation.JointName.thumbMP.rawValue.rawValue, VNHumanHandPoseObservation.JointName.thumbIP.rawValue.rawValue),
        BonePair(VNHumanHandPoseObservation.JointName.thumbIP.rawValue.rawValue, VNHumanHandPoseObservation.JointName.thumbTip.rawValue.rawValue),

        // Index
        BonePair(VNHumanHandPoseObservation.JointName.wrist.rawValue.rawValue, VNHumanHandPoseObservation.JointName.indexMCP.rawValue.rawValue),
        BonePair(VNHumanHandPoseObservation.JointName.indexMCP.rawValue.rawValue, VNHumanHandPoseObservation.JointName.indexPIP.rawValue.rawValue),
        BonePair(VNHumanHandPoseObservation.JointName.indexPIP.rawValue.rawValue, VNHumanHandPoseObservation.JointName.indexDIP.rawValue.rawValue),
        BonePair(VNHumanHandPoseObservation.JointName.indexDIP.rawValue.rawValue, VNHumanHandPoseObservation.JointName.indexTip.rawValue.rawValue),

        // Middle
        BonePair(VNHumanHandPoseObservation.JointName.wrist.rawValue.rawValue, VNHumanHandPoseObservation.JointName.middleMCP.rawValue.rawValue),
        BonePair(VNHumanHandPoseObservation.JointName.middleMCP.rawValue.rawValue, VNHumanHandPoseObservation.JointName.middlePIP.rawValue.rawValue),
        BonePair(VNHumanHandPoseObservation.JointName.middlePIP.rawValue.rawValue, VNHumanHandPoseObservation.JointName.middleDIP.rawValue.rawValue),
        BonePair(VNHumanHandPoseObservation.JointName.middleDIP.rawValue.rawValue, VNHumanHandPoseObservation.JointName.middleTip.rawValue.rawValue),

        // Ring
        BonePair(VNHumanHandPoseObservation.JointName.wrist.rawValue.rawValue, VNHumanHandPoseObservation.JointName.ringMCP.rawValue.rawValue),
        BonePair(VNHumanHandPoseObservation.JointName.ringMCP.rawValue.rawValue, VNHumanHandPoseObservation.JointName.ringPIP.rawValue.rawValue),
        BonePair(VNHumanHandPoseObservation.JointName.ringPIP.rawValue.rawValue, VNHumanHandPoseObservation.JointName.ringDIP.rawValue.rawValue),
        BonePair(VNHumanHandPoseObservation.JointName.ringDIP.rawValue.rawValue, VNHumanHandPoseObservation.JointName.ringTip.rawValue.rawValue),

        // Little
        BonePair(VNHumanHandPoseObservation.JointName.wrist.rawValue.rawValue, VNHumanHandPoseObservation.JointName.littleMCP.rawValue.rawValue),
        BonePair(VNHumanHandPoseObservation.JointName.littleMCP.rawValue.rawValue, VNHumanHandPoseObservation.JointName.littlePIP.rawValue.rawValue),
        BonePair(VNHumanHandPoseObservation.JointName.littlePIP.rawValue.rawValue, VNHumanHandPoseObservation.JointName.littleDIP.rawValue.rawValue),
        BonePair(VNHumanHandPoseObservation.JointName.littleDIP.rawValue.rawValue, VNHumanHandPoseObservation.JointName.littleTip.rawValue.rawValue),

        // Palm Knuckle Arch
        BonePair(VNHumanHandPoseObservation.JointName.indexMCP.rawValue.rawValue, VNHumanHandPoseObservation.JointName.middleMCP.rawValue.rawValue),
        BonePair(VNHumanHandPoseObservation.JointName.middleMCP.rawValue.rawValue, VNHumanHandPoseObservation.JointName.ringMCP.rawValue.rawValue),
        BonePair(VNHumanHandPoseObservation.JointName.ringMCP.rawValue.rawValue, VNHumanHandPoseObservation.JointName.littleMCP.rawValue.rawValue)
    ]
}

/// Protocol abstracting Vision hand pose detection.
public protocol HandPoseDetecting: Sendable {
    /// Minimum joint confidence threshold to consider a joint valid (default 0.3).
    var confidenceThreshold: Float { get }

    /// Detects a hand pose from a camera sample buffer frame.
    nonisolated func detectPose(in sampleBuffer: CMSampleBuffer) async throws -> HandPose?
}

/// Fallback hand pose detector stub.
public struct StubHandPoseDetector: HandPoseDetecting {
    public var confidenceThreshold: Float = 0.3

    public nonisolated init(confidenceThreshold: Float = 0.3) {
        self.confidenceThreshold = confidenceThreshold
    }

    public nonisolated func detectPose(in sampleBuffer: CMSampleBuffer) async throws -> HandPose? {
        nil
    }
}
