import Foundation
import Testing
@testable import SignSpeak

@Suite("RecognitionStabiliser & Stability Filter Suite")
struct StabilityFilterTests {
    @Test(
        "Confidence below threshold results in lowConfidence state and is not recognized",
        arguments: [0.0, 0.25, 0.50, 0.70, 0.84, 0.849]
    )
    func belowThresholdIsIgnored(confidence: Double) {
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 1000))
        let stabiliser = RecognitionStabiliser(
            confidenceThreshold: 0.85,
            holdDuration: 1.0,
            dateProvider: clock
        )

        let classification = SignClassification(
            label: "A",
            confidence: confidence,
            candidates: [SignCandidate(label: "A", confidence: confidence)]
        )

        let state = stabiliser.process(classification: classification)
        #expect(state == .lowConfidence(label: "A", confidence: confidence, runnerUp: nil))
        #expect(state.progress == 0.0)
        #expect(!state.isRecognized)
        #expect(state.confidence == confidence)
    }

    @Test(
        "Exact threshold boundary determines lowConfidence vs detecting",
        arguments: [
            (0.8499, false),
            (0.8500, true),
            (0.8501, true)
        ]
    )
    func exactThresholdBoundary(confidence: Double, shouldStartHold: Bool) {
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 1000))
        let stabiliser = RecognitionStabiliser(
            confidenceThreshold: 0.85,
            holdDuration: 1.0,
            dateProvider: clock
        )

        let classification = SignClassification(label: "B", confidence: confidence)
        let state = stabiliser.process(classification: classification)

        if shouldStartHold {
            #expect(state == .detecting(label: "B", confidence: confidence, progress: 0.0, runnerUp: nil))
            #expect(!state.isRecognized)
        } else {
            #expect(state == .lowConfidence(label: "B", confidence: confidence, runnerUp: nil))
            #expect(state.progress == 0.0)
            #expect(!state.isRecognized)
        }
    }

    @Test(
        "Label held for less than 1.0s remains detecting and is not recognized",
        arguments: [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99]
    )
    func labelHeldUnderOneSecondIsNotRecognized(holdSeconds: Double) {
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 2000))
        let stabiliser = RecognitionStabiliser(
            confidenceThreshold: 0.85,
            holdDuration: 1.0,
            dateProvider: clock
        )

        let classification = SignClassification(label: "C", confidence: 0.95)

        // Initial detection at t = 0
        _ = stabiliser.process(classification: classification)

        // Advance clock to sub-second duration
        clock.advance(by: holdSeconds)
        let state = stabiliser.process(classification: classification)

        #expect(!state.isRecognized)
        #expect(state.label == "C")
        #expect(abs(state.progress - holdSeconds) < 0.001)

        if case .detecting(let label, let conf, let prog, _) = state {
            #expect(label == "C")
            #expect(conf == 0.95)
            #expect(abs(prog - holdSeconds) < 0.001)
        } else {
            Issue.record("Expected state to be .detecting for hold time \(holdSeconds)s")
        }
    }

    @Test(
        "Label held for 1.0s or longer transitions to recognized state",
        arguments: [1.0, 1.05, 1.25, 1.5, 2.0, 5.0]
    )
    func labelHeldOneSecondOrMoreIsRecognized(holdSeconds: Double) {
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 3000))
        let stabiliser = RecognitionStabiliser(
            confidenceThreshold: 0.85,
            holdDuration: 1.0,
            dateProvider: clock
        )

        let classification = SignClassification(
            label: "D",
            confidence: 0.96,
            candidates: [
                SignCandidate(label: "D", confidence: 0.96),
                SignCandidate(label: "F", confidence: 0.03)
            ]
        )

        // Initial detection at t = 0
        _ = stabiliser.process(classification: classification)

        // Advance clock past 1.0s hold threshold
        clock.advance(by: holdSeconds)
        let state = stabiliser.process(classification: classification)

        #expect(state.isRecognized)
        #expect(state.progress == 1.0)
        #expect(state.label == "D")
        #expect(state == .recognized(label: "D", confidence: 0.96, runnerUp: SignCandidate(label: "F", confidence: 0.03)))
    }

    @Test("Label switching mid-hold resets the timer to 0.0s for the new sign")
    func labelSwitchMidHoldResetsTimer() {
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 4000))
        let stabiliser = RecognitionStabiliser(
            confidenceThreshold: 0.85,
            holdDuration: 1.0,
            dateProvider: clock
        )

        let signA = SignClassification(label: "A", confidence: 0.90)
        let signB = SignClassification(label: "B", confidence: 0.92)

        // Hold Sign A for 0.8 seconds (80% towards lock-in)
        _ = stabiliser.process(classification: signA)
        clock.advance(by: 0.8)
        let stateA = stabiliser.process(classification: signA)
        #expect(stateA.label == "A")
        #expect(abs(stateA.progress - 0.8) < 0.001)
        #expect(!stateA.isRecognized)

        // Switch to Sign B -> timer must immediately reset to 0.0 for B
        clock.advance(by: 0.05)
        let stateB0 = stabiliser.process(classification: signB)
        #expect(stateB0.label == "B")
        #expect(abs(stateB0.progress - 0.0) < 0.001)
        #expect(!stateB0.isRecognized)

        // Advance by 0.5s for Sign B -> progress must be 0.5, NOT 1.35
        clock.advance(by: 0.5)
        let stateB1 = stabiliser.process(classification: signB)
        #expect(stateB1.label == "B")
        #expect(abs(stateB1.progress - 0.5) < 0.001)
        #expect(!stateB1.isRecognized)

        // Advance remaining 0.5s for Sign B (total 1.0s of B) -> confirmed recognized
        clock.advance(by: 0.5)
        let stateB2 = stabiliser.process(classification: signB)
        #expect(stateB2 == .recognized(label: "B", confidence: 0.92, runnerUp: nil))
        #expect(stateB2.isRecognized)
        #expect(stateB2.progress == 1.0)
    }

    @Test("No-hand (nil classification) resets the hold timer")
    func noHandResetsHoldTimer() {
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 5000))
        let stabiliser = RecognitionStabiliser(
            confidenceThreshold: 0.85,
            holdDuration: 1.0,
            dateProvider: clock
        )

        let signE = SignClassification(label: "E", confidence: 0.91)

        // Hold Sign E for 0.9s
        _ = stabiliser.process(classification: signE)
        clock.advance(by: 0.9)
        let stateE = stabiliser.process(classification: signE)
        #expect(abs(stateE.progress - 0.9) < 0.001)

        // Hand drops out of camera frame
        clock.advance(by: 0.1)
        let noHandState = stabiliser.process(classification: nil)
        #expect(noHandState == .noHand)
        #expect(noHandState.progress == 0.0)
        #expect(!noHandState.isRecognized)

        // Hand reappears with Sign E -> hold timer restarts from 0.0s
        clock.advance(by: 0.1)
        let restartedState = stabiliser.process(classification: signE)
        #expect(restartedState.label == "E")
        #expect(abs(restartedState.progress - 0.0) < 0.001)
        #expect(!restartedState.isRecognized)
    }

    @Test(
        "Background class is never recognized regardless of confidence or hold duration",
        arguments: [
            (0.85, 1.0),
            (0.95, 2.0),
            (0.99, 5.0),
            (1.00, 10.0)
        ]
    )
    func backgroundClassNeverRecognized(confidence: Double, duration: Double) {
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 6000))
        let stabiliser = RecognitionStabiliser(
            confidenceThreshold: 0.85,
            holdDuration: 1.0,
            backgroundLabel: "Background",
            dateProvider: clock
        )

        let bgClassification = SignClassification(
            label: "Background",
            confidence: confidence,
            candidates: [
                SignCandidate(label: "Background", confidence: confidence),
                SignCandidate(label: "A", confidence: 0.01)
            ]
        )

        // Send background frame at start
        let initial = stabiliser.process(classification: bgClassification)
        #expect(initial == .lowConfidence(label: "Background", confidence: confidence, runnerUp: nil))
        #expect(!initial.isRecognized)

        // Advance clock well past required hold duration
        clock.advance(by: duration)
        let finalState = stabiliser.process(classification: bgClassification)
        #expect(finalState == .lowConfidence(label: "Background", confidence: confidence, runnerUp: nil))
        #expect(!finalState.isRecognized)
        #expect(finalState.progress == 0.0)
    }

    @Test("Low confidence state correctly preserves label and runner-up candidate")
    func lowConfidencePreservesLabelAndRunnerUp() {
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 7000))
        let stabiliser = RecognitionStabiliser(
            confidenceThreshold: 0.85,
            holdDuration: 1.0,
            dateProvider: clock
        )

        let classification = SignClassification(
            label: "F",
            confidence: 0.60,
            candidates: [
                SignCandidate(label: "F", confidence: 0.60),
                SignCandidate(label: "E", confidence: 0.25),
                SignCandidate(label: "Background", confidence: 0.15)
            ]
        )

        let state = stabiliser.process(classification: classification)
        #expect(state == .lowConfidence(label: "F", confidence: 0.60, runnerUp: SignCandidate(label: "E", confidence: 0.25)))
        #expect(state.label == "F")
        #expect(state.confidence == 0.60)
        #expect(state.runnerUp?.label == "E")
        #expect(state.runnerUp?.confidence == 0.25)
    }

    @Test("Explicit reset clears all internal state back to noHand")
    func explicitResetClearsState() {
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 8000))
        let stabiliser = RecognitionStabiliser(
            confidenceThreshold: 0.85,
            holdDuration: 1.0,
            dateProvider: clock
        )

        let signK = SignClassification(label: "K", confidence: 0.95)
        _ = stabiliser.process(classification: signK)
        clock.advance(by: 0.7)
        let active = stabiliser.process(classification: signK)
        #expect(active.progress == 0.7)

        stabiliser.reset()

        // After reset, next evaluation starts from 0.0
        let afterReset = stabiliser.process(classification: signK)
        #expect(afterReset.progress == 0.0)
    }
}
