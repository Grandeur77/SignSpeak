import Foundation
import Testing
@testable import SignSpeak

@MainActor
struct ConversationHistoryTests {

    // MARK: - 1. Model & Formatting Tests

    @Test("SavedConversation and ConversationMessage Codable round trip")
    func testModelCodableRoundTrip() throws {
        let msg = ConversationMessage(
            id: "msg-1",
            speaker: "Doctor",
            text: "How are you feeling?",
            at: Date(timeIntervalSince1970: 1_700_000_000),
            source: "speech",
            confidence: 0.99,
            signsCount: 0
        )

        let convo = SavedConversation(
            id: "convo-1",
            userId: "user-123",
            title: "Clinic Visit",
            venueIcon: "cross.case.fill",
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_700_000_272),
            durationSeconds: 272,
            isSaved: true,
            signsRecognizedCount: 14,
            accuracyPercentage: 98,
            messages: [msg]
        )

        let data = try JSONEncoder().encode(convo)
        let decoded = try JSONDecoder().decode(SavedConversation.self, from: data)

        #expect(decoded.id == convo.id)
        #expect(decoded.userId == convo.userId)
        #expect(decoded.title == convo.title)
        #expect(decoded.venueIcon == convo.venueIcon)
        #expect(decoded.durationSeconds == 272)
        #expect(decoded.isSaved == true)
        #expect(decoded.signsRecognizedCount == 14)
        #expect(decoded.accuracyPercentage == 98)
        #expect(decoded.messages.count == 1)
        #expect(decoded.messages.first?.text == "How are you feeling?")
    }

    @Test("SavedConversation formatting helpers (duration, previews, headers)")
    func testFormattingHelpers() {
        let now = Date()
        let convo = SavedConversation(
            title: "Blue Bottle Coffee",
            venueIcon: "cup.and.saucer.fill",
            startedAt: now,
            durationSeconds: 130, // 2m 10s
            isSaved: false,
            signsRecognizedCount: 6,
            accuracyPercentage: 95,
            messages: [
                ConversationMessage(speaker: "Barista", text: "Oat milk latte?", source: "speech"),
                ConversationMessage(speaker: "Maya", text: "Yes please!", source: "sign")
            ]
        )

        #expect(convo.formattedDuration == "2m 10s")
        #expect(convo.formattedDateWithDuration.contains("2m 10s"))
        #expect(convo.fullFormattedDateHeader.contains("2m 10s"))
        #expect(convo.partnerPreview?.speaker == "Barista")
        #expect(convo.partnerPreview?.text == "Oat milk latte?")
        #expect(convo.userPreview?.speaker == "Maya")
        #expect(convo.userPreview?.text == "Yes please!")
    }

    @Test("Pre-seeded default conversations integrity")
    func testPreSeededDefaults() {
        let defaults = SavedConversation.defaults
        #expect(defaults.count >= 3)
        #expect(defaults.contains(where: { $0.title == "Dr. Henderson Clinic" }))
        #expect(defaults.contains(where: { $0.title == "Blue Bottle Coffee" }))
        #expect(defaults.contains(where: { $0.title == "Metro Transit Info" }))

        let clinic = defaults.first(where: { $0.title == "Dr. Henderson Clinic" })
        #expect(clinic?.signsRecognizedCount == 14)
        #expect(clinic?.accuracyPercentage == 98)
        #expect(clinic?.isSaved == true)
    }

    // MARK: - 2. Repository Tests

    @Test("StubConversationRepository fetch, save, toggleSaved, and delete")
    func testRepositoryCRUD() async throws {
        let repo = StubConversationRepository()
        let userId = "test-user-456"

        // 1. Initial fetch pre-seeds defaults
        let initial = try await repo.fetchConversations(userId: userId)
        #expect(initial.count >= 3)

        // 2. Toggle Saved
        guard let firstConvo = initial.first else {
            Issue.record("No conversation found")
            return
        }
        let originalSaved = firstConvo.isSaved
        let toggled = try await repo.toggleSaved(userId: userId, conversationId: firstConvo.id)
        #expect(toggled == !originalSaved)

        // 3. Save new session
        let newConvo = SavedConversation(
            id: "custom-convo-1",
            userId: userId,
            title: "Supermarket Checkout",
            venueIcon: "cart.fill",
            durationSeconds: 65,
            messages: [
                ConversationMessage(speaker: "Cashier", text: "Do you have a rewards card?", source: "speech"),
                ConversationMessage(speaker: "You", text: "No, thank you.", source: "sign")
            ]
        )
        try await repo.saveConversation(userId: userId, conversation: newConvo)
        let afterSave = try await repo.fetchConversations(userId: userId)
        #expect(afterSave.contains(where: { $0.id == "custom-convo-1" }))

        // 4. Delete session
        try await repo.deleteConversation(userId: userId, conversationId: "custom-convo-1")
        let afterDelete = try await repo.fetchConversations(userId: userId)
        #expect(!afterDelete.contains(where: { $0.id == "custom-convo-1" }))
    }

    // MARK: - 3. ConversationHistoryViewModel Tests

    @Test("ConversationHistoryViewModel loads, filters, and searches")
    func testViewModelFilteringAndSearch() async throws {
        let repo = StubConversationRepository()
        let speechRec = StubSpeechRecognitionService()
        let vm = ConversationHistoryViewModel(
            repository: repo,
            speechRecognitionService: speechRec,
            userId: "test-user-789"
        )

        await vm.loadConversations()
        #expect(vm.conversations.count >= 3)
        #expect(vm.filteredConversations.count == vm.conversations.count)

        // Filter: Saved
        vm.selectedFilter = .saved
        let savedList = vm.filteredConversations
        #expect(savedList.allSatisfy { $0.isSaved })

        // Filter: This Week
        vm.selectedFilter = .thisWeek
        #expect(!vm.filteredConversations.isEmpty)

        // Filter: With Transcripts
        vm.selectedFilter = .transcripts
        #expect(vm.filteredConversations.allSatisfy { !$0.messages.isEmpty })

        // Search: By Clinic
        vm.selectedFilter = .all
        vm.searchQuery = "Henderson"
        #expect(vm.filteredConversations.count == 1)
        #expect(vm.filteredConversations.first?.title == "Dr. Henderson Clinic")

        // Search: By message text
        vm.searchQuery = "Airport"
        #expect(vm.filteredConversations.first?.title == "Metro Transit Info")

        vm.searchQuery = ""
        #expect(vm.filteredConversations.count == vm.conversations.count)
    }

    @Test("ConversationHistoryViewModel dictation search streams query")
    func testViewModelDictationSearch() async throws {
        let repo = StubConversationRepository()
        let speechRec = StubSpeechRecognitionService()
        speechRec.simulatedTranscripts = ["Clinic", "Henderson Clinic"]

        let vm = ConversationHistoryViewModel(
            repository: repo,
            speechRecognitionService: speechRec,
            userId: "test-user-789"
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

    @Test("ConversationHistoryViewModel weekly statistics and export summary")
    func testViewModelWeeklyStatsAndExport() async throws {
        let repo = StubConversationRepository()
        let speechRec = StubSpeechRecognitionService()
        let vm = ConversationHistoryViewModel(
            repository: repo,
            speechRecognitionService: speechRec,
            userId: "test-user-789"
        )

        await vm.loadConversations()
        #expect(vm.weeklySignsCaptured >= 142)
        #expect(vm.weeklyAverageAccuracy >= 95)

        let export = vm.generateExportSummary()
        #expect(export.contains("SignSpeak Conversation Logs Export"))
        #expect(export.contains("Dr. Henderson Clinic"))
        #expect(export.contains("[ASL]"))
    }

    // MARK: - 4. ConversationTranscriptViewModel Tests

    @Test("ConversationTranscriptViewModel export, audio replay, and deletion")
    func testTranscriptViewModelOperations() async throws {
        let repo = StubConversationRepository()
        let speechSynth = StubSpeechSynthesisService()
        guard let sampleConvo = SavedConversation.defaults.first else {
            Issue.record("No default sample conversation")
            return
        }

        let vm = ConversationTranscriptViewModel(
            conversation: sampleConvo,
            repository: repo,
            speechSynthesisService: speechSynth,
            userId: "test-user-789"
        )

        // 1. Export text
        let transcriptText = vm.generateFormattedTranscript()
        #expect(transcriptText.contains("SignSpeak Transcript: Dr. Henderson Clinic"))
        #expect(transcriptText.contains("Dr. Henderson (Spoken audio)"))
        #expect(transcriptText.contains("Maya (ASL Camera)"))

        // 2. Audio Replay
        #expect(vm.isPlayingAudio == false)
        vm.replayAudio()
        #expect(vm.isPlayingAudio == true)

        let deadline = Date().addingTimeInterval(6.0)
        while speechSynth.spokenUtterances.isEmpty && Date() < deadline {
            try await Task.sleep(nanoseconds: 30_000_000)
        }

        #expect(!speechSynth.spokenUtterances.isEmpty)
        vm.stopAudio()
        #expect(vm.isPlayingAudio == false)

        // 3. Delete transcript
        await vm.deleteTranscript()
        #expect(vm.isDeleted == true)
        let remaining = try await repo.fetchConversations(userId: "test-user-789")
        #expect(!remaining.contains(where: { $0.id == sampleConvo.id }))
    }
}
