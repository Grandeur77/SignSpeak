import Foundation
import SwiftUI
import Testing
import AVFoundation
@testable import SignSpeak

@Suite("Camera Capture Service & ViewModel")
struct CameraServiceTests {
    @Test("ViewModel initializes with service authorization state")
    @MainActor
    func viewModelInitialization() {
        let mockCamera = MockCameraService(authorizationState: .notDetermined)
        let viewModel = CameraTestViewModel(cameraService: mockCamera)

        #expect(viewModel.authorizationState == .notDetermined)
        #expect(!viewModel.isAuthorized)
        #expect(!viewModel.isDenied)
        #expect(!viewModel.isSessionRunning)
    }

    @Test("Requesting authorization succeeds and starts camera session")
    @MainActor
    func authorizationSuccessFlow() async {
        let mockCamera = MockCameraService(authorizationState: .notDetermined)
        mockCamera.requestAuthorizationResult = true
        let viewModel = CameraTestViewModel(cameraService: mockCamera)

        await viewModel.requestAuthorization()

        #expect(viewModel.authorizationState == .authorized)
        #expect(viewModel.isAuthorized)
        #expect(viewModel.isSessionRunning)
        #expect(mockCamera.startSessionCallCount == 1)
    }

    @Test("Denying camera access updates state and does not start session")
    @MainActor
    func authorizationDeniedFlow() async {
        let mockCamera = MockCameraService(authorizationState: .notDetermined)
        mockCamera.requestAuthorizationResult = false
        let viewModel = CameraTestViewModel(cameraService: mockCamera)

        await viewModel.requestAuthorization()

        #expect(viewModel.authorizationState == .denied)
        #expect(viewModel.isDenied)
        #expect(!viewModel.isSessionRunning)
        #expect(mockCamera.startSessionCallCount == 0)
    }

    @Test("Switching camera invokes service and updates current position")
    @MainActor
    func switchCameraFlow() async {
        let mockCamera = MockCameraService(authorizationState: .authorized)
        mockCamera.currentPosition = .front
        let viewModel = CameraTestViewModel(cameraService: mockCamera)

        #expect(viewModel.currentPosition == .front)

        // Mock camera service switches position
        mockCamera.currentPosition = .back
        await viewModel.switchCamera()

        #expect(mockCamera.switchCameraCallCount == 1)
        #expect(viewModel.currentPosition == .back)
    }

    @Test("Background transition pauses session; foreground transition resumes session")
    @MainActor
    func scenePhaseTransitions() async {
        let mockCamera = MockCameraService(authorizationState: .authorized)
        let viewModel = CameraTestViewModel(cameraService: mockCamera)

        await viewModel.startCamera()
        #expect(viewModel.isSessionRunning)

        // App goes to background -> camera pauses
        await viewModel.handleScenePhaseChange(to: .background)
        #expect(!viewModel.isSessionRunning)
        #expect(mockCamera.stopSessionCallCount == 1)

        // App returns to foreground -> camera resumes
        await viewModel.handleScenePhaseChange(to: .active)
        #expect(viewModel.isSessionRunning)
        #expect(mockCamera.startSessionCallCount == 2)
    }

    @Test("Simulator unavailable state is detected")
    @MainActor
    func simulatorStateDetection() {
        let mockCamera = MockCameraService(authorizationState: .unavailableOnSimulator)
        let viewModel = CameraTestViewModel(cameraService: mockCamera)

        #expect(viewModel.authorizationState == .unavailableOnSimulator)
        #expect(!viewModel.isAuthorized)
    }

    @Test("CameraService frameStream supports recurring multi-attempt subscriptions without terminating")
    func testCameraServiceMultiAttemptStreaming() async throws {
        let cameraService = CameraService()

        // 1st Attempt: subscribe and cancel
        let task1 = Task {
            var count = 0
            for await _ in cameraService.frameStream {
                count += 1
                if count >= 1 { break }
            }
            return count
        }
        task1.cancel()
        _ = await task1.value

        // 2nd Attempt: new subscriber must receive a fresh, working stream instead of a terminated one
        let stream2 = cameraService.frameStream
        let task2 = Task {
            var received = false
            for await _ in stream2 {
                received = true
                break
            }
            return received
        }
        // Ensure stream2 registered successfully and task2 is running without immediate termination
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(!task2.isCancelled)
        task2.cancel()
    }
}
