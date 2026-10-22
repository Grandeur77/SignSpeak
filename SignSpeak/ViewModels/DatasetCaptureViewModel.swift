#if DEBUG
import SwiftUI
import AVFoundation
import CoreMedia
import CoreImage
import UIKit

/// Capture mode: Static Hand Pose (burst photos) vs. Dynamic Hand Action (video clips).
enum DatasetMode: String, CaseIterable, Identifiable {
    case staticSigns = "Static Signs"
    case motionSigns = "Motion Signs"

    var id: String { rawValue }
}

/// ViewModel managing data collection for training Create ML Hand Pose and Hand Action classifiers.
/// - Static signs: captures bursts of camera frames into `Documents/Dataset/Static/<Label>/<Timestamp>.jpg`.
/// - Motion signs: captures 1–3s video clips into `Documents/Dataset/Motion/<Label>/<Timestamp>.mov`.
@Observable
@MainActor
final class DatasetCaptureViewModel {
    static let staticVocabulary: [String] = [
        "A", "B", "C", "D", "E", "F", "G", "H", "I",
        "K", "L", "M", "N", "O", "P", "Q", "R", "S",
        "T", "U", "V", "W", "X", "Y", "ILoveYou", "Background"
    ]

    static let motionVocabulary: [String] = [
        "J", "Z", "Hello", "ThankYou", "Please", "Yes",
        "No", "Sorry", "Water", "Good", "Mother", "Father", "Background"
    ]

    /// Static vocabulary alias for backward compatibility.
    static var vocabulary: [String] { staticVocabulary }

    private let cameraService: any CameraServicing
    private let handPoseDetector: any HandPoseDetecting
    private var frameTask: Task<Void, Never>?
    private let ciContext = CIContext()

    var mode: DatasetMode = .motionSigns {
        didSet {
            selectedLabel = currentVocabulary.first ?? (mode == .motionSigns ? "J" : "A")
            refreshDatasetCounts()
        }
    }

    var currentVocabulary: [String] {
        mode == .staticSigns ? Self.staticVocabulary : Self.motionVocabulary
    }

    var selectedLabel: String = "J"

    // Static burst capture settings
    var burstCount: Int = 30
    var burstInterval: TimeInterval = 0.3
    var isCapturing: Bool = false
    var capturedInCurrentBurst: Int = 0
    var lastCapturedImage: UIImage?

    // Motion video recording settings
    var clipDuration: TimeInterval = 2.0
    var isRecordingVideo: Bool = false
    var recordingProgress: Double = 0.0

    // Shared countdown
    var isCountingDown: Bool = false
    var countdownRemaining: Int = 3

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

    // Video Recording internals
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var recordingStartTime: CMTime?
    private var recordingTimeoutTask: Task<Void, Never>?

    init(
        cameraService: any CameraServicing,
        handPoseDetector: any HandPoseDetecting = StubHandPoseDetector()
    ) {
        self.cameraService = cameraService
        self.handPoseDetector = handPoseDetector
        self.authorizationState = cameraService.authorizationState
        self.currentPosition = cameraService.currentPosition
        self.selectedLabel = Self.motionVocabulary.first ?? "J"
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
        recordingTimeoutTask?.cancel()
        recordingTimeoutTask = nil
        isCapturing = false
        isRecordingVideo = false
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

                // Handle video recording for motion dataset
                if self.isRecordingVideo, let writer = self.assetWriter, let input = self.assetWriterInput {
                    let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    if self.recordingStartTime == nil {
                        self.recordingStartTime = pts
                        writer.startSession(atSourceTime: pts)
                    }

                    if input.isReadyForMoreMediaData {
                        input.append(sampleBuffer)
                    }

                    if let start = self.recordingStartTime {
                        let elapsed = CMTimeGetSeconds(CMTimeSubtract(pts, start))
                        self.recordingProgress = min(1.0, elapsed / self.clipDuration)
                        if elapsed >= self.clipDuration {
                            Task { [weak self] in
                                await self?.stopVideoClipRecording()
                            }
                        }
                    }
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

    // MARK: - Static Burst Capture

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

    // MARK: - Motion Video Recording

    func startMotionRecordingSequence() {
        guard !isRecordingVideo && !isCountingDown else { return }

        isCountingDown = true
        countdownRemaining = 3

        captureBurstTask = Task { [weak self] in
            guard let self else { return }

            while self.countdownRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                self.countdownRemaining -= 1
            }

            self.isCountingDown = false
            await self.beginVideoRecording()
        }
    }

    private func beginVideoRecording() async {
        let labelDir = labelDirectoryURL(for: selectedLabel)
        try? FileManager.default.createDirectory(at: labelDir, withIntermediateDirectories: true)

        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let filename = "\(selectedLabel)_\(timestamp).mov"
        let outputURL = labelDir.appendingPathComponent(filename)

        try? FileManager.default.removeItem(at: outputURL)

        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mov) else {
            return
        }

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 720,
            AVVideoHeightKey: 1280
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = true

        if currentPosition == .front {
            input.transform = CGAffineTransform(rotationAngle: .pi / 2).scaledBy(x: -1, y: 1)
        } else {
            input.transform = CGAffineTransform(rotationAngle: .pi / 2)
        }

        if writer.canAdd(input) {
            writer.add(input)
        }

        writer.startWriting()
        self.assetWriter = writer
        self.assetWriterInput = input
        self.recordingStartTime = nil
        self.recordingProgress = 0.0
        self.isRecordingVideo = true

        // Safety timeout so recording stops even if camera stream pauses
        recordingTimeoutTask?.cancel()
        recordingTimeoutTask = Task { [weak self] in
            guard let self else { return }
            let safetyDuration = UInt64((self.clipDuration + 0.8) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: safetyDuration)
            if self.isRecordingVideo {
                await self.stopVideoClipRecording()
            }
        }
    }

    func stopVideoClipRecording() async {
        guard isRecordingVideo else { return }
        recordingTimeoutTask?.cancel()
        recordingTimeoutTask = nil
        isRecordingVideo = false
        assetWriterInput?.markAsFinished()

        if let writer = assetWriter {
            await withCheckedContinuation { continuation in
                writer.finishWriting {
                    continuation.resume()
                }
            }
        }

        assetWriter = nil
        assetWriterInput = nil
        recordingStartTime = nil
        recordingProgress = 0.0

        refreshDatasetCounts()
    }

    func cancelMotionRecording() {
        captureBurstTask?.cancel()
        captureBurstTask = nil
        recordingTimeoutTask?.cancel()
        recordingTimeoutTask = nil
        isCountingDown = false
        isRecordingVideo = false
        assetWriter?.cancelWriting()
        assetWriter = nil
        assetWriterInput = nil
        recordingStartTime = nil
        recordingProgress = 0.0
        refreshDatasetCounts()
    }

    // MARK: - Storage Management

    var datasetDirectoryURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("Dataset", isDirectory: true)
    }

    var currentModeDirectoryURL: URL {
        let subfolder = (mode == .staticSigns) ? "Static" : "Motion"
        return datasetDirectoryURL.appendingPathComponent(subfolder, isDirectory: true)
    }

    func labelDirectoryURL(for label: String) -> URL {
        currentModeDirectoryURL.appendingPathComponent(label, isDirectory: true)
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
        let targetExtensions = (mode == .staticSigns) ? [".jpg", ".jpeg"] : [".mov", ".mp4"]

        for label in currentVocabulary {
            let labelDir = labelDirectoryURL(for: label)
            var count = 0
            if let files = try? FileManager.default.contentsOfDirectory(atPath: labelDir.path) {
                count = files.filter { file in
                    targetExtensions.contains { file.lowercased().hasSuffix($0) }
                }.count
            }

            // Fallback for flat legacy static folder: Documents/Dataset/<label>
            if mode == .staticSigns && count == 0 {
                let legacyDir = datasetDirectoryURL.appendingPathComponent(label, isDirectory: true)
                if let legacyFiles = try? FileManager.default.contentsOfDirectory(atPath: legacyDir.path) {
                    count = legacyFiles.filter { $0.hasSuffix(".jpg") || $0.hasSuffix(".jpeg") }.count
                }
            }

            counts[label] = count
        }
        self.classCounts = counts
    }

    func deleteItems(for label: String) {
        let labelDir = labelDirectoryURL(for: label)
        try? FileManager.default.removeItem(at: labelDir)
        if mode == .staticSigns {
            let legacyDir = datasetDirectoryURL.appendingPathComponent(label, isDirectory: true)
            try? FileManager.default.removeItem(at: legacyDir)
        }
        refreshDatasetCounts()
    }

    func deletePhotos(for label: String) {
        deleteItems(for: label)
    }

    func clearAllDataset() {
        try? FileManager.default.removeItem(at: datasetDirectoryURL)
        refreshDatasetCounts()
    }
}
#endif
