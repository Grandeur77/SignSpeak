import SwiftUI
import AVFoundation
import CoreMedia

/// ViewModel managing camera capture lifecycle, permissions, Vision hand pose detection,
/// and live sign recognition stability filtering.
@Observable
@MainActor
final class CameraTestViewModel {
    private let cameraService: any CameraServicing
    private let handPoseDetector: any HandPoseDetecting
    private let signClassifier: any SignClassifying
    let signRecognitionService: any SignRecognitionServicing
    private var frameTask: Task<Void, Never>?

    var authorizationState: CameraAuthorizationState = .notDetermined
    var isSessionRunning = false
    var currentPosition: AVCaptureDevice.Position = .front
    var frameCount: Int = 0
    var isSimulator: Bool = false
    var isLeftHanded: Bool = false
    var detectedPose: HandPose?
    var currentClassification: SignClassification?
    var recognitionState: RecognitionState = .noHand

    // Practice sequence matching designs 30-practice-recognized and 31-practice-try-again
    var practiceTargets: [String] = ["A", "B", "C", "D", "E", "F"]
    var targetIndex: Int = 5 // Defaults to "F" (index 5) to match reference designs
    var isPracticeMode: Bool = true
    var showTryAgainGuidance: Bool = false
    private var lastHapticSign: String?

    var currentTargetSign: String {
        guard !practiceTargets.isEmpty else { return "F" }
        return practiceTargets[targetIndex % practiceTargets.count]
    }

    var progressStepText: String {
        guard !practiceTargets.isEmpty else { return "1 / 1" }
        return "\(targetIndex + 1) / \(practiceTargets.count)"
    }

    var isTargetMatched: Bool {
        if case .recognized(let label, _, _) = recognitionState, label == currentTargetSign {
            return true
        }
        return false
    }

    var currentPrecision: Double {
        if let currentClassification {
            return currentClassification.confidence
        }
        return recognitionState.confidence
    }

    var activeModelSource: RecognitionModelSource {
        currentClassification?.modelSource ?? .none
    }

    var holdProgress: Double {
        recognitionState.progress
    }

    var isAuthorized: Bool {
        authorizationState == .authorized
    }

    var isDenied: Bool {
        authorizationState == .denied || authorizationState == .restricted
    }

    init(
        cameraService: any CameraServicing,
        handPoseDetector: any HandPoseDetecting = StubHandPoseDetector(),
        signClassifier: any SignClassifying = StubSignClassifier(),
        signRecognitionService: (any SignRecognitionServicing)? = nil,
        practiceTargets: [String] = ["A", "B", "C", "D", "E", "F"],
        initialTargetIndex: Int = 5
    ) {
        self.cameraService = cameraService
        self.handPoseDetector = handPoseDetector
        self.signClassifier = signClassifier
        self.practiceTargets = practiceTargets
        self.targetIndex = initialTargetIndex
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

    func onAppear() async {
        refreshState()
        if isAuthorized {
            await startCamera()
        }
    }

    func onDisappear() async {
        await stopCamera()
    }

    func refreshState() {
        authorizationState = cameraService.authorizationState
        currentPosition = cameraService.currentPosition
    }

    func requestAuthorization() async {
        let granted = await cameraService.requestAuthorization()
        refreshState()
        if granted {
            await startCamera()
        }
    }

    func startCamera() async {
        guard isAuthorized else { return }
        await cameraService.startSession()
        isSessionRunning = true
        startFrameStreamObservation()
    }

    func stopCamera() async {
        frameTask?.cancel()
        frameTask = nil
        await cameraService.stopSession()
        await signRecognitionService.stopRecognition()
        isSessionRunning = false
        detectedPose = nil
        currentClassification = nil
        recognitionState = .noHand
    }

    func switchCamera() async {
        await cameraService.switchCamera()
        currentPosition = cameraService.currentPosition
    }

    func toggleLeftHandMirror() {
        isLeftHanded.toggle()
    }

    func togglePracticeMode() {
        isPracticeMode.toggle()
    }

    func nextSign() {
        if !practiceTargets.isEmpty {
            targetIndex = (targetIndex + 1) % practiceTargets.count
        }
        lastHapticSign = nil
        showTryAgainGuidance = false
        recognitionState = .noHand
        signRecognitionService.reset()
    }

    func tryAgain() {
        showTryAgainGuidance = false
        lastHapticSign = nil
        recognitionState = .noHand
        signRecognitionService.reset()
    }

    func skipSign() {
        nextSign()
    }

    func openGuidance() {
        showTryAgainGuidance = true
    }

    func closeGuidance() {
        showTryAgainGuidance = false
    }

    func handleScenePhaseChange(to phase: ScenePhase) async {
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

    private func startFrameStreamObservation() {
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

                        if case .recognized(let label, _, _) = state, label == self.currentTargetSign {
                            self.triggerHapticIfFirstTime(for: label)
                        }
                    }
                } catch {
                    // Frame skipped gracefully
                }
            }
        }
    }

    private func triggerHapticIfFirstTime(for label: String) {
        if lastHapticSign != label {
            lastHapticSign = label
            #if canImport(UIKit)
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
            #endif
        }
    }
}

