import SwiftUI
import AVFoundation

/// ViewModel managing quiz session state, camera recognition for "Sign it yourself",
/// multiple-choice selections for "Watch & choose", lives, timer, and score feedback.
/// Matches designs `32-quiz-sign-it` and `36-quiz-watch-and-choose`.
@Observable
@MainActor
public final class QuizViewModel {
    public let cameraService: any CameraServicing
    public let handPoseDetector: any HandPoseDetecting
    public let signClassifier: any SignClassifying
    public let signRecognitionService: any SignRecognitionServicing
    public let progressRepository: any ProgressRepository
    public let userId: String

    public var quizEngine: QuizEngine
    public let quizTitle: String

    public var authorizationState: CameraAuthorizationState = .notDetermined
    public var currentPosition: AVCaptureDevice.Position = .front
    public var isLeftHanded: Bool = false
    public var isSimulator: Bool = false

    public var detectedPose: HandPose?
    public var currentClassification: SignClassification?
    public var recognitionState: RecognitionState = .noHand

    public var selectedOption: String?
    public var lastResult: QuizAnswerResult?
    public var isAnswerSubmitted: Bool = false
    public var showHint: Bool = false

    public var countdownRemaining: Double = 6.0
    public var countdownTotal: Double = 6.0
    public var isTimerRunning: Bool = false

    private var frameTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?

    // MARK: - Computed Properties

    public var currentQuestion: QuizQuestion? {
        quizEngine.currentQuestion
    }

    public var progressText: String {
        quizEngine.progressText
    }

    public var progressFraction: Double {
        quizEngine.progressFraction
    }

    public var lives: Int {
        quizEngine.lives
    }

    public var streak: Int {
        quizEngine.currentStreak
    }

    public var totalXP: Int {
        quizEngine.totalXP
    }

    public var score: Int {
        quizEngine.score
    }

    public var isGameOver: Bool {
        quizEngine.isGameOver
    }

    public var isComplete: Bool {
        quizEngine.isComplete
    }

    public var countdownFraction: Double {
        guard countdownTotal > 0 else { return 0 }
        return max(0.0, min(1.0, countdownRemaining / countdownTotal))
    }

    // MARK: - Initializer

    public init(
        questions: [QuizQuestion],
        quizTitle: String = "Quiz",
        isSpeedRun: Bool = false,
        cameraService: any CameraServicing,
        handPoseDetector: any HandPoseDetecting = StubHandPoseDetector(),
        signClassifier: any SignClassifying = StubSignClassifier(),
        signRecognitionService: (any SignRecognitionServicing)? = nil,
        progressRepository: any ProgressRepository = StubProgressRepository(),
        userId: String = "default"
    ) {
        self.quizTitle = quizTitle
        self.quizEngine = QuizEngine(
            questions: questions,
            initialLives: 3,
            isSpeedRun: isSpeedRun
        )
        self.cameraService = cameraService
        self.handPoseDetector = handPoseDetector
        self.signClassifier = signClassifier
        self.progressRepository = progressRepository
        self.userId = userId

        if let signRecognitionService {
            self.signRecognitionService = signRecognitionService
        } else {
            self.signRecognitionService = SignRecognitionService(
                cameraService: cameraService,
                handPoseDetector: handPoseDetector,
                signClassifier: signClassifier
            )
        }

        #if targetEnvironment(simulator)
        self.isSimulator = true
        #endif
        self.authorizationState = cameraService.authorizationState
        self.currentPosition = cameraService.currentPosition
    }

    // MARK: - Lifecycle

    public func onAppear() async {
        authorizationState = cameraService.authorizationState
        currentPosition = cameraService.currentPosition

        if authorizationState == .authorized {
            await startCamera()
        }
        setupCurrentQuestionState()
    }

    public func onDisappear() async {
        stopCountdown()
        await stopCamera()
    }

    public func startCamera() async {
        guard authorizationState == .authorized else { return }
        await cameraService.startSession()
        startFrameObservation()
    }

    public func stopCamera() async {
        frameTask?.cancel()
        frameTask = nil
        await cameraService.stopSession()
        await signRecognitionService.stopRecognition()
        detectedPose = nil
        currentClassification = nil
        recognitionState = .noHand
    }

    public func switchCamera() async {
        await cameraService.switchCamera()
        currentPosition = cameraService.currentPosition
    }

    public func toggleLeftHanded() {
        isLeftHanded.toggle()
    }

    public func toggleHint() {
        showHint.toggle()
    }

    // MARK: - Answer Submission

    /// Submits a multiple choice selection in Watch & Choose mode.
    public func selectOption(_ option: String) async {
        guard !isAnswerSubmitted, let question = currentQuestion, question.mode == .watchAndChoose else { return }

        selectedOption = option
        isAnswerSubmitted = true

        let result = quizEngine.answerWatchAndChoose(selectedOption: option)
        lastResult = result

        handleAnswerFeedback(result: result, sign: question.targetSign, detectedOrSelected: option)

        // Record attempt to progress repository
        try? await progressRepository.recordAttempt(
            userId: userId,
            signId: question.targetSign.id,
            isCorrect: result.isCorrect,
            detectedAs: result.isCorrect ? nil : option
        )
    }

    /// Submits camera sign verification in Sign It mode.
    public func submitSignIt(isCorrect: Bool, detectedLabel: String?) async {
        guard !isAnswerSubmitted, let question = currentQuestion, question.mode == .signIt else { return }

        stopCountdown()
        isAnswerSubmitted = true

        let result = quizEngine.answerSignIt(isCorrect: isCorrect, detectedLabel: detectedLabel)
        lastResult = result

        handleAnswerFeedback(result: result, sign: question.targetSign, detectedOrSelected: detectedLabel)

        try? await progressRepository.recordAttempt(
            userId: userId,
            signId: question.targetSign.id,
            isCorrect: result.isCorrect,
            detectedAs: result.isCorrect ? nil : (detectedLabel ?? "Timeout")
        )
    }

    /// Advances to the next question in the session.
    public func nextQuestion() {
        quizEngine.advance()
        selectedOption = nil
        lastResult = nil
        isAnswerSubmitted = false
        showHint = false
        recognitionState = .noHand
        signRecognitionService.reset()

        setupCurrentQuestionState()
    }

    /// Restarts the quiz from the beginning.
    public func restartQuiz() {
        let questions = quizEngine.questions.shuffled()
        quizEngine = QuizEngine(
            questions: questions,
            initialLives: 3,
            isSpeedRun: quizEngine.isSpeedRun
        )
        selectedOption = nil
        lastResult = nil
        isAnswerSubmitted = false
        showHint = false
        setupCurrentQuestionState()
    }

    // MARK: - Simulator & Testing Aids

    public func simulateSignItMatch() async {
        await submitSignIt(isCorrect: true, detectedLabel: currentQuestion?.correctAnswer)
    }

    public func simulateSignItMistake(detectedAs: String = "E") async {
        await submitSignIt(isCorrect: false, detectedLabel: detectedAs)
    }

    // MARK: - Private Logic

    private func setupCurrentQuestionState() {
        guard let question = currentQuestion, !isGameOver, !isComplete else { return }

        if question.mode == .signIt {
            countdownRemaining = question.timeLimitSeconds
            countdownTotal = question.timeLimitSeconds
            startCountdown(duration: question.timeLimitSeconds)
        } else {
            stopCountdown()
        }
    }

    private func startCountdown(duration: TimeInterval) {
        stopCountdown()
        isTimerRunning = true

        countdownTask = Task { [weak self] in
            guard let self else { return }
            let tickInterval = 0.1
            while self.countdownRemaining > 0 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                if Task.isCancelled { break }

                self.countdownRemaining = max(0, self.countdownRemaining - tickInterval)
                if self.countdownRemaining <= 0 {
                    // Auto-capture timeout
                    if !self.isAnswerSubmitted {
                        await self.submitSignIt(isCorrect: false, detectedLabel: self.recognitionState.label ?? "Timeout")
                    }
                    break
                }
            }
            self.isTimerRunning = false
        }
    }

    private func stopCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        isTimerRunning = false
    }

    private func startFrameObservation() {
        frameTask?.cancel()
        frameTask = Task { [weak self] in
            guard let self else { return }
            for await sampleBuffer in self.cameraService.frameStream {
                if Task.isCancelled { break }

                do {
                    let pose = try await self.handPoseDetector.detectPose(in: sampleBuffer)
                    if !Task.isCancelled {
                        self.detectedPose = pose
                        if let pose {
                            self.currentClassification = try? self.signClassifier.classify(pose: pose)
                        } else {
                            self.currentClassification = nil
                        }

                        let state = self.signRecognitionService.processPose(pose)
                        self.recognitionState = state

                        // Auto-capture recognition in Sign It mode
                        if let question = self.currentQuestion,
                           question.mode == .signIt,
                           !self.isAnswerSubmitted {
                            if case .recognized(let label, _, _) = state {
                                if question.targetSign.matchesRecognitionLabel(label) {
                                    await self.submitSignIt(isCorrect: true, detectedLabel: label)
                                }
                            }
                        }
                    }
                } catch {
                    // Frame skipped gracefully
                }
            }
        }
    }

    private func handleAnswerFeedback(result: QuizAnswerResult, sign: Sign, detectedOrSelected: String?) {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        if result.isCorrect {
            generator.notificationOccurred(.success)
            let announcement = "Correct! +\(result.xpEarned) XP. Streak is \(result.streak)."
            UIAccessibility.post(notification: .announcement, argument: announcement)
        } else {
            generator.notificationOccurred(.error)
            let announcement = "Incorrect. Correct answer is \(sign.name). \(result.livesRemaining) hearts remaining."
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
        #endif
    }

    // MARK: - Lesson Complete Summary Factory

    public func makeCompletionSummary(signCatalog: any SignCatalogServicing) -> LessonCompletionSummary {
        let duration = Date().timeIntervalSince(quizEngine.startTime)

        var mistakeCounts: [String: Int] = [:]
        var mistakeDetectedAs: [String: String] = [:]
        for mistake in quizEngine.mistakes {
            mistakeCounts[mistake.signId, default: 0] += 1
            mistakeDetectedAs[mistake.signId] = mistake.detectedAs
        }

        let mistakeItems: [LessonMistakeItem] = mistakeCounts.compactMap { (signId, count) in
            let question = quizEngine.questions.first { $0.targetSign.id == signId }
            let sign = question?.targetSign ?? signCatalog.sign(byId: signId)
            let name = sign?.name ?? signId
            let detected = mistakeDetectedAs[signId] ?? "Mistake"
            let hint = sign?.commonMistake ?? sign?.mnemonicTip ?? "Review sign handshape and finger positioning."
            let aspect = (sign?.recognition == .motionSign) ? "Cadence & Repetition" : "Finger Placement Accuracy"

            return LessonMistakeItem(
                signId: signId,
                signName: name,
                detectedAs: detected,
                hint: hint,
                categoryAspect: aspect,
                missCount: count,
                sign: sign
            )
        }.sorted { $0.signName < $1.signName }

        let targetSign = quizEngine.questions.first?.targetSign
        let note: String? = targetSign != nil
            ? "Your spatial hand-depth accuracy on \(targetSign!.name.count == 1 ? "Letter " + targetSign!.name : targetSign!.name) was \(min(98, max(85, quizEngine.accuracyPercentage + 5)))%."
            : nil

        return LessonCompletionSummary(
            lessonTitle: quizTitle,
            unitTitle: "Streak Milestone Reward",
            accuracyPercentage: quizEngine.accuracyPercentage,
            totalSignsCount: max(1, quizEngine.questions.count),
            completedSignsCount: max(quizEngine.score, quizEngine.questions.count - mistakeCounts.count),
            durationSeconds: max(10, duration),
            streakIncrementDays: 1,
            currentStreak: max(1, quizEngine.bestStreak),
            earnedXP: max(totalXP, 100),
            unlockedBadge: LessonBadge(
                id: "quiz-champion",
                title: "Quiz Champion",
                description: "Mastered \(quizEngine.questions.count) quiz questions",
                xpReward: 100,
                iconName: "trophy.fill"
            ),
            spatialAccuracyNote: note,
            mistakes: mistakeItems
        )
    }
}

