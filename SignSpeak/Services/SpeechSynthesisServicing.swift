import Foundation
import AVFoundation

/// Speaking speed presets for text-to-speech output (design `54-voice-and-speech`).
public enum SpeakingRate: String, CaseIterable, Identifiable, Sendable {
    case slow = "slow"
    case `default` = "default"
    case fast = "fast"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .slow: return "Slow"
        case .default: return "Default"
        case .fast: return "Fast"
        }
    }

    public var multiplierText: String {
        switch self {
        case .slow: return "0.75×"
        case .default: return "1.0×"
        case .fast: return "1.25×"
        }
    }

    public var rawRate: Float {
        switch self {
        case .slow:
            return AVSpeechUtteranceDefaultSpeechRate * 0.75
        case .default:
            return AVSpeechUtteranceDefaultSpeechRate
        case .fast:
            return min(AVSpeechUtteranceMaximumSpeechRate, AVSpeechUtteranceDefaultSpeechRate * 1.25)
        }
    }
}

/// Metadata describing an available speech synthesis voice.
public struct VoiceOption: Identifiable, Sendable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let language: String
    public let displayName: String
    public let qualityDescription: String

    public init(
        id: String,
        name: String,
        language: String,
        displayName: String,
        qualityDescription: String = "Default"
    ) {
        self.id = id
        self.name = name
        self.language = language
        self.displayName = displayName
        self.qualityDescription = qualityDescription
    }
}

/// Protocol abstracting text-to-speech synthesis via Apple's AVSpeechSynthesizer.
public protocol SpeechSynthesisServicing: Sendable {
    /// True if the synthesizer is actively speaking an utterance.
    var isSpeaking: Bool { get }

    /// Speaks the provided text aloud with optional voice identifier, language, rate, pitch, and volume.
    func speak(
        text: String,
        voiceIdentifier: String?,
        language: String?,
        rate: Float?,
        pitchMultiplier: Float?,
        volume: Float?
    ) async throws

    /// Convenience speak method matching earlier baseline signature.
    func speak(text: String, voiceLanguage: String?) async throws

    /// Immediately stops any ongoing speech output.
    func stopSpeaking()

    /// Returns list of available synthesis voices on the device.
    func availableVoices() -> [VoiceOption]
}

public extension SpeechSynthesisServicing {
    func speak(text: String, voiceLanguage: String? = nil) async throws {
        try await speak(
            text: text,
            voiceIdentifier: nil,
            language: voiceLanguage,
            rate: nil,
            pitchMultiplier: nil,
            volume: nil
        )
    }

    func availableVoices() -> [VoiceOption] {
        []
    }
}

// MARK: - Concrete On-Device Speech Synthesis Service

/// Production text-to-speech synthesis service using Apple's `AVSpeechSynthesizer`.
public final class OnDeviceSpeechSynthesisService: NSObject, SpeechSynthesisServicing, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private let synthesizer: AVSpeechSynthesizer
    private var _isSpeaking: Bool = false
    private var activeContinuation: CheckedContinuation<Void, Never>?

    public override init() {
        self.synthesizer = AVSpeechSynthesizer()
        super.init()
        self.synthesizer.delegate = self
    }

    public var isSpeaking: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isSpeaking || synthesizer.isSpeaking
    }

    public func speak(
        text: String,
        voiceIdentifier: String? = nil,
        language: String? = nil,
        rate: Float? = nil,
        pitchMultiplier: Float? = nil,
        volume: Float? = nil
    ) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Configure audio session for playback
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            // Audio session configuration warning; continue to attempt playback
        }

        // Cancel previous continuation and stop active speech if any
        stopSpeaking()

        let utterance = AVSpeechUtterance(string: trimmed)

        // Configure Voice
        if let voiceIdentifier, let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            utterance.voice = voice
        } else if let language, let voice = AVSpeechSynthesisVoice(language: language) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier) ?? AVSpeechSynthesisVoice(language: "en-US")
        }

        // Configure Rate, Pitch, and Volume
        if let rate {
            utterance.rate = min(AVSpeechUtteranceMaximumSpeechRate, max(AVSpeechUtteranceMinimumSpeechRate, rate))
        } else {
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        }

        if let pitchMultiplier {
            utterance.pitchMultiplier = min(2.0, max(0.5, pitchMultiplier))
        }

        if let volume {
            utterance.volume = min(1.0, max(0.0, volume))
        }

        await withCheckedContinuation { continuation in
            lock.lock()
            self._isSpeaking = true
            self.activeContinuation = continuation
            lock.unlock()

            synthesizer.speak(utterance)
        }
    }

    public func stopSpeaking() {
        lock.lock()
        _isSpeaking = false
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let cont = activeContinuation
        activeContinuation = nil
        lock.unlock()

        cont?.resume()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    public func availableVoices() -> [VoiceOption] {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let currentLang = Locale.current.language.languageCode?.identifier ?? "en"

        return voices.map { voice in
            let qualityStr: String
            switch voice.quality {
            case .enhanced: qualityStr = "Enhanced"
            case .premium: qualityStr = "Premium"
            default: qualityStr = "Default"
            }
            let locale = Locale(identifier: voice.language)
            let langName = locale.localizedString(forIdentifier: voice.language) ?? voice.language

            return VoiceOption(
                id: voice.identifier,
                name: voice.name,
                language: voice.language,
                displayName: "\(voice.name) (\(langName))",
                qualityDescription: qualityStr
            )
        }
        .sorted { v1, v2 in
            let v1Current = v1.language.hasPrefix(currentLang)
            let v2Current = v2.language.hasPrefix(currentLang)
            if v1Current != v2Current {
                return v1Current
            }
            return v1.displayName < v2.displayName
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        lock.lock()
        _isSpeaking = false
        let cont = activeContinuation
        activeContinuation = nil
        lock.unlock()

        cont?.resume()
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        lock.lock()
        _isSpeaking = false
        let cont = activeContinuation
        activeContinuation = nil
        lock.unlock()

        cont?.resume()
    }
}

// MARK: - Stub Speech Synthesis Service for Previews & Unit Tests

/// In-memory mock/stub speech synthesis service.
public final class StubSpeechSynthesisService: SpeechSynthesisServicing, @unchecked Sendable {
    private let lock = NSLock()
    public var isSpeaking: Bool = false
    public var simulatedVoices: [VoiceOption]
    public private(set) var spokenUtterances: [String] = []
    public private(set) var lastVoiceIdentifier: String?
    public private(set) var lastRate: Float?
    public var simulateDelayNanoseconds: UInt64 = 0

    public init(simulatedVoices: [VoiceOption]? = nil) {
        if let simulatedVoices {
            self.simulatedVoices = simulatedVoices
        } else {
            self.simulatedVoices = [
                VoiceOption(id: "com.apple.voice.compact.en-US.Samantha", name: "Samantha", language: "en-US", displayName: "Samantha (English - US)", qualityDescription: "Enhanced"),
                VoiceOption(id: "com.apple.voice.compact.en-GB.Daniel", name: "Daniel", language: "en-GB", displayName: "Daniel (English - UK)", qualityDescription: "Enhanced"),
                VoiceOption(id: "com.apple.voice.compact.en-AU.Karen", name: "Karen", language: "en-AU", displayName: "Karen (English - Australia)", qualityDescription: "Default"),
                VoiceOption(id: "com.apple.voice.compact.es-ES.Monica", name: "Monica", language: "es-ES", displayName: "Monica (Spanish - Spain)", qualityDescription: "Enhanced"),
                VoiceOption(id: "com.apple.voice.compact.fr-FR.Thomas", name: "Thomas", language: "fr-FR", displayName: "Thomas (French - France)", qualityDescription: "Default")
            ]
        }
    }

    public func speak(
        text: String,
        voiceIdentifier: String? = nil,
        language: String? = nil,
        rate: Float? = nil,
        pitchMultiplier: Float? = nil,
        volume: Float? = nil
    ) async throws {
        lock.lock()
        isSpeaking = true
        spokenUtterances.append(text)
        lastVoiceIdentifier = voiceIdentifier
        lastRate = rate
        let delay = simulateDelayNanoseconds
        lock.unlock()

        if delay > 0 {
            try? await Task.sleep(nanoseconds: delay)
        }

        lock.lock()
        isSpeaking = false
        lock.unlock()
    }

    public func speak(text: String, voiceLanguage: String? = nil) async throws {
        try await speak(
            text: text,
            voiceIdentifier: nil,
            language: voiceLanguage,
            rate: nil,
            pitchMultiplier: nil,
            volume: nil
        )
    }

    public func stopSpeaking() {
        lock.lock()
        isSpeaking = false
        lock.unlock()
    }

    public func availableVoices() -> [VoiceOption] {
        lock.lock()
        defer { lock.unlock() }
        return simulatedVoices
    }
}
