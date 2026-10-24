import Foundation
import AVFoundation
import SoundAnalysis

/// Interface for sound detection and classification (`Phase 12`).
public protocol SoundAlerting: AnyObject, Sendable {
    var isListening: Bool { get }
    var settings: SoundAlertSettings { get }
    var alertStream: AsyncStream<SoundAlertRecord> { get }

    func startListening() async throws
    func stopListening()
    func pauseListening()
    func resumeListening()
    func updateSettings(_ newSettings: SoundAlertSettings)
    func simulateAlert(_ alert: SoundAlertRecord)
}

/// Live sound classification service powered by Apple's `SoundAnalysis` framework and `AVAudioEngine`.
public final class SoundAlertService: NSObject, SoundAlerting, @unchecked Sendable {
    private var audioEngine: AVAudioEngine?
    private var streamAnalyzer: SNAudioStreamAnalyzer?
    private var resultsObserver: SoundResultsObserver?

    private let lock = NSLock()
    private var _isListening: Bool = false
    private var _isPaused: Bool = false
    private var _settings: SoundAlertSettings
    private var lastAlertTimestamps: [SoundAlertType: Date] = [:]
    private let coolDownInterval: TimeInterval = 5.0

    private var alertContinuation: AsyncStream<SoundAlertRecord>.Continuation?
    public let alertStream: AsyncStream<SoundAlertRecord>

    public var isListening: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isListening && !_isPaused
    }

    public var settings: SoundAlertSettings {
        lock.lock()
        defer { lock.unlock() }
        return _settings
    }

    public init(settings: SoundAlertSettings = SoundAlertSettings()) {
        self._settings = settings
        var continuation: AsyncStream<SoundAlertRecord>.Continuation?
        self.alertStream = AsyncStream { cont in
            continuation = cont
        }
        self.alertContinuation = continuation
        super.init()
    }

    public func updateSettings(_ newSettings: SoundAlertSettings) {
        lock.lock()
        self._settings = newSettings
        let shouldListen = newSettings.isListening
        lock.unlock()

        if shouldListen && !isListening {
            Task { try? await startListening() }
        } else if !shouldListen && isListening {
            stopListening()
        }
    }

    public func startListening() async throws {
        lock.lock()
        if _isListening && !_isPaused {
            lock.unlock()
            return
        }
        _isListening = true
        _isPaused = false
        lock.unlock()

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let bus = 0
        let recordingFormat = inputNode.outputFormat(forBus: bus)

        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            return
        }

        let analyzer = SNAudioStreamAnalyzer(format: recordingFormat)
        let observer = SoundResultsObserver { [weak self] classifications in
            self?.handleClassifications(classifications)
        }

        let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
        request.windowDuration = CMTime(seconds: 1.0, preferredTimescale: 44100)
        request.overlapFactor = 0.5

        try analyzer.add(request, withObserver: observer)

        inputNode.removeTap(onBus: bus)
        inputNode.installTap(onBus: bus, bufferSize: 8192, format: recordingFormat) { buffer, time in
            analyzer.analyze(buffer, atAudioFramePosition: time.sampleTime)
        }

        try engine.start()

        lock.lock()
        self.audioEngine = engine
        self.streamAnalyzer = analyzer
        self.resultsObserver = observer
        lock.unlock()
    }

    public func stopListening() {
        lock.lock()
        _isListening = false
        _isPaused = false
        let engine = audioEngine
        audioEngine = nil
        streamAnalyzer = nil
        resultsObserver = nil
        lock.unlock()

        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    public func pauseListening() {
        lock.lock()
        guard _isListening, !_isPaused else {
            lock.unlock()
            return
        }
        _isPaused = true
        let engine = audioEngine
        lock.unlock()

        engine?.pause()
    }

    public func resumeListening() {
        lock.lock()
        guard _isListening, _isPaused else {
            lock.unlock()
            return
        }
        _isPaused = false
        let engine = audioEngine
        lock.unlock()

        try? engine?.start()
    }

    public func simulateAlert(_ alert: SoundAlertRecord) {
        lock.lock()
        lastAlertTimestamps[alert.type] = Date()
        lock.unlock()
        alertContinuation?.yield(alert)
    }

    // MARK: - Classification Mapping & Filtering

    private func handleClassifications(_ classifications: [SNClassification]) {
        lock.lock()
        guard _isListening, !_isPaused else {
            lock.unlock()
            return
        }

        if _settings.isMuted {
            lock.unlock()
            return
        }

        let now = Date()
        let enabled = _settings.enabledSounds
        let currentSensitivities = _settings.sensitivities

        for classification in classifications {
            guard let mappedType = Self.mapIdentifierToSoundType(classification.identifier) else {
                continue
            }

            guard enabled.contains(mappedType) else {
                continue
            }

            let minConfidence = (currentSensitivities[mappedType] ?? .medium).minimumConfidence
            guard Double(classification.confidence) >= minConfidence else {
                continue
            }

            if let lastTime = lastAlertTimestamps[mappedType], now.timeIntervalSince(lastTime) < coolDownInterval {
                // Suppressed by cool-down
                continue
            }

            lastAlertTimestamps[mappedType] = now
            lock.unlock()

            let record = SoundAlertRecord(
                type: mappedType,
                timestamp: now,
                confidence: Double(classification.confidence),
                isEmergency: mappedType.isUrgent
            )

            alertContinuation?.yield(record)
            return
        }

        lock.unlock()
    }

    /// Maps Apple built-in SoundAnalysis identifiers to `SoundAlertType`.
    public static func mapIdentifierToSoundType(_ identifier: String) -> SoundAlertType? {
        let id = identifier.lowercased()

        // Doorbell
        if id.contains("doorbell") || id.contains("ding_dong") || id.contains("door_bell") || id == "bell" || id.contains("chime") {
            return .doorbell
        }

        // Knocking
        if id.contains("knock") || id.contains("door_knock") || id == "tapping" || id == "thump" {
            return .knocking
        }

        // Fire Alarm / Smoke Detector
        if id.contains("smoke_detector") || id.contains("fire_alarm") || id.contains("smoke_alarm") || id.contains("buzzer") {
            return .fireAlarm
        }

        // Emergency Sirens
        if id.contains("siren") || id.contains("ambulance") || id.contains("police") || id.contains("emergency_vehicle") {
            return .sirens
        }

        // Baby Crying
        if id.contains("baby") || id.contains("infant") || (id.contains("crying") && !id.contains("cheering")) {
            return .babyCrying
        }

        // Someone Calling / Shouting
        if id.contains("shout") || id.contains("yell") || id.contains("screaming") {
            return .nameCalling
        }

        return nil
    }
}

// MARK: - SoundResultsObserver

private final class SoundResultsObserver: NSObject, SNResultsObserving {
    private let onResults: ([SNClassification]) -> Void

    init(onResults: @escaping ([SNClassification]) -> Void) {
        self.onResults = onResults
    }

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let classificationResult = result as? SNClassificationResult else { return }
        onResults(classificationResult.classifications)
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {}
    func requestDidComplete(_ request: SNRequest) {}
}

// MARK: - MockSoundAlertService

/// In-memory mock for unit tests and SwiftUI Previews.
public final class MockSoundAlertService: SoundAlerting, @unchecked Sendable {
    public var isListening: Bool = false
    public var settings: SoundAlertSettings
    private var alertContinuation: AsyncStream<SoundAlertRecord>.Continuation?
    public let alertStream: AsyncStream<SoundAlertRecord>
    public var simulatedAlertHistory: [SoundAlertRecord] = []

    public init(settings: SoundAlertSettings = SoundAlertSettings()) {
        self.settings = settings
        var continuation: AsyncStream<SoundAlertRecord>.Continuation?
        self.alertStream = AsyncStream { cont in
            continuation = cont
        }
        self.alertContinuation = continuation
    }

    public func startListening() async throws {
        isListening = true
    }

    public func stopListening() {
        isListening = false
    }

    public func pauseListening() {
        isListening = false
    }

    public func resumeListening() {
        isListening = true
    }

    public func updateSettings(_ newSettings: SoundAlertSettings) {
        self.settings = newSettings
        self.isListening = newSettings.isListening
    }

    public func simulateAlert(_ alert: SoundAlertRecord) {
        guard settings.enabledSounds.contains(alert.type) else { return }
        guard !settings.isMuted else { return }
        let minConf = settings.sensitivity(for: alert.type).minimumConfidence
        guard alert.confidence >= minConf else { return }

        simulatedAlertHistory.append(alert)
        alertContinuation?.yield(alert)
    }
}
