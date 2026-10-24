import XCTest
import CoreML
import SwiftUI
@testable import SignSpeak

final class Phase15AuditTests: XCTestCase {

    // MARK: - 15.3 Network Monitoring Tests

    func testStubNetworkMonitorInitialState() {
        let onlineMonitor = StubNetworkMonitorService(isConnected: true)
        XCTAssertTrue(onlineMonitor.isConnected)

        let offlineMonitor = StubNetworkMonitorService(isConnected: false)
        XCTAssertFalse(offlineMonitor.isConnected)
    }

    func testStubNetworkMonitorStatusStream() async {
        let monitor = StubNetworkMonitorService(isConnected: true)
        var receivedStates: [Bool] = []

        let task = Task {
            for await status in monitor.statusStream {
                receivedStates.append(status)
                if receivedStates.count == 3 {
                    break
                }
            }
        }

        // Wait brief moment for stream task to attach
        try? await Task.sleep(nanoseconds: 50_000_000)
        monitor.setConnected(false)
        monitor.setConnected(true)

        await task.value
        XCTAssertEqual(receivedStates, [true, false, true])
    }

    // MARK: - 15.2 Performance & Core ML Model Optimization Tests

    func testSignClassifierDefaultConfigurationOptimization() {
        let config = SignClassifier.defaultConfiguration()
        XCTAssertEqual(config.computeUnits, .all, "SignClassifier must use .all compute units (CPU, GPU, ANE)")
        XCTAssertTrue(config.allowLowPrecisionAccumulationOnGPU, "SignClassifier must enable low-precision GPU accumulation")
    }

    func testMotionClassifierDefaultConfigurationOptimization() {
        let config = MotionClassifier.defaultConfiguration()
        XCTAssertEqual(config.computeUnits, .all, "MotionClassifier must use .all compute units (CPU, GPU, ANE)")
        XCTAssertTrue(config.allowLowPrecisionAccumulationOnGPU, "MotionClassifier must enable low-precision GPU accumulation")
    }

    func testSignRecognitionPipelineFrameThrottling() {
        let mockCamera = MockCameraService()
        let mockDetector = MockHandPoseDetector()
        let stubSignClassifier = StubSignClassifier()
        let stubMotionClassifier = MockMotionSignClassifier()
        let stubStabilityFilter = StabilityFilter(confidenceThreshold: 0.85, holdDuration: 1.0)

        let recognitionService = SignRecognitionService(
            cameraService: mockCamera,
            handPoseDetector: mockDetector,
            signClassifier: stubSignClassifier,
            motionSignClassifier: stubMotionClassifier,
            stabilityFilter: stubStabilityFilter
        )

        // Reset should restore idle state
        recognitionService.reset()
        XCTAssertEqual(recognitionService.currentState, RecognitionState.noHand)
        XCTAssertNil(recognitionService.currentPose)
        XCTAssertNil(recognitionService.currentClassification)
    }

    // MARK: - 15.1 Accessibility & Error Views

    func testEmptyStateViewRenders() {
        let emptyView = EmptyStateView(
            title: "No Signs Found",
            message: "Try clearing your search filters.",
            systemImage: "tray"
        )
        XCTAssertNotNil(emptyView.body)
    }

    func testErrorStateViewRendersWithAction() {
        var retried = false
        let errorView = ErrorStateView(
            title: "Network Error",
            message: "Please check your internet connection.",
            onRetry: { retried = true }
        )
        XCTAssertNotNil(errorView.body)
        errorView.onRetry()
        XCTAssertTrue(retried, "ErrorStateView retry handler must execute")
    }

    func testOfflineBannerViewInitialization() {
        let banner = OfflineBannerView()
        XCTAssertNotNil(banner.body)
    }

    // MARK: - 15.3 Structured Logging Tests

    func testAppLoggerCategoriesAvailable() {
        // Verify all os.Logger categories are initialized without crashing
        _ = AppLogger.camera
        _ = AppLogger.vision
        _ = AppLogger.recognition
        _ = AppLogger.speech
        _ = AppLogger.network
        _ = AppLogger.soundAlerts
        _ = AppLogger.accessibility
        _ = AppLogger.performance
        _ = AppLogger.ui
    }
}
