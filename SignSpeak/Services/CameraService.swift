import AVFoundation
import CoreMedia
import UIKit
import os

/// Concrete camera service capturing video frames via AVFoundation on dedicated serial queues.
/// Delivers video frames via `AsyncStream<CMSampleBuffer>` without blocking the main UI thread.
public final class CameraService: NSObject, CameraServicing, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let sessionQueue = DispatchQueue(label: "com.mileesha.SignSpeak.camera.session", qos: .userInitiated)
    private let outputQueue = DispatchQueue(label: "com.mileesha.SignSpeak.camera.videoOutput", qos: .userInteractive)

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var position: AVCaptureDevice.Position = .front
    private var videoOrientation: AVCaptureVideoOrientation = .portrait
    private var isConfigured = false

    private let streamLock = NSLock()
    private var frameContinuations: [UUID: AsyncStream<CMSampleBuffer>.Continuation] = [:]

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

    public var frameStream: AsyncStream<CMSampleBuffer> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            streamLock.lock()
            frameContinuations[id] = continuation
            streamLock.unlock()

            continuation.onTermination = { [weak self] _ in
                self?.removeFrameContinuation(id: id)
            }
        }
    }

    private func removeFrameContinuation(id: UUID) {
        streamLock.lock()
        frameContinuations.removeValue(forKey: id)
        streamLock.unlock()
    }

    public override init() {
        super.init()
        session.automaticallyConfiguresApplicationAudioSession = false
    }

    deinit {
        stopSessionSync()
        streamLock.lock()
        let targets = Array(frameContinuations.values)
        frameContinuations.removeAll()
        streamLock.unlock()
        for continuation in targets {
            continuation.finish()
        }
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
        AppLogger.camera.notice("Camera startSession requested on simulator (stubbed).")
        return
        #else
        guard authorizationState == .authorized else {
            AppLogger.camera.warning("startSession aborted: camera authorization is \(String(describing: self.authorizationState))")
            return
        }

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
                    AppLogger.camera.info("AVCaptureSession started running (position: \(String(describing: self.position)))")
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
                AppLogger.camera.info("AVCaptureSession stopped running.")
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
                AppLogger.camera.info("Camera position switched to: \(String(describing: self.position))")
                continuation.resume()
            }
        }
        #endif
    }


    /// Updates video output orientation to match iPad device/interface rotation.
    public func setOrientation(_ orientation: AVCaptureVideoOrientation) async {
        #if targetEnvironment(simulator)
        return
        #else
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                self.videoOrientation = orientation
                self.updateConnection()
                continuation.resume()
            }
        }
        #endif
    }

    // MARK: - Private Configuration

    private func configureSession() {
        session.beginConfiguration()
        session.automaticallyConfiguresApplicationAudioSession = false
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
            if #available(iOS 17.0, *) {
                let angle: CGFloat
                switch videoOrientation {
                case .portrait: angle = 90.0
                case .portraitUpsideDown: angle = 270.0
                case .landscapeRight: angle = 0.0
                case .landscapeLeft: angle = 180.0
                @unknown default: angle = 90.0
                }
                if connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }
            } else {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = videoOrientation
                }
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
        streamLock.lock()
        let targets = Array(frameContinuations.values)
        streamLock.unlock()

        for continuation in targets {
            continuation.yield(sampleBuffer)
        }
    }

    public func captureOutput(
        _ output: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Late frame discarded to ensure real-time responsiveness and avoid queue build-up.
    }
}
