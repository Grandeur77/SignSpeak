import SwiftUI
import AVFoundation

/// Interactive quiz interface supporting both "Watch & Choose" (design `36-quiz-watch-and-choose`)
/// and "Sign It Yourself" (design `32-quiz-sign-it`).
/// Features 3 hearts lives system, streak multiplier, per-question feedback,
/// auto-capturing gesture countdown, and speed-run mode.
public struct QuizView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies

    @State private var viewModel: QuizViewModel

    public init(
        questions: [QuizQuestion],
        quizTitle: String = "Quiz",
        isSpeedRun: Bool = false,
        viewModel: QuizViewModel? = nil
    ) {
        if let viewModel {
            _viewModel = State(initialValue: viewModel)
        } else {
            let cameraService = AppDependencies.live.cameraService
            let handPoseDetector = AppDependencies.live.handPoseDetector
            let signClassifier = AppDependencies.live.signClassifier
            let signRecognitionService = AppDependencies.live.signRecognitionService
            let progressRepository = AppDependencies.live.progressRepository

            _viewModel = State(initialValue: QuizViewModel(
                questions: questions,
                quizTitle: quizTitle,
                isSpeedRun: isSpeedRun,
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

            if viewModel.isGameOver {
                gameOverView
            } else if viewModel.isComplete {
                quizCompleteView
            } else if let question = viewModel.currentQuestion {
                switch question.mode {
                case .watchAndChoose:
                    watchAndChooseView(question: question)
                case .signIt:
                    signItView(question: question)
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await viewModel.onAppear()
        }
        .onDisappear {
            Task { await viewModel.onDisappear() }
        }
    }

    // MARK: - Top Header Bar (Shared between modes)

    private func headerBar(modeTitle: String, isSignIt: Bool) -> some View {
        VStack(spacing: Theme.Spacing.s) {
            HStack {
                // Close button
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
                .accessibilityLabel("Exit quiz")

                Spacer()

                // Mode Badge
                Text(modeTitle.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(isSignIt ? Color.black : Color.brandTurquoise)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(isSignIt ? Color.brandYellow : Color.brandTurquoise.opacity(0.15), in: Capsule())

                Spacer()

                // Hearts / Lives (3 Hearts system)
                HStack(spacing: 3) {
                    ForEach(0..<3) { index in
                        Image(systemName: index < viewModel.lives ? "heart.fill" : "heart")
                            .font(.system(size: 14))
                            .foregroundStyle(index < viewModel.lives ? Color.danger : Color.white.opacity(0.3))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1), in: Capsule())
                .accessibilityLabel("\(viewModel.lives) hearts remaining")

                // Streak Badge
                if viewModel.streak > 1 {
                    HStack(spacing: 2) {
                        Text("🔥")
                            .font(.caption2)
                        Text("\(viewModel.streak)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.brandYellow)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.brandYellow.opacity(0.2), in: Capsule())
                }

                // XP Badge
                HStack(spacing: 3) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(Color.brandTurquoise)
                    Text("+\(viewModel.totalXP) XP")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.brandTurquoise)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.brandTurquoise.opacity(0.15), in: Capsule())
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
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.top, Theme.Spacing.m)
    }

    // MARK: - Watch & Choose View (36-quiz-watch-and-choose)

    private func watchAndChooseView(question: QuizQuestion) -> some View {
        VStack(spacing: Theme.Spacing.m) {
            headerBar(modeTitle: "Watch & Choose", isSignIt: false)

            ScrollView {
                VStack(spacing: Theme.Spacing.m) {
                    // Question Prompt
                    VStack(spacing: 4) {
                        Text("Question \(viewModel.progressText)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.brandTurquoise)

                        Text("Watch the sign and choose the correct meaning:")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 4)

                    // Media Viewport (Video or Photo Demonstration)
                    ZStack(alignment: .bottomTrailing) {
                        if let imageName = question.targetSign.imageName,
                           let _ = UIImage(named: imageName) {
                            Image(imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            SignMediaPlayer(sign: question.targetSign)
                                .frame(height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                    // 4 Multiple Choice Option Cards
                    VStack(spacing: 10) {
                        ForEach(question.options, id: \.self) { option in
                            optionButton(option: option, question: question)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, Theme.Spacing.l)
            }

            Spacer()

            // Feedback & Continue Action Banner
            if viewModel.isAnswerSubmitted {
                feedbackBottomBar
            }
        }
        .background(Color.brandNavy.ignoresSafeArea())
    }

    private func optionButton(option: String, question: QuizQuestion) -> some View {
        let isSelected = viewModel.selectedOption == option
        let isCorrect = option.lowercased() == question.correctAnswer.lowercased()

        let bgColor: Color
        let textColor: Color
        let iconName: String?

        if viewModel.isAnswerSubmitted {
            if isCorrect {
                bgColor = Color.brandTurquoise
                textColor = Color.brandNavy
                iconName = "checkmark.circle.fill"
            } else if isSelected {
                bgColor = Color.danger
                textColor = .white
                iconName = "xmark.circle.fill"
            } else {
                bgColor = Color.white.opacity(0.08)
                textColor = .white.opacity(0.5)
                iconName = nil
            }
        } else {
            bgColor = isSelected ? Color.brandTurquoise.opacity(0.3) : Color.white.opacity(0.08)
            textColor = .white
            iconName = nil
        }

        return Button {
            Task {
                await viewModel.selectOption(option)
            }
        } label: {
            HStack {
                Text(option)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(textColor)

                Spacer()

                if let iconName {
                    Image(systemName: iconName)
                        .font(.title3)
                        .foregroundStyle(textColor)
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(bgColor, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .stroke(isSelected && !viewModel.isAnswerSubmitted ? Color.brandTurquoise : Color.white.opacity(0.12), lineWidth: 1.5)
            )
        }
        .disabled(viewModel.isAnswerSubmitted)
        .accessibilityLabel("Option \(option)")
    }

    // MARK: - Sign It Yourself View (32-quiz-sign-it)

    private func signItView(question: QuizQuestion) -> some View {
        GeometryReader { geometry in
            ZStack {
                // Live camera preview layer
                CameraPreviewView(
                    session: viewModel.cameraService.captureSession,
                    isMirrored: viewModel.currentPosition == .front
                )
                .ignoresSafeArea()

                // Vision hand skeleton and guide
                HandSkeletonOverlay(
                    pose: viewModel.detectedPose,
                    isFrontCamera: viewModel.currentPosition == .front,
                    isLeftHanded: viewModel.isLeftHanded
                )
                .ignoresSafeArea()

                // Overlay Controls & Feedback
                VStack(spacing: 0) {
                    headerBar(modeTitle: "Sign It Yourself", isSignIt: true)

                    // Target Sign Floating Box
                    VStack(spacing: 6) {
                        Text("Sign the letter or word:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.8))

                        Text("\"\(question.correctAnswer)\"")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.brandYellow)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.top, Theme.Spacing.m)

                    // Countdown Ring & Controls
                    HStack(spacing: 16) {
                        // Circular Countdown Timer
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 4)
                                .frame(width: 48, height: 48)

                            Circle()
                                .trim(from: 0, to: CGFloat(viewModel.countdownFraction))
                                .stroke(viewModel.countdownRemaining < 2.0 ? Color.danger : Color.brandTurquoise, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: 48, height: 48)
                                .rotationEffect(.degrees(-90))

                            Text(String(format: "%.0f", ceil(viewModel.countdownRemaining)))
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                        }

                        // Hint Toggle Button
                        Button {
                            viewModel.toggleHint()
                        } label: {
                            Image(systemName: "lightbulb.fill")
                                .font(.subheadline)
                                .foregroundStyle(viewModel.showHint ? Color.brandYellow : .white)
                                .padding(12)
                                .background(Color.black.opacity(0.6), in: Circle())
                        }
                        .accessibilityLabel("Show hint")

                        // Switch Camera Button
                        Button {
                            Task { await viewModel.switchCamera() }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.6), in: Circle())
                        }
                        .accessibilityLabel("Switch camera")
                    }
                    .padding(.top, Theme.Spacing.m)

                    // Hint Callout
                    if viewModel.showHint, let tip = question.targetSign.mnemonicTip ?? question.targetSign.howToSteps.first {
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(Color.brandYellow)
                            Text(tip)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.8), in: Capsule())
                        .padding(.top, Theme.Spacing.s)
                    }

                    Spacer()

                    // Evaluation outcome banner
                    if viewModel.isAnswerSubmitted {
                        feedbackBottomBar
                            .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 0 : Theme.Spacing.m)
                    } else if viewModel.isSimulator {
                        // Simulator quick test buttons
                        HStack(spacing: 12) {
                            Button("Simulate Correct") {
                                Task { await viewModel.simulateSignItMatch() }
                            }
                            .buttonStyle(.primary)

                            Button("Simulate Timeout") {
                                Task { await viewModel.simulateSignItMistake() }
                            }
                            .buttonStyle(.secondary)
                        }
                        .padding(.bottom, Theme.Spacing.m)
                    }
                }
            }
        }
    }

    // MARK: - Feedback Bottom Bar

    private var feedbackBottomBar: some View {
        let isCorrect = viewModel.lastResult?.isCorrect ?? false

        return VStack(spacing: Theme.Spacing.s) {
            HStack(spacing: 12) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(isCorrect ? Color.brandTurquoise : Color.danger)

                VStack(alignment: .leading, spacing: 2) {
                    Text(isCorrect ? "Correct!" : "Incorrect")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text(isCorrect ? "+\(viewModel.lastResult?.xpEarned ?? 10) XP earned" : "Correct sign was \"\(viewModel.currentQuestion?.correctAnswer ?? "")\"")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.l)

            Button {
                viewModel.nextQuestion()
            } label: {
                HStack(spacing: 8) {
                    Text("Continue")
                        .font(.appButton)
                        .fontWeight(.bold)
                    Image(systemName: "arrow.right")
                        .font(.headline)
                }
                .foregroundStyle(Color.brandNavy)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(isCorrect ? Color.brandTurquoise : Color.brandYellow, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.s)
        }
        .padding(.vertical, Theme.Spacing.m)
        .background(Color.black.opacity(0.92))
    }

    // MARK: - Game Over View

    private var gameOverView: some View {
        VStack(spacing: Theme.Spacing.l) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.danger.opacity(0.2))
                    .frame(width: 100, height: 100)

                Image(systemName: "heart.slash.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.danger)
            }

            VStack(spacing: 8) {
                Text("Out of Lives!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("You ran out of hearts during this quiz.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))

                Text("Score: \(viewModel.score) of \(viewModel.quizEngine.questions.count) correct")
                    .font(.headline)
                    .foregroundStyle(Color.brandYellow)
            }

            Spacer()

            VStack(spacing: Theme.Spacing.m) {
                Button("Try Again") {
                    viewModel.restartQuiz()
                }
                .buttonStyle(.primary)

                Button("Exit Quiz") {
                    dismiss()
                }
                .foregroundStyle(.white.opacity(0.8))
                .padding(.top, 4)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.l)
        }
        .background(Color.brandNavy.ignoresSafeArea())
    }

    // MARK: - Quiz Complete View

    private var quizCompleteView: some View {
        VStack(spacing: Theme.Spacing.l) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.brandYellow.opacity(0.2))
                    .frame(width: 110, height: 110)

                Image(systemName: "trophy.fill")
                    .font(.system(size: 58))
                    .foregroundStyle(Color.brandYellow)
            }

            VStack(spacing: 8) {
                Text("Quiz Complete!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(viewModel.quizTitle)
                    .font(.headline)
                    .foregroundStyle(Color.brandTurquoise)

                Text("+\(viewModel.totalXP) XP earned")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.brandYellow)
            }

            // Stats Cards
            HStack(spacing: Theme.Spacing.m) {
                VStack(spacing: 4) {
                    Text("\(viewModel.quizEngine.accuracyPercentage)%")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.brandTurquoise)
                    Text("Accuracy")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, minHeight: 70)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.Radius.card))

                VStack(spacing: 4) {
                    Text("🔥 \(viewModel.quizEngine.bestStreak)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.brandYellow)
                    Text("Best Streak")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, minHeight: 70)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            }
            .padding(.horizontal, Theme.Spacing.l)

            Spacer()

            Button("Finish Quiz") {
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
}
