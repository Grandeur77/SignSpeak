import UIKit
import CoreHaptics

/// Service managing tactile vibration feedback patterns for deaf and hard-of-hearing users.
/// Uses `CoreHaptics` where supported and falls back gracefully to `UIFeedbackGenerator`.
public final class HapticFeedbackService: @unchecked Sendable {
    public static let shared = HapticFeedbackService()

    private var hapticEngine: CHHapticEngine?
    private let supportsCoreHaptics: Bool

    public init() {
        self.supportsCoreHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        if supportsCoreHaptics {
            do {
                let engine = try CHHapticEngine()
                try engine.start()
                self.hapticEngine = engine
            } catch {
                self.hapticEngine = nil
            }
        }
    }

    /// Plays a predetermined vibration pattern.
    public func play(_ pattern: HapticPattern) {
        Task { @MainActor in
            if supportsCoreHaptics, let engine = hapticEngine {
                do {
                    try engine.start()
                    let chPattern = try buildCHPattern(for: pattern)
                    let player = try engine.makePlayer(with: chPattern)
                    try player.start(atTime: CHHapticTimeImmediate)
                    return
                } catch {
                    // Fall back to UIKit generators on error
                }
            }

            playFallback(pattern)
        }
    }

    // MARK: - CoreHaptics Pattern Builders

    private func buildCHPattern(for pattern: HapticPattern) throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []

        switch pattern {
        case .pulse:
            // 3 rhythmic tap bursts
            for i in 0..<3 {
                let time = Double(i) * 0.2
                let event = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                    ],
                    relativeTime: time
                )
                events.append(event)
            }

        case .long:
            // 1 continuous steady vibration for 1.2s
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0,
                duration: 1.2
            )
            events.append(event)

        case .sos:
            // Morse SOS: ... --- ...
            var currentTime: Double = 0.0

            // 3 short dots
            for _ in 0..<3 {
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                    ],
                    relativeTime: currentTime
                ))
                currentTime += 0.15
            }

            currentTime += 0.15

            // 3 long dashes
            for _ in 0..<3 {
                events.append(CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                    ],
                    relativeTime: currentTime,
                    duration: 0.4
                ))
                currentTime += 0.55
            }

            currentTime += 0.15

            // 3 short dots
            for _ in 0..<3 {
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                    ],
                    relativeTime: currentTime
                ))
                currentTime += 0.15
            }
        }

        return try CHHapticPattern(events: events, parameters: [])
    }

    // MARK: - Fallback Generators

    @MainActor
    private func playFallback(_ pattern: HapticPattern) {
        switch pattern {
        case .pulse:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                generator.impactOccurred()
            }

        case .long:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)

        case .sos:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                generator.notificationOccurred(.error)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                generator.notificationOccurred(.error)
            }
        }
    }
}
