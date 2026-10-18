import SwiftUI
import AVFoundation
import CoreMedia

/// ViewModel managing camera capture lifecycle, permissions, and Vision hand pose detection.
@Observable
@MainActor
final class CameraTestViewModel {
    private let cameraService: any CameraServicing
    private let handPoseDetector: any HandPoseDetecting
    private let signClassifier: any SignClassifying
    private var frameTask: Task<Void, Never>?

    var authorizationState: CameraAuthorizationState = .notDetermined
    var isSessionRunning = false
    var currentPosition: AVCaptureDevice.Position = .front
    var frameCount: Int = 0
    var isSimulator: Bool = false
    var isLeftHanded: Bool = false
    var detectedPose: HandPose?
    var currentClassification: SignClassification?

    var isAuthorized: Bool {
        authorizationState == .authorized
    }

    var isDenied: Bool {
        authorizationState == .denied || authorizationState == .restricted
    }

    init(
        cameraService: any CameraServicing,
        handPoseDetector: any HandPoseDetecting = StubHandPoseDetector(),
        signClassifier: any SignClassifying = StubSignClassifier()
    ) {
        self.cameraService = cameraService
        self.handPoseDetector = handPoseDetector
        self.signClassifier = signClassifier
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
        isSessionRunning = false
        detectedPose = nil
        currentClassification = nil
    }

    func switchCamera() async {
        await cameraService.switchCamera()
        currentPosition = cameraService.currentPosition
    }

    func toggleLeftHandMirror() {
        isLeftHanded.toggle()
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
                    }
                } catch {
                    // Frame skipped gracefully
                }
            }
        }
    }
}
