import Foundation
import Testing
import UIKit
@testable import SignSpeak

@Suite("Quick Phrases & Counter Mode Tests (Step 7.5)")
@MainActor
struct QuickPhrasesTests {
    // MARK: - Model Tests

    @Test("QuickPhrase encodes and decodes losslessly")
    func testQuickPhraseEncodingDecoding() throws {
        let original = QuickPhrase(
            id: "test-phrase-1",
            userId: "user-42",
            text: "Where is the emergency exit?",
            category: "Emergency",
            isEmergency: true,
            playCount: 15,
            signId: "exit",
            note: "Safety",
            isKeyCard: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(QuickPhrase.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.userId == original.userId)
        #expect(decoded.text == original.text)
        #expect(decoded.category == original.category)
        #expect(decoded.isEmergency == true)
        #expect(decoded.playCount == 15)
        #expect(decoded.signId == "exit")
        #expect(decoded.note == "Safety")
        #expect(decoded.isKeyCard == true)
    }

    @Test("QuickPhrase defaults are populated with essential categories and key cards")
    func testQuickPhraseDefaults() {
        let defaults = QuickPhrase.defaults
        #expect(!defaults.isEmpty)
        #expect(defaults.contains(where: { $0.isKeyCard }))
        #expect(defaults.contains(where: { $0.isEmergency }))
        #expect(defaults.contains(where: { $0.category == "Essentials" }))
        #expect(defaults.contains(where: { $0.category == "Emergency" }))
        #expect(defaults.contains(where: { $0.category == "Greetings" }))
        #expect(defaults.contains(where: { $0.category == "Shopping" }))
    }

    // MARK: - Repository Tests

    @Test("StubQuickPhraseRepository seeds defaults on first fetch and sorts correctly")
    func testRepositorySeedingAndSorting() async throws {
        let repo = StubQuickPhraseRepository()
        let phrases = try await repo.fetchPhrases(userId: "u1")

        #expect(!phrases.isEmpty)
        // Emergency phrases must be sorted first
        if let first = phrases.first {
            #expect(first.isEmergency == true)
        }
    }

    @Test("StubQuickPhraseRepository performs CRUD and play count increment")
    func testRepositoryCRUDAndPlayCount() async throws {
        let repo = StubQuickPhraseRepository()
        _ = try await repo.fetchPhrases(userId: "u1")

        let customPhrase = QuickPhrase(
            id: "custom-1",
            userId: "u1",
            text: "Need extra napkins please",
            category: "Dining",
            playCount: 2
        )

        try await repo.addPhrase(customPhrase)
        var fetched = try await repo.fetchPhrases(userId: "u1")
        #expect(fetched.contains(where: { $0.id == "custom-1" }))

        // Increment play count
        let newCount = try await repo.incrementPlayCount(id: "custom-1", userId: "u1")
        #expect(newCount == 3)

        // Update
        var toUpdate = customPhrase
        toUpdate.text = "Need water please"
        try await repo.updatePhrase(toUpdate)

        fetched = try await repo.fetchPhrases(userId: "u1")
        #expect(fetched.first(where: { $0.id == "custom-1" })?.text == "Need water please")

        // Delete
        try await repo.deletePhrase(id: "custom-1", userId: "u1")
        fetched = try await repo.fetchPhrases(userId: "u1")
        #expect(!fetched.contains(where: { $0.id == "custom-1" }))
    }

    // MARK: - QuickPhrasesViewModel Tests

    @Test("QuickPhrasesViewModel loads phrases and filters by category and search")
    func testViewModelFiltering() async throws {
        let repo = StubQuickPhraseRepository()
        let speechSynth = StubSpeechSynthesisService()
        let speechRec = StubSpeechRecognitionService()

        let vm = QuickPhrasesViewModel(
            repository: repo,
            speechSynthesisService: speechSynth,
            speechRecognitionService: speechRec,
            userId: "u1"
        )

        await vm.loadPhrases()
        #expect(!vm.phrases.isEmpty)

        // All category
        vm.selectedCategory = "All"
        #expect(vm.filteredPhrases.count == vm.phrases.count)

        // Emergency category
        vm.selectedCategory = "Emergency"
        for p in vm.filteredPhrases {
            #expect(p.isEmergency || p.category == "Emergency")
        }

        // Search query
        vm.selectedCategory = "All"
        vm.searchQuery = "bathroom"
        #expect(vm.filteredPhrases.contains(where: { $0.text.contains("bathroom") }))
    }

    @Test("QuickPhrasesViewModel speak synthesizes audio, toasts, and increments play count")
    func testViewModelSpeechAndPlayCount() async throws {
        let repo = StubQuickPhraseRepository()
        let speechSynth = StubSpeechSynthesisService()
        let speechRec = StubSpeechRecognitionService()

        let vm = QuickPhrasesViewModel(
            repository: repo,
            speechSynthesisService: speechSynth,
            speechRecognitionService: speechRec,
            userId: "u1"
        )

        await vm.loadPhrases()
        guard let phrase = vm.phrases.first else {
            Issue.record("No phrases loaded")
            return
        }

        let initialPlayCount = phrase.playCount
        vm.speak(phrase: phrase)

        #expect(vm.toastMessage?.contains(phrase.text) == true)
        #expect(vm.spokenPhraseId == phrase.id)

        // Wait adaptive polling for async task to complete
        let deadline = Date().addingTimeInterval(6.0)
        while speechSynth.spokenUtterances.isEmpty && Date() < deadline {
            try await Task.sleep(nanoseconds: 30_000_000)
        }

        #expect(speechSynth.spokenUtterances.contains(phrase.text))

        // Play count increment in repo
        let updatedList = try await repo.fetchPhrases(userId: "u1")
        let updatedPhrase = updatedList.first(where: { $0.id == phrase.id })
        #expect((updatedPhrase?.playCount ?? 0) >= initialPlayCount + 1)
    }

    @Test("QuickPhrasesViewModel search dictation streams speech recognition into search query")
    func testViewModelSearchDictation() async throws {
        let repo = StubQuickPhraseRepository()
        let speechSynth = StubSpeechSynthesisService()
        let speechRec = StubSpeechRecognitionService()
        speechRec.simulatedTranscripts = ["Doctor", "Doctor emergency"]

        let vm = QuickPhrasesViewModel(
            repository: repo,
            speechSynthesisService: speechSynth,
            speechRecognitionService: speechRec,
            userId: "u1"
        )

        #expect(vm.isDictatingSearch == false)
        vm.startDictationSearch()
        #expect(vm.isDictatingSearch == true)

        let deadline = Date().addingTimeInterval(6.0)
        while vm.searchQuery.isEmpty && Date() < deadline {
            try await Task.sleep(nanoseconds: 30_000_000)
        }

        #expect(!vm.searchQuery.isEmpty)
        vm.stopDictationSearch()
        #expect(vm.isDictatingSearch == false)
    }

    @Test("QuickPhrasesViewModel add, update, and delete")
    func testViewModelAddUpdateDelete() async throws {
        let repo = StubQuickPhraseRepository()
        let speechSynth = StubSpeechSynthesisService()
        let speechRec = StubSpeechRecognitionService()

        let vm = QuickPhrasesViewModel(
            repository: repo,
            speechSynthesisService: speechSynth,
            speechRecognitionService: speechRec,
            userId: "u1"
        )

        await vm.loadPhrases()
        let countBefore = vm.phrases.count

        await vm.addPhrase(text: "Unique Test Phrase", category: "Questions")
        #expect(vm.phrases.count == countBefore + 1)
        #expect(vm.phrases.contains(where: { $0.text == "Unique Test Phrase" }))

        if let added = vm.phrases.first(where: { $0.text == "Unique Test Phrase" }) {
            var updated = added
            updated.text = "Updated Unique Test Phrase"
            await vm.updatePhrase(updated)
            #expect(vm.phrases.contains(where: { $0.text == "Updated Unique Test Phrase" }))

            await vm.deletePhrase(id: added.id)
            #expect(!vm.phrases.contains(where: { $0.id == added.id }))
        }
    }

    // MARK: - CounterModeViewModel Tests

    @Test("CounterModeViewModel initializes, switches chips, toggles flip and fullscreen")
    func testCounterModeBasics() async throws {
        let repo = StubQuickPhraseRepository()
        let speechSynth = StubSpeechSynthesisService()
        let speechRec = StubSpeechRecognitionService()

        let vm = CounterModeViewModel(
            repository: repo,
            speechSynthesisService: speechSynth,
            speechRecognitionService: speechRec,
            userId: "u1",
            initialPhrase: "Please speak slowly, I am deaf"
        )

        #expect(vm.currentPhrase == "Please speak slowly, I am deaf")
        #expect(vm.isFlipped180 == false)
        #expect(vm.isFullscreen == false)

        // Flip 180
        vm.toggleFlip180()
        #expect(vm.isFlipped180 == true)

        // Fullscreen
        vm.toggleFullscreen()
        #expect(vm.isFullscreen == true)

        // Chip switch
        vm.selectChipPhrase("Where is the train?")
        #expect(vm.currentPhrase == "Where is the train?")

        // Speak aloud
        vm.speakAloud()
        #expect(vm.isSpeaking == true)

        let deadline = Date().addingTimeInterval(3.0)
        while speechSynth.spokenUtterances.isEmpty && Date() < deadline {
            try await Task.sleep(nanoseconds: 30_000_000)
        }
        #expect(speechSynth.spokenUtterances.contains("Where is the train?"))
    }

    @Test("CounterModeViewModel edit phrase sheet updates display text")
    func testCounterModeEditPhrase() {
        let repo = StubQuickPhraseRepository()
        let speechSynth = StubSpeechSynthesisService()
        let speechRec = StubSpeechRecognitionService()

        let vm = CounterModeViewModel(
            repository: repo,
            speechSynthesisService: speechSynth,
            speechRecognitionService: speechRec,
            userId: "u1"
        )

        vm.openEditSheet()
        #expect(vm.isShowingEditSheet == true)
        #expect(vm.editInputText == vm.currentPhrase)

        vm.editInputText = "Can I get a receipt, please?"
        vm.applyEditedPhrase()

        #expect(vm.isShowingEditSheet == false)
        #expect(vm.currentPhrase == "Can I get a receipt, please?")
    }

    @Test("CounterModeViewModel reply dictation and speech")
    func testCounterModeReplyDictation() async throws {
        let repo = StubQuickPhraseRepository()
        let speechSynth = StubSpeechSynthesisService()
        let speechRec = StubSpeechRecognitionService()
        speechRec.simulatedTranscripts = ["Yes", "Yes of course here is your receipt"]

        let vm = CounterModeViewModel(
            repository: repo,
            speechSynthesisService: speechSynth,
            speechRecognitionService: speechRec,
            userId: "u1"
        )

        #expect(vm.isListeningReply == false)
        vm.startReplyDictation()
        #expect(vm.isListeningReply == true)

        let deadline = Date().addingTimeInterval(6.0)
        while vm.replyText.isEmpty && Date() < deadline {
            try await Task.sleep(nanoseconds: 30_000_000)
        }

        #expect(!vm.replyText.isEmpty)
        vm.stopReplyDictation()
        #expect(vm.isListeningReply == false)

        // Speak reply
        vm.speakReply()
        let synthDeadline = Date().addingTimeInterval(6.0)
        while speechSynth.spokenUtterances.isEmpty && Date() < synthDeadline {
            try await Task.sleep(nanoseconds: 30_000_000)
        }
        #expect(speechSynth.spokenUtterances.contains(vm.replyText))
    }

    @Test("CounterModeViewModel keeps screen awake on appear and restores on disappear")
    func testCounterModeScreenAwake() {
        let repo = StubQuickPhraseRepository()
        let speechSynth = StubSpeechSynthesisService()
        let speechRec = StubSpeechRecognitionService()

        let vm = CounterModeViewModel(
            repository: repo,
            speechSynthesisService: speechSynth,
            speechRecognitionService: speechRec,
            userId: "u1"
        )

        UIApplication.shared.isIdleTimerDisabled = false

        vm.onAppear()
        #expect(UIApplication.shared.isIdleTimerDisabled == true)

        vm.onDisappear()
        #expect(UIApplication.shared.isIdleTimerDisabled == false)
    }
}
