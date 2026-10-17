import Foundation

/// Protocol abstracting text-to-speech synthesis via AVSpeechSynthesizer.
public protocol SpeechSynthesisServicing: Sendable {
    /// True if the synthesizer is actively speaking an utterance.
    var isSpeaking: Bool { get }

    /// Speaks the provided text aloud using on-device speech synthesis.
    func speak(text: String, voiceLanguage: String?) async throws

    /// Immediately stops any ongoing speech output.
    func stopSpeaking()
}

/// Fallback speech synthesis service stub.
public final class StubSpeechSynthesisService: SpeechSynthesisServicing, @unchecked Sendable {
    public var isSpeaking: Bool = false

    public init() {}

    public func speak(text: String, voiceLanguage: String? = nil) async throws {}

    public func stopSpeaking() {}
}
