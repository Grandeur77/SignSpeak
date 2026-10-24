#if DEBUG
import Foundation
import Testing
@testable import SignSpeak

@Suite("Live Practice & Recognition Tests (Step 5.3)")
struct LivePracticeTests {

    private func makeSigns() -> [Sign] {
        [
            Sign(
                id: "sign-letter-f",
                name: "F",
                category: "alphabet",
                recognition: .staticSign,
                description: "Form an OK circle with thumb and index.",
                howToSteps: ["Touch index to thumb", "Extend middle, ring, pinky straight"],
                commonMistake: "Curling all fingers into an E.",
                imageName: "sign_letter_f"
            ),
            Sign(
                id: "sign-letter-g",
                name: "G",
                category: "alphabet",
                recognition: .staticSign,
                description: "Point index and thumb forward.",
                howToSteps: ["Make a fist", "Point index and thumb forward"],
                imageName: "sign_letter_g"
            ),
            Sign(
                id: "sign-hello",
                name: "Hello",
                category: "greetings",
                recognition: .none, // Visual only
                description: "Salute gesture moving outward from forehead.",
                howToSteps: ["Touch temple with flat palm", "Move outward forward"],
                imageName: "sign_hello"
            )
        ]
    }

    @MainActor
    private func makeViewModel(
        signs: [Sign]? = nil,
        initialIndex: Int = 0
    ) -> (PracticeViewModel, MockCameraService, MockSignRecognitionService, StubProgressRepository) {
        let testSigns = signs ?? makeSigns()
        let camera = MockCameraService(authorizationState: .authorized)
        let recognition = MockSignRecognitionService()
        let progress = StubProgressRepository(initialStore: [:])

        let vm = PracticeViewModel(
            signs: testSigns,
            initialIndex: initialIndex,
            lessonTitle: "Unit 1: Alphabet & Greetings",
            cameraService: camera,
            handPoseDetector: MockHandPoseDetector(),
            signClassifier: MockSignClassifier(),
            signRecognitionService: recognition,
            progressRepository: progress,
            userId: "test-user-practice"
        )
        return (vm, camera, recognition, progress)
    }

    // MARK: - Initial State Tests

    @Test("PracticeViewModel initializes with correct first target and progress step")
    @MainActor
    func initialViewModelState() {
        let (vm, _, _, _) = makeViewModel()

        #expect(vm.signs.count == 3)
        #expect(vm.currentSignIndex == 0)
        #expect(vm.currentSign?.name == "F")
        #expect(vm.currentTargetLabel == "F")
        #expect(vm.progressStepText == "1 / 3")
        #expect(vm.isTargetMatched == false)
        #expect(vm.showTryAgainGuidance == false)
        #expect(vm.sessionMistakes.isEmpty)
        #expect(vm.isSessionCompleted == false)
    }

    // MARK: - Match Recognition & Progress

    @Test("Correct sign recognition marks target matched and records progress")
    @MainActor
    func correctTargetRecognition() async throws {
        let (vm, _, _, progress) = makeViewModel()

        #expect(vm.isTargetMatched == false)

        // Simulate target match
        await vm.simulateMatch()

        #expect(vm.isTargetMatched == true)

        // Verify progress recorded
        let records = try await progress.fetchProgress(userId: "test-user-practice")
        let fRecord = records.first(where: { $0.signId == "sign-letter-f" })
        #expect(fRecord != nil)
        #expect(fRecord?.correct == 1)
        #expect(fRecord?.attempts == 1)
    }

    // MARK: - Mistake Detection & Try Again (31-practice-try-again)

    @Test("Mistake detection triggers Try-Again sheet and records confusion pairing")
    @MainActor
    func mistakeDetectionFlow() async throws {
        let (vm, _, _, progress) = makeViewModel()

        #expect(vm.showTryAgainGuidance == false)
        #expect(vm.sessionMistakes.isEmpty)

        // Target is "F", but detector identifies "E"
        await vm.simulateMistake(detectedAs: "E")

        #expect(vm.showTryAgainGuidance == true)
        #expect(vm.lastDetectedMistake == "E")
        #expect(vm.sessionMistakes.count == 1)
        #expect(vm.sessionMistakes.first?.signName == "F")
        #expect(vm.sessionMistakes.first?.detectedAs == "E")

        // Verify mistake recorded in progress repository with detectedAs
        let records = try await progress.fetchProgress(userId: "test-user-practice")
        let fRecord = records.first(where: { $0.signId == "sign-letter-f" })
        #expect(fRecord != nil)
        #expect(fRecord?.attempts == 1)
        #expect(fRecord?.correct == 0)
        #expect(fRecord?.lastDetectedAs == "E")

        // Verify anatomical feedback mapping for F vs E
        let feedback = SignPracticeHint.feedback(target: "F", detected: "E")
        #expect(feedback.title == "Not quite — looks like \"E\"")
        #expect(feedback.subtitle.contains("index finger is curled down"))

        // Try again resets guidance state
        vm.tryAgain()
        #expect(vm.showTryAgainGuidance == false)
    }

    // MARK: - Progression & Session Completion

    @Test("Next sign advances sequentially and completes session at end")
    @MainActor
    func sequenceProgression() {
        let (vm, _, _, _) = makeViewModel()

        #expect(vm.currentSignIndex == 0)
        #expect(vm.currentSign?.name == "F")

        // Advance to sign 2
        vm.nextSign()
        #expect(vm.currentSignIndex == 1)
        #expect(vm.currentSign?.name == "G")
        #expect(vm.progressStepText == "2 / 3")
        #expect(vm.isTargetMatched == false)

        // Advance to sign 3
        vm.nextSign()
        #expect(vm.currentSignIndex == 2)
        #expect(vm.currentSign?.name == "Hello")
        #expect(vm.progressStepText == "3 / 3")

        // Advance past end -> completes session
        vm.nextSign()
        #expect(vm.isSessionCompleted == true)
    }

    @Test("Skip sign advances target without recording mistake")
    @MainActor
    func skipSignBehavior() {
        let (vm, _, _, _) = makeViewModel()

        #expect(vm.currentSignIndex == 0)
        vm.skipSign()

        #expect(vm.currentSignIndex == 1)
        #expect(vm.sessionMistakes.isEmpty)
        #expect(vm.accuracyPercentage == 100)
    }

    // MARK: - Non-Recognizable Signs (Visual Study)

    @Test("Non-recognizable signs evaluate isRecognizable as false and advance with markAsLearned")
    @MainActor
    func visualStudySignFlow() async throws {
        // Start directly at index 2 ("Hello", visual only)
        let (vm, _, _, progress) = makeViewModel(initialIndex: 2)

        guard let currentSign = vm.currentSign else {
            Issue.record("Expected current sign at index 2")
            return
        }

        #expect(currentSign.name == "Hello")
        #expect(currentSign.isRecognizable == false)

        // Mark as learned
        await vm.markAsLearned()

        // Should complete session since it was the last sign
        #expect(vm.isSessionCompleted == true)

        let records = try await progress.fetchProgress(userId: "test-user-practice")
        let helloRecord = records.first(where: { $0.signId == "sign-hello" })
        #expect(helloRecord != nil)
        #expect(helloRecord?.correct == 1)
    }

    // MARK: - Camera & Accessibility Controls

    @Test("Camera controls toggle mirror mode and switch camera position")
    @MainActor
    func cameraControls() async {
        let (vm, camera, _, _) = makeViewModel()

        #expect(vm.isLeftHanded == false)
        vm.toggleLeftHanded()
        #expect(vm.isLeftHanded == true)

        #expect(camera.switchCameraCallCount == 0)
        await vm.switchCamera()
        #expect(camera.switchCameraCallCount == 1)
    }

    // MARK: - Sign Model Recognition Matching Helper

    @Test("Sign.matchesRecognitionLabel handles case-insensitive names and ids")
    func signRecognitionLabelMatching() {
        let signF = Sign(id: "sign-letter-f", name: "F", category: "alphabet", description: "", howToSteps: [])
        let signHello = Sign(id: "sign-hello", name: "Hello", category: "greetings", description: "", howToSteps: [])

        #expect(signF.matchesRecognitionLabel("F"))
        #expect(signF.matchesRecognitionLabel("f"))
        #expect(signF.matchesRecognitionLabel("E") == false)

        #expect(signHello.matchesRecognitionLabel("Hello"))
        #expect(signHello.matchesRecognitionLabel("hello"))
        #expect(signHello.matchesRecognitionLabel("Goodbye") == false)
    }

    @Test("PracticeViewModel recognises sign on 1st attempt and on subsequent attempts after reset")
    @MainActor
    func testMultiAttemptRecognition() async {
        let (vm, _, _, _) = makeViewModel()

        // 1st Attempt: simulate match for sign "F"
        await vm.simulateMatch()
        #expect(vm.currentTargetLabel == "F")
        #expect(vm.isTargetMatched == true)

        // Reset for 2nd Attempt
        vm.tryAgain()
        #expect(vm.isTargetMatched == false)
        #expect(vm.recognitionState == .noHand)

        // 2nd Attempt: match again
        await vm.simulateMatch()
        #expect(vm.isTargetMatched == true)
        #expect(vm.currentPrecision >= 0.90)
    }
}
#endif
