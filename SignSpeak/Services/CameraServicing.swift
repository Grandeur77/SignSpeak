import AVFoundation
import CoreMedia

/// Authorization state for camera capture.
public enum CameraAuthorizationState: Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unavailableOnSimulator
}

/// Protocol abstracting AVFoundation camera session management and frame delivery.
public protocol CameraServicing: Sendable {
    /// The current camera authorization status.
    var authorizationState: CameraAuthorizationState { get }

    /// Active AVCaptureSession for preview layers.
    var captureSession: AVCaptureSession? { get }

    /// Current camera lens position (front or back).
    var currentPosition: AVCaptureDevice.Position { get }

    /// Stream of video frames delivered from the camera session.
    var frameStream: AsyncStream<CMSampleBuffer> { get }

    /// Prompts the user for camera access if not yet determined.
    func requestAuthorization() async -> Bool

    /// Starts camera capture on a background queue.
    func startSession() async

    /// Stops camera capture.
    func stopSession() async

    /// Toggles between front and rear cameras.
    func switchCamera() async

    /// Updates video output orientation to match iPad device/interface rotation.
    func setOrientation(_ orientation: AVCaptureVideoOrientation) async
}

public final class StubCameraService: CameraServicing, @unchecked Sendable {
    public var authorizationState: CameraAuthorizationState
    public var captureSession: AVCaptureSession? { nil }
    public var currentPosition: AVCaptureDevice.Position { .front }
    public var currentOrientation: AVCaptureVideoOrientation = .portrait

    public var frameStream: AsyncStream<CMSampleBuffer> {
        AsyncStream { $0.finish() }
    }

    public init(authorizationState: CameraAuthorizationState = .unavailableOnSimulator) {
        self.authorizationState = authorizationState
    }
    public func requestAuthorization() async -> Bool {
        authorizationState == .authorized
    }
    public func startSession() async {}
    public func stopSession() async {}
    public func switchCamera() async {}
    public func setOrientation(_ orientation: AVCaptureVideoOrientation) async {
        currentOrientation = orientation
    }
}
