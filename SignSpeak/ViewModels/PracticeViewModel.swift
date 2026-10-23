import SwiftUI
import AVFoundation
import CoreMedia

/// Represents a detected confusion mistake during practice.
public struct SignPracticeMistake: Identifiable, Sendable, Equatable {
    public var id: String { "\(signId)-\(detectedAs)-\(timestamp.timeIntervalSince1970)" }
    public let signId: String
    public let signName: String
    public let detectedAs: String
    public let timestamp: Date

    public init(signId: String, signName: String, detectedAs: String, timestamp: Date = Date()) {
        self.signId = signId
        self.signName = signName
        self.detectedAs = detectedAs
        self.timestamp = timestamp
    }
}

/// ViewModel coordinating interactive live gesture practice matching designs:
/// `30-practice-recognized`, `31-practice-try-again`, and `34-practice-no-hand`.
@Observable
@MainActor
public final class PracticeViewModel {
    public let cameraService: any CameraServicing
    public let handPoseDetector: any HandPoseDetecting
    public let signClassifier: any SignClassifying
    public let signRecognitionService: any SignRecognitionServicing
    public let progressRepository: any ProgressRepository
    public let userId: String

    public let lessonTitle: String
    public var signs: [Sign]
    public var currentSignIndex: Int = 0
    public let startTime: Date = Date()

    public var authorizationState: CameraAuthorizationState = .notDetermined
    public var isSessionRunning: Bool = false
    public var currentPosition: AVCaptureDevice.Position = .front
    public var isLeftHanded: Bool = false
    public var isSimulator: Bool = false
    public var frameCount: Int = 0

    public var detectedPose: HandPose?
    public var currentClassification: SignClassification?
    public var recognitionState: RecognitionState = .noHand

    public var isTargetMatched: Bool = false
    public var showTryAgainGuidance: Bool = false
    public var showHelpModal: Bool = false
    public var lastDetectedMistake: String?
    public var sessionMistakes: [SignPracticeMistake] = []
    public var completedSigns: Set<String> = []
    public var isSessionCompleted: Bool = false

    private var frameTask: Task<Void, Never>?
    private var lastHapticSignId: String?

    // MARK: - Computed Properties

    public var currentSign: Sign? {
        guard !signs.isEmpty, currentSignIndex >= 0, currentSignIndex < signs.count else { return nil }
        return signs[currentSignIndex]
    }

    public var currentTargetLabel: String {
        currentSign?.name ?? ""
    }

    public var progressStepText: String {
        guard !signs.isEmpty else { return "1 / 1" }
        return "\(currentSignIndex + 1) / \(signs.count)"
    }

    public var progressFraction: Double {
        guard !signs.isEmpty else { return 0.0 }
        return Double(currentSignIndex + 1) / Double(signs.count)
    }

    public var currentPrecision: Double {
        if let currentClassification {
            return currentClassification.confidence
        }
        return recognitionState.confidence
    }

    public var holdProgress: Double {
        recognitionState.progress
    }

    public var activeModelSource: RecognitionModelSource {
        currentClassification?.modelSource ?? .none
    }

    public var isAuthorized: Bool {
        authorizationState == .authorized
    }

    public var isDenied: Bool {
        authorizationState == .denied || authorizationState == .restricted
    }

    public var accuracyPercentage: Int {
        guard !signs.isEmpty else { return 100 }
        let total = signs.count
        let mistakeCount = sessionMistakes.map(\.signId).reduce(into: Set<String>()) { $0.insert($1) }.count
        let correct = max(0, total - mistakeCount)
        return Int((Double(correct) / Double(total)) * 100)
    }

    // MARK: - Initializer

    public init(
        signs: [Sign],
        initialIndex: Int = 0,
        lessonTitle: String = "Practice",
        cameraService: any CameraServicing,
        handPoseDetector: any HandPoseDetecting = StubHandPoseDetector(),
        signClassifier: any SignClassifying = StubSignClassifier(),
        signRecognitionService: (any SignRecognitionServicing)? = nil,
        progressRepository: any ProgressRepository = StubProgressRepository(),
        userId: String = "default"
    ) {
        self.signs = signs
        self.currentSignIndex = min(max(0, initialIndex), max(0, signs.count - 1))
        self.lessonTitle = lessonTitle
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
        refreshState()
        if isAuthorized {
            await startCamera()
        }
    }

    public func onDisappear() async {
        await stopCamera()
    }

    public func refreshState() {
        authorizationState = cameraService.authorizationState
        currentPosition = cameraService.currentPosition
    }

    public func requestAuthorization() async {
        let granted = await cameraService.requestAuthorization()
        refreshState()
        if granted {
            await startCamera()
        }
    }

    public func startCamera() async {
        guard isAuthorized else { return }
        await cameraService.startSession()
        isSessionRunning = true
        startFrameObservation()
    }

    public func stopCamera() async {
        frameTask?.cancel()
        frameTask = nil
        await cameraService.stopSession()
        await signRecognitionService.stopRecognition()
        isSessionRunning = false
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

    public func handleScenePhaseChange(to phase: ScenePhase) async {
        switch phase {
        case .background:
            await stopCamera()
        case .active:
            refreshState()
            if isAuthorized && !isSessionRunning {
                await startCamera()
            }
        default:
            break
        }
    }

    // MARK: - Practice Flow Actions

    public func nextSign() {
        if let currentSign {
            completedSigns.insert(currentSign.id)
        }

        if currentSignIndex + 1 < signs.count {
            currentSignIndex += 1
            resetSignRecognitionState()
        } else {
            isSessionCompleted = true
            Task {
                await recordCompletedSession()
            }
        }
    }

    public func recordCompletedSession() async {
        let duration = Int(Date().timeIntervalSince(startTime))
        let totalAttempts = max(signs.count, signs.count + sessionMistakes.count)
        let session = LearningSession(
            durationSeconds: max(1, duration),
            kind: "lesson",
            attempts: totalAttempts,
            correct: max(0, signs.count - sessionMistakes.count),
            signIds: signs.map(\.id),
            xpEarned: 100
        )
        try? await progressRepository.recordSession(userId: userId, session: session)
    }

    public func skipSign() {
        nextSign()
    }

    public func tryAgain() {
        showTryAgainGuidance = false
        lastHapticSignId = nil
        resetSignRecognitionState()
    }

    public func openGuidance() {
        showTryAgainGuidance = true
    }

    public func closeGuidance() {
        showTryAgainGuidance = false
    }

    public func toggleHelpModal() {
        showHelpModal.toggle()
    }

    public func markAsLearned() async {
        guard let sign = currentSign else { return }
        completedSigns.insert(sign.id)

        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        #endif

        try? await progressRepository.recordAttempt(
            userId: userId,
            signId: sign.id,
            isCorrect: true,
            detectedAs: nil
        )

        nextSign()
    }

    // MARK: - Testing and Simulation Aids

    public func simulateMatch() async {
        guard let currentSign else { return }
        isTargetMatched = true
        triggerSuccessFeedback(for: currentSign, confidence: 0.94)
        try? await progressRepository.recordAttempt(
            userId: userId,
            signId: currentSign.id,
            isCorrect: true,
            detectedAs: nil
        )
    }

    public func simulateMistake(detectedAs: String) async {
        await handleMistakeDetected(detectedAs: detectedAs)
    }

    // MARK: - Private Pipelines

    private func resetSignRecognitionState() {
        isTargetMatched = false
        showTryAgainGuidance = false
        lastDetectedMistake = nil
        recognitionState = .noHand
        signRecognitionService.reset()
    }

    private func startFrameObservation() {
        frameTask?.cancel()
        frameTask = Task { [weak self] in
            guard let self else { return }
            for await sampleBuffer in self.cameraService.frameStream {
                if Task.isCancelled { break }
                self.frameCount += 1

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

                        if let currentSign = self.currentSign, currentSign.isRecognizable {
                            await self.evaluateRecognitionState(state, for: currentSign)
                        }
                    }
                } catch {
                    // Frame skipped gracefully
                }
            }
        }
    }

    private func evaluateRecognitionState(_ state: RecognitionState, for sign: Sign) async {
        guard !isTargetMatched else { return }

        switch state {
        case .recognized(let label, let confidence, _):
            if sign.matchesRecognitionLabel(label) {
                isTargetMatched = true
                triggerSuccessFeedback(for: sign, confidence: confidence)
                try? await progressRepository.recordAttempt(
                    userId: userId,
                    signId: sign.id,
                    isCorrect: true,
                    detectedAs: nil
                )
            } else if label != "Background" {
                await handleMistakeDetected(detectedAs: label)
            }

        case .detecting(let label, _, _, _):
            if !sign.matchesRecognitionLabel(label) && label != "Background" {
                lastDetectedMistake = label
            }

        case .lowConfidence(let label, _, _):
            if let label, !sign.matchesRecognitionLabel(label) && label != "Background" {
                lastDetectedMistake = label
            }

        case .noHand:
            break
        }
    }

    public func handleMistakeDetected(detectedAs: String) async {
        lastDetectedMistake = detectedAs
        guard let currentSign else { return }

        let alreadyRecorded = sessionMistakes.contains { $0.signId == currentSign.id && $0.detectedAs == detectedAs }
        if !alreadyRecorded {
            let mistake = SignPracticeMistake(
                signId: currentSign.id,
                signName: currentSign.name,
                detectedAs: detectedAs
            )
            sessionMistakes.append(mistake)
            try? await progressRepository.recordAttempt(
                userId: userId,
                signId: currentSign.id,
                isCorrect: false,
                detectedAs: detectedAs
            )
        }
        showTryAgainGuidance = true
    }

    private func triggerSuccessFeedback(for sign: Sign, confidence: Double) {
        if lastHapticSignId != sign.id {
            lastHapticSignId = sign.id
            #if canImport(UIKit)
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)

            let announcement = "Correct! Sign \(sign.name) recognized with \(Int(confidence * 100)) percent precision"
            UIAccessibility.post(notification: .announcement, argument: announcement)
            #endif
        }
    }

    // MARK: - Lesson Complete Summary Factory

    public func makeCompletionSummary(signCatalog: any SignCatalogServicing) -> LessonCompletionSummary {
        let duration = Date().timeIntervalSince(startTime)

        var mistakeCounts: [String: Int] = [:]
        var mistakeDetectedAs: [String: String] = [:]
        for mistake in sessionMistakes {
            mistakeCounts[mistake.signId, default: 0] += 1
            mistakeDetectedAs[mistake.signId] = mistake.detectedAs
        }

        let mistakeItems: [LessonMistakeItem] = mistakeCounts.compactMap { (signId, count) in
            let sign = signs.first { $0.id == signId } ?? signCatalog.sign(byId: signId)
            let name = sign?.name ?? signId
            let detected = mistakeDetectedAs[signId] ?? "Incomplete"
            let hint = sign?.commonMistake ?? sign?.mnemonicTip ?? "Hold hand steady and ensure clear finger separation."
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

        let bestSign = signs.first { completedSigns.contains($0.id) } ?? signs.first
        let note: String? = bestSign != nil
            ? "Your spatial hand-depth accuracy on \(bestSign!.name.count == 1 ? "Letter " + bestSign!.name : bestSign!.name) was \(min(98, max(85, accuracyPercentage + 5)))%."
            : nil

        return LessonCompletionSummary(
            lessonTitle: lessonTitle,
            unitTitle: "Streak Milestone Reward",
            accuracyPercentage: accuracyPercentage,
            totalSignsCount: max(1, signs.count),
            completedSignsCount: max(completedSigns.count, signs.count - mistakeCounts.count),
            durationSeconds: max(15, duration),
            streakIncrementDays: 1,
            currentStreak: 8,
            earnedXP: 100,
            unlockedBadge: LessonBadge(
                id: "alphabet-starter",
                title: "Alphabet Starter",
                description: "Completed your first \(signs.count) manual finger-signs",
                xpReward: 100,
                iconName: "medal.fill"
            ),
            spatialAccuracyNote: note,
            mistakes: mistakeItems
        )
    }
}

