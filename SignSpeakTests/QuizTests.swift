#if DEBUG
import Foundation
import Testing
@testable import SignSpeak

@Suite("Quiz Engine & Quiz Mode Tests (Step 5.4)")
struct QuizTests {

    private func makeSampleSigns() -> [Sign] {
        [
            Sign(
                id: "sign-letter-a",
                name: "A",
                category: "alphabet",
                recognition: .staticSign,
                description: "Fist with thumb up.",
                howToSteps: ["Make a fist", "Thumb along index"]
            ),
            Sign(
                id: "sign-letter-b",
                name: "B",
                category: "alphabet",
                recognition: .staticSign,
                description: "Four fingers up, thumb folded.",
                howToSteps: ["Extend 4 fingers", "Fold thumb across palm"]
            ),
            Sign(
                id: "sign-letter-c",
                name: "C",
                category: "alphabet",
                recognition: .staticSign,
                description: "Curved hand forming C shape.",
                howToSteps: ["Curve fingers and thumb"]
            ),
            Sign(
                id: "sign-letter-d",
                name: "D",
                category: "alphabet",
                recognition: .staticSign,
                description: "Index pointing up, other fingers on thumb.",
                howToSteps: ["Index up", "Middle, ring, pinky touch thumb"]
            ),
            Sign(
                id: "sign-hello",
                name: "Hello",
                category: "greetings",
                recognition: .none, // Visual only
                description: "Salute gesture from forehead.",
                howToSteps: ["Hand at forehead", "Move outward"]
            )
        ]
    }

    // MARK: - QuizEngine Pure Unit Tests

    @Test("QuizEngine generates questions without duplicate target signs")
    func noDuplicateQuestions() {
        let signs = makeSampleSigns()
        let questions = QuizEngine.generateQuestions(from: signs, allCatalogSigns: signs, count: 5)

        #expect(questions.count == 5)

        let targetNames = questions.map(\.targetSign.name)
        let uniqueNames = Set(targetNames)
        #expect(uniqueNames.count == questions.count)
    }

    @Test("Watch & Choose questions always contain 4 distinct options including the correct answer")
    func watchAndChooseOptionsIntegrity() {
        let signs = makeSampleSigns()
        let questions = QuizEngine.generateQuestions(
            from: signs,
            allCatalogSigns: signs,
            count: 4,
            preferredMode: .watchAndChoose
        )

        for question in questions {
            #expect(question.mode == .watchAndChoose)
            #expect(question.options.count == 4)
            #expect(Set(question.options).count == 4)
            #expect(question.options.contains(question.correctAnswer))
        }
    }

    @Test("Non-recognizable signs are never assigned to Sign It mode")
    func nonRecognizableSignsFallback() {
        let signs = makeSampleSigns() // Contains "Hello" which has recognition == .none
        let helloSign = signs.first(where: { $0.id == "sign-hello" })!

        let questions = QuizEngine.generateQuestions(
            from: [helloSign],
            allCatalogSigns: signs,
            count: 1,
            preferredMode: .signIt
        )

        #expect(questions.count == 1)
        #expect(questions[0].mode == .watchAndChoose)
    }

    @Test("QuizEngine scoring awards XP and accumulates streaks on correct answers")
    func scoringAndStreakBonus() {
        let signs = makeSampleSigns()
        let questions = [
            QuizQuestion(targetSign: signs[0], mode: .watchAndChoose, options: ["A", "B", "C", "D"], correctAnswer: "A"),
            QuizQuestion(targetSign: signs[1], mode: .watchAndChoose, options: ["A", "B", "C", "D"], correctAnswer: "B"),
            QuizQuestion(targetSign: signs[2], mode: .watchAndChoose, options: ["A", "B", "C", "D"], correctAnswer: "C")
        ]

        var engine = QuizEngine(questions: questions, initialLives: 3)

        // Question 1: Correct (+10 XP)
        let r1 = engine.answerWatchAndChoose(selectedOption: "A")
        #expect(r1.isCorrect == true)
        #expect(r1.xpEarned == 10)
        #expect(r1.streak == 1)
        #expect(engine.score == 1)
        #expect(engine.totalXP == 10)
        engine.advance()

        // Question 2: Correct (+10 XP)
        let r2 = engine.answerWatchAndChoose(selectedOption: "B")
        #expect(r2.isCorrect == true)
        #expect(r2.streak == 2)
        #expect(engine.totalXP == 20)
        engine.advance()

        // Question 3: Correct with streak >= 3 bonus (+10 + 5 = 15 XP)
        let r3 = engine.answerWatchAndChoose(selectedOption: "C")
        #expect(r3.isCorrect == true)
        #expect(r3.streak == 3)
        #expect(r3.xpEarned == 15)
        #expect(engine.totalXP == 35)
        #expect(engine.score == 3)
    }

    @Test("Incorrect answer decrements lives and resets streak")
    func incorrectAnswerLosesLife() {
        let signs = makeSampleSigns()
        let questions = [
            QuizQuestion(targetSign: signs[0], mode: .watchAndChoose, options: ["A", "B", "C", "D"], correctAnswer: "A")
        ]

        var engine = QuizEngine(questions: questions, initialLives: 3)
        let result = engine.answerWatchAndChoose(selectedOption: "B")

        #expect(result.isCorrect == false)
        #expect(result.livesRemaining == 2)
        #expect(result.streak == 0)
        #expect(engine.mistakes.count == 1)
        #expect(engine.mistakes.first?.detectedAs == "B")
    }

    @Test("Losing all 3 lives triggers game over")
    func gameOverCondition() {
        let signs = makeSampleSigns()
        let questions = [
            QuizQuestion(targetSign: signs[0], mode: .watchAndChoose, options: ["A", "B", "C", "D"], correctAnswer: "A"),
            QuizQuestion(targetSign: signs[1], mode: .watchAndChoose, options: ["A", "B", "C", "D"], correctAnswer: "B"),
            QuizQuestion(targetSign: signs[2], mode: .watchAndChoose, options: ["A", "B", "C", "D"], correctAnswer: "C")
        ]

        var engine = QuizEngine(questions: questions, initialLives: 3)

        _ = engine.answerWatchAndChoose(selectedOption: "Wrong1")
        #expect(engine.lives == 2)
        #expect(engine.isGameOver == false)
        engine.advance()

        _ = engine.answerWatchAndChoose(selectedOption: "Wrong2")
        #expect(engine.lives == 1)
        #expect(engine.isGameOver == false)
        engine.advance()

        let r3 = engine.answerWatchAndChoose(selectedOption: "Wrong3")
        #expect(engine.lives == 0)
        #expect(engine.isGameOver == true)
        #expect(r3.isGameOver == true)
    }

    // MARK: - QuizViewModel Integration Tests

    @Test("QuizViewModel coordinates option selection and persists progress")
    @MainActor
    func viewModelOptionSelection() async throws {
        let signs = makeSampleSigns()
        let questions = [
            QuizQuestion(targetSign: signs[0], mode: .watchAndChoose, options: ["A", "B", "C", "D"], correctAnswer: "A"),
            QuizQuestion(targetSign: signs[1], mode: .signIt, options: [], correctAnswer: "B")
        ]

        let camera = MockCameraService(authorizationState: .authorized)
        let recognition = MockSignRecognitionService()
        let progress = StubProgressRepository(initialStore: [:])

        let vm = QuizViewModel(
            questions: questions,
            quizTitle: "Alphabet Checkup",
            cameraService: camera,
            signRecognitionService: recognition,
            progressRepository: progress,
            userId: "quiz-test-user"
        )

        #expect(vm.lives == 3)
        #expect(vm.isAnswerSubmitted == false)

        // Select correct option "A"
        await vm.selectOption("A")

        #expect(vm.isAnswerSubmitted == true)
        #expect(vm.lastResult?.isCorrect == true)
        #expect(vm.score == 1)

        // Verify progress recorded to repository
        let records = try await progress.fetchProgress(userId: "quiz-test-user")
        let aRecord = records.first(where: { $0.signId == "sign-letter-a" })
        #expect(aRecord != nil)
        #expect(aRecord?.correct == 1)

        // Advance to Question 2 (Sign It mode)
        vm.nextQuestion()
        #expect(vm.currentQuestion?.mode == .signIt)
        #expect(vm.isAnswerSubmitted == false)

        // Simulate correct Sign It match
        await vm.simulateSignItMatch()
        #expect(vm.isAnswerSubmitted == true)
        #expect(vm.lastResult?.isCorrect == true)
        #expect(vm.score == 2)
        #expect(vm.streak == 2)
    }

    @Test("Sign It countdown timeout marks question incorrect")
    @MainActor
    func viewModelSignItTimeout() async {
        let signs = makeSampleSigns()
        let questions = [
            QuizQuestion(targetSign: signs[1], mode: .signIt, options: [], correctAnswer: "B")
        ]

        let camera = MockCameraService(authorizationState: .authorized)
        let progress = StubProgressRepository(initialStore: [:])

        let vm = QuizViewModel(
            questions: questions,
            cameraService: camera,
            progressRepository: progress,
            userId: "quiz-test-user"
        )

        // Simulate timeout / mistaken pose
        await vm.simulateSignItMistake(detectedAs: "D")

        #expect(vm.isAnswerSubmitted == true)
        #expect(vm.lastResult?.isCorrect == false)
        #expect(vm.lives == 2)
        #expect(vm.streak == 0)
    }
}
#endif
