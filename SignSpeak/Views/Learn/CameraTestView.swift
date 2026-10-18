import SwiftUI
import AVFoundation

/// Camera debug screen with live AVFoundation preview, real-time Vision hand pose detection,
/// skeletal joint overlays, left-hand mirroring, and simulator fallbacks.
struct CameraTestView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dependencies) private var dependencies

    @State private var viewModel: CameraTestViewModel

    init(viewModel: CameraTestViewModel? = nil, dependencies: AppDependencies = .live) {
        if let viewModel {
            _viewModel = State(initialValue: viewModel)
        } else {
            _viewModel = State(initialValue: CameraTestViewModel(
                cameraService: dependencies.cameraService,
                handPoseDetector: dependencies.handPoseDetector,
                signClassifier: dependencies.signClassifier
            ))
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch viewModel.authorizationState {
            case .notDetermined:
                CameraPermissionView(
                    isDenied: false,
                    onRequestAccess: {
                        Task { await viewModel.requestAuthorization() }
                    },
                    onSkip: { dismiss() }
                )

            case .denied, .restricted:
                CameraPermissionView(
                    isDenied: true,
                    onRequestAccess: {},
                    onSkip: { dismiss() }
                )

            case .unavailableOnSimulator:
                simulatorUnavailableView

            case .authorized:
                cameraActiveView
            }
        }
        .navigationTitle("Camera Practice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
                .foregroundStyle(.white)
            }
        }
        .task {
            await viewModel.onAppear()
        }
        .onDisappear {
            Task { await viewModel.onDisappear() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            Task { await viewModel.handleScenePhaseChange(to: newPhase) }
        }
    }

    // MARK: - Active Camera View

    private var cameraActiveView: some View {
        GeometryReader { geometry in
            ZStack {
                // Live camera preview layer
                CameraPreviewView(
                    session: dependencies.cameraService.captureSession,
                    isMirrored: viewModel.currentPosition == .front
                )
                .ignoresSafeArea()

                // Vision hand skeleton and guide overlay
                HandSkeletonOverlay(
                    pose: viewModel.detectedPose,
                    isFrontCamera: viewModel.currentPosition == .front,
                    isLeftHanded: viewModel.isLeftHanded
                )
                .ignoresSafeArea()

                // Overlays
                VStack {
                    topStatusHeader
                        .padding(.top, geometry.safeAreaInsets.top > 0 ? 0 : Theme.Spacing.m)

                    Spacer()

                    bottomControlBar
                        .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 0 : Theme.Spacing.m)
                }
                .padding(.horizontal, Theme.Spacing.m)
            }
        }
    }

    // MARK: - Simulator Fallback View

    private var simulatorUnavailableView: some View {
        VStack(spacing: Theme.Spacing.l) {
            Spacer()

            VStack(spacing: Theme.Spacing.m) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.brandTurquoise)
                    .frame(width: 96, height: 96)
                    .background(Color.brandNavy, in: Circle())
                    .accessibilityHidden(true)

                Text("Camera Unavailable in Simulator")
                    .font(.appTitle)
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("Apple's iOS Simulator does not provide a virtual video camera. To test real-time gesture recognition, connect a physical iPhone running iOS 17 or later.")
                    .font(.appBody)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            .padding(Theme.Spacing.l)
            .background(.cardBackground, in: .rect(cornerRadius: Theme.Radius.card))

            Spacer()

            Button("Close Preview") {
                dismiss()
            }
            .buttonStyle(.secondary)
            .frame(maxWidth: 240)
            .padding(.bottom, Theme.Spacing.l)
        }
        .padding(Theme.Spacing.m)
        .background(.appBackground)
    }

    // MARK: - Overlays & Controls

    private var topStatusHeader: some View {
        VStack(spacing: Theme.Spacing.s) {
            HStack {
                // Processing status chip
                HStack(spacing: Theme.Spacing.xs) {
                    Circle()
                        .fill(Color.brandTurquoise)
                        .frame(width: 8, height: 8)
                    Text("Processed on this iPhone")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, Theme.Spacing.s)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.6), in: Capsule())

                Spacer()

                // Lens & Frame Badge
                HStack(spacing: Theme.Spacing.xs) {
                    Text(viewModel.currentPosition == .front ? "Front" : "Back")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                    if viewModel.frameCount > 0 {
                        Text("• \(viewModel.frameCount) frames")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, Theme.Spacing.s)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.6), in: Capsule())
            }

            // Real-time Hand Detection & Core ML Sign Prediction
            if let classification = viewModel.currentClassification {
                VStack(spacing: 4) {
                    HStack(spacing: Theme.Spacing.s) {
                        Circle()
                            .fill(classification.label == "Background" ? Color.brandYellow : Color.brandTurquoise)
                            .frame(width: 10, height: 10)

                        if classification.label == "Background" {
                            Text("Background • No sign")
                                .font(.headline)
                                .foregroundStyle(.white)
                        } else {
                            Text("Sign: \(classification.label)")
                                .font(.appTitle2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.brandTurquoise)

                            Text("(\(Int(classification.confidence * 100))%)")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }

                    // Runner-up hint if available
                    if classification.candidates.count > 1, classification.label != "Background" {
                        let runnerUp = classification.candidates[1]
                        if runnerUp.confidence > 0.05 && runnerUp.label != "Background" {
                            Text("Runner-up: \(runnerUp.label) (\(Int(runnerUp.confidence * 100))%)")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Recognized sign: \(classification.label), confidence \(Int(classification.confidence * 100)) percent")
            } else {
                HStack(spacing: Theme.Spacing.xs) {
                    Circle()
                        .fill(viewModel.detectedPose != nil ? Color.success : Color.brandYellow)
                        .frame(width: 8, height: 8)
                    Text(viewModel.detectedPose != nil ? "Hand detected • Classifying..." : "Searching for hand...")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.65), in: Capsule())
                .accessibilityElement(children: .combine)
                .accessibilityLabel(viewModel.detectedPose != nil ? "Hand detected, evaluating pose" : "Searching for hand gestures")
            }
        }
        .padding(.top, Theme.Spacing.s)
    }

    private var bottomControlBar: some View {
        HStack(spacing: Theme.Spacing.l) {
            // Flip camera button
            Button {
                Task { await viewModel.switchCamera() }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.black.opacity(0.6), in: Circle())
            }
            .accessibilityLabel("Switch camera lens")
            .accessibilityHint("Toggles between front and rear cameras")

            // Left-handed mirror toggle
            Button {
                viewModel.toggleLeftHandMirror()
            } label: {
                Image(systemName: viewModel.isLeftHanded ? "hand.point.left.fill" : "hand.point.right.fill")
                    .font(.title2)
                    .foregroundStyle(viewModel.isLeftHanded ? Color.brandYellow : .white)
                    .frame(width: 56, height: 56)
                    .background(Color.black.opacity(0.6), in: Circle())
            }
            .accessibilityLabel(viewModel.isLeftHanded ? "Left-handed mode active" : "Right-handed mode active")
            .accessibilityHint("Toggles left-hand gesture mirroring")

            // Session pause/resume toggle
            Button {
                Task {
                    if viewModel.isSessionRunning {
                        await viewModel.stopCamera()
                    } else {
                        await viewModel.startCamera()
                    }
                }
            } label: {
                Image(systemName: viewModel.isSessionRunning ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.brandTurquoise, in: Circle())
            }
            .accessibilityLabel(viewModel.isSessionRunning ? "Pause camera capture" : "Resume camera capture")
        }
        .padding(Theme.Spacing.m)
    }
}

#Preview("Authorized Camera View") {
    NavigationStack {
        CameraTestView(
            viewModel: CameraTestViewModel(
                cameraService: StubCameraService(authorizationState: .authorized),
                handPoseDetector: StubHandPoseDetector()
            )
        )
    }
}

#Preview("Simulator Fallback") {
    NavigationStack {
        CameraTestView(
            viewModel: CameraTestViewModel(
                cameraService: StubCameraService(authorizationState: .unavailableOnSimulator),
                handPoseDetector: StubHandPoseDetector()
            )
        )
    }
}

#Preview("Permission Denied") {
    NavigationStack {
        CameraTestView(
            viewModel: CameraTestViewModel(
                cameraService: StubCameraService(authorizationState: .denied),
                handPoseDetector: StubHandPoseDetector()
            )
        )
    }
}
