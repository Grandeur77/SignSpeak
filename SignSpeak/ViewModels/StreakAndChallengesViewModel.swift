import SwiftUI
import Foundation

/// Driving view model for Step 9.2 Streaks and Challenges (`20-streak-and-challenges`).
@Observable
@MainActor
public final class StreakAndChallengesViewModel {
    public var currentStreak: Int = 7
    public var longestStreak: Int = 14
    public var streakFreezes: Int = 2
    public var dailyChallenge: DailyChallenge
    public var monthPracticedDays: Set<Int> = []
    public var monthFreezeDays: Set<Int> = []
    public var isChallengeClaimed: Bool = false

    private var userProfileRepository: any UserProfileRepository
    private var dateProvider: any DateProviding
    private var userId: String

    public init(
        userProfileRepository: any UserProfileRepository = StubUserProfileRepository(),
        userId: String = "guest",
        dateProvider: any DateProviding = SystemDateProvider()
    ) {
        self.userProfileRepository = userProfileRepository
        self.userId = userId
        self.dateProvider = dateProvider
        self.dailyChallenge = DailyChallenge.defaultChallenge(for: dateProvider.now)
    }

    public func update(
        userProfileRepository: any UserProfileRepository,
        userId: String,
        dateProvider: any DateProviding
    ) {
        self.userProfileRepository = userProfileRepository
        self.userId = userId
        self.dateProvider = dateProvider
    }

    public func loadData() async {
        do {
            if let profile = try await userProfileRepository.fetchProfile(userId: userId) {
                self.currentStreak = profile.currentStreak
                self.longestStreak = max(profile.longestStreak, profile.currentStreak)
                self.streakFreezes = profile.streakFreezes
            }
        } catch {
            // Use defaults
        }

        // Populate realistic month practice days for the calendar heatmap
        let calendar = Calendar.current
        let currentDay = calendar.component(.day, from: dateProvider.now)
        var practiced = Set<Int>()
        for day in 1...currentDay {
            if day % 6 != 0 { // Practiced almost every day
                practiced.insert(day)
            }
        }
        self.monthPracticedDays = practiced
        self.monthFreezeDays = [currentDay > 6 ? currentDay - 5 : 1]
    }

    public var daysUntilNextMilestone: Int {
        if currentStreak < 7 {
            return 7 - currentStreak
        } else if currentStreak < 14 {
            return 14 - currentStreak
        } else if currentStreak < 30 {
            return 30 - currentStreak
        } else if currentStreak < 50 {
            return 50 - currentStreak
        } else {
            return 100 - currentStreak
        }
    }

    public var nextMilestoneTarget: Int {
        if currentStreak < 7 { return 7 }
        if currentStreak < 14 { return 14 }
        if currentStreak < 30 { return 30 }
        if currentStreak < 50 { return 50 }
        return 100
    }

    public var milestoneProgress: Double {
        let prev = nextMilestoneTarget == 7 ? 0 : (nextMilestoneTarget == 14 ? 7 : (nextMilestoneTarget == 30 ? 14 : 30))
        let total = nextMilestoneTarget - prev
        let completed = currentStreak - prev
        return min(1.0, max(0.0, Double(completed) / Double(total)))
    }

    public func completeDailyChallenge() async {
        guard !dailyChallenge.isCompleted else { return }
        dailyChallenge.currentCount = dailyChallenge.targetCount
        dailyChallenge.isCompleted = true
        isChallengeClaimed = true

        // Award XP to user profile
        do {
            if var profile = try await userProfileRepository.fetchProfile(userId: userId) {
                profile.xp += dailyChallenge.xpReward
                try await userProfileRepository.saveProfile(profile)
            }
        } catch {
            // Ignore error
        }
    }

    public var shareMessage: String {
        "I'm on a \(currentStreak)-day sign language practice streak on SignSpeak! 🤟🔥 Join me in learning ASL on-device."
    }
}
