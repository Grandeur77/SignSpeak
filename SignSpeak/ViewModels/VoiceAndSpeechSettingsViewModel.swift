import SwiftUI
import AVFoundation

/// Supported on-device speech recognition locale option.
public struct RecognitionLanguageOption: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let region: String
    public let flag: String

    public init(id: String, name: String, region: String, flag: String) {
        self.id = id
        self.name = name
        self.region = region
        self.flag = flag
    }

    public var displayName: String {
        "\(flag) \(name) (\(region))"
    }
}

/// View model backing the Voice & Speech settings screen (`54-voice-and-speech`).
/// Coordinates text-to-speech synthesis preferences, preview audio, speech recognition locale,
/// and microphone background-noise filtering with UserDefaults persistence.
@Observable
@MainActor
public final class VoiceAndSpeechSettingsViewModel {
    // MARK: - Constants & Keys

    public static let keySelectedVoiceId = "voiceSettings_selectedVoiceId"
    public static let keySpeakingRate = "voiceSettings_speakingRate"
    public static let keyRecognitionLanguage = "voiceSettings_recognitionLanguage"
    public static let keyFilterBackgroundNoise = "voiceSettings_filterBackgroundNoise"
    public static let keyTestPhrase = "voiceSettings_testPhrase"

    public static let defaultTestPhrase = "Hello! SignSpeak is translating your signs into natural spoken words."
    public static let defaultRecognitionLocale = "en-US"

    public static let standardRecognitionLanguages: [RecognitionLanguageOption] = [
        RecognitionLanguageOption(id: "en-US", name: "English", region: "United States", flag: "🇺🇸"),
        RecognitionLanguageOption(id: "en-GB", name: "English", region: "United Kingdom", flag: "🇬🇧"),
        RecognitionLanguageOption(id: "en-AU", name: "English", region: "Australia", flag: "🇦🇺"),
        RecognitionLanguageOption(id: "en-CA", name: "English", region: "Canada", flag: "🇨🇦"),
        RecognitionLanguageOption(id: "es-ES", name: "Spanish", region: "Spain", flag: "🇪🇸"),
        RecognitionLanguageOption(id: "es-US", name: "Spanish", region: "United States", flag: "🇺🇸"),
        RecognitionLanguageOption(id: "fr-FR", name: "French", region: "France", flag: "🇫🇷"),
        RecognitionLanguageOption(id: "de-DE", name: "German", region: "Germany", flag: "🇩🇪"),
        RecognitionLanguageOption(id: "ja-JP", name: "Japanese", region: "Japan", flag: "🇯🇵")
    ]

    // MARK: - Dependencies

    public let speechSynthesisService: any SpeechSynthesisServicing
    public let speechRecognitionService: any SpeechRecognitionServicing
    private let userDefaults: UserDefaults

    // MARK: - Published State

    public var availableVoices: [VoiceOption] = []
    public var selectedVoiceId: String = ""
    public var selectedRate: SpeakingRate = .default
    public var speechRecognitionLanguage: String = "en-US"
    public var filterBackgroundNoise: Bool = true
    public var testPhrase: String = defaultTestPhrase

    public var isPlayingTestAudio: Bool = false
    public var previewingVoiceId: String? = nil
    public var errorMessage: String? = nil

    // MARK: - Computed Properties

    public var selectedVoice: VoiceOption? {
        availableVoices.first { $0.id == selectedVoiceId }
    }

    public var selectedRecognitionOption: RecognitionLanguageOption {
        Self.standardRecognitionLanguages.first { $0.id == speechRecognitionLanguage }
            ?? RecognitionLanguageOption(id: speechRecognitionLanguage, name: "Custom", region: speechRecognitionLanguage, flag: "🌐")
    }

    // MARK: - Initialization

    public init(
        speechSynthesisService: any SpeechSynthesisServicing,
        speechRecognitionService: any SpeechRecognitionServicing,
        userDefaults: UserDefaults = .standard
    ) {
        self.speechSynthesisService = speechSynthesisService
        self.speechRecognitionService = speechRecognitionService
        self.userDefaults = userDefaults
        loadSettings()
    }

    // MARK: - Persistence & Loading

    public func loadSettings() {
        // 1. Fetch available voices
        let voices = speechSynthesisService.availableVoices()
        self.availableVoices = voices

        // 2. Load Selected Voice
        if let savedVoiceId = userDefaults.string(forKey: Self.keySelectedVoiceId),
           !savedVoiceId.isEmpty,
           voices.contains(where: { $0.id == savedVoiceId }) {
            self.selectedVoiceId = savedVoiceId
        } else {
            // Default to first English voice or first available voice
            let defaultVoice = voices.first(where: { $0.language.hasPrefix("en") }) ?? voices.first
            self.selectedVoiceId = defaultVoice?.id ?? ""
            if let id = defaultVoice?.id {
                userDefaults.set(id, forKey: Self.keySelectedVoiceId)
            }
        }

        // 3. Load Speaking Rate
        if let savedRateStr = userDefaults.string(forKey: Self.keySpeakingRate),
           let rate = SpeakingRate(rawValue: savedRateStr) {
            self.selectedRate = rate
        } else {
            self.selectedRate = .default
            userDefaults.set(SpeakingRate.default.rawValue, forKey: Self.keySpeakingRate)
        }

        // 4. Load Speech Recognition Language
        let savedLang = userDefaults.string(forKey: Self.keyRecognitionLanguage) ?? Self.defaultRecognitionLocale
        self.speechRecognitionLanguage = savedLang
        speechRecognitionService.setLocale(Locale(identifier: savedLang))

        // 5. Load Filter Background Noise
        if userDefaults.object(forKey: Self.keyFilterBackgroundNoise) != nil {
            self.filterBackgroundNoise = userDefaults.bool(forKey: Self.keyFilterBackgroundNoise)
        } else {
            self.filterBackgroundNoise = true
            userDefaults.set(true, forKey: Self.keyFilterBackgroundNoise)
        }
        speechRecognitionService.setVoiceProcessingEnabled(self.filterBackgroundNoise)

        // 6. Load Test Phrase
        self.testPhrase = userDefaults.string(forKey: Self.keyTestPhrase) ?? Self.defaultTestPhrase
    }

    // MARK: - Actions

    public func selectVoice(id: String) {
        guard selectedVoiceId != id else { return }
        selectedVoiceId = id
        userDefaults.set(id, forKey: Self.keySelectedVoiceId)
    }

    public func selectSpeakingRate(_ rate: SpeakingRate) {
        guard selectedRate != rate else { return }
        selectedRate = rate
        userDefaults.set(rate.rawValue, forKey: Self.keySpeakingRate)
    }

    public func selectRecognitionLanguage(_ langCode: String) {
        guard speechRecognitionLanguage != langCode else { return }
        speechRecognitionLanguage = langCode
        userDefaults.set(langCode, forKey: Self.keyRecognitionLanguage)
        speechRecognitionService.setLocale(Locale(identifier: langCode))
    }

    public func setFilterBackgroundNoise(_ enabled: Bool) {
        guard filterBackgroundNoise != enabled else { return }
        filterBackgroundNoise = enabled
        userDefaults.set(enabled, forKey: Self.keyFilterBackgroundNoise)
        speechRecognitionService.setVoiceProcessingEnabled(enabled)
    }

    public func updateTestPhrase(_ phrase: String) {
        testPhrase = phrase
        userDefaults.set(phrase, forKey: Self.keyTestPhrase)
    }

    // MARK: - Speech Audio Preview & Test

    public func previewVoice(_ voice: VoiceOption) {
        // If already previewing this voice, stop it
        if previewingVoiceId == voice.id {
            speechSynthesisService.stopSpeaking()
            previewingVoiceId = nil
            return
        }

        speechSynthesisService.stopSpeaking()
        isPlayingTestAudio = false
        previewingVoiceId = voice.id

        let previewText = "Hi, I am \(voice.name). Ready to translate."
        Task {
            do {
                try await speechSynthesisService.speak(
                    text: previewText,
                    voiceIdentifier: voice.id,
                    language: voice.language,
                    rate: selectedRate.rawRate,
                    pitchMultiplier: 1.0,
                    volume: 1.0
                )
            } catch {
                self.errorMessage = "Failed to preview voice: \(error.localizedDescription)"
            }
            if self.previewingVoiceId == voice.id {
                self.previewingVoiceId = nil
            }
        }
    }

    public func playTestAudio() {
        if isPlayingTestAudio {
            stopTestAudio()
            return
        }

        speechSynthesisService.stopSpeaking()
        previewingVoiceId = nil
        isPlayingTestAudio = true

        let textToSpeak = testPhrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? Self.defaultTestPhrase
            : testPhrase

        Task {
            do {
                try await speechSynthesisService.speak(
                    text: textToSpeak,
                    voiceIdentifier: selectedVoiceId.isEmpty ? nil : selectedVoiceId,
                    language: selectedVoice?.language,
                    rate: selectedRate.rawRate,
                    pitchMultiplier: 1.0,
                    volume: 1.0
                )
            } catch {
                self.errorMessage = "Failed to play test audio: \(error.localizedDescription)"
            }
            self.isPlayingTestAudio = false
        }
    }

    public func stopTestAudio() {
        speechSynthesisService.stopSpeaking()
        isPlayingTestAudio = false
        previewingVoiceId = nil
    }

    public func resetToDefaults() {
        stopTestAudio()

        let defaultVoice = availableVoices.first(where: { $0.language.hasPrefix("en") }) ?? availableVoices.first
        let voiceId = defaultVoice?.id ?? ""

        selectVoice(id: voiceId)
        selectSpeakingRate(.default)
        selectRecognitionLanguage(Self.defaultRecognitionLocale)
        setFilterBackgroundNoise(true)
        updateTestPhrase(Self.defaultTestPhrase)
    }
}
