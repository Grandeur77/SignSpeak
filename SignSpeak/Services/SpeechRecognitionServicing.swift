import Foundation
import Speech
import AVFoundation

/// Transcription event carrying partial or final transcribed text, confidence, and timestamp.
public struct TranscriptionResult: Sendable, Equatable {
    public let text: String
    public let isFinal: Bool
    public let confidence: Float
    public let timestamp: Date

    public init(
        text: String,
        isFinal: Bool = false,
        confidence: Float = 1.0,
        timestamp: Date = Date()
    ) {
        self.text = text
        self.isFinal = isFinal
        self.confidence = confidence
        self.timestamp = timestamp
    }
}

/// Authorization status for Speech and Microphone permissions.
public enum SpeechRecognitionPermission: String, Sendable, CaseIterable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

/// Errors specific to on-device speech recognition.
public enum SpeechRecognitionError: LocalizedError, Sendable, Equatable {
    case onDeviceRecognitionUnsupported(locale: String)
    case microphonePermissionDenied
    case speechRecognitionPermissionDenied
    case audioEngineFailure(String)
    case recognizerUnavailable
    case interrupted

    public var errorDescription: String? {
        switch self {
        case .onDeviceRecognitionUnsupported(let locale):
            return "On-device speech recognition is not supported on this device for '\(locale)'. To protect your privacy, SignSpeak never uploads your audio to remote servers."
        case .microphonePermissionDenied:
            return "Microphone access has been denied. Please enable microphone permissions in Settings to transcribe speech."
        case .speechRecognitionPermissionDenied:
            return "Speech recognition access has been denied. Please enable speech recognition permissions in Settings."
        case .audioEngineFailure(let details):
            return "Audio engine failed to initialize: \(details)"
        case .recognizerUnavailable:
            return "Speech recognizer is currently unavailable."
        case .interrupted:
            return "Audio capture was interrupted by another system activity."
        }
    }
}

/// Protocol abstracting on-device speech-to-text recognition via Apple's Speech framework.
public protocol SpeechRecognitionServicing: Sendable {
    /// True if speech recognition is authorized and available on current hardware.
    var isAvailable: Bool { get }

    /// True while an active transcription session is recording.
    var isTranscribing: Bool { get }

    /// True if on-device recognition is supported for the current locale without cloud fallback.
    var supportsOnDeviceRecognition: Bool { get }

    /// Current active language/locale.
    var currentLocale: Locale { get }

    /// Requests necessary microphone and speech recognition permissions.
    func requestPermissions() async -> Bool

    /// Checks current permission statuses.
    func checkPermissions() -> (speech: SpeechRecognitionPermission, mic: SpeechRecognitionPermission)

    /// Sets recognition locale from user preferences.
    func setLocale(_ locale: Locale)

    /// Enables or disables hardware voice processing (background-noise filtering).
    func setVoiceProcessingEnabled(_ enabled: Bool)

    /// Starts audio recording and delivers a real-time stream of transcribed text with punctuation.
    func startTranscription() async throws -> AsyncStream<TranscriptionResult>

    /// Provides a stream of normalized audio power levels (0.0 to 1.0) for waveform visualization.
    func audioLevelStream() -> AsyncStream<Float>

    /// Stops audio capture and speech recognition cleanly.
    func stopTranscription() async
}

// MARK: - Concrete On-Device Implementation

/// Production on-device speech recognition service using Apple's `SFSpeechRecognizer` and `AVAudioEngine`.
/// Strictly enforces `requiresOnDeviceRecognition = true` with zero cloud fallbacks.
public final class OnDeviceSpeechRecognitionService: NSObject, SpeechRecognitionServicing, SFSpeechRecognizerDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var _currentLocale: Locale
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?

    private var transcriptContinuation: AsyncStream<TranscriptionResult>.Continuation?
    private var audioLevelContinuation: AsyncStream<Float>.Continuation?

    private var _isTranscribing: Bool = false
    private var _isVoiceProcessingEnabled: Bool = true

    public override init() {
        let initialLocale = Locale(identifier: "en-US")
        self._currentLocale = initialLocale
        self.speechRecognizer = SFSpeechRecognizer(locale: initialLocale)
        super.init()
        self.speechRecognizer?.delegate = self
        setupInterruptionObserver()
    }

    public init(locale: Locale) {
        self._currentLocale = locale
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        super.init()
        self.speechRecognizer?.delegate = self
        setupInterruptionObserver()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Properties

    public var isAvailable: Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let recognizer = speechRecognizer else { return false }
        return recognizer.isAvailable && recognizer.supportsOnDeviceRecognition
    }

    public var isTranscribing: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isTranscribing
    }

    public var supportsOnDeviceRecognition: Bool {
        lock.lock()
        defer { lock.unlock() }
        return speechRecognizer?.supportsOnDeviceRecognition ?? false
    }

    public var currentLocale: Locale {
        lock.lock()
        defer { lock.unlock() }
        return _currentLocale
    }

    // MARK: - Configuration

    public func setLocale(_ locale: Locale) {
        lock.lock()
        defer { lock.unlock() }
        guard locale != _currentLocale else { return }
        self._currentLocale = locale
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        self.speechRecognizer?.delegate = self
    }

    public func setVoiceProcessingEnabled(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        self._isVoiceProcessingEnabled = enabled
        if let engine = audioEngine, _isTranscribing {
            try? engine.inputNode.setVoiceProcessingEnabled(enabled)
        }
    }

    // MARK: - Permissions

    public func checkPermissions() -> (speech: SpeechRecognitionPermission, mic: SpeechRecognitionPermission) {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let speechPermission: SpeechRecognitionPermission
        switch speechStatus {
        case .authorized: speechPermission = .authorized
        case .denied: speechPermission = .denied
        case .restricted: speechPermission = .restricted
        case .notDetermined: speechPermission = .notDetermined
        @unknown default: speechPermission = .denied
        }

        let audioSession = AVAudioSession.sharedInstance()
        let micPermission: SpeechRecognitionPermission
        switch audioSession.recordPermission {
        case .granted: micPermission = .authorized
        case .denied: micPermission = .denied
        case .undetermined: micPermission = .notDetermined
        @unknown default: micPermission = .denied
        }

        return (speech: speechPermission, mic: micPermission)
    }

    public func requestPermissions() async -> Bool {
        // 1. Request Speech Recognizer Permission
        let speechStatus: Bool = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechStatus else { return false }

        // 2. Request Microphone Permission
        let micStatus: Bool
        if #available(iOS 17.0, *) {
            micStatus = await AVAudioApplication.requestRecordPermission()
        } else {
            micStatus = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }

        return micStatus
    }

    // MARK: - Transcription

    public func startTranscription() async throws -> AsyncStream<TranscriptionResult> {
        lock.lock()
        defer { lock.unlock() }

        // Stop any currently running task
        cleanupInternal()

        // 1. Verify Permissions
        let permissions = checkPermissions()
        guard permissions.mic == .authorized else {
            throw SpeechRecognitionError.microphonePermissionDenied
        }
        guard permissions.speech == .authorized else {
            throw SpeechRecognitionError.speechRecognitionPermissionDenied
        }

        // 2. Verify On-Device Capability (Strict Privacy Rule: Never fall back to server)
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw SpeechRecognitionError.recognizerUnavailable
        }

        guard recognizer.supportsOnDeviceRecognition else {
            throw SpeechRecognitionError.onDeviceRecognitionUnsupported(locale: _currentLocale.identifier)
        }

        // 3. Configure Audio Session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw SpeechRecognitionError.audioEngineFailure("AudioSession setup failed: \(error.localizedDescription)")
        }

        // 4. Create On-Device Recognition Request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true // ENFORCED: Never send audio to Apple servers
        request.shouldReportPartialResults = true   // Live real-time partial updates
        if #available(iOS 16.0, *) {
            request.addsPunctuation = true          // Natural sentence punctuation
        }
        self.recognitionRequest = request

        // 5. Configure Audio Engine & Voice Processing Input Node
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        if _isVoiceProcessingEnabled {
            // Hardware voice processing filters background noise and suppresses echo
            try? inputNode.setVoiceProcessingEnabled(true)
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0 else {
            throw SpeechRecognitionError.audioEngineFailure("Invalid microphone audio format.")
        }

        // 6. Install Tap to stream PCM audio to SFSpeech and compute RMS waveform level
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.recognitionRequest?.append(buffer)

            // Compute audio power level for waveform
            let level = Self.calculateAudioLevel(buffer: buffer)
            self.lock.lock()
            self.audioLevelContinuation?.yield(level)
            self.lock.unlock()
        }

        self.audioEngine = engine

        // 7. Start Audio Engine
        do {
            engine.prepare()
            try engine.start()
            self._isTranscribing = true
        } catch {
            cleanupInternal()
            throw SpeechRecognitionError.audioEngineFailure("Engine failed to start: \(error.localizedDescription)")
        }

        // 8. Create AsyncStream for Transcription Results
        let (stream, continuation) = AsyncStream<TranscriptionResult>.makeStream()
        self.transcriptContinuation = continuation

        continuation.onTermination = { [weak self] _ in
            Task { [weak self] in
                await self?.stopTranscription()
            }
        }

        // 9. Start SFSpeech Recognition Task
        self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let text = result.bestTranscription.formattedString
                let isFinal = result.isFinal
                let confidence = result.bestTranscription.segments.last?.confidence ?? 1.0

                let item = TranscriptionResult(
                    text: text,
                    isFinal: isFinal,
                    confidence: confidence,
                    timestamp: Date()
                )

                self.lock.lock()
                self.transcriptContinuation?.yield(item)
                self.lock.unlock()

                if isFinal {
                    self.lock.lock()
                    self.transcriptContinuation?.finish()
                    self.lock.unlock()
                }
            }

            if let error {
                self.lock.lock()
                self.transcriptContinuation?.finish()
                self.lock.unlock()
                Task { [weak self] in
                    await self?.stopTranscription()
                }
            }
        }

        return stream
    }

    public func audioLevelStream() -> AsyncStream<Float> {
        lock.lock()
        defer { lock.unlock() }

        let (stream, continuation) = AsyncStream<Float>.makeStream()
        self.audioLevelContinuation = continuation
        return stream
    }

    public func stopTranscription() async {
        lock.lock()
        defer { lock.unlock() }
        cleanupInternal()
    }

    // MARK: - Internal Teardown

    private func cleanupInternal() {
        _isTranscribing = false

        if let engine = audioEngine {
            if engine.isRunning {
                engine.stop()
            }
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        transcriptContinuation?.finish()
        transcriptContinuation = nil

        audioLevelContinuation?.finish()
        audioLevelContinuation = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Audio Level Calculation

    /// Pure function calculating normalized audio power level (0.0 to 1.0) from PCM buffer.
    public static func calculateAudioLevel(buffer: AVAudioPCMBuffer) -> Float {
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        if let channelData = buffer.floatChannelData?[0] {
            var sum: Float = 0
            for i in 0..<frameLength {
                let sample = channelData[i]
                sum += sample * sample
            }
            let rms = sqrt(sum / Float(frameLength))
            return min(1.0, max(0.0, rms * 5.0))
        } else if let int16Data = buffer.int16ChannelData?[0] {
            var sum: Float = 0
            for i in 0..<frameLength {
                let sample = Float(int16Data[i]) / 32768.0
                sum += sample * sample
            }
            let rms = sqrt(sum / Float(frameLength))
            return min(1.0, max(0.0, rms * 5.0))
        }

        return 0
    }

    // MARK: - Audio Interruption Handling

    private func setupInterruptionObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            lock.lock()
            if _isTranscribing {
                cleanupInternal()
            }
            lock.unlock()

        case .ended:
            // Let the UI or caller explicitly restart session
            break

        @unknown default:
            break
        }
    }
}

// MARK: - Stub Implementation for Tests & Previews

/// Configurable stub implementation of `SpeechRecognitionServicing` for unit tests and SwiftUI previews.
public final class StubSpeechRecognitionService: SpeechRecognitionServicing, @unchecked Sendable {
    private let lock = NSLock()

    public var isAvailable: Bool = true
    public var isTranscribing: Bool = false
    public var supportsOnDeviceRecognition: Bool = true
    public var currentLocale: Locale = Locale(identifier: "en-US")
    public var voiceProcessingEnabled: Bool = true

    public var permissionResult: Bool = true
    public var simulatedPermissions: (speech: SpeechRecognitionPermission, mic: SpeechRecognitionPermission) = (.authorized, .authorized)

    public var simulatedTranscripts: [String] = [
        "Hello",
        "Hello, how can I",
        "Hello, how can I help you today?"
    ]
    public var simulatedAudioLevels: [Float] = [0.1, 0.35, 0.7, 0.9, 0.4, 0.2, 0.0]
    public var simulatedError: SpeechRecognitionError? = nil

    private var activeContinuation: AsyncStream<TranscriptionResult>.Continuation?
    private var activeLevelContinuation: AsyncStream<Float>.Continuation?

    public init(
        isAvailable: Bool = true,
        supportsOnDevice: Bool = true,
        locale: Locale = Locale(identifier: "en-US")
    ) {
        self.isAvailable = isAvailable
        self.supportsOnDeviceRecognition = supportsOnDevice
        self.currentLocale = locale
    }

    public func requestPermissions() async -> Bool {
        permissionResult
    }

    public func checkPermissions() -> (speech: SpeechRecognitionPermission, mic: SpeechRecognitionPermission) {
        simulatedPermissions
    }

    public func setLocale(_ locale: Locale) {
        lock.lock()
        defer { lock.unlock() }
        self.currentLocale = locale
    }

    public func setVoiceProcessingEnabled(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        self.voiceProcessingEnabled = enabled
    }

    public func startTranscription() async throws -> AsyncStream<TranscriptionResult> {
        lock.lock()
        defer { lock.unlock() }

        if let err = simulatedError {
            throw err
        }

        guard supportsOnDeviceRecognition else {
            throw SpeechRecognitionError.onDeviceRecognitionUnsupported(locale: currentLocale.identifier)
        }

        isTranscribing = true

        let (stream, continuation) = AsyncStream<TranscriptionResult>.makeStream()
        self.activeContinuation = continuation

        // Deliver simulated transcript sequence
        let items = simulatedTranscripts
        Task {
            for (index, text) in items.enumerated() {
                try? await Task.sleep(nanoseconds: 30_000_000)
                let isLast = index == items.count - 1
                continuation.yield(TranscriptionResult(text: text, isFinal: isLast))
            }
        }

        return stream
    }

    public func audioLevelStream() -> AsyncStream<Float> {
        lock.lock()
        defer { lock.unlock() }

        let (stream, continuation) = AsyncStream<Float>.makeStream()
        self.activeLevelContinuation = continuation

        let levels = simulatedAudioLevels
        Task {
            for level in levels {
                try? await Task.sleep(nanoseconds: 20_000_000)
                continuation.yield(level)
            }
        }

        return stream
    }

    public func stopTranscription() async {
        lock.lock()
        defer { lock.unlock() }
        isTranscribing = false
        activeContinuation?.finish()
        activeContinuation = nil
        activeLevelContinuation?.finish()
        activeLevelContinuation = nil
    }

    /// Helper for test assertions to simulate an interruption event.
    public func simulateInterruption() {
        lock.lock()
        defer { lock.unlock() }
        isTranscribing = false
        activeContinuation?.finish()
        activeContinuation = nil
        activeLevelContinuation?.finish()
        activeLevelContinuation = nil
    }
}
