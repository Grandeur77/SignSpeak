import Foundation

/// Protocol abstracting on-device speech-to-text recognition via Apple's Speech framework.
public protocol SpeechRecognitionServicing: Sendable {
    /// True if speech recognition is authorized and supported on the current device.
    var isAvailable: Bool { get }

    /// Starts audio recording and delivers a real-time stream of transcribed text.
    func startTranscription() async throws -> AsyncStream<String>

    /// Stops audio capture and speech recognition.
    func stopTranscription() async
}

/// Fallback speech recognition stub for simulator and early compilation.
public final class StubSpeechRecognitionService: SpeechRecognitionServicing, @unchecked Sendable {
    public var isAvailable: Bool = true

    public init() {}

    public func startTranscription() async throws -> AsyncStream<String> {
        AsyncStream { $0.finish() }
    }

    public func stopTranscription() async {}
}
