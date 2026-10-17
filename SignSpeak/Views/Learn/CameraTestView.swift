import SwiftUI
import AVFoundation

/// Temporary camera debug screen reachable from ContentView to test CameraService,
/// preview layer, front/back switching, and background lifecycle handling.
struct CameraTestView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dependencies) private var dependencies

    @State private var viewModel: CameraTestViewModel

    init(viewModel: CameraTestViewModel? = nil, dependencies: AppDependencies = .live) {
        if let viewModel {
            _viewModel = State(initialValue: viewModel)
        } else {
            _viewModel = State(initialValue: CameraTestViewModel(cameraService: dependencies.cameraService))
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
        .navigationTitle("Camera Preview")
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

            // Frame counter / Position badge
            HStack(spacing: Theme.Spacing.xs) {
                Text(viewModel.currentPosition == .front ? "Front Camera" : "Back Camera")
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
        .padding(.top, Theme.Spacing.s)
        .accessibilityElement(children: .combine)
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
            .accessibilityHint("Toggles between the front and rear cameras")

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
            viewModel: CameraTestViewModel(cameraService: StubCameraService(authorizationState: .authorized))
        )
    }
}

#Preview("Simulator Fallback") {
    NavigationStack {
        CameraTestView(
            viewModel: CameraTestViewModel(cameraService: StubCameraService(authorizationState: .unavailableOnSimulator))
        )
    }
}

#Preview("Permission Denied") {
    NavigationStack {
        CameraTestView(
            viewModel: CameraTestViewModel(cameraService: StubCameraService(authorizationState: .denied))
        )
    }
}
