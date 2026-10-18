import Foundation
import Testing
@testable import SignSpeak

@Suite("Temporal Stability Filter & Thresholding")
struct StabilityFilterTests {
    @Test("Rejects predictions below confidence threshold")
    func rejectsBelowThreshold() {
        let baseDate = Date(timeIntervalSince1970: 1000)
        let filter = StabilityFilter(
            confidenceThreshold: 0.85,
            holdDuration: 1.0
        )

        let lowConfClassification = SignClassification(
            label: "A",
            confidence: 0.84,
            candidates: [SignCandidate(label: "A", confidence: 0.84)]
        )

        let state = filter.process(classification: lowConfClassification, at: baseDate)
        #expect(state == .lowConfidence(label: "A", confidence: 0.84, runnerUp: nil))
        #expect(state.progress == 0.0)
        #expect(!state.isRecognized)
    }

    @Test("Requires full 1.0s continuous hold to confirm recognition")
    func requiresFullHoldDuration() {
        let baseDate = Date(timeIntervalSince1970: 1000)
        let filter = StabilityFilter(
            confidenceThreshold: 0.85,
            holdDuration: 1.0
        )

        let validClassification = SignClassification(
            label: "F",
            confidence: 0.94,
            candidates: [
                SignCandidate(label: "F", confidence: 0.94),
                SignCandidate(label: "E", confidence: 0.05)
            ]
        )

        // t = 0.0s -> Detecting with progress = 0
        let state0 = filter.process(classification: validClassification, at: baseDate)
        #expect(state0 == .detecting(label: "F", confidence: 0.94, progress: 0.0, runnerUp: SignCandidate(label: "E", confidence: 0.05)))
        #expect(!state0.isRecognized)

        // t = 0.5s -> Detecting with progress = 0.5
        let state1 = filter.process(classification: validClassification, at: baseDate.addingTimeInterval(0.5))
        #expect(state1 == .detecting(label: "F", confidence: 0.94, progress: 0.5, runnerUp: SignCandidate(label: "E", confidence: 0.05)))
        #expect(!state1.isRecognized)

        // t = 1.0s -> Recognized with progress = 1.0
        let state2 = filter.process(classification: validClassification, at: baseDate.addingTimeInterval(1.0))
        #expect(state2 == .recognized(label: "F", confidence: 0.94, runnerUp: SignCandidate(label: "E", confidence: 0.05)))
        #expect(state2.isRecognized)
        #expect(state2.progress == 1.0)

        // t = 1.5s -> Continues to remain recognized
        let state3 = filter.process(classification: validClassification, at: baseDate.addingTimeInterval(1.5))
        #expect(state3.isRecognized)
    }

    @Test("Switching sign label resets the hold timer")
    func labelSwitchResetsTimer() {
        let baseDate = Date(timeIntervalSince1970: 1000)
        let filter = StabilityFilter(
            confidenceThreshold: 0.85,
            holdDuration: 1.0
        )

        let signA = SignClassification(label: "A", confidence: 0.90)
        let signB = SignClassification(label: "B", confidence: 0.92)

        // Hold A for 0.6s
        _ = filter.process(classification: signA, at: baseDate)
        let stateA = filter.process(classification: signA, at: baseDate.addingTimeInterval(0.6))
        #expect(stateA.label == "A")
        #expect(abs(stateA.progress - 0.6) < 0.001)

        // Switch to B at 0.7s -> Timer must reset to 0.0s for B
        let stateB0 = filter.process(classification: signB, at: baseDate.addingTimeInterval(0.7))
        #expect(stateB0.label == "B")
        #expect(abs(stateB0.progress - 0.0) < 0.001)

        // Advance to 1.2s (0.5s of B held) -> progress = 0.5
        let stateB1 = filter.process(classification: signB, at: baseDate.addingTimeInterval(1.2))
        #expect(stateB1.label == "B")
        #expect(abs(stateB1.progress - 0.5) < 0.001)
        #expect(!stateB1.isRecognized)

        // Advance to 1.7s (1.0s of B held) -> recognized
        let stateB2 = filter.process(classification: signB, at: baseDate.addingTimeInterval(1.7))
        #expect(stateB2 == .recognized(label: "B", confidence: 0.92, runnerUp: nil))
    }

    @Test("Dropping hand (nil classification) resets the hold timer")
    func droppingHandResetsTimer() {
        let baseDate = Date(timeIntervalSince1970: 1000)
        let filter = StabilityFilter(
            confidenceThreshold: 0.85,
            holdDuration: 1.0
        )

        let signC = SignClassification(label: "C", confidence: 0.95)

        // Hold C for 0.8s
        _ = filter.process(classification: signC, at: baseDate)
        let held = filter.process(classification: signC, at: baseDate.addingTimeInterval(0.8))
        #expect(abs(held.progress - 0.8) < 0.001)

        // Drop hand (nil)
        let noHand = filter.process(classification: nil, at: baseDate.addingTimeInterval(0.9))
        #expect(noHand == .noHand)

        // Resume C -> timer restarts from 0
        let restarted = filter.process(classification: signC, at: baseDate.addingTimeInterval(1.0))
        #expect(restarted.label == "C")
        #expect(abs(restarted.progress - 0.0) < 0.001)
    }

    @Test("Background class is never recognized even with 99% confidence")
    func backgroundIsNeverRecognized() {
        let baseDate = Date(timeIntervalSince1970: 1000)
        let filter = StabilityFilter(
            confidenceThreshold: 0.85,
            holdDuration: 1.0,
            backgroundLabel: "Background"
        )

        let bgClassification = SignClassification(
            label: "Background",
            confidence: 0.99,
            candidates: [
                SignCandidate(label: "Background", confidence: 0.99),
                SignCandidate(label: "A", confidence: 0.01)
            ]
        )

        // Send background multiple times past hold duration
        let s1 = filter.process(classification: bgClassification, at: baseDate)
        let s2 = filter.process(classification: bgClassification, at: baseDate.addingTimeInterval(2.0))

        #expect(s1 == .lowConfidence(label: "Background", confidence: 0.99, runnerUp: nil))
        #expect(s2 == .lowConfidence(label: "Background", confidence: 0.99, runnerUp: nil))
        #expect(!s2.isRecognized)
    }

    @Test("Extracts runner-up candidate excluding background")
    func extractsRunnerUpCandidate() {
        let baseDate = Date(timeIntervalSince1970: 1000)
        let filter = StabilityFilter(confidenceThreshold: 0.85, holdDuration: 1.0)

        let classification = SignClassification(
            label: "F",
            confidence: 0.92,
            candidates: [
                SignCandidate(label: "F", confidence: 0.92),
                SignCandidate(label: "Background", confidence: 0.05),
                SignCandidate(label: "E", confidence: 0.03)
            ]
        )

        let state = filter.process(classification: classification, at: baseDate)
        #expect(state.runnerUp?.label == "E")
        #expect(state.runnerUp?.confidence == 0.03)
    }

    @Test("Injected DateProviding clock advances deterministically")
    func injectedDateProviderAdvancesDeterministically() {
        var mockClock = FixedDateProvider(now: Date(timeIntervalSince1970: 5000))
        let filter = StabilityFilter(
            confidenceThreshold: 0.85,
            holdDuration: 1.0,
            dateProvider: mockClock
        )

        let signL = SignClassification(label: "L", confidence: 0.95)

        // Process without passing explicit Date -> uses dateProvider.now
        let s0 = filter.process(classification: signL)
        #expect(s0.progress == 0.0)

        mockClock.now = Date(timeIntervalSince1970: 5001)
        let filterWithAdvancedClock = StabilityFilter(
            confidenceThreshold: 0.85,
            holdDuration: 1.0,
            dateProvider: mockClock
        )
        // With explicit date
        let s1 = filter.process(classification: signL, at: Date(timeIntervalSince1970: 5001))
        #expect(s1.isRecognized)
    }
}
