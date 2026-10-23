import Testing
import Foundation
@testable import SignSpeak

@Suite("Progress, XP, Levels, Streaks and Freezes Tests")
struct ProgressAndStreakTests {

    // MARK: - 1. Streak Edge Cases (StreakEngine)

    @Test("StreakEngine: First day practice initializes streak to 1")
    func streakFirstDay() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_790_812_800) // 1 Oct 2026
        let provider = FixedDateProvider(now: now, calendar: calendar)

        let result = StreakEngine.evaluatePractice(
            currentStreak: 0,
            longestStreak: 0,
            lastPracticeDay: nil,
            streakFreezes: 0,
            dateProvider: provider
        )

        #expect(result.newStreak == 1)
        #expect(result.newLongestStreak == 1)
        #expect(result.newStreakFreezes == 0)
        #expect(result.isNewDay == true)
        #expect(result.freezeUsed == false)
    }

    @Test("StreakEngine: Same-day practice maintains current streak without incrementing")
    func streakSameDay() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_790_812_800)
        let provider = FixedDateProvider(now: now, calendar: calendar)

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: now)

        let result = StreakEngine.evaluatePractice(
            currentStreak: 5,
            longestStreak: 10,
            lastPracticeDay: todayString,
            streakFreezes: 1,
            dateProvider: provider
        )

        #expect(result.newStreak == 5)
        #expect(result.newLongestStreak == 10)
        #expect(result.newStreakFreezes == 1)
        #expect(result.isNewDay == false)
        #expect(result.freezeUsed == false)
    }

    @Test("StreakEngine: Next consecutive day advances streak")
    func streakNextDay() {
        let calendar = Calendar(identifier: .gregorian)
        let day1 = Date(timeIntervalSince1970: 1_790_812_800)
        let day2 = calendar.date(byAdding: .day, value: 1, to: day1)!

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM-dd"
        let day1String = formatter.string(from: day1)

        let provider = FixedDateProvider(now: day2, calendar: calendar)

        let result = StreakEngine.evaluatePractice(
            currentStreak: 4,
            longestStreak: 6,
            lastPracticeDay: day1String,
            streakFreezes: 0,
            dateProvider: provider
        )

        #expect(result.newStreak == 5)
        #expect(result.newLongestStreak == 6)
        #expect(result.isNewDay == true)
        #expect(result.freezeUsed == false)
    }

    @Test("StreakEngine: 7-day milestone earns a streak freeze capped at 2")
    func streakFreezeMilestoneAndCap() {
        let calendar = Calendar(identifier: .gregorian)
        let day6 = Date(timeIntervalSince1970: 1_790_812_800)
        let day7 = calendar.date(byAdding: .day, value: 1, to: day6)!

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM-dd"
        let day6String = formatter.string(from: day6)

        let provider = FixedDateProvider(now: day7, calendar: calendar)

        // Case A: 0 freezes -> earns 1 on Day 7
        let result1 = StreakEngine.evaluatePractice(
            currentStreak: 6,
            longestStreak: 6,
            lastPracticeDay: day6String,
            streakFreezes: 0,
            dateProvider: provider
        )
        #expect(result1.newStreak == 7)
        #expect(result1.newStreakFreezes == 1)
        #expect(result1.earnedFreeze == true)

        // Case B: already at max 2 freezes -> stays capped at 2
        let result2 = StreakEngine.evaluatePractice(
            currentStreak: 13,
            longestStreak: 13,
            lastPracticeDay: day6String,
            streakFreezes: 2,
            dateProvider: provider
        )
        #expect(result2.newStreak == 14)
        #expect(result2.newStreakFreezes == 2)
        #expect(result2.earnedFreeze == false)
    }

    @Test("StreakEngine: Missed 1 day with freeze auto-uses freeze and preserves streak")
    func streakMissedDayWithFreeze() {
        let calendar = Calendar(identifier: .gregorian)
        let day1 = Date(timeIntervalSince1970: 1_790_812_800)
        let day3 = calendar.date(byAdding: .day, value: 2, to: day1)! // Missed day 2!

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM-dd"
        let day1String = formatter.string(from: day1)

        let provider = FixedDateProvider(now: day3, calendar: calendar)

        let result = StreakEngine.evaluatePractice(
            currentStreak: 5,
            longestStreak: 8,
            lastPracticeDay: day1String,
            streakFreezes: 1,
            dateProvider: provider
        )

        #expect(result.newStreak == 6)
        #expect(result.newStreakFreezes == 0) // Used freeze
        #expect(result.freezeUsed == true)
        #expect(result.isNewDay == true)
    }

    @Test("StreakEngine: Missed 1 day without freeze resets streak to 1")
    func streakMissedDayWithoutFreeze() {
        let calendar = Calendar(identifier: .gregorian)
        let day1 = Date(timeIntervalSince1970: 1_790_812_800)
        let day3 = calendar.date(byAdding: .day, value: 2, to: day1)!

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM-dd"
        let day1String = formatter.string(from: day1)

        let provider = FixedDateProvider(now: day3, calendar: calendar)

        let result = StreakEngine.evaluatePractice(
            currentStreak: 5,
            longestStreak: 8,
            lastPracticeDay: day1String,
            streakFreezes: 0,
            dateProvider: provider
        )

        #expect(result.newStreak == 1) // Streak broken!
        #expect(result.newLongestStreak == 8)
        #expect(result.freezeUsed == false)
    }

    @Test("StreakEngine: Midnight transition (23:59 to 00:01) counts as consecutive days")
    func streakMidnightTransition() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!

        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 1
        components.hour = 23
        components.minute = 59
        components.second = 30
        let night = calendar.date(from: components)!

        // 40 seconds later (across midnight)
        let morning = night.addingTimeInterval(40)

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let nightString = formatter.string(from: night)

        let provider = FixedDateProvider(now: morning, calendar: calendar)

        let result = StreakEngine.evaluatePractice(
            currentStreak: 3,
            longestStreak: 5,
            lastPracticeDay: nightString,
            streakFreezes: 0,
            dateProvider: provider
        )

        #expect(result.newStreak == 4)
        #expect(result.isNewDay == true)
        #expect(result.freezeUsed == false)
    }

    @Test("StreakEngine: Time zone change westward is handled safely")
    func streakTimeZoneTravel() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Pacific/Honolulu")!

        let now = Date()
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let todayHawaiian = formatter.string(from: now)

        let provider = FixedDateProvider(now: now, calendar: calendar)

        let result = StreakEngine.evaluatePractice(
            currentStreak: 6,
            longestStreak: 12,
            lastPracticeDay: todayHawaiian,
            streakFreezes: 1,
            dateProvider: provider
        )

        #expect(result.newStreak == 6)
        #expect(result.isNewDay == false)
    }

    // MARK: - 2. XP & Explorer Tiers

    @Test("ExplorerLevel: XP amounts map to correct Explorer tiers and levels")
    func explorerLevelTiers() {
        #expect(ExplorerLevel.level(forXP: 0) == 1)
        #expect(ExplorerLevel.tierTitle(forXP: 0) == "Explorer I")
        #expect(ExplorerLevel.progressFraction(forXP: 50) == 0.50)

        #expect(ExplorerLevel.level(forXP: 100) == 2)
        #expect(ExplorerLevel.tierTitle(forXP: 100) == "Explorer II")

        #expect(ExplorerLevel.level(forXP: 450) == 3)
        #expect(ExplorerLevel.tierTitle(forXP: 450) == "Explorer III")

        #expect(ExplorerLevel.level(forXP: 750) == 4)
        #expect(ExplorerLevel.tierTitle(forXP: 750) == "Pathfinder I")

        #expect(ExplorerLevel.level(forXP: 1200) == 5)
        #expect(ExplorerLevel.tierTitle(forXP: 1200) == "Pathfinder II")

        #expect(ExplorerLevel.level(forXP: 1600) == 6)
        #expect(ExplorerLevel.tierTitle(forXP: 1600) == "Pioneer")

        #expect(ExplorerLevel.level(forXP: 2500) == 7)
        #expect(ExplorerLevel.tierTitle(forXP: 2500) == "Navigator")

        #expect(ExplorerLevel.level(forXP: 3500) == 8)
        #expect(ExplorerLevel.tierTitle(forXP: 3500) == "Master Explorer")
        #expect(ExplorerLevel.progressFraction(forXP: 5000) == 1.0)
    }

    // MARK: - 3. Mastery Rules

    @Test("SignProgress: Mastery requires >= 5 correct attempts and >= 75% accuracy")
    func signMasteryRules() {
        var progress = SignProgress(signId: "sign-letter-a")

        // 1 to 4 attempts, all correct -> Not mastered yet (needs 5 correct)
        for _ in 1...4 {
            progress.applyAttempt(isCorrect: true)
            #expect(progress.isMastered == false)
        }

        // 5 attempts, 5 correct -> Mastered! (100% >= 75%)
        progress.applyAttempt(isCorrect: true)
        #expect(progress.isMastered == true)

        // Reset with high error rate
        var unmastered = SignProgress(signId: "sign-letter-b")
        unmastered.applyAttempt(isCorrect: true)
        unmastered.applyAttempt(isCorrect: false)
        unmastered.applyAttempt(isCorrect: true)
        unmastered.applyAttempt(isCorrect: false)
        // 2 correct out of 4 attempts (50%) -> Not mastered
        #expect(unmastered.isMastered == false)

        // 5th attempt correct -> 3 correct out of 5 (60%) -> Still not mastered (needs 5 correct)
        unmastered.applyAttempt(isCorrect: true)
        #expect(unmastered.isMastered == false)

        // 6th attempt correct -> 4 correct out of 6 (66.7%) -> Not mastered (needs 5 correct)
        unmastered.applyAttempt(isCorrect: true)
        #expect(unmastered.isMastered == false)

        // 7th attempt correct -> 5 correct out of 7 (71.4%) -> Not mastered (< 75% accuracy)
        unmastered.applyAttempt(isCorrect: true)
        #expect(unmastered.isMastered == false)

        // 8th attempt correct -> 6 correct out of 8 (75%) -> Mastered! (6 correct >= 5 and 75% >= 75%)
        unmastered.applyAttempt(isCorrect: true)
        #expect(unmastered.isMastered == true)
    }

    // MARK: - 4. Session Recording, Public Profile & Widget Snapshot Sync

    @Test("ProgressRepository: Recording a session synchronizes profile, streak, and widget snapshot")
    func recordSessionSynchronizesAll() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_790_812_800)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM-dd"
        let yesterdayString = formatter.string(from: yesterday)

        let dateProvider = FixedDateProvider(now: now, calendar: calendar)
        let userRepo = StubUserProfileRepository(initialProfiles: [
            UserProfile(
                id: "user-abc",
                displayName: "Jordan Lee",
                currentStreak: 3,
                xp: 80,
                level: 1,
                longestStreak: 3,
                lastPracticeDay: yesterdayString
            )
        ])
        let publicRepo = StubPublicProfileRepository()
        let widgetDefaults = UserDefaults(suiteName: "test-widget-\(UUID().uuidString)")!
        let widgetManager = WidgetSnapshotManager(defaults: widgetDefaults)

        let progressRepo = StubProgressRepository(
            userProfileRepository: userRepo,
            publicProfileRepository: publicRepo,
            dateProvider: dateProvider,
            widgetSnapshotManager: widgetManager
        )

        let session = LearningSession(
            durationSeconds: 180,
            kind: "lesson",
            attempts: 5,
            correct: 5,
            signIds: ["sign-letter-a", "sign-letter-b"],
            xpEarned: 50 // 80 + 50 = 130 XP -> graduates to Level 2!
        )

        let result = try await progressRepo.recordSession(userId: "user-abc", session: session)

        #expect(result.updatedXP == 130)
        #expect(result.updatedLevel == 2)
        #expect(result.levelTitle == "Explorer II")
        #expect(result.leveledUp == true)
        #expect(result.streakResult.newStreak == 4)

        // 1. Verify UserProfile was updated in repo
        let updatedProfile = try await userRepo.fetchProfile(userId: "user-abc")
        #expect(updatedProfile?.xp == 130)
        #expect(updatedProfile?.level == 2)
        #expect(updatedProfile?.currentStreak == 4)

        // 2. Verify PublicProfile was synced
        let syncedPublic = try await publicRepo.fetchPublicProfile(userId: "user-abc")
        #expect(syncedPublic?.level == 2)
        #expect(syncedPublic?.currentStreak == 4)

        // 3. Verify Widget Snapshot was saved
        let snapshot = widgetManager.fetchSnapshot()
        #expect(snapshot != nil)
        #expect(snapshot?.xp == 130)
        #expect(snapshot?.level == 2)
        #expect(snapshot?.levelTitle == "Explorer II")
        #expect(snapshot?.currentStreak == 4)
    }

    // MARK: - 5. Offline Persistence Verification

    @Test("ProgressRepository: Offline persistence guarantees safe data retrieval without network")
    func offlinePersistenceFallback() async throws {
        let repo = StubProgressRepository()

        // Record attempts offline
        try await repo.recordAttempt(userId: "offline-user", signId: "sign-letter-c", isCorrect: true)
        try await repo.recordAttempt(userId: "offline-user", signId: "sign-letter-d", isCorrect: false, detectedAs: "E")

        let progress = try await repo.fetchProgress(userId: "offline-user")
        #expect(progress.count == 2)

        let mistakes = try await repo.fetchMistakes(userId: "offline-user")
        #expect(mistakes.count == 1)
        #expect(mistakes.first?.signId == "sign-letter-d")
        #expect(mistakes.first?.lastDetectedAs == "E")
    }
}
