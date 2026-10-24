import Foundation

/// Context data passed to `AchievementEngine` when evaluating unlocked achievements.
public struct AchievementEvaluationContext: Sendable {
    public var profile: UserProfile
    public var progressList: [SignProgress]
    public var totalAttempts: Int
    public var latestSessionAccuracy: Double?
    public var latestSessionSignCount: Int?
    public var completedConversationCount: Int
    public var communityReactionsCount: Int
    public var communityPostsCount: Int
    public var quickPhrasesUsedCount: Int
    public var isCalibrationCompleted: Bool
    public var practiceHour: Int?

    public init(
        profile: UserProfile,
        progressList: [SignProgress] = [],
        totalAttempts: Int = 0,
        latestSessionAccuracy: Double? = nil,
        latestSessionSignCount: Int? = nil,
        completedConversationCount: Int = 0,
        communityReactionsCount: Int = 0,
        communityPostsCount: Int = 0,
        quickPhrasesUsedCount: Int = 0,
        isCalibrationCompleted: Bool = false,
        practiceHour: Int? = nil
    ) {
        self.profile = profile
        self.progressList = progressList
        self.totalAttempts = totalAttempts
        self.latestSessionAccuracy = latestSessionAccuracy
        self.latestSessionSignCount = latestSessionSignCount
        self.completedConversationCount = completedConversationCount
        self.communityReactionsCount = communityReactionsCount
        self.communityPostsCount = communityPostsCount
        self.quickPhrasesUsedCount = quickPhrasesUsedCount
        self.isCalibrationCompleted = isCalibrationCompleted
        self.practiceHour = practiceHour
    }
}

/// Evaluates rules for the 16 Step 9.4 achievements and returns updated progress and newly unlocked badges.
public struct AchievementEngine: Sendable {

    /// Evaluates existing achievements list against context and returns updated achievements + newly unlocked list.
    public static func evaluate(
        currentAchievements: [Achievement] = AchievementCatalog.all,
        context: AchievementEvaluationContext,
        now: Date = Date()
    ) -> (updated: [Achievement], newlyUnlocked: [Achievement]) {
        var updated: [Achievement] = []
        var newlyUnlocked: [Achievement] = []

        let masteredAlphabetCount = context.progressList
            .filter { $0.signId.contains("letter") && $0.isMastered }
            .count

        let totalSignsPracticed = max(context.totalAttempts, context.progressList.map(\.attempts).reduce(0, +))

        for item in currentAchievements {
            var badge = item
            let previouslyUnlocked = badge.isUnlocked
            var count = badge.currentCount

            switch badge.id {
            case "first_sign":
                count = totalSignsPracticed > 0 ? 1 : 0

            case "streak_7":
                count = max(count, context.profile.currentStreak)

            case "conversation_starter":
                count = max(count, context.completedConversationCount)

            case "alphabet_master":
                count = max(count, masteredAlphabetCount)

            case "helpful_friend":
                count = max(count, context.communityReactionsCount)

            case "sharp_eye":
                if let acc = context.latestSessionAccuracy, acc >= 0.95 {
                    count = 1
                }

            case "century_club":
                count = max(count, totalSignsPracticed)

            case "night_owl":
                if let hour = context.practiceHour, hour >= 21 || hour < 4 {
                    count = 1
                }

            case "early_bird":
                if let hour = context.practiceHour, hour >= 5 && hour < 8 {
                    count = 1
                }

            case "weekend_warrior":
                let weekday = Calendar.current.component(.weekday, from: now)
                if (weekday == 1 || weekday == 7) && context.profile.currentStreak >= 2 {
                    count = max(count, 2)
                }

            case "speed_demon":
                if (context.latestSessionSignCount ?? 0) >= 5 {
                    count = max(count, 5)
                }

            case "flawless_session":
                if let acc = context.latestSessionAccuracy, acc >= 1.0, (context.latestSessionSignCount ?? 0) >= 5 {
                    count = max(count, 5)
                }

            case "quick_phrases_explorer":
                count = max(count, context.quickPhrasesUsedCount)

            case "gesture_calibrated":
                count = context.isCalibrationCompleted ? 1 : count

            case "steady_hands":
                count = max(count, min(10, totalSignsPracticed / 3))

            case "community_contributor":
                count = max(count, context.communityPostsCount)

            default:
                break
            }

            badge.currentCount = min(badge.targetCount, count)
            if badge.currentCount >= badge.targetCount && !previouslyUnlocked {
                badge.isUnlocked = true
                badge.unlockedAt = now
                newlyUnlocked.append(badge)
            }

            updated.append(badge)
        }

        return (updated, newlyUnlocked)
    }
}
