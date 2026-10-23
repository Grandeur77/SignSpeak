import Testing
import Foundation
@testable import SignSpeak

/// Step 7.7 Communicator view-model tests with mock speech, synthesis and recognition:
/// transcript updates, fingerspelling buffer, phrase speaking and play counts,
/// counter-mode phrase switching, save on end, unsupported on-device recognition.
@Suite("Communicator Step 7.7 View-Model Suite")
@MainActor
struct CommunicatorViewModelTests {

    // MARK: - Test Helpers

    @MainActor
    private func makeLiveViewModel(
        stubSpeechRecognition: StubSpeechRecognitionService? = nil,
        stubSpeechSynthesis: StubSpeechSynthesisService? = nil,
        mockCamera: MockCameraService? = nil,
        stubSignRecognition: StubSignRecognitionService? = nil,
        stubConversationRepo: StubConversationRepository? = nil
    ) -> CommunicatorLiveViewModel {
        CommunicatorLiveViewModel(
            cameraService: mockCamera ?? MockCameraService(),
            handPoseDetector: StubHandPoseDetector(),
            signClassifier: StubSignClassifier(),
            signRecognitionService: stubSignRecognition ?? StubSignRecognitionService(),
            speechRecognitionService: stubSpeechRecognition ?? StubSpeechRecognitionService(),
            speechSynthesisService: stubSpeechSynthesis ?? StubSpeechSynthesisService(),
            conversationRepository: stubConversationRepo ?? StubConversationRepository(),
            userId: "test-user-step-7-7"
        )
    }

    // MARK: - 1. Transcript Updates

    @Test("Transcript updates: streams partner speech into active buffer and finalizes message")
    func testTranscriptUpdates() async throws {
        let stubSpeech = StubSpeechRecognitionService()
        stubSpeech.simulatedTranscripts = ["Hello", "Hello, do you", "Hello, do you need help?"]
        let vm = makeLiveViewModel(stubSpeechRecognition: stubSpeech)

        await vm.startSpeechRecognition()

        let deadline = Date().addingTimeInterval(6.0)
        while vm.messages.isEmpty && Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        #expect(!vm.messages.isEmpty)
        #expect(vm.messages.last?.speaker == "Partner")
        #expect(vm.messages.last?.text == "Hello, do you need help?")
        #expect(vm.messages.last?.source == "speech")
    }

    // MARK: - 2. Fingerspelling Buffer

    @Test("Fingerspelling buffer: supports append, delete, clear, and speak aloud")
    func testFingerspellingBuffer() async {
        let stubSynthesis = StubSpeechSynthesisService()
        let vm = makeLiveViewModel(stubSpeechSynthesis: stubSynthesis)

        vm.appendFingerspelling("H")
        vm.appendFingerspelling("E")
        vm.appendFingerspelling("L")
        vm.appendFingerspelling("P")
        #expect(vm.fingerspellingBuffer == "HELP")

        // Backspace
        vm.deleteLastFingerspellingLetter()
        #expect(vm.fingerspellingBuffer == "HEL")

        // Speak Buffer
        await vm.speakFingerspellingBuffer()
        #expect(stubSynthesis.spokenUtterances.contains("HEL"))
        #expect(vm.messages.last?.text == "HEL")
        #expect(vm.fingerspellingBuffer.isEmpty)

        // Append and Clear
        vm.appendFingerspelling("N")
        vm.appendFingerspelling("O")
        #expect(vm.fingerspellingBuffer == "NO")
        vm.clearFingerspellingBuffer()
        #expect(vm.fingerspellingBuffer.isEmpty)
    }

    // MARK: - 3. Phrase Speaking & Play Counts

    @Test("Phrase speaking and play counts: increments repository play count on vocalization")
    func testPhraseSpeakingAndPlayCounts() async throws {
        let repo = StubQuickPhraseRepository()
        let speechSynth = StubSpeechSynthesisService()
        let speechRec = StubSpeechRecognitionService()

        let vm = QuickPhrasesViewModel(
            repository: repo,
            speechSynthesisService: speechSynth,
            speechRecognitionService: speechRec,
            userId: "user-7-7"
        )

        await vm.loadPhrases()
        guard let phrase = vm.phrases.first else {
            Issue.record("No phrase loaded")
            return
        }

        let initialCount = phrase.playCount
        vm.speak(phrase: phrase)

        let deadline = Date().addingTimeInterval(6.0)
        while speechSynth.spokenUtterances.isEmpty && Date() < deadline {
            try await Task.sleep(nanoseconds: 30_000_000)
        }

        #expect(speechSynth.spokenUtterances.contains(phrase.text))

        // Verify count updated in repository
        let list = try await repo.fetchPhrases(userId: "user-7-7")
        let updated = list.first(where: { $0.id == phrase.id })
        #expect((updated?.playCount ?? 0) >= initialCount + 1)
    }

    // MARK: - 4. Counter-Mode Phrase Switching

    @Test("Counter-mode phrase switching: switches preset phrases, edits text, and flips 180")
    func testCounterModePhraseSwitching() async {
        let repo = StubQuickPhraseRepository()
        let speechSynth = StubSpeechSynthesisService()
        let speechRec = StubSpeechRecognitionService()

        let vm = CounterModeViewModel(
            repository: repo,
            speechSynthesisService: speechSynth,
            speechRecognitionService: speechRec,
            userId: "user-7-7",
            initialPhrase: "Initial Text"
        )

        // Switch to preset chip
        vm.selectChipPhrase("I need a doctor")
        #expect(vm.currentPhrase == "I need a doctor")

        // Edit phrase via sheet
        vm.openEditSheet()
        #expect(vm.isShowingEditSheet == true)
        vm.editInputText = "Where is the pharmacy?"
        vm.applyEditedPhrase()
        #expect(vm.isShowingEditSheet == false)
        #expect(vm.currentPhrase == "Where is the pharmacy?")

        // Flip 180 degrees
        #expect(vm.isFlipped180 == false)
        vm.toggleFlip180()
        #expect(vm.isFlipped180 == true)

        // Fullscreen toggle
        #expect(vm.isFullscreen == false)
        vm.toggleFullscreen()
        #expect(vm.isFullscreen == true)
    }

    // MARK: - 5. Save on End

    @Test("Save on end: stops sessions, aggregates sign counts, and saves conversation to repository")
    func testSaveOnEndSession() async throws {
        let repo = StubConversationRepository()
        let vm = makeLiveViewModel(stubConversationRepo: repo)

        vm.appendMessage(speaker: "Doctor", text: "How is your leg feeling?", source: "speech")
        vm.appendMessage(speaker: "Maya", text: "Much better today, thank you.", source: "sign")

        let saved = await vm.endConversation()

        #expect(saved.messages.count == 2)
        #expect(saved.endedAt != nil)
        #expect(saved.durationSeconds >= 0)

        let allSaved = try await repo.fetchConversations(userId: "test-user-step-7-7")
        #expect(allSaved.contains(where: { $0.id == saved.id }))
    }

    // MARK: - 6. Unsupported On-Device Recognition

    @Test("Unsupported on-device recognition: safely handles unsupported locale and surfaces privacy notice")
    func testUnsupportedOnDeviceRecognition() async {
        let stubSpeech = StubSpeechRecognitionService(supportsOnDevice: false)
        let vm = makeLiveViewModel(stubSpeechRecognition: stubSpeech)

        await vm.startSpeechRecognition()

        let deadline = Date().addingTimeInterval(4.0)
        while vm.errorMessage == nil && Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        #expect(vm.errorMessage != nil)
        #expect(vm.errorMessage?.contains("not supported") == true)
    }
}
