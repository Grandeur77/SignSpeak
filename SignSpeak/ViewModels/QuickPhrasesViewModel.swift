import SwiftUI

/// View model driving the Quick Phrases catalog (`39c-quick-phrases`).
/// Handles category filtering, speech-to-text dictation search, phrase speech playback, play count tracking, and phrase CRUD.
@Observable
@MainActor
public final class QuickPhrasesViewModel {
    // MARK: - Dependencies

    private let repository: any QuickPhraseRepository
    private let speechSynthesisService: any SpeechSynthesisServicing
    private let speechRecognitionService: any SpeechRecognitionServicing
    public let userId: String

    // MARK: - State

    public var phrases: [QuickPhrase] = []
    public var selectedCategory: String = "All"
    public var searchQuery: String = ""
    public var isDictatingSearch: Bool = false
    public var dictationError: String? = nil
    public var spokenPhraseId: String? = nil
    public var toastMessage: String? = nil

    public var isShowingAddSheet: Bool = false
    public var editingPhrase: QuickPhrase? = nil
    public var selectedSignPhrase: QuickPhrase? = nil

    public var isLoading: Bool = false

    private var dictationTask: Task<Void, Never>? = nil

    public static let categories: [String] = [
        "All", "Essentials", "Emergency", "Greetings", "Shopping", "Transport", "Dining", "Questions"
    ]

    // MARK: - Initialization

    public init(
        repository: any QuickPhraseRepository,
        speechSynthesisService: any SpeechSynthesisServicing,
        speechRecognitionService: any SpeechRecognitionServicing,
        userId: String
    ) {
        self.repository = repository
        self.speechSynthesisService = speechSynthesisService
        self.speechRecognitionService = speechRecognitionService
        self.userId = userId
    }

    // MARK: - Data Loading

    public func loadPhrases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fetched = try await repository.fetchPhrases(userId: userId)
            self.phrases = fetched
        } catch {
            self.phrases = QuickPhrase.defaults
        }
    }

    // MARK: - Filtered Phrases

    public var filteredPhrases: [QuickPhrase] {
        var result = phrases

        // Category filter
        if selectedCategory != "All" {
            if selectedCategory == "Emergency" {
                result = result.filter { $0.isEmergency || $0.category.localizedCaseInsensitiveCompare("Emergency") == .orderedSame }
            } else {
                result = result.filter { $0.category.localizedCaseInsensitiveCompare(selectedCategory) == .orderedSame }
            }
        }

        // Search text filter
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            result = result.filter { phrase in
                phrase.text.localizedCaseInsensitiveContains(query) ||
                phrase.category.localizedCaseInsensitiveContains(query) ||
                (phrase.note?.localizedCaseInsensitiveContains(query) ?? false)
            }
        }

        return result
    }

    /// Primary featured key card (e.g., "Please speak slowly, I am deaf")
    public var keyCardPhrase: QuickPhrase? {
        if let key = phrases.first(where: { $0.isKeyCard }) {
            return key
        }
        return phrases.first(where: { $0.category == "Essentials" }) ?? phrases.first
    }

    // MARK: - Speech Synthesis

    public func speak(phrase: QuickPhrase) {
        spokenPhraseId = phrase.id
        toastMessage = "\"\(phrase.text)\" spoken aloud"

        Task {
            do {
                try await speechSynthesisService.speak(text: phrase.text, voiceLanguage: "en-US")
            } catch {
                // Audio synthesis error handled gracefully
            }

            // Increment play count
            if let newCount = try? await repository.incrementPlayCount(id: phrase.id, userId: userId) {
                if let idx = phrases.firstIndex(where: { $0.id == phrase.id }) {
                    phrases[idx].playCount = newCount
                }
            }

            try? await Task.sleep(nanoseconds: 600_000_000)
            if spokenPhraseId == phrase.id {
                spokenPhraseId = nil
            }
        }
    }

    // MARK: - Search Dictation

    public func toggleDictationSearch() {
        if isDictatingSearch {
            stopDictationSearch()
        } else {
            startDictationSearch()
        }
    }

    public func startDictationSearch() {
        guard !isDictatingSearch else { return }
        dictationError = nil
        isDictatingSearch = true

        dictationTask = Task {
            do {
                let stream = try await speechRecognitionService.startTranscription()
                for await result in stream {
                    guard !Task.isCancelled else { break }
                    if isDictatingSearch {
                        self.searchQuery = result.text
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.dictationError = error.localizedDescription
                }
            }
            if !Task.isCancelled {
                self.isDictatingSearch = false
            }
        }
    }

    public func stopDictationSearch() {
        dictationTask?.cancel()
        dictationTask = nil
        Task {
            await speechRecognitionService.stopTranscription()
        }
        isDictatingSearch = false
    }

    // MARK: - CRUD

    public func addPhrase(
        text: String,
        category: String = "Essentials",
        isEmergency: Bool = false,
        signId: String? = nil,
        note: String? = nil,
        isKeyCard: Bool = false
    ) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let newPhrase = QuickPhrase(
            userId: userId,
            text: trimmed,
            category: category,
            isEmergency: isEmergency,
            playCount: 0,
            signId: signId,
            note: note,
            isKeyCard: isKeyCard
        )

        do {
            try await repository.addPhrase(newPhrase)
            await loadPhrases()
            toastMessage = "Added \"\(trimmed)\""
        } catch {
            // Local fallback
            phrases.append(newPhrase)
            toastMessage = "Added \"\(trimmed)\""
        }
    }

    public func updatePhrase(_ phrase: QuickPhrase) async {
        do {
            try await repository.updatePhrase(phrase)
            await loadPhrases()
            toastMessage = "Updated \"\(phrase.text)\""
        } catch {
            if let idx = phrases.firstIndex(where: { $0.id == phrase.id }) {
                phrases[idx] = phrase
            }
        }
    }

    public func deletePhrase(id: String) async {
        do {
            try await repository.deletePhrase(id: id, userId: userId)
            await loadPhrases()
            toastMessage = "Phrase deleted"
        } catch {
            phrases.removeAll { $0.id == id }
        }
    }
}
