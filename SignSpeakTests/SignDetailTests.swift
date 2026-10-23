import Testing
import Foundation
@testable import SignSpeak

@MainActor
struct SignDetailTests {

    private func makeSampleSign(
        id: String = "sign-word-hello",
        name: String = "Hello",
        isRecognizable: Bool = true,
        recognition: SignRecognitionType = .motionSign
    ) -> Sign {
        Sign(
            id: id,
            name: name,
            pronunciationHint: "HEH-loh",
            category: "greetings",
            level: .beginner,
            frequencyTag: "Top 10",
            handedness: .oneHanded,
            recognition: recognition,
            description: "A friendly salute gesture moving away from your forehead.",
            howToSteps: [
                "Open Hand: Place flat hand near temple.",
                "Forward Wave: Move hand forward and outward."
            ],
            commonMistake: "Don't wave side-to-side.",
            mnemonicTip: "A warm salute to a friend.",
            imageName: "sign_hello",
            frontVideoName: "video_hello_front",
            sideVideoName: "video_hello_side"
        )
    }

    @Test("SignDetailViewModel initializes properly from Sign model")
    func viewModelInitializationFromSign() async {
        let sign = makeSampleSign()
        let catalog = StubSignCatalogService(payload: SignCatalogPayload(signs: [sign]))
        let favouritesRepo = StubFavouritesRepository()
        let progressRepo = StubProgressRepository()

        let vm = SignDetailViewModel(
            sign: sign,
            favouritesRepository: favouritesRepo,
            progressRepository: progressRepo,
            signCatalogService: catalog,
            userId: "test-user"
        )

        #expect(vm.sign?.id == "sign-word-hello")
        #expect(vm.signId == "sign-word-hello")
        #expect(vm.isRecognizable == true)
        #expect(vm.recommendedPracticeMode == .cameraRecognition)
    }

    @Test("SignDetailViewModel resolves sign lazily when initialized with signId")
    func viewModelInitializationFromSignId() async {
        let sign = makeSampleSign(id: "sign-letter-m", name: "M")
        let catalog = StubSignCatalogService(payload: SignCatalogPayload(signs: [sign]))
        let favouritesRepo = StubFavouritesRepository()
        let progressRepo = StubProgressRepository()

        let vm = SignDetailViewModel(
            signId: "sign-letter-m",
            favouritesRepository: favouritesRepo,
            progressRepository: progressRepo,
            signCatalogService: catalog,
            userId: "test-user"
        )

        #expect(vm.sign?.name == "M")
        #expect(vm.signId == "sign-letter-m")
    }

    @Test("Loading populates favourite state and learning progress")
    func loadingPopulatesState() async throws {
        let sign = makeSampleSign()
        let catalog = StubSignCatalogService(payload: SignCatalogPayload(signs: [sign]))
        let favouritesRepo = StubFavouritesRepository()
        let progressRepo = StubProgressRepository()

        // Seed favourite and progress
        try await favouritesRepo.addFavourite(userId: "test-user", signId: sign.id)
        try await progressRepo.recordAttempt(userId: "test-user", signId: sign.id, isCorrect: true, detectedAs: "Hello")
        try await progressRepo.recordAttempt(userId: "test-user", signId: sign.id, isCorrect: true, detectedAs: "Hello")

        let vm = SignDetailViewModel(
            sign: sign,
            favouritesRepository: favouritesRepo,
            progressRepository: progressRepo,
            signCatalogService: catalog,
            userId: "test-user"
        )

        await vm.load()

        #expect(vm.isFavourite == true)
        #expect(vm.isBookmarked == true)
        #expect(vm.signProgress?.attempts == 2)
        #expect(vm.signProgress?.correct == 2)
        #expect(vm.masteryStatusTitle == "Learning")
        #expect(vm.accuracyPercentageText?.contains("100%") == true)
    }

    @Test("Toggling favourite updates repository and local state")
    func toggleFavouriteWorkflow() async throws {
        let sign = makeSampleSign()
        let catalog = StubSignCatalogService(payload: SignCatalogPayload(signs: [sign]))
        let favouritesRepo = StubFavouritesRepository(initialStore: [:])
        let progressRepo = StubProgressRepository()

        let vm = SignDetailViewModel(
            sign: sign,
            favouritesRepository: favouritesRepo,
            progressRepository: progressRepo,
            signCatalogService: catalog,
            userId: "user-123"
        )

        #expect(vm.isFavourite == false)

        // Toggle on
        await vm.toggleFavourite()
        #expect(vm.isFavourite == true)
        #expect(vm.isBookmarked == true)
        let isSavedInRepo = try await favouritesRepo.isFavourite(userId: "user-123", signId: sign.id)
        #expect(isSavedInRepo == true)

        // Toggle off
        await vm.toggleFavourite()
        #expect(vm.isFavourite == false)
        #expect(vm.isBookmarked == false)
        let isRemovedFromRepo = try await favouritesRepo.isFavourite(userId: "user-123", signId: sign.id)
        #expect(isRemovedFromRepo == false)
    }

    @Test("Mastery status correctly reflects New, Learning, and Mastered")
    func masteryStatusMapping() async throws {
        let sign = makeSampleSign()
        let catalog = StubSignCatalogService(payload: SignCatalogPayload(signs: [sign]))
        let favouritesRepo = StubFavouritesRepository()
        let progressRepo = StubProgressRepository()

        let vm = SignDetailViewModel(
            sign: sign,
            favouritesRepository: favouritesRepo,
            progressRepository: progressRepo,
            signCatalogService: catalog,
            userId: "user-abc"
        )

        // 1. Initial / New Sign
        await vm.load()
        #expect(vm.masteryStatusTitle == "New Sign")
        #expect(vm.accuracyPercentageText == nil)

        // 2. Learning state (attempts > 0, not mastered)
        try await progressRepo.recordAttempt(userId: "user-abc", signId: sign.id, isCorrect: true, detectedAs: "Hello")
        await vm.load()
        #expect(vm.masteryStatusTitle == "Learning")
        #expect(vm.accuracyPercentageText?.contains("100%") == true)
        #expect(vm.attemptsCountText?.contains("1 practice attempt") == true)

        // 3. Mastered state (5 attempts, 5 correct)
        for _ in 1...4 {
            try await progressRepo.recordAttempt(userId: "user-abc", signId: sign.id, isCorrect: true, detectedAs: "Hello")
        }
        await vm.load()
        #expect(vm.masteryStatusTitle == "Mastered")
        #expect(vm.signProgress?.isMastered == true)
        #expect(vm.accuracyPercentageText?.contains("100%") == true)
    }

    @Test("Practice mode routes to Camera for recognizable and Watch & Choose for visual signs")
    func practiceModeRouting() async {
        let recognizableSign = makeSampleSign(id: "s1", recognition: .staticSign)
        let visualSign = makeSampleSign(id: "s2", recognition: .none)

        let catalog = StubSignCatalogService(payload: SignCatalogPayload(signs: [recognizableSign, visualSign]))
        let favouritesRepo = StubFavouritesRepository()
        let progressRepo = StubProgressRepository()

        let vm1 = SignDetailViewModel(
            sign: recognizableSign,
            favouritesRepository: favouritesRepo,
            progressRepository: progressRepo,
            signCatalogService: catalog
        )
        #expect(vm1.recommendedPracticeMode == .cameraRecognition)

        let vm2 = SignDetailViewModel(
            sign: visualSign,
            favouritesRepository: favouritesRepo,
            progressRepository: progressRepo,
            signCatalogService: catalog
        )
        #expect(vm2.recommendedPracticeMode == .watchAndChoose)
    }

    @Test("Watch and choose question generates valid options with target sign and distractors")
    func watchAndChooseQuestionGeneration() async {
        let sign1 = makeSampleSign(id: "s1", name: "Hello")
        let sign2 = makeSampleSign(id: "s2", name: "Goodbye")
        let sign3 = makeSampleSign(id: "s3", name: "Please")
        let sign4 = makeSampleSign(id: "s4", name: "Thank You")

        let catalog = StubSignCatalogService(payload: SignCatalogPayload(signs: [sign1, sign2, sign3, sign4]))
        let favouritesRepo = StubFavouritesRepository()
        let progressRepo = StubProgressRepository()

        let vm = SignDetailViewModel(
            sign: sign1,
            favouritesRepository: favouritesRepo,
            progressRepository: progressRepo,
            signCatalogService: catalog
        )

        let question = vm.makeWatchAndChooseQuestion()
        #expect(question != nil)
        #expect(question?.correctAnswer == "Hello")
        #expect(question?.mode == .watchAndChoose)
        #expect(question?.options.contains("Hello") == true)
        #expect(question?.options.count == 4)
    }

    @Test("Share text includes sign name, category, description, and deep link")
    func shareTextFormatting() async {
        let sign = makeSampleSign(name: "Hello")
        let catalog = StubSignCatalogService(payload: SignCatalogPayload(signs: [sign]))
        let favouritesRepo = StubFavouritesRepository()
        let progressRepo = StubProgressRepository()

        let vm = SignDetailViewModel(
            sign: sign,
            favouritesRepository: favouritesRepo,
            progressRepository: progressRepo,
            signCatalogService: catalog
        )

        let text = vm.shareText
        #expect(text.contains("Hello"))
        #expect(text.contains("American Sign Language"))
        #expect(text.contains("Greetings"))
        #expect(text.contains("signspeak://sign?id=sign-word-hello"))
    }
}
