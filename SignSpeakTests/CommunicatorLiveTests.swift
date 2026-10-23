import Testing
import Foundation
import AVFoundation
@testable import SignSpeak

/// Test suite validating the live two-way Communicator session (design `39a-communicator-live`),
/// speech-to-text transcript streaming, camera sign recognition with immediate word speech,
/// fingerspelling buffer controls (speak/delete/clear), rotation, pause, and conversation persistence.
@Suite("Live Two-Way Communicator")
@MainActor
struct CommunicatorLiveTests {

    // MARK: - Test Helpers

    private func makeViewModel(
        stubSpeechRecognition: StubSpeechRecognitionService = StubSpeechRecognitionService(),
        stubSpeechSynthesis: StubSpeechSynthesisService = StubSpeechSynthesisService(),
        mockCamera: MockCameraService = MockCameraService(),
        stubSignRecognition: StubSignRecognitionService = StubSignRecognitionService(),
        stubConversationRepo: StubConversationRepository = StubConversationRepository()
    ) -> CommunicatorLiveViewModel {
        CommunicatorLiveViewModel(
            cameraService: mockCamera,
            handPoseDetector: StubHandPoseDetector(),
            signClassifier: StubSignClassifier(),
            signRecognitionService: stubSignRecognition,
            speechRecognitionService: stubSpeechRecognition,
            speechSynthesisService: stubSpeechSynthesis,
            conversationRepository: stubConversationRepo,
            userId: "test-user-123"
        )
    }

    // MARK: - 1. Initial State

    @Test("ViewModel initializes with default split-screen state and empty buffers")
    func initialViewModelState() {
        let vm = makeViewModel()

        #expect(vm.messages.isEmpty)
        #expect(vm.activePartnerTranscript.isEmpty)
        #expect(!vm.isPartnerSpeaking)
        #expect(vm.isPartnerRotated180 == true)
        #expect(vm.fingerspellingBuffer.isEmpty)
        #expect(!vm.isPaused)
        #expect(!vm.showSpokenAloudChip)
        #expect(vm.spokenAloudWord == nil)
        #expect(vm.activeSoundAlert == nil)
    }

    // MARK: - 2. Speech-to-Text Transcript Streaming

    @Test("Speech transcription stream delivers partial results and saves final message")
    func speechTranscriptionStreaming() async throws {
        let stubSpeech = StubSpeechRecognitionService()
        stubSpeech.simulatedTranscripts = ["Hello", "Hello there!", "Hello there! How are you?"]
        let vm = makeViewModel(stubSpeechRecognition: stubSpeech)

        await vm.startSpeechRecognition()

        // Wait adaptively for simulated transcripts to stream under CI/simulator load
        let deadline = Date().addingTimeInterval(6.0)
        while vm.messages.isEmpty && Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        // After final transcript, message is recorded
        #expect(!vm.messages.isEmpty)
        #expect(vm.messages.last?.speaker == "Partner")
        #expect(vm.messages.last?.source == "speech")
        #expect(vm.messages.last?.text == "Hello there! How are you?")
    }

    // MARK: - 3. Words Spoken Immediately vs Fingerspelling Buffer

    @Test("Recognized complete word is spoken aloud immediately and triggers spoken chip")
    func wordSpokenImmediately() async {
        let stubSynthesis = StubSpeechSynthesisService()
        let vm = makeViewModel(stubSpeechSynthesis: stubSynthesis)

        await vm.handleRecognizedSign("HELLO")

        #expect(vm.spokenAloudWord == "HELLO")
        #expect(vm.showSpokenAloudChip == true)
        #expect(stubSynthesis.spokenUtterances.contains("HELLO"))
        #expect(vm.messages.last?.speaker == "You")
        #expect(vm.messages.last?.text == "HELLO")
        #expect(vm.messages.last?.source == "sign")
        #expect(vm.fingerspellingBuffer.isEmpty)
    }

    @Test("Recognized single letter is appended to fingerspelling buffer without immediate speech")
    func singleLetterFingerspellingBuffer() async {
        let stubSynthesis = StubSpeechSynthesisService()
        let vm = makeViewModel(stubSpeechSynthesis: stubSynthesis)

        await vm.handleRecognizedSign("A")

        #expect(vm.fingerspellingBuffer == "A")
        #expect(!stubSynthesis.spokenUtterances.contains("A"))
        #expect(vm.showSpokenAloudChip == false)
    }

    // MARK: - 4. Fingerspelling Buffer Controls (Speak / Delete / Clear)

    @Test("Fingerspelling buffer supports append, delete, clear, and speak aloud")
    func fingerspellingBufferOperations() async {
        let stubSynthesis = StubSpeechSynthesisService()
        let vm = makeViewModel(stubSpeechSynthesis: stubSynthesis)

        vm.appendFingerspelling("C")
        vm.appendFingerspelling("A")
        vm.appendFingerspelling("T")
        vm.appendFingerspelling("S")
        #expect(vm.fingerspellingBuffer == "CATS")

        // Backspace
        vm.deleteLastFingerspellingLetter()
        #expect(vm.fingerspellingBuffer == "CAT")

        // Speak Buffer
        await vm.speakFingerspellingBuffer()
        #expect(stubSynthesis.spokenUtterances.contains("CAT"))
        #expect(vm.messages.last?.text == "CAT")
        #expect(vm.fingerspellingBuffer.isEmpty)

        // Clear Buffer
        vm.appendFingerspelling("D")
        vm.appendFingerspelling("O")
        vm.appendFingerspelling("G")
        #expect(vm.fingerspellingBuffer == "DOG")
        vm.clearFingerspellingBuffer()
        #expect(vm.fingerspellingBuffer.isEmpty)
    }

    // MARK: - 5. Live Controls: Rotation, Pause, Switch Camera

    @Test("Live session toggles rotation, pause, and switches camera")
    func sessionControlActions() async {
        let mockCamera = MockCameraService()
        let vm = makeViewModel(mockCamera: mockCamera)

        // Rotation
        #expect(vm.isPartnerRotated180 == true)
        vm.toggleRotation()
        #expect(vm.isPartnerRotated180 == false)

        // Pause
        #expect(!vm.isPaused)
        vm.togglePause()
        #expect(vm.isPaused == true)
        vm.togglePause()
        #expect(vm.isPaused == false)

        // Switch Camera
        await vm.switchCamera()
        #expect(mockCamera.switchCameraCallCount == 1)
    }

    // MARK: - 6. Thumbs-Up and Replay Shortcuts

    @Test("Thumbs-up shortcut sends confirmation and speaks aloud")
    func thumbsUpShortcut() async {
        let stubSynthesis = StubSpeechSynthesisService()
        let vm = makeViewModel(stubSpeechSynthesis: stubSynthesis)

        await vm.sendThumbsUp()

        #expect(vm.messages.last?.text == "👍 Got it!")
        #expect(vm.messages.last?.source == "typed")
        #expect(stubSynthesis.spokenUtterances.contains("Got it!"))
    }

    @Test("Replay shortcut repeats last message in transcript")
    func replayLastMessage() async {
        let stubSynthesis = StubSpeechSynthesisService()
        let vm = makeViewModel(stubSpeechSynthesis: stubSynthesis)

        vm.appendMessage(speaker: "Partner", text: "Can you hear me?", source: "speech")
        await vm.replayLastMessage()

        #expect(stubSynthesis.spokenUtterances.contains("Can you hear me?"))
    }

    // MARK: - 7. End Conversation & Transcript Persistence

    @Test("Ending conversation stops sessions and persists transcript to repository")
    func endConversationSavesTranscript() async throws {
        let stubRepo = StubConversationRepository()
        let vm = makeViewModel(stubConversationRepo: stubRepo)

        vm.appendMessage(speaker: "Partner", text: "Hello! Table for two?", source: "speech")
        vm.appendMessage(speaker: "You", text: "Yes please, by the window.", source: "sign")

        let saved = await vm.endConversation()

        #expect(saved.messages.count == 2)
        #expect(saved.messages.first?.text == "Hello! Table for two?")

        let stored = try await stubRepo.fetchConversations(userId: "test-user-123")
        #expect(stored.contains { $0.id == saved.id })
    }

    // MARK: - 8. Sound Alerts Banner Slot

    @Test("Sound alert slot presents and dismisses alert")
    func soundAlertsSlot() {
        let vm = makeViewModel()
        #expect(vm.activeSoundAlert == nil)

        vm.activeSoundAlert = "Doorbell"
        #expect(vm.activeSoundAlert == "Doorbell")

        vm.activeSoundAlert = nil
        #expect(vm.activeSoundAlert == nil)
    }
}
