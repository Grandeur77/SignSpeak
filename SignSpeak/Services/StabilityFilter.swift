import Foundation

/// Pure, deterministic temporal stability filter.
/// Evaluates sequential Core ML predictions against a confidence threshold and hold duration,
/// rejects non-sign/background classes, extracts runner-up candidates, and computes hold progress (0.0 ... 1.0).
public final class StabilityFilter: @unchecked Sendable {
    public let confidenceThreshold: Double
    public let holdDuration: TimeInterval
    public let backgroundLabel: String
    private let dateProvider: any DateProviding
    private let lock = NSLock()

    private var currentHoldingLabel: String?
    private var holdStartTime: Date?
    private var lastState: RecognitionState = .noHand

    public init(
        confidenceThreshold: Double = 0.85,
        holdDuration: TimeInterval = 1.0,
        backgroundLabel: String = "Background",
        dateProvider: any DateProviding = SystemDateProvider()
    ) {
        self.confidenceThreshold = confidenceThreshold
        self.holdDuration = holdDuration
        self.backgroundLabel = backgroundLabel
        self.dateProvider = dateProvider
    }

    /// Evaluates a classification against stability thresholds at a specified moment (or now).
    @discardableResult
    public func process(classification: SignClassification?, at date: Date? = nil) -> RecognitionState {
        lock.lock()
        defer { lock.unlock() }

        let timestamp = date ?? dateProvider.now

        guard let classification else {
            resetHoldState()
            lastState = .noHand
            return .noHand
        }

        // Extract runner-up candidate
        let runnerUp = extractRunnerUp(from: classification.candidates, primaryLabel: classification.label)

        // 1. Rejection of background / non-sign frames
        if classification.label == backgroundLabel {
            resetHoldState()
            let state = RecognitionState.lowConfidence(
                label: backgroundLabel,
                confidence: classification.confidence,
                runnerUp: runnerUp
            )
            lastState = state
            return state
        }

        // 2. Below confidence threshold
        if classification.confidence < confidenceThreshold {
            resetHoldState()
            let state = RecognitionState.lowConfidence(
                label: classification.label,
                confidence: classification.confidence,
                runnerUp: runnerUp
            )
            lastState = state
            return state
        }

        // 3. Above confidence threshold -> Advance or start hold duration
        if currentHoldingLabel != classification.label || holdStartTime == nil {
            currentHoldingLabel = classification.label
            holdStartTime = timestamp
        }

        let elapsed = max(0, timestamp.timeIntervalSince(holdStartTime!))
        let rawProgress = min(1.0, elapsed / max(0.001, holdDuration))
        let progress = (rawProgress * 10_000).rounded() / 10_000

        let state: RecognitionState
        if progress >= 1.0 {
            state = .recognized(
                label: classification.label,
                confidence: classification.confidence,
                runnerUp: runnerUp
            )
        } else {
            state = .detecting(
                label: classification.label,
                confidence: classification.confidence,
                progress: progress,
                runnerUp: runnerUp
            )
        }

        lastState = state
        return state
    }

    /// Resets all internal hold timers and state.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        resetHoldState()
        lastState = .noHand
    }

    private func resetHoldState() {
        currentHoldingLabel = nil
        holdStartTime = nil
    }

    private func extractRunnerUp(from candidates: [SignCandidate], primaryLabel: String) -> SignCandidate? {
        for candidate in candidates {
            if candidate.label != primaryLabel && candidate.label != backgroundLabel && candidate.confidence > 0.01 {
                return candidate
            }
        }
        return nil
    }
}
