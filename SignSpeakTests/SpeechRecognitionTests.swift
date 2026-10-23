import Testing
import Foundation
import AVFoundation
import Speech
@testable import SignSpeak

/// Test suite validating on-device speech recognition requirements, privacy guarantees,
/// audio level RMS calculations, permission handling, and streaming lifecycles.
@Suite("Speech Recognition & On-Device Processing")
struct SpeechRecognitionTests {

    // MARK: - 1. TranscriptionResult Model Tests

    @Test("TranscriptionResult initializes with expected defaults and equality")
    func transcriptionResultModel() {
        let fixedDate = Date(timeIntervalSince1970: 1_790_812_800)
        let item1 = TranscriptionResult(text: "Hello world", isFinal: false, confidence: 0.95, timestamp: fixedDate)
        let item2 = TranscriptionResult(text: "Hello world", isFinal: false, confidence: 0.95, timestamp: fixedDate)
        let item3 = TranscriptionResult(text: "Hello world", isFinal: true, confidence: 0.95, timestamp: fixedDate)

        #expect(item1 == item2)
        #expect(item1 != item3)
        #expect(item1.text == "Hello world")
        #expect(item1.isFinal == false)
        #expect(item1.confidence == 0.95)
        #expect(item1.timestamp == fixedDate)

        let defaultItem = TranscriptionResult(text: "Testing defaults")
        #expect(defaultItem.isFinal == false)
        #expect(defaultItem.confidence == 1.0)
    }

    // MARK: - 2. Permissions & Error Descriptions

    @Test("SpeechRecognitionPermission contains all required authorization states")
    func speechRecognitionPermissions() {
        let allCases = SpeechRecognitionPermission.allCases
        #expect(allCases.contains(.notDetermined))
        #expect(allCases.contains(.authorized))
        #expect(allCases.contains(.denied))
        #expect(allCases.contains(.restricted))
        #expect(SpeechRecognitionPermission.authorized.rawValue == "authorized")
    }

    @Test("SpeechRecognitionError provides privacy-focused localized descriptions without server fallback")
    func speechRecognitionErrorDescriptions() {
        let unsupportedError = SpeechRecognitionError.onDeviceRecognitionUnsupported(locale: "fr-FR")
        let desc = unsupportedError.errorDescription ?? ""
        #expect(desc.contains("fr-FR"))
        #expect(desc.contains("never uploads your audio to remote servers"))

        let micError = SpeechRecognitionError.microphonePermissionDenied
        #expect(micError.errorDescription?.contains("Microphone access has been denied") == true)

        let speechError = SpeechRecognitionError.speechRecognitionPermissionDenied
        #expect(speechError.errorDescription?.contains("Speech recognition access has been denied") == true)

        let engineError = SpeechRecognitionError.audioEngineFailure("Failed to allocate node")
        #expect(engineError.errorDescription?.contains("Failed to allocate node") == true)

        let unavailableError = SpeechRecognitionError.recognizerUnavailable
        #expect(unavailableError.errorDescription?.contains("currently unavailable") == true)

        let interruptedError = SpeechRecognitionError.interrupted
        #expect(interruptedError.errorDescription?.contains("interrupted") == true)
    }

    // MARK: - 3. Audio Level RMS Calculation Tests

    @Test("RMS audio calculation returns 0.0 for silent float buffer")
    func calculateAudioLevelSilentFloat() {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024) else {
            Issue.record("Failed to create AVAudioPCMBuffer")
            return
        }
        buffer.frameLength = 1024
        guard let channelData = buffer.floatChannelData?[0] else {
            Issue.record("Missing float channel data")
            return
        }
        for i in 0..<1024 {
            channelData[i] = 0.0
        }

        let level = OnDeviceSpeechRecognitionService.calculateAudioLevel(buffer: buffer)
        #expect(level == 0.0)
    }

    @Test("RMS audio calculation computes correct normalized value for active float buffer")
    func calculateAudioLevelActiveFloat() {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 100) else {
            Issue.record("Failed to create AVAudioPCMBuffer")
            return
        }
        buffer.frameLength = 100
        guard let channelData = buffer.floatChannelData?[0] else {
            Issue.record("Missing float channel data")
            return
        }
        // Constant amplitude 0.1 -> RMS = 0.1 -> scaled by 5.0 = 0.5
        for i in 0..<100 {
            channelData[i] = 0.1
        }

        let level = OnDeviceSpeechRecognitionService.calculateAudioLevel(buffer: buffer)
        #expect(abs(level - 0.5) < 0.001)
    }

    @Test("RMS audio calculation clamps loud signals to 1.0")
    func calculateAudioLevelClampedFloat() {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 100) else {
            Issue.record("Failed to create AVAudioPCMBuffer")
            return
        }
        buffer.frameLength = 100
        guard let channelData = buffer.floatChannelData?[0] else {
            Issue.record("Missing float channel data")
            return
        }
        // Amplitude 0.8 -> RMS = 0.8 -> scaled by 5.0 = 4.0 -> clamped to 1.0
        for i in 0..<100 {
            channelData[i] = 0.8
        }

        let level = OnDeviceSpeechRecognitionService.calculateAudioLevel(buffer: buffer)
        #expect(level == 1.0)
    }

    @Test("RMS audio calculation handles Int16 PCM buffers")
    func calculateAudioLevelInt16() {
        guard let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 44100, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 100) else {
            Issue.record("Failed to create Int16 AVAudioPCMBuffer")
            return
        }
        buffer.frameLength = 100
        guard let channelData = buffer.int16ChannelData?[0] else {
            Issue.record("Missing Int16 channel data")
            return
        }
        for i in 0..<100 {
            channelData[i] = 0
        }

        let silentLevel = OnDeviceSpeechRecognitionService.calculateAudioLevel(buffer: buffer)
        #expect(silentLevel == 0.0)

        // 16384 is approx 0.5 normalized amplitude -> RMS = 0.5 -> scaled by 5.0 -> clamped to 1.0
        for i in 0..<100 {
            channelData[i] = 16384
        }
        let activeLevel = OnDeviceSpeechRecognitionService.calculateAudioLevel(buffer: buffer)
        #expect(activeLevel == 1.0)
    }

    @Test("RMS audio calculation returns 0.0 for empty frame length")
    func calculateAudioLevelEmptyBuffer() {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512) else {
            Issue.record("Failed to create AVAudioPCMBuffer")
            return
        }
        buffer.frameLength = 0

        let level = OnDeviceSpeechRecognitionService.calculateAudioLevel(buffer: buffer)
        #expect(level == 0.0)
    }

    // MARK: - 4. Privacy & Fallback Enforcement

    @Test("Service strictly enforces on-device recognition and throws if unsupported without server fallback")
    func strictOnDeviceEnforcement() async {
        let stub = StubSpeechRecognitionService(
            isAvailable: true,
            supportsOnDevice: false,
            locale: Locale(identifier: "ja-JP")
        )

        do {
            _ = try await stub.startTranscription()
            Issue.record("Expected onDeviceRecognitionUnsupported error to be thrown")
        } catch let error as SpeechRecognitionError {
            #expect(error == .onDeviceRecognitionUnsupported(locale: "ja-JP"))
            #expect(error.errorDescription?.contains("never uploads your audio") == true)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    // MARK: - 5. Real-Time Streaming & Partial Results

    @Test("Transcription stream emits progressive partial results and terminates on final item")
    func progressiveTranscriptionStream() async throws {
        let stub = StubSpeechRecognitionService()
        stub.simulatedTranscripts = [
            "Good",
            "Good morning,",
            "Good morning, can you hear me?"
        ]

        let stream = try await stub.startTranscription()
        #expect(stub.isTranscribing == true)

        var collected: [TranscriptionResult] = []
        for await result in stream {
            collected.append(result)
            if result.isFinal {
                break
            }
        }

        #expect(collected.count == 3)
        #expect(collected[0].text == "Good")
        #expect(collected[0].isFinal == false)
        #expect(collected[1].text == "Good morning,")
        #expect(collected[1].isFinal == false)
        #expect(collected[2].text == "Good morning, can you hear me?")
        #expect(collected[2].isFinal == true)

        await stub.stopTranscription()
        #expect(stub.isTranscribing == false)
    }

    // MARK: - 6. Waveform Audio Level Stream

    @Test("Audio level stream delivers normalized power levels")
    func audioLevelStreamDelivery() async {
        let stub = StubSpeechRecognitionService()
        stub.simulatedAudioLevels = [0.15, 0.45, 0.85]

        let stream = stub.audioLevelStream()

        var levels: [Float] = []
        for await level in stream {
            levels.append(level)
            if levels.count == 3 {
                break
            }
        }

        #expect(levels == [0.15, 0.45, 0.85])
    }

    // MARK: - 7. Configuration: Locale and Voice Processing

    @Test("Service allows dynamic locale switching and voice processing toggling")
    func configurationUpdates() {
        let stub = StubSpeechRecognitionService()
        #expect(stub.currentLocale.identifier == "en-US")
        #expect(stub.voiceProcessingEnabled == true)

        stub.setLocale(Locale(identifier: "es-ES"))
        #expect(stub.currentLocale.identifier == "es-ES")

        stub.setVoiceProcessingEnabled(false)
        #expect(stub.voiceProcessingEnabled == false)
    }

    // MARK: - 8. Interruption Handling

    @Test("Interruption stops active transcription session cleanly")
    func interruptionHandling() async throws {
        let stub = StubSpeechRecognitionService()
        _ = try await stub.startTranscription()
        #expect(stub.isTranscribing == true)

        stub.simulateInterruption()
        #expect(stub.isTranscribing == false)
    }

    // MARK: - 9. Concrete OnDeviceSpeechRecognitionService Unit Properties

    @Test("OnDeviceSpeechRecognitionService initial state conforms to protocol contracts")
    func concreteServiceInitialization() {
        let service = OnDeviceSpeechRecognitionService()
        #expect(service.currentLocale.identifier == "en-US")
        #expect(service.isTranscribing == false)

        let customService = OnDeviceSpeechRecognitionService(locale: Locale(identifier: "de-DE"))
        #expect(customService.currentLocale.identifier == "de-DE")

        customService.setLocale(Locale(identifier: "en-GB"))
        #expect(customService.currentLocale.identifier == "en-GB")

        // Voice processing toggle
        customService.setVoiceProcessingEnabled(false)
        customService.setVoiceProcessingEnabled(true)
    }

    @Test("OnDeviceSpeechRecognitionService checks permissions correctly")
    func concreteServicePermissionCheck() {
        let service = OnDeviceSpeechRecognitionService()
        let permissions = service.checkPermissions()
        // In CI/test environment without TCC prompt, status will be one of the enum values
        #expect(SpeechRecognitionPermission.allCases.contains(permissions.speech))
        #expect(SpeechRecognitionPermission.allCases.contains(permissions.mic))
    }
}
