#if DEBUG
import SwiftUI
import AVFoundation
import CoreMedia
import CoreImage
import UIKit

/// ViewModel managing data collection for training Create ML Hand Pose and Hand Action classifiers.
/// Captures bursts of camera frames directly into `Documents/Dataset/<Label>/<Timestamp>.jpg`.
@Observable
@MainActor
final class DatasetCaptureViewModel {
    static let vocabulary: [String] = [
        "A", "B", "C", "D", "E", "F", "G", "H", "I",
        "K", "L", "M", "N", "O", "P", "Q", "R", "S",
        "T", "U", "V", "W", "X", "Y", "ILoveYou", "Background"
    ]

    private let cameraService: any CameraServicing
    private let handPoseDetector: any HandPoseDetecting
    private var frameTask: Task<Void, Never>?
    private let ciContext = CIContext()

    var selectedLabel: String = "A"
    var burstCount: Int = 30
    var burstInterval: TimeInterval = 0.3
    var isCountingDown: Bool = false
    var countdownRemaining: Int = 3
    var isCapturing: Bool = false
    var capturedInCurrentBurst: Int = 0
    var lastCapturedImage: UIImage?

    var authorizationState: CameraAuthorizationState = .notDetermined
    var isSessionRunning = false
    var currentPosition: AVCaptureDevice.Position = .front
    var isLeftHanded: Bool = false
    var detectedPose: HandPose?

    var classCounts: [String: Int] = [:]
    var totalPhotosCount: Int {
        classCounts.values.reduce(0, +)
    }

    private var latestPixelBuffer: CVPixelBuffer?
    private var captureBurstTask: Task<Void, Never>?

    init(
        cameraService: any CameraServicing,
        handPoseDetector: any HandPoseDetecting = StubHandPoseDetector()
    ) {
        self.cameraService = cameraService
        self.handPoseDetector = handPoseDetector
        self.authorizationState = cameraService.authorizationState
        self.currentPosition = cameraService.currentPosition
        refreshDatasetCounts()
    }

    // MARK: - Lifecycle

    func onAppear() async {
        authorizationState = cameraService.authorizationState
        currentPosition = cameraService.currentPosition
        refreshDatasetCounts()
        if authorizationState == .authorized {
            await startCamera()
        }
    }

    func onDisappear() async {
        await stopCamera()
    }

    func startCamera() async {
        await cameraService.startSession()
        isSessionRunning = true
        startFrameStreamObservation()
    }

    func stopCamera() async {
        captureBurstTask?.cancel()
        captureBurstTask = nil
        isCapturing = false
        isCountingDown = false
        frameTask?.cancel()
        frameTask = nil
        await cameraService.stopSession()
        isSessionRunning = false
        detectedPose = nil
    }

    func switchCamera() async {
        await cameraService.switchCamera()
        currentPosition = cameraService.currentPosition
    }

    func toggleLeftHandMirror() {
        isLeftHanded.toggle()
    }

    // MARK: - Frame Stream Observation

    private func startFrameStreamObservation() {
        frameTask?.cancel()
        frameTask = Task { [weak self] in
            guard let self else { return }
            for await sampleBuffer in self.cameraService.frameStream {
                if Task.isCancelled { break }

                if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                    self.latestPixelBuffer = pixelBuffer
                }

                do {
                    let pose = try await self.handPoseDetector.detectPose(in: sampleBuffer)
                    if !Task.isCancelled {
                        self.detectedPose = pose
                    }
                } catch {
                    // Frame skipped
                }
            }
        }
    }

    // MARK: - Burst Capture

    func startBurstSequence() {
        guard !isCapturing && !isCountingDown else { return }

        isCountingDown = true
        countdownRemaining = 3

        captureBurstTask = Task { [weak self] in
            guard let self else { return }

            // 3-second countdown
            while self.countdownRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                self.countdownRemaining -= 1
            }

            self.isCountingDown = false
            self.isCapturing = true
            self.capturedInCurrentBurst = 0

            // Capture loop
            let intervalNanoseconds = UInt64(self.burstInterval * 1_000_000_000)
            while self.capturedInCurrentBurst < self.burstCount {
                if Task.isCancelled { break }

                self.captureCurrentFrame()
                self.capturedInCurrentBurst += 1

                try? await Task.sleep(nanoseconds: intervalNanoseconds)
            }

            self.isCapturing = false
            self.refreshDatasetCounts()
        }
    }

    func cancelBurst() {
        captureBurstTask?.cancel()
        captureBurstTask = nil
        isCountingDown = false
        isCapturing = false
        refreshDatasetCounts()
    }

    private func captureCurrentFrame() {
        guard let pixelBuffer = latestPixelBuffer else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }

        // Determine orientation
        let orientation: UIImage.Orientation = (currentPosition == .front) ? .leftMirrored : .right
        let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
        self.lastCapturedImage = image

        // Generate JPEG data
        guard let jpegData = image.jpegData(compressionQuality: 0.85) else { return }

        saveImageFile(jpegData, label: selectedLabel)
    }

    // MARK: - Storage Management

    var datasetDirectoryURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("Dataset", isDirectory: true)
    }

    func labelDirectoryURL(for label: String) -> URL {
        datasetDirectoryURL.appendingPathComponent(label, isDirectory: true)
    }

    private func saveImageFile(_ data: Data, label: String) {
        let labelDir = labelDirectoryURL(for: label)
        try? FileManager.default.createDirectory(at: labelDir, withIntermediateDirectories: true)

        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let filename = "\(label)_\(timestamp).jpg"
        let fileURL = labelDir.appendingPathComponent(filename)

        try? data.write(to: fileURL, options: .atomic)
    }

    func refreshDatasetCounts() {
        var counts: [String: Int] = [:]
        for label in Self.vocabulary {
            let labelDir = labelDirectoryURL(for: label)
            if let files = try? FileManager.default.contentsOfDirectory(atPath: labelDir.path) {
                counts[label] = files.filter { $0.hasSuffix(".jpg") || $0.hasSuffix(".jpeg") }.count
            } else {
                counts[label] = 0
            }
        }
        self.classCounts = counts
    }

    func deletePhotos(for label: String) {
        let labelDir = labelDirectoryURL(for: label)
        try? FileManager.default.removeItem(at: labelDir)
        refreshDatasetCounts()
    }

    func clearAllDataset() {
        try? FileManager.default.removeItem(at: datasetDirectoryURL)
        refreshDatasetCounts()
    }
}
#endif
