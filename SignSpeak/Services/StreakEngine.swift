import Foundation

/// Pure deterministic streak calculation engine supporting streak freezes and timezone transitions.
/// Adheres to requirement: "streak updates with DateProviding and the user's calendar,
/// streak freezes (earn one per 7-day streak, max 2, auto-used on a missed day)".
public struct StreakEngine: Sendable {

    /// Evaluates streak increment, milestone freeze rewards, and automatic freeze consumption upon session completion.
    public static func evaluatePractice(
        currentStreak: Int,
        longestStreak: Int,
        lastPracticeDay: String?,
        streakFreezes: Int,
        dateProvider: any DateProviding
    ) -> StreakUpdateResult {
        let calendar = dateProvider.calendar
        let today = dateProvider.now

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: today)

        guard let lastPracticeDay, !lastPracticeDay.isEmpty else {
            // First recorded practice
            return StreakUpdateResult(
                newStreak: 1,
                newLongestStreak: max(longestStreak, 1),
                newStreakFreezes: streakFreezes,
                lastPracticeDay: todayString,
                freezeUsed: false,
                earnedFreeze: false,
                isNewDay: true
            )
        }

        // Case 1: Same day practice
        if lastPracticeDay == todayString {
            return StreakUpdateResult(
                newStreak: currentStreak,
                newLongestStreak: longestStreak,
                newStreakFreezes: streakFreezes,
                lastPracticeDay: todayString,
                freezeUsed: false,
                earnedFreeze: false,
                isNewDay: false
            )
        }

        // Parse previous practice date
        guard let lastDate = formatter.date(from: lastPracticeDay) else {
            return StreakUpdateResult(
                newStreak: 1,
                newLongestStreak: max(longestStreak, 1),
                newStreakFreezes: streakFreezes,
                lastPracticeDay: todayString,
                freezeUsed: false,
                earnedFreeze: false,
                isNewDay: true
            )
        }

        let startOfToday = calendar.startOfDay(for: today)
        let startOfLastDay = calendar.startOfDay(for: lastDate)
        let daysBetween = calendar.dateComponents([.day], from: startOfLastDay, to: startOfToday).day ?? 0

        // Clock skew / western timezone change across date line
        if daysBetween <= 0 {
            return StreakUpdateResult(
                newStreak: currentStreak,
                newLongestStreak: longestStreak,
                newStreakFreezes: streakFreezes,
                lastPracticeDay: todayString,
                freezeUsed: false,
                earnedFreeze: false,
                isNewDay: false
            )
        }

        // Case 2: Consecutive next day (daysBetween == 1)
        if daysBetween == 1 {
            let nextStreak = currentStreak + 1
            var updatedFreezes = streakFreezes
            var earned = false

            // Earn one freeze per 7-day streak milestone, max 2
            if nextStreak > 0 && nextStreak % 7 == 0 {
                if updatedFreezes < 2 {
                    updatedFreezes += 1
                    earned = true
                }
            }

            return StreakUpdateResult(
                newStreak: nextStreak,
                newLongestStreak: max(longestStreak, nextStreak),
                newStreakFreezes: updatedFreezes,
                lastPracticeDay: todayString,
                freezeUsed: false,
                earnedFreeze: earned,
                isNewDay: true
            )
        }

        // Case 3: Missed 1 day (daysBetween == 2)
        if daysBetween == 2 {
            if streakFreezes > 0 {
                // Auto-use 1 streak freeze to protect streak
                var updatedFreezes = streakFreezes - 1
                let nextStreak = currentStreak + 1
                var earned = false

                if nextStreak > 0 && nextStreak % 7 == 0 {
                    if updatedFreezes < 2 {
                        updatedFreezes += 1
                        earned = true
                    }
                }

                return StreakUpdateResult(
                    newStreak: nextStreak,
                    newLongestStreak: max(longestStreak, nextStreak),
                    newStreakFreezes: updatedFreezes,
                    lastPracticeDay: todayString,
                    freezeUsed: true,
                    earnedFreeze: earned,
                    isNewDay: true
                )
            } else {
                // No freezes available -> Streak breaks
                return StreakUpdateResult(
                    newStreak: 1,
                    newLongestStreak: max(longestStreak, 1),
                    newStreakFreezes: streakFreezes,
                    lastPracticeDay: todayString,
                    freezeUsed: false,
                    earnedFreeze: false,
                    isNewDay: true
                )
            }
        }

        // Case 4: Missed 2 days (daysBetween == 3)
        if daysBetween == 3 && streakFreezes >= 2 {
            // Auto-use both freezes to protect streak
            var updatedFreezes = streakFreezes - 2
            let nextStreak = currentStreak + 1
            var earned = false

            if nextStreak > 0 && nextStreak % 7 == 0 {
                if updatedFreezes < 2 {
                    updatedFreezes += 1
                    earned = true
                }
            }

            return StreakUpdateResult(
                newStreak: nextStreak,
                newLongestStreak: max(longestStreak, nextStreak),
                newStreakFreezes: updatedFreezes,
                lastPracticeDay: todayString,
                freezeUsed: true,
                earnedFreeze: earned,
                isNewDay: true
            )
        }

        // Case 5: Missed more days than available freezes -> Reset streak to 1
        return StreakUpdateResult(
            newStreak: 1,
            newLongestStreak: max(longestStreak, 1),
            newStreakFreezes: streakFreezes,
            lastPracticeDay: todayString,
            freezeUsed: false,
            earnedFreeze: false,
            isNewDay: true
        )
    }

    /// Evaluates whether the user's streak is currently active, protected by a freeze, or broken before practicing today.
    public static func inspectStatus(
        currentStreak: Int,
        lastPracticeDay: String?,
        streakFreezes: Int,
        dateProvider: any DateProviding
    ) -> (activeStreak: Int, freezesRemaining: Int, freezeUsed: Bool, isBroken: Bool) {
        guard let lastPracticeDay, !lastPracticeDay.isEmpty else {
            return (activeStreak: currentStreak, freezesRemaining: streakFreezes, freezeUsed: false, isBroken: false)
        }

        let calendar = dateProvider.calendar
        let today = dateProvider.now

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"

        guard let lastDate = formatter.date(from: lastPracticeDay) else {
            return (activeStreak: currentStreak, freezesRemaining: streakFreezes, freezeUsed: false, isBroken: false)
        }

        let startOfToday = calendar.startOfDay(for: today)
        let startOfLastDay = calendar.startOfDay(for: lastDate)
        let daysBetween = calendar.dateComponents([.day], from: startOfLastDay, to: startOfToday).day ?? 0

        if daysBetween <= 1 {
            // Practiced today or yesterday -> perfectly active
            return (activeStreak: currentStreak, freezesRemaining: streakFreezes, freezeUsed: false, isBroken: false)
        } else if daysBetween == 2 {
            // Missed yesterday
            if streakFreezes > 0 {
                return (activeStreak: currentStreak, freezesRemaining: streakFreezes - 1, freezeUsed: true, isBroken: false)
            } else {
                return (activeStreak: 0, freezesRemaining: 0, freezeUsed: false, isBroken: true)
            }
        } else if daysBetween == 3 {
            // Missed 2 days
            if streakFreezes >= 2 {
                return (activeStreak: currentStreak, freezesRemaining: streakFreezes - 2, freezeUsed: true, isBroken: false)
            } else {
                return (activeStreak: 0, freezesRemaining: streakFreezes, freezeUsed: false, isBroken: true)
            }
        } else {
            // Missed > 2 days
            return (activeStreak: 0, freezesRemaining: streakFreezes, freezeUsed: false, isBroken: true)
        }
    }
}
