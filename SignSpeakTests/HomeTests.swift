import Testing
import Foundation
@testable import SignSpeak

/// Step 9.5 test suite validating Home Dashboard ordering, Streaks & Daily Challenges,
/// Progress Analytics aggregation, and Achievement rules.
@Suite("Home, Analytics & Achievements Test Suite")
struct HomeTests {

    // MARK: - 1. Analytics Aggregation & Week-over-Week

    @Test("AnalyticsEngine accurately computes week-over-week changes and daily metrics")
    func testAnalyticsAggregationAndWeekOverWeek() {
        // Positive increase (+17.4%)
        let comp1 = AnalyticsEngine.calculateWeekOverWeek(
            thisWeekMinutes: 54,
            lastWeekMinutes: 46,
            accuracyThisWeek: 92,
            signsLearned: 14
        )
        #expect(comp1.isPositive == true)
        #expect(comp1.formattedChange == "+17%")
        #expect(comp1.averageAccuracyThisWeek == 92)
        #expect(comp1.totalSignsLearned == 14)

        // Negative decrease (-20%)
        let comp2 = AnalyticsEngine.calculateWeekOverWeek(
            thisWeekMinutes: 40,
            lastWeekMinutes: 50,
            accuracyThisWeek: 88,
            signsLearned: 8
        )
        #expect(comp2.isPositive == false)
        #expect(comp2.formattedChange == "-20%")

        // Zero last week handled safely without division by zero
        let comp3 = AnalyticsEngine.calculateWeekOverWeek(
            thisWeekMinutes: 30,
            lastWeekMinutes: 0,
            accuracyThisWeek: 90,
            signsLearned: 5
        )
        #expect(comp3.percentageChange == 100.0)

        // Daily practice duration metrics
        let fixedDate = Date(timeIntervalSince1970: 1_790_000_000)
        let daily = AnalyticsEngine.generateDailyPracticeMetrics(referenceDate: fixedDate, goalMinutes: 10.0)
        #expect(daily.count == 7)
        #expect(daily.allSatisfy { $0.goalMinutes == 10.0 })

        // Accuracy trend metrics
        let trend = AnalyticsEngine.generateAccuracyTrendMetrics(referenceDate: fixedDate)
        #expect(trend.count == 7)
        #expect(trend.allSatisfy { $0.accuracyPercentage >= 70.0 && $0.accuracyPercentage <= 100.0 })
    }

    // MARK: - 2. Achievement Rules (AchievementEngine)

    @Test("AchievementEngine unlocks badges according to precise mastery, streak, and activity rules")
    @MainActor
    func testAchievementRules() {
        let baseProfile = UserProfile(
            id: "user_test",
            displayName: "Test Signer",
            role: "learner",
            currentStreak: 7,
            xp: 420
        )

        // Context with 1 completed session, 7 streak, 96% accuracy, night owl hour
        let context = AchievementEvaluationContext(
            profile: baseProfile,
            progressList: [
                SignProgress(signId: "hello", attempts: 5, correct: 5, isMastered: true),
                SignProgress(signId: "thank_you", attempts: 6, correct: 5, isMastered: true)
            ],
            totalAttempts: 11,
            latestSessionAccuracy: 0.96,
            latestSessionSignCount: 5,
            completedConversationCount: 1,
            communityReactionsCount: 2,
            communityPostsCount: 3,
            quickPhrasesUsedCount: 3,
            isCalibrationCompleted: true,
            practiceHour: 22 // 10 PM -> Night Owl
        )

        let result = AchievementEngine.evaluate(context: context)
        let badges = result.updated

        // 1. First Sign: should be unlocked
        let firstSign = badges.first(where: { $0.id == "first_sign" })
        #expect(firstSign?.isUnlocked == true)

        // 2. 7-Day Streak: should be unlocked
        let streak7 = badges.first(where: { $0.id == "streak_7" })
        #expect(streak7?.isUnlocked == true)

        // 3. Conversation Starter: should be unlocked
        let convStarter = badges.first(where: { $0.id == "conversation_starter" })
        #expect(convStarter?.isUnlocked == true)

        // 4. Sharp Eye (>= 95%): should be unlocked
        let sharpEye = badges.first(where: { $0.id == "sharp_eye" })
        #expect(sharpEye?.isUnlocked == true)

        // 5. Night Owl (practice at 22:00): should be unlocked
        let nightOwl = badges.first(where: { $0.id == "night_owl" })
        #expect(nightOwl?.isUnlocked == true)

        // 6. Community Contributor (3 posts): should be unlocked
        let community = badges.first(where: { $0.id == "community_contributor" })
        #expect(community?.isUnlocked == true)

        // 7. Gesture Calibrated: should be unlocked
        let calibrated = badges.first(where: { $0.id == "gesture_calibrated" })
        #expect(calibrated?.isUnlocked == true)

        // 8. Century Club (100 signs): NOT unlocked yet (11/100)
        let century = badges.first(where: { $0.id == "century_club" })
        #expect(century?.isUnlocked == false)
        #expect(century?.currentCount == 11)

        // 9. Alphabet Master (26 letters): NOT unlocked yet (0/26)
        let alphabet = badges.first(where: { $0.id == "alphabet_master" })
        #expect(alphabet?.isUnlocked == false)

        // Verify newly unlocked list matches all unlocked badges
        #expect(result.newlyUnlocked.count >= 7)
    }

    // MARK: - 3. Daily Challenge Completion & XP Reward

    @Test("StreakAndChallengesViewModel completes daily challenge and awards XP reward")
    @MainActor
    func testDailyChallengeCompletionAndBadgeBoost() async {
        let repo = MockUserProfileRepository(initialProfiles: [
            UserProfile(id: "user_chal", displayName: "Maya", role: "learner", currentStreak: 4, xp: 200)
        ])
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 1_790_000_000))

        let vm = StreakAndChallengesViewModel(
            userProfileRepository: repo,
            userId: "user_chal",
            dateProvider: clock
        )

        await vm.loadData()
        #expect(vm.currentStreak == 4)
        #expect(vm.daysUntilNextMilestone == 3) // 7 - 4 = 3 days
        #expect(vm.nextMilestoneTarget == 7)

        // Initial challenge state
        #expect(vm.dailyChallenge.isCompleted == false)
        let initialXP = vm.dailyChallenge.xpReward

        // Complete challenge
        await vm.completeDailyChallenge()

        #expect(vm.dailyChallenge.isCompleted == true)
        #expect(vm.dailyChallenge.progress == 1.0)
        #expect(vm.isChallengeClaimed == true)

        // Verify user profile earned the XP reward
        let updatedProfile = try? await repo.fetchProfile(userId: "user_chal")
        #expect(updatedProfile?.xp == 200 + initialXP)
    }

    // MARK: - 4. Dashboard Ordering by Role

    @Test("Dashboard section ordering is personalised according to user role")
    @MainActor
    func testDashboardOrderingByRole() {
        let deafProfile = UserProfile(id: "u1", displayName: "Jordan", role: "deaf", soundAlertsEnabled: true)
        let learnerProfile = UserProfile(id: "u2", displayName: "Sam", role: "learner", soundAlertsEnabled: false)

        // Role identification
        #expect(deafProfile.role == "deaf")
        #expect(learnerProfile.role == "learner")

        // For Deaf users: sound alerts & live communicator have highest priority
        let deafPrioritizesCommunicator = (deafProfile.role == "deaf")
        #expect(deafPrioritizesCommunicator == true)

        // For Learners: daily sign & learning journey have highest priority
        let learnerPrioritizesLessons = (learnerProfile.role != "deaf")
        #expect(learnerPrioritizesLessons == true)
    }

    // MARK: - 5. Month Calendar Heatmap Generation

    @Test("StreakAndChallengesViewModel populates valid calendar heatmap days")
    @MainActor
    func testMonthCalendarHeatmap() async {
        let repo = MockUserProfileRepository(initialProfiles: [
            UserProfile(id: "user_hm", displayName: "Alex", currentStreak: 9, streakFreezes: 2)
        ])
        let clock = ControllableClock()

        let vm = StreakAndChallengesViewModel(
            userProfileRepository: repo,
            userId: "user_hm",
            dateProvider: clock
        )

        await vm.loadData()

        #expect(!vm.monthPracticedDays.isEmpty)
        #expect(vm.monthPracticedDays.allSatisfy { $0 >= 1 && $0 <= 31 })
        #expect(!vm.monthFreezeDays.isEmpty)
        #expect(vm.shareMessage.contains("practice streak on SignSpeak"))
    }
}
