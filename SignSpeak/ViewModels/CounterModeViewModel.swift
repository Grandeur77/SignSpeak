import SwiftUI
import UIKit

/// View model driving Counter Mode / Communicator Full Screen Text (`39b-communicator-full-screen-text`).
/// Manages oversized phrase display, speech playback, quick-switch chips, 180° orientation flipping,
/// keeping screen awake, and two-way reply dictation.
@Observable
@MainActor
public final class CounterModeViewModel {
    // MARK: - Dependencies

    private let repository: any QuickPhraseRepository
    private let speechSynthesisService: any SpeechSynthesisServicing
    private let speechRecognitionService: any SpeechRecognitionServicing
    public let userId: String

    // MARK: - State

    public var currentPhrase: String = "Please speak slowly, I am deaf"
    public var isSpeaking: Bool = false
    public var isFlipped180: Bool = false
    public var isFullscreen: Bool = false
    public var isShowingEditSheet: Bool = false
    public var editInputText: String = ""

    public var replyText: String = ""
    public var isListeningReply: Bool = false
    public var dictationError: String? = nil

    public var quickSwitchPhrases: [QuickPhrase] = []

    private var previousIdleTimerState: Bool = false
    private var dictationTask: Task<Void, Never>? = nil

    // MARK: - Initialization

    public init(
        repository: any QuickPhraseRepository,
        speechSynthesisService: any SpeechSynthesisServicing,
        speechRecognitionService: any SpeechRecognitionServicing,
        userId: String,
        initialPhrase: String = "Please speak slowly, I am deaf"
    ) {
        self.repository = repository
        self.speechSynthesisService = speechSynthesisService
        self.speechRecognitionService = speechRecognitionService
        self.userId = userId
        self.currentPhrase = initialPhrase
        self.editInputText = initialPhrase
    }

    // MARK: - Lifecycle & Screen Wake Lock

    public func onAppear() {
        previousIdleTimerState = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true

        Task {
            await loadQuickSwitchPhrases()
        }
    }

    public func onDisappear() {
        UIApplication.shared.isIdleTimerDisabled = previousIdleTimerState
        stopReplyDictation()
    }

    // MARK: - Data

    public func loadQuickSwitchPhrases() async {
        do {
            let all = try await repository.fetchPhrases(userId: userId)
            // Filter a representative top set of quick phrases for the chip bar
            self.quickSwitchPhrases = Array(all.prefix(8))
        } catch {
            self.quickSwitchPhrases = Array(QuickPhrase.defaults.prefix(8))
        }
    }

    public func selectChipPhrase(_ text: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            self.currentPhrase = text
        }
    }

    // MARK: - Actions

    public func toggleFlip180() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isFlipped180.toggle()
        }
    }

    public func toggleFullscreen() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isFullscreen.toggle()
        }
    }

    public func speakAloud() {
        let textToSpeak = currentPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textToSpeak.isEmpty else { return }

        isSpeaking = true

        Task {
            do {
                try await speechSynthesisService.speak(text: textToSpeak, voiceLanguage: "en-US")
            } catch {
                // Audio synthesis error handled gracefully
            }

            try? await Task.sleep(nanoseconds: 1_200_000_000)
            self.isSpeaking = false
        }
    }

    public func openEditSheet() {
        editInputText = currentPhrase
        isShowingEditSheet = true
    }

    public func applyEditedPhrase() {
        let trimmed = editInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            currentPhrase = trimmed
        }
        isShowingEditSheet = false
    }

    // MARK: - Reply Dictation

    public func toggleReplyDictation() {
        if isListeningReply {
            stopReplyDictation()
        } else {
            startReplyDictation()
        }
    }

    public func startReplyDictation() {
        guard !isListeningReply else { return }
        dictationError = nil
        isListeningReply = true

        dictationTask = Task {
            do {
                let stream = try await speechRecognitionService.startTranscription()
                for await result in stream {
                    guard !Task.isCancelled else { break }
                    if isListeningReply {
                        self.replyText = result.text
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.dictationError = error.localizedDescription
                }
            }
            if !Task.isCancelled {
                self.isListeningReply = false
            }
        }
    }

    public func stopReplyDictation() {
        dictationTask?.cancel()
        dictationTask = nil
        Task {
            await speechRecognitionService.stopTranscription()
        }
        isListeningReply = false
    }

    public func speakReply() {
        let text = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        Task {
            try? await speechSynthesisService.speak(text: text, voiceLanguage: "en-US")
        }
    }
}
