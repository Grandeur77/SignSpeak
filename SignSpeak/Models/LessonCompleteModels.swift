import Foundation

/// Badge reward unlocked upon completing a lesson milestone.
public struct LessonBadge: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let description: String
    public let xpReward: Int
    public let iconName: String

    public init(
        id: String = "alphabet-starter",
        title: String = "Alphabet Starter",
        description: String = "Completed your first 5 manual finger-signs",
        xpReward: Int = 100,
        iconName: String = "medal.fill"
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.xpReward = xpReward
        self.iconName = iconName
    }
}

/// A specific mistake item identified during a practice or quiz session for targeted review.
/// Matches design `37-review-mistakes`.
public struct LessonMistakeItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let signId: String
    public let signName: String
    public let detectedAs: String
    public let hint: String
    public let categoryAspect: String
    public let missCount: Int
    public let sign: Sign?

    public init(
        id: String = UUID().uuidString,
        signId: String,
        signName: String,
        detectedAs: String,
        hint: String,
        categoryAspect: String = "Finger Placement Accuracy",
        missCount: Int = 1,
        sign: Sign? = nil
    ) {
        self.id = id
        self.signId = signId
        self.signName = signName
        self.detectedAs = detectedAs
        self.hint = hint
        self.categoryAspect = categoryAspect
        self.missCount = missCount
        self.sign = sign
    }

    /// Formatted display title matching `37-review-mistakes` (e.g. "Letter 'E'" or "Word 'Water'").
    public var displayTitle: String {
        if signName.count == 1 {
            return "Letter '\(signName)'"
        } else {
            return "Word '\(signName)'"
        }
    }

    /// Formatted miss count tag (e.g. "Missed 1x" or "Missed 2x").
    public var missCountText: String {
        "Missed \(missCount)x"
    }
}

/// Comprehensive summary model representing completed lesson performance.
/// Matches design `35-lesson-complete`.
public struct LessonCompletionSummary: Identifiable, Sendable, Equatable {
    public let id: String
    public let lessonTitle: String
    public let unitTitle: String
    public let accuracyPercentage: Int
    public let totalSignsCount: Int
    public let completedSignsCount: Int
    public let durationSeconds: TimeInterval
    public let streakIncrementDays: Int
    public let currentStreak: Int
    public let earnedXP: Int
    public let unlockedBadge: LessonBadge?
    public let spatialAccuracyNote: String?
    public let mistakes: [LessonMistakeItem]

    public init(
        id: String = UUID().uuidString,
        lessonTitle: String = "Lesson 2: Letters F–J",
        unitTitle: String = "Streak Milestone Reward",
        accuracyPercentage: Int = 89,
        totalSignsCount: Int = 5,
        completedSignsCount: Int = 5,
        durationSeconds: TimeInterval = 252, // 4 minutes 12 seconds
        streakIncrementDays: Int = 1,
        currentStreak: Int = 8,
        earnedXP: Int = 100,
        unlockedBadge: LessonBadge? = LessonBadge(),
        spatialAccuracyNote: String? = "Your spatial hand-depth accuracy on Letter H was 94%.",
        mistakes: [LessonMistakeItem] = []
    ) {
        self.id = id
        self.lessonTitle = lessonTitle
        self.unitTitle = unitTitle
        self.accuracyPercentage = accuracyPercentage
        self.totalSignsCount = totalSignsCount
        self.completedSignsCount = completedSignsCount
        self.durationSeconds = durationSeconds
        self.streakIncrementDays = streakIncrementDays
        self.currentStreak = currentStreak
        self.earnedXP = earnedXP
        self.unlockedBadge = unlockedBadge
        self.spatialAccuracyNote = spatialAccuracyNote
        self.mistakes = mistakes
    }

    /// Formatted paced duration string (e.g. "4:12").
    public var formattedPacedTime: String {
        let totalSeconds = Int(durationSeconds)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Qualitative accuracy rating caption matching design `35-lesson-complete`.
    public var accuracyRatingText: String {
        switch accuracyPercentage {
        case 95...100:
            return "PERFECT ACCURACY"
        case 80..<95:
            return "GREAT ACCURACY"
        case 65..<80:
            return "GOOD EFFORT"
        default:
            return "KEEP PRACTICING"
        }
    }

    /// Percentile label badge matching design (e.g. "Top 15% of daily signers").
    public var percentileText: String {
        if accuracyPercentage >= 90 {
            return "Top 10% of daily signers"
        } else if accuracyPercentage >= 80 {
            return "Top 15% of daily signers"
        } else if accuracyPercentage >= 70 {
            return "Top 25% of daily signers"
        } else {
            return "Daily Signer Progress"
        }
    }

    /// Potential bonus XP waiting to be unlocked by reviewing mistakes.
    public var reviewBonusXP: Int {
        max(20, mistakes.count * 20)
    }
}
