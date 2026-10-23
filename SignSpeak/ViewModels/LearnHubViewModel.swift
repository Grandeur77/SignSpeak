import SwiftUI

/// View model orchestrating learning hub state, metrics, progress rings, and fast-track actions.
/// Matches design `25-learn-hub`.
@Observable
@MainActor
public final class LearnHubViewModel {
    public private(set) var metrics: LearnHubMetrics = LearnHubMetrics()
    public private(set) var currentStreak: Int = 7
    public private(set) var isLoading: Bool = false
    public private(set) var mistakeSigns: [Sign] = []
    public private(set) var rawMistakes: [SignProgress] = []

    public var isQuizPresented: Bool = false
    public var isMistakesPracticePresented: Bool = false
    public var isCameraPracticePresented: Bool = false

    private let progressRepository: any ProgressRepository
    private let signCatalogService: any SignCatalogServicing
    private let userProfileRepository: any UserProfileRepository
    private let authService: any AuthServicing

    public init(
        progressRepository: any ProgressRepository,
        signCatalogService: any SignCatalogServicing,
        userProfileRepository: any UserProfileRepository,
        authService: any AuthServicing
    ) {
        self.progressRepository = progressRepository
        self.signCatalogService = signCatalogService
        self.userProfileRepository = userProfileRepository
        self.authService = authService
    }

    /// Loads metrics, streak, and mistakes for the active user.
    public func load() async {
        isLoading = true
        defer { isLoading = false }

        let userId = authService.currentUserId ?? "default"

        // 1. Load User Profile / Streak
        if let profile = try? await userProfileRepository.fetchProfile(userId: userId) {
            self.currentStreak = max(1, profile.currentStreak)
        } else {
            self.currentStreak = 7
        }

        // 2. Load Learn Hub Progress Metrics
        if let loadedMetrics = try? await progressRepository.fetchLearnHubMetrics(userId: userId) {
            self.metrics = loadedMetrics
        }

        // 3. Resolve mistake signs from catalog
        if let rawMistakes = try? await progressRepository.fetchMistakes(userId: userId) {
            self.rawMistakes = rawMistakes
            let signs = rawMistakes.compactMap { signCatalogService.sign(byId: $0.signId) }
            if !signs.isEmpty {
                self.mistakeSigns = signs
            } else {
                // Fallback to sample mistake signs if catalog lookup yields empty
                self.mistakeSigns = [
                    signCatalogService.sign(byId: "sign-letter-m") ?? signCatalogService.sign(named: "M"),
                    signCatalogService.sign(byId: "sign-letter-n") ?? signCatalogService.sign(named: "N"),
                    signCatalogService.sign(byId: "sign-letter-r") ?? signCatalogService.sign(named: "R")
                ].compactMap { $0 }
            }
        }
    }

    public func startSpeedRun() {
        isQuizPresented = true
    }

    public func startMistakesReview() {
        isMistakesPracticePresented = true
    }

    public func startCameraPractice() {
        isCameraPracticePresented = true
    }

    public func makeReviewMistakesSummary(signCatalog: any SignCatalogServicing) -> LessonCompletionSummary {
        let items: [LessonMistakeItem] = mistakeSigns.map { sign in
            let raw = rawMistakes.first { $0.signId == sign.id }
            let detected = raw?.lastDetectedAs ?? (sign.name == "E" ? "F" : (sign.name == "Water" ? "Drink" : "N"))
            let count = max(1, (raw?.attempts ?? 1) - (raw?.correct ?? 0))
            let aspect = (sign.recognition == .motionSign) ? "Cadence & Repetition" : "Finger Placement Accuracy"
            let hint = sign.commonMistake ?? sign.mnemonicTip ?? "Hold hand steady and ensure clear finger separation."

            return LessonMistakeItem(
                signId: sign.id,
                signName: sign.name,
                detectedAs: detected,
                hint: hint,
                categoryAspect: aspect,
                missCount: count,
                sign: sign
            )
        }

        return LessonCompletionSummary(
            lessonTitle: "Targeted Mistakes Review",
            unitTitle: "Lesson Review",
            accuracyPercentage: max(75, 100 - (items.count * 8)),
            totalSignsCount: items.count,
            completedSignsCount: 0,
            durationSeconds: 180,
            streakIncrementDays: 1,
            currentStreak: currentStreak,
            earnedXP: 40,
            unlockedBadge: LessonBadge(
                id: "precision-master",
                title: "Precision Master",
                description: "Mastered all identified targeted mistake signs"
            ),
            spatialAccuracyNote: "Targeting \(items.count) signs will increase your overall recognition confidence.",
            mistakes: items
        )
    }
}

