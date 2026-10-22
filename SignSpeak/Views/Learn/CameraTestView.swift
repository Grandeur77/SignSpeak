import SwiftUI
import AVFoundation

/// Recognition Lab debug & practice screen with AVFoundation preview, real-time Vision hand pose detection,
/// kinematic match meter, temporal stability hold indicator, and practice feedback matching designs
/// `30-practice-recognized.png` and `31-practice-try-again.png`.
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
                signClassifier: dependencies.signClassifier,
                signRecognitionService: dependencies.signRecognitionService
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
                recognitionLabView
            }
        }
        .navigationTitle("Recognition Lab")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
                .foregroundStyle(.white)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.togglePracticeMode()
                } label: {
                    Text(viewModel.isPracticeMode ? "Freeform" : "Practice")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.brandTurquoise)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.brandNavy.opacity(0.8), in: Capsule())
                }
            }
        }
        .sheet(isPresented: $viewModel.showTryAgainGuidance) {
            tryAgainGuidanceSheet
                .presentationDetents([.fraction(0.85), .large])
                .presentationDragIndicator(.visible)
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

    // MARK: - Recognition Lab View

    private var recognitionLabView: some View {
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

                // Dynamic Overlays
                VStack(spacing: 0) {
                    topPracticeHeader
                        .padding(.top, geometry.safeAreaInsets.top > 0 ? 0 : Theme.Spacing.m)

                    Spacer()

                    bottomMatchPanel
                        .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 0 : Theme.Spacing.m)
                }
                .padding(.horizontal, Theme.Spacing.m)
            }
        }
    }

    // MARK: - Top Practice Header (Matching 30-practice-recognized.png)

    private var topPracticeHeader: some View {
        VStack(spacing: Theme.Spacing.s) {
            if viewModel.isPracticeMode {
                HStack {
                    // Close button
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(Color.black.opacity(0.6), in: Circle())
                    }
                    .accessibilityLabel("Close practice session")

                    Spacer()

                    // Target Sign Capsule
                    HStack(spacing: 6) {
                        Text("Sign \"\(viewModel.currentTargetSign)\"")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        Text("✋")
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.brandNavy.opacity(0.85), in: Capsule())

                    Spacer()

                    // Step counter badge
                    Text(viewModel.progressStepText)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.brandNavy.opacity(0.85), in: Capsule())
                }
            }

            // Live Status Banner overlay (Matches 30-practice-recognized.png)
            if viewModel.isTargetMatched {
                HStack(spacing: Theme.Spacing.s) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.brandNavy)

                    Text("Correct! \(viewModel.currentTargetSign) — \(Int(viewModel.currentPrecision * 100))%")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.brandNavy)
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, 10)
                .background(Color.brandTurquoise, in: Capsule())
                .shadow(color: Color.brandTurquoise.opacity(0.4), radius: 8, y: 3)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Correct sign \(viewModel.currentTargetSign) recognized with \(Int(viewModel.currentPrecision * 100)) percent precision")
            } else if let detected = viewModel.recognitionState.label,
                      detected != viewModel.currentTargetSign,
                      viewModel.isPracticeMode,
                      detected != "Background" {
                // Not quite banner -> Tapping opens Try Again sheet
                Button {
                    viewModel.openGuidance()
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.white)

                        Text("Looks like \"\(detected)\" — tap for tips")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)

                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.vertical, 8)
                    .background(Color.danger.opacity(0.85), in: Capsule())
                }
            } else if let classification = viewModel.currentClassification {
                // Freeform / Detecting status
                HStack(spacing: Theme.Spacing.s) {
                    Circle()
                        .fill(classification.label == "Background" ? Color.brandYellow : Color.brandTurquoise)
                        .frame(width: 8, height: 8)

                    if classification.label == "Background" {
                        Text("Background • No sign detected")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    } else {
                        Text("Detected: \(classification.label) (\(Int(classification.confidence * 100))%)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.65), in: Capsule())
            }
        }
        .padding(.top, Theme.Spacing.s)
    }

    // MARK: - Bottom Match Panel (Matching 30-practice-recognized.png)

    private var bottomMatchPanel: some View {
        VStack(spacing: Theme.Spacing.m) {
            // In-frame Spatial Tracking Pill + Quick Controls
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.detectedPose != nil ? Color.brandYellow : Color.secondary)
                        .frame(width: 8, height: 8)
                    Text("SPATIAL TRACKING ACTIVE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.7), in: Capsule())

                Spacer()

                // Mirror toggle
                Button {
                    viewModel.toggleLeftHandMirror()
                } label: {
                    Image(systemName: viewModel.isLeftHanded ? "hand.point.left.fill" : "hand.point.right.fill")
                        .font(.caption)
                        .foregroundStyle(viewModel.isLeftHanded ? Color.brandYellow : .white)
                        .padding(8)
                        .background(Color.black.opacity(0.6), in: Circle())
                }
                .accessibilityLabel(viewModel.isLeftHanded ? "Left-handed mode active" : "Right-handed mode active")

                // Camera switch toggle
                Button {
                    Task { await viewModel.switchCamera() }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.6), in: Circle())
                }
                .accessibilityLabel("Switch camera")
            }

            // Kinematic Match Card
            VStack(spacing: Theme.Spacing.s) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        Text("Kinematic Match")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Text("\(Int(viewModel.currentPrecision * 100))% Precision")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.brandTurquoise)
                }

                // Precision & Hold Duration Progress Bar
                GeometryReader { barGeo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(viewModel.isTargetMatched ? Color.brandTurquoise : Color.brandTurquoise.opacity(0.85))
                            .frame(width: max(0, barGeo.size.width * CGFloat(viewModel.holdProgress)), height: 8)
                            .animation(.easeOut(duration: 0.1), value: viewModel.holdProgress)
                    }
                }
                .frame(height: 8)

                // Subtitle metadata
                HStack(spacing: 6) {
                    Text("Threshold: 85%")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))

                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))

                    Text(viewModel.activeModelSource.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(viewModel.activeModelSource == .motionModel ? Color.brandYellow : Color.brandTurquoise)

                    Spacer()

                    Text(viewModel.isTargetMatched ? "Lock-in Confirmed" : (viewModel.holdProgress > 0 ? "Holding... \(Int(viewModel.holdProgress * 100))%" : "Hold steady for 1.0s"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(viewModel.isTargetMatched ? Color.brandTurquoise : .white.opacity(0.8))
                }
            }
            .padding(Theme.Spacing.m)
            .background(Color.brandNavy.opacity(0.9), in: RoundedRectangle(cornerRadius: Theme.Radius.card))

            // Action Button: Yellow "Next sign →" when confirmed
            if viewModel.isPracticeMode {
                if viewModel.isTargetMatched {
                    Button {
                        viewModel.nextSign()
                    } label: {
                        HStack(spacing: 8) {
                            Text("Next sign")
                                .font(.appButton)
                                .fontWeight(.bold)
                            Image(systemName: "arrow.right")
                                .font(.headline)
                        }
                        .foregroundStyle(Color.brandNavy)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Color.brandYellow, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
                    }
                } else {
                    HStack(spacing: Theme.Spacing.m) {
                        Button {
                            viewModel.openGuidance()
                        } label: {
                            Text("Review Tips")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.brandTurquoise)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.Radius.button)
                                        .strokeBorder(Color.brandTurquoise, lineWidth: 1.5)
                                )
                        }

                        Button {
                            viewModel.skipSign()
                        } label: {
                            Text("Skip sign")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.white.opacity(0.8))
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.Radius.button))
                        }
                    }
                }
            }
        }
        .padding(.bottom, Theme.Spacing.s)
    }

    // MARK: - Try Again Guidance Sheet (Matching 31-practice-try-again.png)

    private var tryAgainGuidanceSheet: some View {
        let target = viewModel.currentTargetSign
        let detected = viewModel.recognitionState.label ?? viewModel.currentClassification?.label
        let feedback = SignPracticeHint.feedback(target: target, detected: detected)

        return VStack(spacing: Theme.Spacing.m) {
            // Header: Close, Title with Letter Badge, and Star Count
            HStack {
                Button {
                    viewModel.closeGuidance()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.1), in: Circle())
                }

                Spacer()

                VStack(spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Sign the letter")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        Text(target)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.brandNavy)
                            .frame(width: 28, height: 28)
                            .background(Color.brandTurquoise, in: Circle())
                    }

                    Text("ASL FINGERSPELLING")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.brandTurquoise)
                        .tracking(1)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.brandYellow)
                    Text(viewModel.progressStepText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.12), in: Capsule())
            }
            .padding(.top, Theme.Spacing.m)

            // Step Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 4)

                    Capsule()
                        .fill(Color.brandTurquoise)
                        .frame(width: geo.size.width * CGFloat(Double(viewModel.targetIndex + 1) / Double(max(1, viewModel.practiceTargets.count))), height: 4)
                }
            }
            .frame(height: 4)

            ScrollView {
                VStack(spacing: Theme.Spacing.m) {
                    // Match Percentage Chip
                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.danger)
                                .frame(width: 8, height: 8)
                            Text("SIGN: \(Int(viewModel.currentPrecision * 100))% MATCH")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5), in: Capsule())
                    }

                    // Alert Banner: "Not quite — looks like "E""
                    HStack(alignment: .top, spacing: Theme.Spacing.m) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.danger, in: RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(feedback.title)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.brandNavy)

                            Text(feedback.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(Color.brandNavy.opacity(0.85))
                        }

                        Spacer()
                    }
                    .padding(Theme.Spacing.m)
                    .background(Color.danger.opacity(0.2), in: RoundedRectangle(cornerRadius: Theme.Radius.card))

                    // Comparison side by side
                    HStack(spacing: Theme.Spacing.m) {
                        // Your hand
                        VStack(spacing: 8) {
                            HStack {
                                Text("Your hand")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.danger)
                            }

                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 100)

                                Text("Letter \(detected ?? "?") detected")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.danger.opacity(0.8), in: Capsule())
                            }
                        }
                        .padding(12)
                        .background(Color.brandNavy, in: RoundedRectangle(cornerRadius: Theme.Radius.card))

                        // Target
                        VStack(spacing: 8) {
                            HStack {
                                Text("Target \(target)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.brandTurquoise)
                            }

                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 100)

                                Text("Goal Pose")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.brandNavy)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.brandTurquoise, in: Capsule())
                            }
                        }
                        .padding(12)
                        .background(Color.brandNavy, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                    }

                    // Quick Correction Card
                    HStack(alignment: .top, spacing: Theme.Spacing.m) {
                        Image(systemName: "hand.point.up.left.fill")
                            .font(.title2)
                            .foregroundStyle(Color.brandNavy)
                            .frame(width: 44, height: 44)
                            .background(Color.brandTurquoise, in: Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Quick correction")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)

                            Text(feedback.correction)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()
                    }
                    .padding(Theme.Spacing.m)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.Radius.card))

                    // Buttons
                    VStack(spacing: Theme.Spacing.s) {
                        Button {
                            viewModel.tryAgain()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.headline)
                                Text("Try again")
                                    .font(.appButton)
                                    .fontWeight(.bold)
                            }
                            .foregroundStyle(Color.brandNavy)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Color.brandYellow, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
                        }

                        Button {
                            viewModel.skipSign()
                        } label: {
                            Text("Skip this sign >")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.brandTurquoise)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.top, Theme.Spacing.s)
                }
                .padding(.horizontal, Theme.Spacing.m)
            }
        }
        .background(Color.brandNavy.ignoresSafeArea())
    }

    // MARK: - Simulator Fallback View

    private var simulatorUnavailableView: some View {
        VStack(spacing: Theme.Spacing.l) {
            Spacer()

            VStack(spacing: Theme.Spacing.m) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.brandTurquoise)
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
            .background(Color.cardBackground, in: .rect(cornerRadius: Theme.Radius.card))

            Spacer()

            Button("Close Preview") {
                dismiss()
            }
            .buttonStyle(.secondary)
            .frame(maxWidth: 240)
            .padding(.bottom, Theme.Spacing.l)
        }
        .padding(Theme.Spacing.m)
        .background(Color.appBackground)
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
