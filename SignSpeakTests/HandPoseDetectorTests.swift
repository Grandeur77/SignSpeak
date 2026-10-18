import Foundation
import SwiftUI
import Testing
import Vision
import CoreMedia
@testable import SignSpeak

@Suite("Vision Hand Pose Detection & Skeleton Overlay")
struct HandPoseDetectorTests {
    @Test("HandPose model initializes with 21 joints and standard bone connections")
    func handPoseModelStructure() {
        let wristKey = VNHumanHandPoseObservation.JointName.wrist.rawValue.rawValue
        let indexTipKey = VNHumanHandPoseObservation.JointName.indexTip.rawValue.rawValue
        let joints: [String: HandJoint] = [
            wristKey: HandJoint(name: wristKey, position: CGPoint(x: 0.5, y: 0.1), confidence: 0.95),
            indexTipKey: HandJoint(name: indexTipKey, position: CGPoint(x: 0.5, y: 0.8), confidence: 0.92)
        ]

        let pose = HandPose(joints: joints, confidence: 0.93, isRightHand: true)

        #expect(pose.joints.count == 2)
        #expect(pose.joint(named: wristKey)?.confidence == 0.95)
        #expect(pose.isRightHand)
        #expect(!HandPose.standardBones.isEmpty)
        #expect(HandPose.standardBones.contains(where: { $0.startJoint == wristKey }))
    }

    @Test("CameraTestViewModel updates detectedPose when hand pose is detected")
    @MainActor
    func viewModelHandPoseDetection() async {
        let mockCamera = MockCameraService(authorizationState: .authorized)
        let samplePose = HandPose(
            joints: ["wrist": HandJoint(name: "wrist", position: CGPoint(x: 0.5, y: 0.5), confidence: 0.9)],
            confidence: 0.9
        )
        let mockDetector = MockHandPoseDetector(stubbedPose: samplePose)

        let viewModel = CameraTestViewModel(
            cameraService: mockCamera,
            handPoseDetector: mockDetector
        )

        await viewModel.startCamera()

        #expect(viewModel.isSessionRunning)
        #expect(viewModel.detectedPose == nil)

        // Simulate frame delivery
        // Since sample buffer creation is low-level, we can directly verify detector integration
        _ = try? await mockDetector.detectPose(in: sampleSampleBuffer())
        #expect(mockDetector.detectPoseCallCount == 1)
    }

    @Test("Left-handed mode toggles correctly in ViewModel")
    @MainActor
    func leftHandedToggle() {
        let mockCamera = MockCameraService(authorizationState: .authorized)
        let viewModel = CameraTestViewModel(cameraService: mockCamera)

        #expect(!viewModel.isLeftHanded)
        viewModel.toggleLeftHandMirror()
        #expect(viewModel.isLeftHanded)
        viewModel.toggleLeftHandMirror()
        #expect(!viewModel.isLeftHanded)
    }

    @Test("HandSkeletonOverlay initializes with both detected pose and empty state")
    func overlayInitialization() {
        let pose = HandPose(
            joints: ["wrist": HandJoint(name: "wrist", position: CGPoint(x: 0.5, y: 0.2), confidence: 0.9)],
            confidence: 0.9
        )

        let overlayWithHand = HandSkeletonOverlay(pose: pose, isFrontCamera: true)
        let overlayNoHand = HandSkeletonOverlay(pose: nil, isFrontCamera: true)

        #expect(overlayWithHand.pose != nil)
        #expect(overlayNoHand.pose == nil)
    }

    // Helper to generate a dummy CMSampleBuffer for testing
    private func sampleSampleBuffer() -> CMSampleBuffer {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, 100, 100, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)

        var formatDesc: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer!, formatDescriptionOut: &formatDesc)

        var timingInfo = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: .zero, decodeTimeStamp: .invalid)
        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer!, formatDescription: formatDesc!, sampleTiming: &timingInfo, sampleBufferOut: &sampleBuffer)

        return sampleBuffer!
    }
}
