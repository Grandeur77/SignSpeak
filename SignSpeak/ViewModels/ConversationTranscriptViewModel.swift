import Foundation
import SwiftUI

/// View model driving the detailed Conversation Transcript screen (`41-conversation-transcript`).
@Observable
@MainActor
public final class ConversationTranscriptViewModel {
    // MARK: - Dependencies
    private let repository: any ConversationRepository
    private let speechSynthesisService: any SpeechSynthesisServicing
    public let userId: String

    // MARK: - State Properties
    public var conversation: SavedConversation
    public var isPlayingAudio: Bool = false
    public var spokenMessageId: String?
    public var toastMessage: String?
    public var isShowingDeleteAlert: Bool = false
    public var isShowingShareSheet: Bool = false
    public var isDeleted: Bool = false

    private var audioPlaybackTask: Task<Void, Never>?

    public init(
        conversation: SavedConversation,
        repository: any ConversationRepository,
        speechSynthesisService: any SpeechSynthesisServicing,
        userId: String
    ) {
        self.conversation = conversation
        self.repository = repository
        self.speechSynthesisService = speechSynthesisService
        self.userId = userId
    }

    // MARK: - Audio Replay
    public func replayAudio() {
        if isPlayingAudio {
            stopAudio()
            return
        }

        isPlayingAudio = true
        toastMessage = "Playing synthesized audio replay..."

        audioPlaybackTask = Task {
            // Find all voice/speech utterances to speak aloud
            let spokenMessages = conversation.messages.filter { $0.source == "speech" || $0.source == "typed" }
            for msg in spokenMessages {
                guard !Task.isCancelled else { break }
                spokenMessageId = msg.id
                do {
                    try await speechSynthesisService.speak(text: msg.text, voiceLanguage: "en-US")
                } catch {
                    // Handled gracefully
                }
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
            spokenMessageId = nil
            isPlayingAudio = false
        }
    }

    public func stopAudio() {
        audioPlaybackTask?.cancel()
        audioPlaybackTask = nil
        spokenMessageId = nil
        isPlayingAudio = false
    }

    // MARK: - Share & Export
    public func generateFormattedTranscript() -> String {
        var output = "SignSpeak Transcript: \(conversation.title)\n"
        output += "\(conversation.fullFormattedDateHeader)\n"
        output += "\(conversation.signsRecognizedCount) signs recognized • \(conversation.accuracyPercentage)% accuracy\n"
        output += "----------------------------------------\n\n"

        for msg in conversation.messages {
            let timeStr = msg.at.formatted(date: .omitted, time: .shortened)
            let tag = msg.source == "sign" ? "ASL Camera" : "Spoken audio"
            output += "[\(timeStr)] \(msg.speaker) (\(tag)):\n"
            output += "\(msg.text)\n\n"
        }

        output += "----------------------------------------\n"
        output += "Exported from SignSpeak Assistive Platform."
        return output
    }

    // MARK: - Delete Transcript
    public func confirmDelete() {
        isShowingDeleteAlert = true
    }

    public func deleteTranscript() async {
        do {
            try await repository.deleteConversation(userId: userId, conversationId: conversation.id)
            isDeleted = true
            toastMessage = "Archived session deleted"
        } catch {
            toastMessage = "Failed to delete transcript"
        }
    }
}
