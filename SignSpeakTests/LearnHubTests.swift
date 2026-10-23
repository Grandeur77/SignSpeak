#if DEBUG
import Foundation
import Testing
@testable import SignSpeak

@Suite("Learn Hub & Progress Tests (Step 5.1)")
struct LearnHubTests {

    private func makeDependencies() -> (StubProgressRepository, SignCatalogService, StubUserProfileRepository, StubAuthService) {
        let progressRepo = StubProgressRepository()
        let catalog = SignCatalogService()
        let profileRepo = StubUserProfileRepository(initialProfiles: [
            UserProfile(
                id: "test-user-123",
                displayName: "Test Learner",
                email: "test@example.com",
                role: "learner",
                currentStreak: 7
            )
        ])
        let authService = StubAuthService(initialUserId: "test-user-123")
        return (progressRepo, catalog, profileRepo, authService)
    }

    // MARK: - Metrics Calculations

    @Test("LearnHubMetrics calculates progress ratios correctly")
    func metricsProgressRatios() {
        let metrics = LearnHubMetrics(
            dailyGoalTarget: 3,
            dailyGoalVerified: 2,
            alphabetTotal: 26,
            alphabetMastered: 12,
            wordsCategoriesCount: 6,
            wordsTotal: 56,
            wordsLearned: 18,
            mistakesCount: 3
        )

        #expect(metrics.alphabetProgress > 0.46 && metrics.alphabetProgress < 0.47)
        #expect(metrics.wordsProgress > 0.32 && metrics.wordsProgress < 0.33)
        #expect(metrics.dailyGoalVerified == 2)
        #expect(metrics.dailyGoalTarget == 3)
        #expect(metrics.mistakesCount == 3)
    }

    @Test("LearnHubMetrics handles zero totals without crashing")
    func metricsZeroTotals() {
        let metrics = LearnHubMetrics(
            alphabetTotal: 0,
            alphabetMastered: 0,
            wordsTotal: 0,
            wordsLearned: 0
        )

        #expect(metrics.alphabetProgress == 0.0)
        #expect(metrics.wordsProgress == 0.0)
    }

    // MARK: - ViewModel Loading

    @Test("LearnHubViewModel loads streak, metrics, and mistakes successfully")
    @MainActor
    func viewModelLoadsMetricsAndMistakes() async {
        let (progressRepo, catalog, profileRepo, authService) = makeDependencies()

        let viewModel = LearnHubViewModel(
            progressRepository: progressRepo,
            signCatalogService: catalog,
            userProfileRepository: profileRepo,
            authService: authService
        )

        await viewModel.load()

        #expect(viewModel.currentStreak == 7)
        #expect(viewModel.metrics.alphabetMastered >= 12)
        #expect(viewModel.metrics.wordsLearned >= 18)
        #expect(viewModel.metrics.dailyGoalVerified >= 2)
        #expect(viewModel.mistakeSigns.isEmpty == false)
    }

    // MARK: - Fast-Track Action Toggles

    @Test("ViewModel action methods trigger presentation flags")
    @MainActor
    func viewModelActionToggles() {
        let (progressRepo, catalog, profileRepo, authService) = makeDependencies()

        let viewModel = LearnHubViewModel(
            progressRepository: progressRepo,
            signCatalogService: catalog,
            userProfileRepository: profileRepo,
            authService: authService
        )

        #expect(viewModel.isQuizPresented == false)
        #expect(viewModel.isMistakesPracticePresented == false)
        #expect(viewModel.isCameraPracticePresented == false)

        viewModel.startSpeedRun()
        #expect(viewModel.isQuizPresented == true)

        viewModel.startMistakesReview()
        #expect(viewModel.isMistakesPracticePresented == true)

        viewModel.startCameraPractice()
        #expect(viewModel.isCameraPracticePresented == true)
    }

    // MARK: - Progress Repository Attempt Recording

    @Test("StubProgressRepository records attempts and unlocks mastery after 5 correct")
    func repositoryRecordsAttemptsAndMastery() async throws {
        let repo = StubProgressRepository()
        let userId = "user-attempt-test"
        let signId = "sign-test-practice"

        // Initial progress: empty
        var progress = try await repo.fetchProgress(userId: userId)
        #expect(progress.first(where: { $0.signId == signId }) == nil)

        // Record 4 correct attempts
        for _ in 1...4 {
            try await repo.recordAttempt(userId: userId, signId: signId, isCorrect: true)
        }

        progress = try await repo.fetchProgress(userId: userId)
        var item = progress.first(where: { $0.signId == signId })
        #expect(item?.attempts == 4)
        #expect(item?.correct == 4)
        #expect(item?.isMastered == false)

        // 5th correct attempt unlocks mastery
        try await repo.recordAttempt(userId: userId, signId: signId, isCorrect: true)

        progress = try await repo.fetchProgress(userId: userId)
        item = progress.first(where: { $0.signId == signId })
        #expect(item?.attempts == 5)
        #expect(item?.correct == 5)
        #expect(item?.isMastered == true)
    }
}
#endif
