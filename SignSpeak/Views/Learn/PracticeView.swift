import SwiftUI
import AVFoundation

/// Live gesture recognition practice screen matching designs:
/// `30-practice-recognized`, `31-practice-try-again`, and `34-practice-no-hand`.
/// Coordinates real-time camera preview, Vision skeletal overlay, match precision meter,
/// temporal hold lock-in, try-again guidance with side-by-side comparison,
/// and visual study fallback for non-recognizable signs.
public struct PracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dependencies) private var dependencies

    @State private var viewModel: PracticeViewModel

    public init(
        signs: [Sign],
        initialIndex: Int = 0,
        lessonTitle: String = "Practice",
        viewModel: PracticeViewModel? = nil
    ) {
        if let viewModel {
            _viewModel = State(initialValue: viewModel)
        } else {
            let cameraService = AppDependencies.live.cameraService
            let handPoseDetector = AppDependencies.live.handPoseDetector
            let signClassifier = AppDependencies.live.signClassifier
            let signRecognitionService = AppDependencies.live.signRecognitionService
            let progressRepository = AppDependencies.live.progressRepository

            _viewModel = State(initialValue: PracticeViewModel(
                signs: signs,
                initialIndex: initialIndex,
                lessonTitle: lessonTitle,
                cameraService: cameraService,
                handPoseDetector: handPoseDetector,
                signClassifier: signClassifier,
                signRecognitionService: signRecognitionService,
                progressRepository: progressRepository
            ))
        }
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.isSessionCompleted {
                sessionCompletedView
            } else if let sign = viewModel.currentSign, !sign.isRecognizable {
                visualStudyView(sign: sign)
            } else {
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
                    livePracticeCameraView
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $viewModel.showTryAgainGuidance) {
            tryAgainGuidanceSheet
                .presentationDetents([.fraction(0.85), .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.showHelpModal) {
            signHelpSheet
                .presentationDetents([.medium, .large])
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

    // MARK: - Live Camera View (30-practice-recognized & 34-practice-no-hand)

    private var livePracticeCameraView: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. Camera Viewport
                CameraPreviewView(
                    session: viewModel.cameraService.captureSession,
                    isMirrored: viewModel.currentPosition == .front
                )
                .ignoresSafeArea()

                // 2. Vision Skeleton & No-Hand Guide (34-practice-no-hand)
                HandSkeletonOverlay(
                    pose: viewModel.detectedPose,
                    isFrontCamera: viewModel.currentPosition == .front,
                    isLeftHanded: viewModel.isLeftHanded
                )
                .ignoresSafeArea()

                // 3. User Interface Overlays
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

    // MARK: - Top Practice Header

    private var topPracticeHeader: some View {
        VStack(spacing: Theme.Spacing.s) {
            HStack {
                // Close button
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.6), in: Circle())
                }
                .accessibilityLabel("Close practice session")

                Spacer()

                // Target Sign Title Capsule
                HStack(spacing: 6) {
                    Text("Sign \"\(viewModel.currentTargetLabel)\"")
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
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.brandNavy.opacity(0.85), in: Capsule())
            }

            // Step Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 4)

                    Capsule()
                        .fill(Color.brandTurquoise)
                        .frame(width: geo.size.width * CGFloat(viewModel.progressFraction), height: 4)
                        .animation(.easeOut(duration: 0.2), value: viewModel.progressFraction)
                }
            }
            .frame(height: 4)
            .padding(.top, 4)

            // Status Banners
            if viewModel.isTargetMatched {
                // Recognized Match Banner (30-practice-recognized.png)
                HStack(spacing: Theme.Spacing.s) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.brandNavy)

                    Text("Correct! \(viewModel.currentTargetLabel) — \(Int(viewModel.currentPrecision * 100))%")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.brandNavy)
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, 10)
                .background(Color.brandTurquoise, in: Capsule())
                .shadow(color: Color.brandTurquoise.opacity(0.4), radius: 8, y: 3)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Correct sign \(viewModel.currentTargetLabel) recognized with \(Int(viewModel.currentPrecision * 100)) percent precision")
            } else if let detectedMistake = viewModel.lastDetectedMistake,
                      detectedMistake != viewModel.currentTargetLabel,
                      detectedMistake != "Background" {
                // Try Again Hint Banner (31-practice-try-again.png)
                Button {
                    viewModel.openGuidance()
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.white)

                        Text("Looks like \"\(detectedMistake)\" — tap for tips")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)

                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.vertical, 8)
                    .background(Color.danger.opacity(0.9), in: Capsule())
                }
            }
        }
        .padding(.top, Theme.Spacing.s)
    }

    // MARK: - Bottom Match Panel (30-practice-recognized)

    private var bottomMatchPanel: some View {
        VStack(spacing: Theme.Spacing.m) {
            // Spatial Tracking Pill + Quick Controls
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.detectedPose != nil ? Color.brandYellow : Color.secondary)
                        .frame(width: 8, height: 8)
                    Text(viewModel.detectedPose != nil ? "SPATIAL TRACKING ACTIVE" : "WAITING FOR HAND")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.7), in: Capsule())

                Spacer()

                // Left-Hand Mirror Toggle
                Button {
                    viewModel.toggleLeftHanded()
                } label: {
                    Image(systemName: viewModel.isLeftHanded ? "hand.point.left.fill" : "hand.point.right.fill")
                        .font(.caption)
                        .foregroundStyle(viewModel.isLeftHanded ? Color.brandYellow : .white)
                        .padding(8)
                        .background(Color.black.opacity(0.6), in: Circle())
                }
                .accessibilityLabel(viewModel.isLeftHanded ? "Left-handed mode active" : "Right-handed mode active")

                // Camera Switch Toggle
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

                // Help Button
                Button {
                    viewModel.toggleHelpModal()
                } label: {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.brandTurquoise)
                        .padding(8)
                        .background(Color.black.opacity(0.6), in: Circle())
                }
                .accessibilityLabel("View sign hints and tips")
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
            .background(Color.brandNavy.opacity(0.92), in: RoundedRectangle(cornerRadius: Theme.Radius.card))

            // Primary Action Buttons
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
                    .shadow(color: Color.brandYellow.opacity(0.35), radius: 8, y: 3)
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
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.Radius.button))
                    }
                }
            }
        }
        .padding(.bottom, Theme.Spacing.s)
    }

    // MARK: - Try Again Guidance Sheet (31-practice-try-again)

    private var tryAgainGuidanceSheet: some View {
        let target = viewModel.currentTargetLabel
        let detected = viewModel.lastDetectedMistake ?? viewModel.recognitionState.label ?? viewModel.currentClassification?.label
        let feedback = SignPracticeHint.feedback(target: target, detected: detected)

        return VStack(spacing: Theme.Spacing.m) {
            // Header
            HStack {
                Button {
                    viewModel.closeGuidance()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.12), in: Circle())
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
                        .frame(width: geo.size.width * CGFloat(viewModel.progressFraction), height: 4)
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
                                .foregroundStyle(Color.brandNavy.opacity(0.9))
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
                                    .frame(height: 110)

                                VStack(spacing: 4) {
                                    Image(systemName: "hand.raised.slash.fill")
                                        .font(.title)
                                        .foregroundStyle(Color.danger)
                                    Text("Letter \(detected ?? "?") detected")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.danger.opacity(0.85), in: Capsule())
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.brandNavy, in: RoundedRectangle(cornerRadius: Theme.Radius.card))

                        // Target Sign
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
                                    .frame(height: 110)

                                if let currentSign = viewModel.currentSign,
                                   let imageName = currentSign.imageName,
                                   let _ = UIImage(named: imageName) {
                                    Image(imageName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 90)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    VStack(spacing: 4) {
                                        Text(target)
                                            .font(.system(size: 32, weight: .bold, design: .rounded))
                                            .foregroundStyle(Color.brandTurquoise)
                                        Text("Goal Pose")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundStyle(Color.brandNavy)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.brandTurquoise, in: Capsule())
                                    }
                                }
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
                                .foregroundStyle(.white.opacity(0.9))
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

    // MARK: - Visual Study View (For Non-Recognizable Signs)

    private func visualStudyView(sign: Sign) -> some View {
        VStack(spacing: Theme.Spacing.m) {
            // Top Bar
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                        .frame(width: 38, height: 38)
                        .background(Color.cardBackground, in: Circle())
                }

                Spacer()

                VStack(spacing: 2) {
                    Text(sign.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.textPrimary)

                    Text("VISUAL STUDY MODE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.brandTurquoise)
                }

                Spacer()

                Text(viewModel.progressStepText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.cardBackground, in: Capsule())
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.m)

            ScrollView {
                VStack(spacing: Theme.Spacing.l) {
                    // Sign Media Player
                    SignMediaPlayer(sign: sign)
                        .frame(height: 280)

                    // Explanation Callout
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "eye.fill")
                                .foregroundStyle(Color.brandTurquoise)
                            Text("Visual Only Sign")
                                .font(.headline)
                                .foregroundStyle(Color.textPrimary)
                        }

                        Text("This sign is practiced visually. Watch the demonstration video, repeat the hand motion, and tap 'Mark as learned' when confident.")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(Theme.Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))

                    // How to steps
                    if !sign.howToSteps.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How to sign:")
                                .font(.headline)
                                .foregroundStyle(Color.textPrimary)

                            ForEach(Array(sign.howToSteps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1).")
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color.brandTurquoise)
                                    Text(step)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.textPrimary)
                                }
                            }
                        }
                        .padding(Theme.Spacing.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
            }

            Spacer()

            // Mark as Learned Action Button
            Button {
                Task {
                    await viewModel.markAsLearned()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.headline)
                    Text("Mark as learned")
                        .font(.appButton)
                        .fontWeight(.bold)
                }
                .foregroundStyle(Color.brandNavy)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Color.brandTurquoise, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.l)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }

    // MARK: - Sign Help Sheet

    private var signHelpSheet: some View {
        NavigationStack {
            ScrollView {
                if let sign = viewModel.currentSign {
                    VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(sign.name)
                                    .font(.appTitle)
                                    .foregroundStyle(Color.textPrimary)

                                if let pronunciation = sign.pronunciationHint {
                                    Text(pronunciation)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.brandTurquoise)
                                }
                            }

                            Spacer()

                            if let imageName = sign.imageName, let _ = UIImage(named: imageName) {
                                Image(imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                                .foregroundStyle(Color.textPrimary)

                            Text(sign.description)
                                .font(.body)
                                .foregroundStyle(Color.textSecondary)
                        }

                        if !sign.howToSteps.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Steps")
                                    .font(.headline)
                                    .foregroundStyle(Color.textPrimary)

                                ForEach(Array(sign.howToSteps.enumerated()), id: \.offset) { index, step in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("\(index + 1).")
                                            .fontWeight(.bold)
                                            .foregroundStyle(Color.brandTurquoise)
                                        Text(step)
                                            .font(.subheadline)
                                            .foregroundStyle(Color.textPrimary)
                                    }
                                }
                            }
                        }

                        if let tip = sign.mnemonicTip {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundStyle(Color.brandYellow)
                                    Text("Memory Tip")
                                        .font(.headline)
                                        .foregroundStyle(Color.textPrimary)
                                }

                                Text(tip)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.textSecondary)
                            }
                            .padding(Theme.Spacing.m)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                        }
                    }
                    .padding(Theme.Spacing.l)
                }
            }
            .navigationTitle("Sign Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        viewModel.showHelpModal = false
                    }
                }
            }
        }
    }

    // MARK: - Session Completed View

    private var sessionCompletedView: some View {
        VStack(spacing: Theme.Spacing.l) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.brandTurquoise.opacity(0.18))
                    .frame(width: 110, height: 110)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 58))
                    .foregroundStyle(Color.brandTurquoise)
            }

            VStack(spacing: 8) {
                Text("Practice Complete!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(viewModel.lessonTitle)
                    .font(.headline)
                    .foregroundStyle(Color.brandTurquoise)

                Text("Great work! You completed \(viewModel.signs.count) signs.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }

            // Stats Cards
            HStack(spacing: Theme.Spacing.m) {
                VStack(spacing: 4) {
                    Text("\(viewModel.accuracyPercentage)%")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.brandYellow)
                    Text("Accuracy")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, minHeight: 70)
                .background(Color.brandNavy, in: RoundedRectangle(cornerRadius: Theme.Radius.card))

                VStack(spacing: 4) {
                    Text("\(viewModel.signs.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.brandTurquoise)
                    Text("Practiced")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, minHeight: 70)
                .background(Color.brandNavy, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            }
            .padding(.horizontal, Theme.Spacing.l)

            // Review Mistakes List (if any)
            if !viewModel.sessionMistakes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Signs to review:")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.8))

                    HStack(spacing: 8) {
                        ForEach(Array(Set(viewModel.sessionMistakes.map(\.signName))), id: \.self) { mistakeName in
                            HStack(spacing: 4) {
                                Text(mistakeName)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.danger)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.danger.opacity(0.2), in: Capsule())
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
            }

            Spacer()

            Button("Finish Session") {
                dismiss()
            }
            .font(.appButton)
            .fontWeight(.bold)
            .foregroundStyle(Color.brandNavy)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Color.brandYellow, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.l)
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

                Text("Camera Unavailable in Simulator")
                    .font(.appTitle)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Apple's iOS Simulator does not provide video input. Connect a physical iPhone running iOS 17 or later, or simulate practice below.")
                    .font(.appBody)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            .padding(Theme.Spacing.l)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))

            Spacer()

            VStack(spacing: Theme.Spacing.m) {
                Button("Simulate Match (Correct)") {
                    Task {
                        await viewModel.simulateMatch()
                    }
                }
                .buttonStyle(.primary)

                Button("Simulate Mistake") {
                    Task {
                        await viewModel.simulateMistake(detectedAs: "E")
                    }
                }
                .buttonStyle(.secondary)

                Button("Close") {
                    dismiss()
                }
                .foregroundStyle(Color.textSecondary)
                .padding(.top, 4)
            }
            .frame(maxWidth: 280)
            .padding(.bottom, Theme.Spacing.l)
        }
        .padding(Theme.Spacing.m)
        .background(Color.appBackground.ignoresSafeArea())
    }
}

#Preview("Practice View Preview") {
    PracticeView(
        signs: [
            Sign(id: "sign-letter-f", name: "F", category: "alphabet", description: "Letter F", howToSteps: ["OK circle"]),
            Sign(id: "sign-letter-g", name: "G", category: "alphabet", description: "Letter G", howToSteps: ["Index thumb pinch"])
        ],
        lessonTitle: "Alphabet: F – J"
    )
}
