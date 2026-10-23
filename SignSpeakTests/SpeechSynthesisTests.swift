import Testing
import Foundation
import AVFoundation
@testable import SignSpeak

/// Comprehensive test suite validating speech synthesis service lifecycle, speaking rates,
/// voice selection, preview audio, speech recognition language syncing, and UserDefaults persistence.
@Suite("Speech Synthesis & Voice Settings")
@MainActor
struct SpeechSynthesisTests {

    // MARK: - 1. SpeakingRate Presets

    @Test("SpeakingRate enum values provide correct multipliers and raw rates")
    func speakingRatePresets() {
        let slow = SpeakingRate.slow
        let def = SpeakingRate.default
        let fast = SpeakingRate.fast

        #expect(slow.title == "Slow")
        #expect(slow.multiplierText == "0.75×")
        #expect(abs(slow.rawRate - (AVSpeechUtteranceDefaultSpeechRate * 0.75)) < 0.001)

        #expect(def.title == "Default")
        #expect(def.multiplierText == "1.0×")
        #expect(abs(def.rawRate - AVSpeechUtteranceDefaultSpeechRate) < 0.001)

        #expect(fast.title == "Fast")
        #expect(fast.multiplierText == "1.25×")
        #expect(abs(fast.rawRate - (AVSpeechUtteranceDefaultSpeechRate * 1.25)) < 0.001)

        #expect(SpeakingRate.allCases.count == 3)
    }

    // MARK: - 2. VoiceOption Model

    @Test("VoiceOption model equality, hashing and custom properties")
    func voiceOptionModel() {
        let v1 = VoiceOption(
            id: "com.apple.voice.compact.en-US.Samantha",
            name: "Samantha",
            language: "en-US",
            displayName: "Samantha (English - US)",
            qualityDescription: "Enhanced"
        )
        let v2 = VoiceOption(
            id: "com.apple.voice.compact.en-US.Samantha",
            name: "Samantha",
            language: "en-US",
            displayName: "Samantha (English - US)",
            qualityDescription: "Enhanced"
        )
        let v3 = VoiceOption(
            id: "com.apple.voice.compact.en-GB.Daniel",
            name: "Daniel",
            language: "en-GB",
            displayName: "Daniel (English - UK)"
        )

        #expect(v1 == v2)
        #expect(v1 != v3)
        #expect(v1.qualityDescription == "Enhanced")
        #expect(v3.qualityDescription == "Default")
    }

    // MARK: - 3. StubSpeechSynthesisService Lifecycle

    @Test("StubSpeechSynthesisService records utterances, rate, and voice identifier")
    func stubSynthesisLifecycle() async throws {
        let stub = StubSpeechSynthesisService()
        #expect(!stub.isSpeaking)
        #expect(stub.availableVoices().count >= 3)

        try await stub.speak(
            text: "Testing speech output",
            voiceIdentifier: "com.apple.voice.compact.en-US.Samantha",
            language: "en-US",
            rate: 0.5,
            pitchMultiplier: 1.0,
            volume: 1.0
        )

        #expect(stub.spokenUtterances.contains("Testing speech output"))
        #expect(stub.lastVoiceIdentifier == "com.apple.voice.compact.en-US.Samantha")
        #expect(stub.lastRate == 0.5)
        #expect(!stub.isSpeaking)

        stub.stopSpeaking()
        #expect(!stub.isSpeaking)
    }

    // MARK: - 4. Concrete OnDeviceSpeechSynthesisService Initialization

    @Test("OnDeviceSpeechSynthesisService initializes cleanly and queries system voices")
    func onDeviceSpeechSynthesisService() {
        let service = OnDeviceSpeechSynthesisService()
        #expect(!service.isSpeaking)

        // Query available voices (on simulator/device this returns the platform's speech voices)
        let voices = service.availableVoices()
        // Should not crash and returns a collection
        #expect(voices.count >= 0)

        service.stopSpeaking()
        #expect(!service.isSpeaking)
    }

    // MARK: - 5. VoiceAndSpeechSettingsViewModel Tests

    @Test("ViewModel initializes with defaults when UserDefaults is empty")
    func viewModelDefaults() {
        let testDefaults = UserDefaults(suiteName: "TestVoiceDefaults_\(UUID().uuidString)")!
        let stubSynthesis = StubSpeechSynthesisService()
        let stubSpeechRecognition = StubSpeechRecognitionService()

        let vm = VoiceAndSpeechSettingsViewModel(
            speechSynthesisService: stubSynthesis,
            speechRecognitionService: stubSpeechRecognition,
            userDefaults: testDefaults
        )

        #expect(vm.selectedRate == .default)
        #expect(vm.speechRecognitionLanguage == "en-US")
        #expect(vm.filterBackgroundNoise == true)
        #expect(vm.testPhrase == VoiceAndSpeechSettingsViewModel.defaultTestPhrase)
        #expect(vm.selectedVoiceId == stubSynthesis.availableVoices().first?.id)
        #expect(stubSpeechRecognition.currentLocale.identifier == "en-US")
        #expect(stubSpeechRecognition.voiceProcessingEnabled == true)
    }

    @Test("ViewModel persists voice selection to UserDefaults")
    func viewModelSelectVoice() {
        let testDefaults = UserDefaults(suiteName: "TestVoiceSelection_\(UUID().uuidString)")!
        let stubSynthesis = StubSpeechSynthesisService()
        let stubSpeechRecognition = StubSpeechRecognitionService()

        let vm = VoiceAndSpeechSettingsViewModel(
            speechSynthesisService: stubSynthesis,
            speechRecognitionService: stubSpeechRecognition,
            userDefaults: testDefaults
        )

        let targetVoice = stubSynthesis.availableVoices().last!
        vm.selectVoice(id: targetVoice.id)

        #expect(vm.selectedVoiceId == targetVoice.id)
        #expect(testDefaults.string(forKey: VoiceAndSpeechSettingsViewModel.keySelectedVoiceId) == targetVoice.id)
    }

    @Test("ViewModel persists speaking rate and propagates updates")
    func viewModelSelectRate() {
        let testDefaults = UserDefaults(suiteName: "TestVoiceRate_\(UUID().uuidString)")!
        let stubSynthesis = StubSpeechSynthesisService()
        let stubSpeechRecognition = StubSpeechRecognitionService()

        let vm = VoiceAndSpeechSettingsViewModel(
            speechSynthesisService: stubSynthesis,
            speechRecognitionService: stubSpeechRecognition,
            userDefaults: testDefaults
        )

        vm.selectSpeakingRate(.fast)
        #expect(vm.selectedRate == .fast)
        #expect(testDefaults.string(forKey: VoiceAndSpeechSettingsViewModel.keySpeakingRate) == "fast")

        vm.selectSpeakingRate(.slow)
        #expect(vm.selectedRate == .slow)
        #expect(testDefaults.string(forKey: VoiceAndSpeechSettingsViewModel.keySpeakingRate) == "slow")
    }

    @Test("ViewModel updates speech recognition language and notifies recognition service")
    func viewModelRecognitionLanguage() {
        let testDefaults = UserDefaults(suiteName: "TestVoiceLang_\(UUID().uuidString)")!
        let stubSynthesis = StubSpeechSynthesisService()
        let stubSpeechRecognition = StubSpeechRecognitionService()

        let vm = VoiceAndSpeechSettingsViewModel(
            speechSynthesisService: stubSynthesis,
            speechRecognitionService: stubSpeechRecognition,
            userDefaults: testDefaults
        )

        vm.selectRecognitionLanguage("es-ES")
        #expect(vm.speechRecognitionLanguage == "es-ES")
        #expect(testDefaults.string(forKey: VoiceAndSpeechSettingsViewModel.keyRecognitionLanguage) == "es-ES")
        #expect(stubSpeechRecognition.currentLocale.identifier == "es-ES")
        #expect(vm.selectedRecognitionOption.id == "es-ES")
        #expect(vm.selectedRecognitionOption.flag == "🇪🇸")
    }

    @Test("ViewModel toggles background noise filtering and notifies recognition service")
    func viewModelNoiseFiltering() {
        let testDefaults = UserDefaults(suiteName: "TestVoiceNoise_\(UUID().uuidString)")!
        let stubSynthesis = StubSpeechSynthesisService()
        let stubSpeechRecognition = StubSpeechRecognitionService()

        let vm = VoiceAndSpeechSettingsViewModel(
            speechSynthesisService: stubSynthesis,
            speechRecognitionService: stubSpeechRecognition,
            userDefaults: testDefaults
        )

        vm.setFilterBackgroundNoise(false)
        #expect(vm.filterBackgroundNoise == false)
        #expect(testDefaults.bool(forKey: VoiceAndSpeechSettingsViewModel.keyFilterBackgroundNoise) == false)
        #expect(stubSpeechRecognition.voiceProcessingEnabled == false)

        vm.setFilterBackgroundNoise(true)
        #expect(vm.filterBackgroundNoise == true)
        #expect(testDefaults.bool(forKey: VoiceAndSpeechSettingsViewModel.keyFilterBackgroundNoise) == true)
        #expect(stubSpeechRecognition.voiceProcessingEnabled == true)
    }

    @Test("ViewModel previewVoice speaks expected intro text with selected rate")
    func viewModelPreviewVoice() async {
        let testDefaults = UserDefaults(suiteName: "TestVoicePreview_\(UUID().uuidString)")!
        let stubSynthesis = StubSpeechSynthesisService()
        let stubSpeechRecognition = StubSpeechRecognitionService()

        let vm = VoiceAndSpeechSettingsViewModel(
            speechSynthesisService: stubSynthesis,
            speechRecognitionService: stubSpeechRecognition,
            userDefaults: testDefaults
        )

        let voice = stubSynthesis.availableVoices().first!
        vm.previewVoice(voice)

        // Wait brief task cycle for Task to finish
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(stubSynthesis.spokenUtterances.contains { $0.contains("Hi, I am \(voice.name)") })
        #expect(stubSynthesis.lastVoiceIdentifier == voice.id)
    }

    @Test("ViewModel test audio plays custom phrase and toggles state")
    func viewModelTestAudio() async {
        let testDefaults = UserDefaults(suiteName: "TestVoiceAudio_\(UUID().uuidString)")!
        let stubSynthesis = StubSpeechSynthesisService()
        let stubSpeechRecognition = StubSpeechRecognitionService()

        let vm = VoiceAndSpeechSettingsViewModel(
            speechSynthesisService: stubSynthesis,
            speechRecognitionService: stubSpeechRecognition,
            userDefaults: testDefaults
        )

        vm.updateTestPhrase("Custom speech test sentence.")
        #expect(testDefaults.string(forKey: VoiceAndSpeechSettingsViewModel.keyTestPhrase) == "Custom speech test sentence.")

        vm.playTestAudio()
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(stubSynthesis.spokenUtterances.contains("Custom speech test sentence."))

        vm.stopTestAudio()
        #expect(!vm.isPlayingTestAudio)
    }

    @Test("ViewModel resetToDefaults restores standard configuration")
    func viewModelResetToDefaults() {
        let testDefaults = UserDefaults(suiteName: "TestVoiceReset_\(UUID().uuidString)")!
        let stubSynthesis = StubSpeechSynthesisService()
        let stubSpeechRecognition = StubSpeechRecognitionService()

        let vm = VoiceAndSpeechSettingsViewModel(
            speechSynthesisService: stubSynthesis,
            speechRecognitionService: stubSpeechRecognition,
            userDefaults: testDefaults
        )

        // Set non-defaults
        vm.selectSpeakingRate(.slow)
        vm.selectRecognitionLanguage("fr-FR")
        vm.setFilterBackgroundNoise(false)
        vm.updateTestPhrase("Non-default phrase")

        // Reset
        vm.resetToDefaults()

        #expect(vm.selectedRate == .default)
        #expect(vm.speechRecognitionLanguage == "en-US")
        #expect(vm.filterBackgroundNoise == true)
        #expect(vm.testPhrase == VoiceAndSpeechSettingsViewModel.defaultTestPhrase)
        #expect(stubSpeechRecognition.currentLocale.identifier == "en-US")
        #expect(stubSpeechRecognition.voiceProcessingEnabled == true)
    }
}
