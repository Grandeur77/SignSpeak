import Testing
import Foundation
@testable import SignSpeak

@Suite("Lesson Complete & Review Mistakes Tests")
struct LessonCompleteTests {

    @Test("LessonCompletionSummary computes accurate paced time and rating texts")
    func summaryPacedTimeAndRatings() {
        // 4 minutes 12 seconds = 252 seconds matching design 35-lesson-complete
        let summary1 = LessonCompletionSummary(
            accuracyPercentage: 89,
            durationSeconds: 252
        )
        #expect(summary1.formattedPacedTime == "4:12")
        #expect(summary1.accuracyRatingText == "GREAT ACCURACY")
        #expect(summary1.percentileText == "Top 15% of daily signers")

        // 100% accuracy
        let summary2 = LessonCompletionSummary(
            accuracyPercentage: 100,
            durationSeconds: 65
        )
        #expect(summary2.formattedPacedTime == "1:05")
        #expect(summary2.accuracyRatingText == "PERFECT ACCURACY")
        #expect(summary2.percentileText == "Top 10% of daily signers")

        // 72% accuracy
        let summary3 = LessonCompletionSummary(
            accuracyPercentage: 72,
            durationSeconds: 30
        )
        #expect(summary3.formattedPacedTime == "0:30")
        #expect(summary3.accuracyRatingText == "GOOD EFFORT")
        #expect(summary3.percentileText == "Top 25% of daily signers")

        // 55% accuracy
        let summary4 = LessonCompletionSummary(
            accuracyPercentage: 55,
            durationSeconds: 15
        )
        #expect(summary4.accuracyRatingText == "KEEP PRACTICING")
        #expect(summary4.percentileText == "Daily Signer Progress")
    }

    @Test("LessonMistakeItem formats display titles and miss counts properly")
    func mistakeItemFormatting() {
        let letterMistake = LessonMistakeItem(
            signId: "sign-letter-e",
            signName: "E",
            detectedAs: "F",
            hint: "Keep all four fingers curled down tight onto thumb tip.",
            categoryAspect: "Finger Placement Accuracy",
            missCount: 1
        )
        #expect(letterMistake.displayTitle == "Letter 'E'")
        #expect(letterMistake.missCountText == "Missed 1x")

        let wordMistake = LessonMistakeItem(
            signId: "sign-water",
            signName: "Water",
            detectedAs: "Drink",
            hint: "Tap chin twice with index finger in steady W-shape.",
            categoryAspect: "Cadence & Repetition",
            missCount: 2
        )
        #expect(wordMistake.displayTitle == "Word 'Water'")
        #expect(wordMistake.missCountText == "Missed 2x")
    }

    @Test("Bonus XP waiting scales with number of targeted mistakes")
    func bonusXPScaling() {
        let item1 = LessonMistakeItem(
            signId: "1",
            signName: "E",
            detectedAs: "F",
            hint: "Hint"
        )
        let item2 = LessonMistakeItem(
            signId: "2",
            signName: "Water",
            detectedAs: "Drink",
            hint: "Hint"
        )

        let summaryTwo = LessonCompletionSummary(mistakes: [item1, item2])
        #expect(summaryTwo.reviewBonusXP == 40) // +40 XP matching design 37-review-mistakes

        let summaryThree = LessonCompletionSummary(mistakes: [item1, item2, item1])
        #expect(summaryThree.reviewBonusXP == 60)

        let summaryEmpty = LessonCompletionSummary(mistakes: [])
        #expect(summaryEmpty.reviewBonusXP == 20) // Minimum baseline bonus
    }

    @Test("PracticeViewModel builds comprehensive LessonCompletionSummary")
    @MainActor
    func practiceViewModelSummaryGeneration() async {
        let signE = Sign(
            id: "sign-letter-e",
            name: "E",
            category: "alphabet",
            recognition: .staticSign,
            description: "Letter E",
            howToSteps: ["Curl fingers"],
            commonMistake: "Fingers not resting on thumb"
        )
        let signF = Sign(
            id: "sign-letter-f",
            name: "F",
            category: "alphabet",
            recognition: .staticSign,
            description: "Letter F",
            howToSteps: ["Touch index and thumb"]
        )
        let signWater = Sign(
            id: "sign-water",
            name: "Water",
            category: "words",
            recognition: .motionSign,
            description: "Word Water",
            howToSteps: ["Tap chin with W"]
        )

        let viewModel = PracticeViewModel(
            signs: [signE, signF, signWater],
            lessonTitle: "Alphabet Practice",
            cameraService: StubCameraService(),
            handPoseDetector: StubHandPoseDetector(),
            signClassifier: StubSignClassifier(),
            signRecognitionService: StubSignRecognitionService(),
            progressRepository: StubProgressRepository()
        )

        // Record a mistake on sign E detected as F
        viewModel.sessionMistakes.append(SignPracticeMistake(
            signId: "sign-letter-e",
            signName: "E",
            detectedAs: "F"
        ))
        // And another mistake on sign E
        viewModel.sessionMistakes.append(SignPracticeMistake(
            signId: "sign-letter-e",
            signName: "E",
            detectedAs: "F"
        ))

        // Record a mistake on sign Water detected as Drink
        viewModel.sessionMistakes.append(SignPracticeMistake(
            signId: "sign-water",
            signName: "Water",
            detectedAs: "Drink"
        ))

        let catalog = SignCatalogService(payload: SignCatalogPayload(signs: [signE, signF, signWater]))
        let summary = viewModel.makeCompletionSummary(signCatalog: catalog)

        #expect(summary.totalSignsCount == 3)
        #expect(summary.lessonTitle == "Alphabet Practice")
        #expect(summary.mistakes.count == 2) // E and Water

        let eMistake = summary.mistakes.first { $0.signId == "sign-letter-e" }
        #expect(eMistake != nil)
        #expect(eMistake?.missCount == 2)
        #expect(eMistake?.detectedAs == "F")
        #expect(eMistake?.categoryAspect == "Finger Placement Accuracy")

        let waterMistake = summary.mistakes.first { $0.signId == "sign-water" }
        #expect(waterMistake != nil)
        #expect(waterMistake?.missCount == 1)
        #expect(waterMistake?.detectedAs == "Drink")
        #expect(waterMistake?.categoryAspect == "Cadence & Repetition")
    }

    @Test("QuizViewModel builds comprehensive LessonCompletionSummary")
    @MainActor
    func quizViewModelSummaryGeneration() async {
        let signA = Sign(
            id: "sign-letter-a",
            name: "A",
            category: "alphabet",
            recognition: .staticSign,
            description: "Letter A",
            howToSteps: ["Fist with thumb upright"]
        )
        let signB = Sign(
            id: "sign-letter-b",
            name: "B",
            category: "alphabet",
            recognition: .staticSign,
            description: "Letter B",
            howToSteps: ["Flat hand with thumb tucked"]
        )

        let questions = [
            QuizQuestion(
                targetSign: signA,
                mode: .watchAndChoose,
                options: ["A", "B", "C", "D"],
                correctAnswer: "A"
            ),
            QuizQuestion(
                targetSign: signB,
                mode: .watchAndChoose,
                options: ["A", "B", "C", "D"],
                correctAnswer: "B"
            )
        ]

        let viewModel = QuizViewModel(
            questions: questions,
            quizTitle: "Letter Quiz",
            cameraService: StubCameraService(),
            handPoseDetector: StubHandPoseDetector(),
            signClassifier: StubSignClassifier(),
            signRecognitionService: StubSignRecognitionService(),
            progressRepository: StubProgressRepository()
        )

        // Select correct answer for Q1
        await viewModel.selectOption("A")
        viewModel.nextQuestion()

        // Select incorrect answer for Q2
        await viewModel.selectOption("C")

        let catalog = SignCatalogService(payload: SignCatalogPayload(signs: [signA, signB]))
        let summary = viewModel.makeCompletionSummary(signCatalog: catalog)

        #expect(summary.totalSignsCount == 2)
        #expect(summary.lessonTitle == "Letter Quiz")
        #expect(summary.accuracyPercentage == 50)
        #expect(summary.mistakes.count == 1)
        #expect(summary.mistakes.first?.signId == "sign-letter-b")
        #expect(summary.mistakes.first?.detectedAs == "C")
    }

    @Test("LearnHubViewModel builds review mistakes summary from catalog")
    @MainActor
    func learnHubViewModelSummaryGeneration() async {
        let signM = Sign(
            id: "sign-letter-m",
            name: "M",
            category: "alphabet",
            description: "Letter M",
            howToSteps: ["Tuck thumb under 3 fingers"]
        )
        let signN = Sign(
            id: "sign-letter-n",
            name: "N",
            category: "alphabet",
            description: "Letter N",
            howToSteps: ["Tuck thumb under 2 fingers"]
        )

        let catalog = SignCatalogService(payload: SignCatalogPayload(signs: [signM, signN]))
        let repo = StubProgressRepository(initialStore: [
            "user1": [
                "sign-letter-m": SignProgress(signId: "sign-letter-m", attempts: 3, correct: 1, lastDetectedAs: "N"),
                "sign-letter-n": SignProgress(signId: "sign-letter-n", attempts: 2, correct: 1, lastDetectedAs: "M")
            ]
        ])

        let viewModel = LearnHubViewModel(
            progressRepository: repo,
            signCatalogService: catalog,
            userProfileRepository: StubUserProfileRepository(),
            authService: StubAuthService(initialUserId: "user1")
        )

        await viewModel.load()

        let summary = viewModel.makeReviewMistakesSummary(signCatalog: catalog)
        #expect(summary.mistakes.count == 2)
        #expect(summary.unitTitle == "Lesson Review")

        let mMistake = summary.mistakes.first { $0.signId == "sign-letter-m" }
        #expect(mMistake?.detectedAs == "N")
        #expect(mMistake?.missCount == 2) // 3 attempts - 1 correct = 2 misses
    }
}
