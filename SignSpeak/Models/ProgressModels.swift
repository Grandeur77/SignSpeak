import Foundation

/// Learning session document stored in `users/{uid}/sessions/{id}`.
public struct LearningSession: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let startedAt: Date
    public let durationSeconds: Int
    public let kind: String // "lesson" | "quiz" | "review" | "favourites"
    public let attempts: Int
    public let correct: Int
    public let signIds: [String]
    public let xpEarned: Int

    public init(
        id: String = UUID().uuidString,
        startedAt: Date = Date(),
        durationSeconds: Int = 0,
        kind: String = "lesson",
        attempts: Int = 0,
        correct: Int = 0,
        signIds: [String] = [],
        xpEarned: Int = 0
    ) {
        self.id = id
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.kind = kind
        self.attempts = attempts
        self.correct = correct
        self.signIds = signIds
        self.xpEarned = xpEarned
    }
}

/// Explorer tier metadata representing learning progression and milestones.
public struct ExplorerTier: Sendable, Equatable {
    public let level: Int
    public let title: String
    public let minXP: Int
    public let maxXP: Int // Use Int.max for top tier

    public init(level: Int, title: String, minXP: Int, maxXP: Int) {
        self.level = level
        self.title = title
        self.minXP = minXP
        self.maxXP = maxXP
    }
}

/// Gamification engine calculating XP, levels, and Explorer tiers.
public enum ExplorerLevel {
    public static let tiers: [ExplorerTier] = [
        ExplorerTier(level: 1, title: "Explorer I", minXP: 0, maxXP: 100),
        ExplorerTier(level: 2, title: "Explorer II", minXP: 100, maxXP: 250),
        ExplorerTier(level: 3, title: "Explorer III", minXP: 250, maxXP: 500),
        ExplorerTier(level: 4, title: "Pathfinder I", minXP: 500, maxXP: 900),
        ExplorerTier(level: 5, title: "Pathfinder II", minXP: 900, maxXP: 1400),
        ExplorerTier(level: 6, title: "Pioneer", minXP: 1400, maxXP: 2000),
        ExplorerTier(level: 7, title: "Navigator", minXP: 2000, maxXP: 3000),
        ExplorerTier(level: 8, title: "Master Explorer", minXP: 3000, maxXP: Int.max)
    ]

    /// Calculates the learner level for a given cumulative XP amount.
    public static func level(forXP xp: Int) -> Int {
        tier(forXP: xp).level
    }

    /// Returns the active tier title for a given XP amount.
    public static func tierTitle(forXP xp: Int) -> String {
        tier(forXP: xp).title
    }

    /// Returns the full tier metadata for a given XP amount.
    public static func tier(forXP xp: Int) -> ExplorerTier {
        let clampedXP = max(0, xp)
        for tier in tiers {
            if clampedXP < tier.maxXP {
                return tier
            }
        }
        return tiers.last ?? ExplorerTier(level: 1, title: "Explorer I", minXP: 0, maxXP: 100)
    }

    /// Returns the XP target required to graduate to the subsequent level.
    public static func nextLevelXP(forXP xp: Int) -> Int {
        tier(forXP: xp).maxXP
    }

    /// Returns a 0.0...1.0 progression fraction within the current level tier.
    public static func progressFraction(forXP xp: Int) -> Double {
        let currentTier = tier(forXP: xp)
        guard currentTier.maxXP < Int.max else { return 1.0 }
        let span = currentTier.maxXP - currentTier.minXP
        guard span > 0 else { return 1.0 }
        let progress = max(0, xp - currentTier.minXP)
        return min(1.0, Double(progress) / Double(span))
    }
}

/// Result of evaluating user streak and streak freeze consumption.
public struct StreakUpdateResult: Sendable, Equatable {
    public let newStreak: Int
    public let newLongestStreak: Int
    public let newStreakFreezes: Int
    public let lastPracticeDay: String // "yyyy-MM-dd"
    public let freezeUsed: Bool
    public let earnedFreeze: Bool
    public let isNewDay: Bool

    public init(
        newStreak: Int,
        newLongestStreak: Int,
        newStreakFreezes: Int,
        lastPracticeDay: String,
        freezeUsed: Bool = false,
        earnedFreeze: Bool = false,
        isNewDay: Bool = true
    ) {
        self.newStreak = newStreak
        self.newLongestStreak = newLongestStreak
        self.newStreakFreezes = newStreakFreezes
        self.lastPracticeDay = lastPracticeDay
        self.freezeUsed = freezeUsed
        self.earnedFreeze = earnedFreeze
        self.isNewDay = isNewDay
    }
}

/// Consolidated outcome after recording a completed session and updating all progress metrics.
public struct SessionCompletionResult: Sendable, Equatable {
    public let session: LearningSession
    public let streakResult: StreakUpdateResult
    public let updatedXP: Int
    public let updatedLevel: Int
    public let levelTitle: String
    public let leveledUp: Bool

    public init(
        session: LearningSession,
        streakResult: StreakUpdateResult,
        updatedXP: Int,
        updatedLevel: Int,
        levelTitle: String,
        leveledUp: Bool
    ) {
        self.session = session
        self.streakResult = streakResult
        self.updatedXP = updatedXP
        self.updatedLevel = updatedLevel
        self.levelTitle = levelTitle
        self.leveledUp = leveledUp
    }
}

/// App Group container snapshot for Home and Lock Screen widgets.
public struct WidgetSnapshot: Codable, Sendable, Equatable {
    public let currentStreak: Int
    public let longestStreak: Int
    public let xp: Int
    public let level: Int
    public let levelTitle: String
    public let streakFreezes: Int
    public let dailyGoalMinutes: Int
    public let dailyGoalVerified: Int
    public let dailyGoalTarget: Int
    public let lastPracticeDay: String?
    public let lastUpdated: Date

    public init(
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        xp: Int = 0,
        level: Int = 1,
        levelTitle: String = "Explorer I",
        streakFreezes: Int = 0,
        dailyGoalMinutes: Int = 10,
        dailyGoalVerified: Int = 0,
        dailyGoalTarget: Int = 3,
        lastPracticeDay: String? = nil,
        lastUpdated: Date = Date()
    ) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.xp = xp
        self.level = level
        self.levelTitle = levelTitle
        self.streakFreezes = streakFreezes
        self.dailyGoalMinutes = dailyGoalMinutes
        self.dailyGoalVerified = dailyGoalVerified
        self.dailyGoalTarget = dailyGoalTarget
        self.lastPracticeDay = lastPracticeDay
        self.lastUpdated = lastUpdated
    }
}
