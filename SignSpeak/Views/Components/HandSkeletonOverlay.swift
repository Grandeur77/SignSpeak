import SwiftUI
import Vision

/// Draws real-time skeletal joints and bone connections over the camera preview.
/// Converts Vision's normalized bottom-left coordinates into screen space,
/// handles front-camera mirroring and left-hand adaptation, and renders
/// an intuitive guide outline when no hand is present (per `30-practice-recognized` and `34-practice-no-hand`).
public struct HandSkeletonOverlay: View {
    let pose: HandPose?
    let isFrontCamera: Bool
    var isLeftHanded: Bool = false

    public init(pose: HandPose?, isFrontCamera: Bool = true, isLeftHanded: Bool = false) {
        self.pose = pose
        self.isFrontCamera = isFrontCamera
        self.isLeftHanded = isLeftHanded
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let pose, !pose.joints.isEmpty {
                    activeSkeletonView(pose: pose, size: geometry.size)
                } else {
                    noHandGuideView(size: geometry.size)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(pose != nil ? "Hand skeleton tracked on screen" : "No hand detected, guide outline shown")
    }

    // MARK: - Active Skeleton Rendering

    @ViewBuilder
    private func activeSkeletonView(pose: HandPose, size: CGSize) -> some View {
        // Draw connecting bones
        Path { path in
            for bone in HandPose.standardBones {
                if let startJoint = pose.joint(named: bone.startJoint),
                   let endJoint = pose.joint(named: bone.endJoint) {
                    let startPoint = convert(startJoint.position, in: size)
                    let endPoint = convert(endJoint.position, in: size)

                    path.move(to: startPoint)
                    path.addLine(to: endPoint)
                }
            }
        }
        .stroke(Color.brandTurquoise, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
        .shadow(color: Color.brandTurquoise.opacity(0.4), radius: 4)

        // Draw joint nodes
        ForEach(pose.allJoints, id: \.name) { joint in
            let point = convert(joint.position, in: size)
            let isKeyTip = isTip(joint.name)

            ZStack {
                Circle()
                    .fill(Color.brandTurquoise)
                    .frame(width: 14, height: 14)

                Circle()
                    .fill(isKeyTip ? Color.brandYellow : Color.white)
                    .frame(width: 8, height: 8)
            }
            .position(point)
        }
    }

    // MARK: - No Hand Guide View

    private var noHandGuideView: some View {
        noHandGuideView(size: CGSize(width: 300, height: 400))
    }

    private func noHandGuideView(size: CGSize) -> some View {
        VStack(spacing: Theme.Spacing.l) {
            Spacer()

            // Dashed stylized hand outline
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(
                        Color.brandTurquoise.opacity(0.6),
                        style: StrokeStyle(lineWidth: 2.5, dash: [8, 8])
                    )
                    .frame(width: 180, height: 260)

                Image(systemName: "hand.raised")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.brandTurquoise.opacity(0.4))
            }

            VStack(spacing: Theme.Spacing.xs) {
                Text("Place your hand inside the outline")
                    .font(.appSectionTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Camera auto-detects signing gestures in real-time")
                    .font(.appBody)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Spacing.l)

            // Lighting / Positioning Hint Banner (per 34-practice-no-hand.png)
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(Color.brandNavy)
                Text("Show your hand — ensure good lighting")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.brandNavy)
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
            .background(Color.brandYellow, in: Capsule())

            Spacer()
        }
        .padding(Theme.Spacing.m)
    }

    // MARK: - Coordinate Conversion

    /// Converts normalized Vision coordinates (0...1, origin bottom-left)
    /// to SwiftUI view coordinates (origin top-left) with mirroring.
    private func convert(_ point: CGPoint, in size: CGSize) -> CGPoint {
        var xNorm = point.x
        let yNorm = 1.0 - point.y // Flip bottom-left to top-left

        // Front camera mirroring
        let shouldMirror = isFrontCamera ? !isLeftHanded : isLeftHanded
        if shouldMirror {
            xNorm = 1.0 - xNorm
        }

        return CGPoint(x: xNorm * size.width, y: yNorm * size.height)
    }

    private func isTip(_ name: String) -> Bool {
        name.lowercased().contains("tip")
    }
}

#Preview("Hand Detected Preview") {
    ZStack {
        Color.black.ignoresSafeArea()

        HandSkeletonOverlay(
            pose: HandPose(
                joints: [
                    VNHumanHandPoseObservation.JointName.wrist.rawValue.rawValue: HandJoint(name: "wrist", position: CGPoint(x: 0.5, y: 0.2), confidence: 0.9),
                    VNHumanHandPoseObservation.JointName.thumbCMC.rawValue.rawValue: HandJoint(name: "thumbCMC", position: CGPoint(x: 0.42, y: 0.3), confidence: 0.9),
                    VNHumanHandPoseObservation.JointName.thumbMP.rawValue.rawValue: HandJoint(name: "thumbMP", position: CGPoint(x: 0.36, y: 0.4), confidence: 0.9),
                    VNHumanHandPoseObservation.JointName.thumbIP.rawValue.rawValue: HandJoint(name: "thumbIP", position: CGPoint(x: 0.34, y: 0.5), confidence: 0.9),
                    VNHumanHandPoseObservation.JointName.thumbTip.rawValue.rawValue: HandJoint(name: "thumbTip", position: CGPoint(x: 0.36, y: 0.58), confidence: 0.9),
                    VNHumanHandPoseObservation.JointName.indexMCP.rawValue.rawValue: HandJoint(name: "indexMCP", position: CGPoint(x: 0.46, y: 0.45), confidence: 0.9),
                    VNHumanHandPoseObservation.JointName.indexPIP.rawValue.rawValue: HandJoint(name: "indexPIP", position: CGPoint(x: 0.46, y: 0.58), confidence: 0.9),
                    VNHumanHandPoseObservation.JointName.indexDIP.rawValue.rawValue: HandJoint(name: "indexDIP", position: CGPoint(x: 0.46, y: 0.68), confidence: 0.9),
                    VNHumanHandPoseObservation.JointName.indexTip.rawValue.rawValue: HandJoint(name: "indexTip", position: CGPoint(x: 0.46, y: 0.76), confidence: 0.9)
                ],
                confidence: 0.92
            ),
            isFrontCamera: true
        )
    }
}

#Preview("No Hand Detected Preview") {
    ZStack {
        Color.black.ignoresSafeArea()
        HandSkeletonOverlay(pose: nil, isFrontCamera: true)
    }
}
