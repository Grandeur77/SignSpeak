import AVFoundation
import CoreMedia
import UIKit

/// Concrete camera service capturing video frames via AVFoundation on dedicated serial queues.
/// Delivers video frames via `AsyncStream<CMSampleBuffer>` without blocking the main UI thread.
public final class CameraService: NSObject, CameraServicing, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let sessionQueue = DispatchQueue(label: "com.mileesha.SignSpeak.camera.session", qos: .userInitiated)
    private let outputQueue = DispatchQueue(label: "com.mileesha.SignSpeak.camera.videoOutput", qos: .userInteractive)

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var position: AVCaptureDevice.Position = .front
    private var isConfigured = false

    private var frameContinuation: AsyncStream<CMSampleBuffer>.Continuation?

    public var captureSession: AVCaptureSession? {
        session
    }

    public var currentPosition: AVCaptureDevice.Position {
        position
    }

    public var authorizationState: CameraAuthorizationState {
        #if targetEnvironment(simulator)
        return .unavailableOnSimulator
        #else
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
        #endif
    }

    public private(set) lazy var frameStream: AsyncStream<CMSampleBuffer> = {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { [weak self] continuation in
            self?.frameContinuation = continuation
            continuation.onTermination = { [weak self] _ in
                self?.frameContinuation = nil
            }
        }
    }()

    public override init() {
        super.init()
    }

    deinit {
        stopSessionSync()
        frameContinuation?.finish()
    }

    /// Requests camera authorization if not already determined.
    public func requestAuthorization() async -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .authorized {
            return true
        } else if status == .notDetermined {
            return await AVCaptureDevice.requestAccess(for: .video)
        } else {
            return false
        }
        #endif
    }

    /// Starts the camera session on a background queue.
    public func startSession() async {
        #if targetEnvironment(simulator)
        return
        #else
        guard authorizationState == .authorized else { return }

        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }

                if !self.isConfigured {
                    self.configureSession()
                }

                if !self.session.isRunning {
                    self.session.startRunning()
                }
                continuation.resume()
            }
        }
        #endif
    }

    /// Stops the camera session.
    public func stopSession() async {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                self?.stopSessionSync()
                continuation.resume()
            }
        }
    }

    /// Toggles between front and rear cameras.
    public func switchCamera() async {
        #if targetEnvironment(simulator)
        return
        #else
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }

                let newPosition: AVCaptureDevice.Position = (self.position == .front) ? .back : .front
                self.setupInput(for: newPosition)
                continuation.resume()
            }
        }
        #endif
    }

    // MARK: - Private Configuration

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        setupInput(for: position)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoOutput.setSampleBufferDelegate(self, queue: outputQueue)

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        updateConnection()
        session.commitConfiguration()
        isConfigured = true
    }

    private func setupInput(for newPosition: AVCaptureDevice.Position) {
        session.beginConfiguration()

        if let currentInput = videoInput {
            session.removeInput(currentInput)
            videoInput = nil
        }

        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: newPosition
        )

        guard let device = discoverySession.devices.first,
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
            self.videoInput = input
            self.position = newPosition
        }

        updateConnection()
        session.commitConfiguration()
    }

    private func updateConnection() {
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = (position == .front)
            }
        }
    }

    private func stopSessionSync() {
        if session.isRunning {
            session.stopRunning()
        }
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        frameContinuation?.yield(sampleBuffer)
    }

    public func captureOutput(
        _ output: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Late frame discarded to ensure real-time responsiveness and avoid queue build-up.
    }
}
