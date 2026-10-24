import SwiftUI
import Foundation

/// Time range filter for analytics screen.
public enum AnalyticsTimeRange: String, CaseIterable, Identifiable, Sendable {
    case week = "Week"
    case month = "Month"
    case all = "All Time"

    public var id: String { rawValue }
}

/// Sign performance summary item for strongest & needs-practice lists.
public struct SignPerformanceItem: Identifiable, Sendable, Equatable {
    public var id: String { signId }
    public let signId: String
    public let signName: String
    public let category: String
    public let accuracyPercentage: Int
    public let attempts: Int

    public init(signId: String, signName: String, category: String, accuracyPercentage: Int, attempts: Int) {
        self.signId = signId
        self.signName = signName
        self.category = category
        self.accuracyPercentage = accuracyPercentage
        self.attempts = attempts
    }
}

/// Driving view model for Step 9.3 Progress Analytics (`24-analytics`).
@Observable
@MainActor
public final class AnalyticsViewModel {
    public var selectedRange: AnalyticsTimeRange = .week
    public var comparison: WeekOverWeekComparison = WeekOverWeekComparison()
    public var dailyMetrics: [DailyPracticeMetric] = []
    public var accuracyMetrics: [AccuracyTrendMetric] = []
    public var strongestSigns: [SignPerformanceItem] = []
    public var needsPracticeSigns: [SignPerformanceItem] = []
    public var isShowingPracticeSession: Bool = false
    public var targetSignIdToPractice: String? = nil

    private var progressRepository: any ProgressRepository
    private var userProfileRepository: any UserProfileRepository
    private var userId: String
    private var dateProvider: any DateProviding

    public init(
        progressRepository: any ProgressRepository = StubProgressRepository(),
        userProfileRepository: any UserProfileRepository = StubUserProfileRepository(),
        userId: String = "guest",
        dateProvider: any DateProviding = SystemDateProvider()
    ) {
        self.progressRepository = progressRepository
        self.userProfileRepository = userProfileRepository
        self.userId = userId
        self.dateProvider = dateProvider
    }

    public func update(
        progressRepository: any ProgressRepository,
        userProfileRepository: any UserProfileRepository,
        userId: String,
        dateProvider: any DateProviding
    ) {
        self.progressRepository = progressRepository
        self.userProfileRepository = userProfileRepository
        self.userId = userId
        self.dateProvider = dateProvider
    }

    public func loadAnalytics() async {
        // Compute daily metrics & trends
        self.dailyMetrics = AnalyticsEngine.generateDailyPracticeMetrics(referenceDate: dateProvider.now)
        self.accuracyMetrics = AnalyticsEngine.generateAccuracyTrendMetrics(referenceDate: dateProvider.now)
        self.comparison = AnalyticsEngine.calculateWeekOverWeek(
            thisWeekMinutes: 54,
            lastWeekMinutes: 46,
            accuracyThisWeek: 92,
            signsLearned: 14
        )

        // Load sign performance lists
        do {
            let progressList = try await progressRepository.fetchProgress(userId: userId)
            if !progressList.isEmpty {
                populateSignLists(from: progressList)
            } else {
                populateDefaultSignLists()
            }
        } catch {
            populateDefaultSignLists()
        }
    }

    private func populateSignLists(from progressList: [SignProgress]) {
        let items: [SignPerformanceItem] = progressList.compactMap { p in
            guard p.attempts > 0 else { return nil }
            let acc = Int((Double(p.correct) / Double(p.attempts)) * 100.0)
            let name = p.signId.replacingOccurrences(of: "_", with: " ").capitalized
            return SignPerformanceItem(
                signId: p.signId,
                signName: name,
                category: p.signId.contains("letter") ? "Alphabet" : "Vocabulary",
                accuracyPercentage: acc,
                attempts: p.attempts
            )
        }

        self.strongestSigns = items.filter { $0.accuracyPercentage >= 85 }
            .sorted { $0.accuracyPercentage > $1.accuracyPercentage }
        self.needsPracticeSigns = items.filter { $0.accuracyPercentage < 85 }
            .sorted { $0.accuracyPercentage < $1.accuracyPercentage }

        if strongestSigns.isEmpty && needsPracticeSigns.isEmpty {
            populateDefaultSignLists()
        }
    }

    private func populateDefaultSignLists() {
        self.strongestSigns = [
            SignPerformanceItem(signId: "thank_you", signName: "Thank You", category: "Polite", accuracyPercentage: 98, attempts: 24),
            SignPerformanceItem(signId: "hello", signName: "Hello", category: "Greetings", accuracyPercentage: 96, attempts: 18),
            SignPerformanceItem(signId: "please", signName: "Please", category: "Polite", accuracyPercentage: 92, attempts: 15)
        ]

        self.needsPracticeSigns = [
            SignPerformanceItem(signId: "coffee", signName: "Coffee", category: "Food & Drink", accuracyPercentage: 68, attempts: 8),
            SignPerformanceItem(signId: "family", signName: "Family", category: "People", accuracyPercentage: 72, attempts: 11),
            SignPerformanceItem(signId: "help", signName: "Help", category: "Emergency", accuracyPercentage: 76, attempts: 9)
        ]
    }
}
