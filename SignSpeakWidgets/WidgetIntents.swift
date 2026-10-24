import Foundation
import AppIntents
import AVFoundation

/// Intent opening the live Communicator conversation tool (`signspeak://communicator`).
public struct OpenCommunicatorIntent: AppIntent {
    public static var title: LocalizedStringResource = "Open Communicator"
    public static var description = IntentDescription("Opens live two-way Communicator in SignSpeak.")
    public static var openAppWhenRun: Bool = true

    public init() {}

    public func perform() async throws -> some IntentResult {
        return .result()
    }
}

/// Intent synthesizing speech for a quick communicator phrase or custom text.
public struct SpeakPhraseIntent: AppIntent {
    public static var title: LocalizedStringResource = "Speak Phrase"
    public static var description = IntentDescription("Speaks a communicator phrase aloud.")
    public static var openAppWhenRun: Bool = false

    @Parameter(title: "Phrase")
    public var phrase: String

    public init() {
        self.phrase = ""
    }

    public init(phrase: String) {
        self.phrase = phrase
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "No phrase was provided to speak.")
        }

        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)

        return .result(dialog: "Speaking: \(trimmed)")
    }
}
