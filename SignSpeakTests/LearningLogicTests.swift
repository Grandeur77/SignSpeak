import Foundation
import Testing
@testable import SignSpeak

// MARK: - 1. Streak Edge Cases

@Suite("Learning Logic - Streak Edge Cases")
struct LearningLogicStreakTests {

    @Test("Same-day practice maintains current streak without incrementing")
    func sameDayPracticeMaintainsStreak() {
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

    @Test("Next consecutive day practice increments streak")
    func nextDayPracticeIncrementsStreak() {
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

    @Test("Missed 1 day without freeze resets streak to 1")
    func missedDayWithoutFreezeResetsStreak() {
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
            streakFreezes: 0,
            dateProvider: provider
        )

        #expect(result.newStreak == 1)
        #expect(result.newLongestStreak == 8)
        #expect(result.freezeUsed == false)
        #expect(result.isNewDay == true)
    }

    @Test("Missed 1 day with freeze auto-uses freeze and preserves streak")
    func missedDayWithFreezeProtectsStreakAndConsumesOne() {
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
            streakFreezes: 1,
            dateProvider: provider
        )

        #expect(result.newStreak == 6)
        #expect(result.newStreakFreezes == 0)
        #expect(result.freezeUsed == true)
        #expect(result.isNewDay == true)
    }

    @Test("Missed 2 days with 2 freezes consumes both and preserves streak")
    func missedTwoDaysWithTwoFreezesConsumesBoth() {
        let calendar = Calendar(identifier: .gregorian)
        let day1 = Date(timeIntervalSince1970: 1_790_812_800)
        let day4 = calendar.date(byAdding: .day, value: 3, to: day1)! // Missed day 2 and day 3!

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM-dd"
        let day1String = formatter.string(from: day1)

        let provider = FixedDateProvider(now: day4, calendar: calendar)

        let result = StreakEngine.evaluatePractice(
            currentStreak: 10,
            longestStreak: 10,
            lastPracticeDay: day1String,
            streakFreezes: 2,
            dateProvider: provider
        )

        #expect(result.newStreak == 11)
        #expect(result.newStreakFreezes == 0)
        #expect(result.freezeUsed == true)
    }

    @Test("Missed 2 days with only 1 freeze breaks streak to 1")
    func missedTwoDaysWithSingleFreezeBreaksStreak() {
        let calendar = Calendar(identifier: .gregorian)
        let day1 = Date(timeIntervalSince1970: 1_790_812_800)
        let day4 = calendar.date(byAdding: .day, value: 3, to: day1)!

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM-dd"
        let day1String = formatter.string(from: day1)

        let provider = FixedDateProvider(now: day4, calendar: calendar)

        let result = StreakEngine.evaluatePractice(
            currentStreak: 10,
            longestStreak: 10,
            lastPracticeDay: day1String,
            streakFreezes: 1, // Only 1 freeze for 2 missed days
            dateProvider: provider
        )

        #expect(result.newStreak == 1)
        #expect(result.freezeUsed == false)
    }

    @Test("Missed 3 or more days resets streak regardless of freezes")
    func missedThreeOrMoreDaysResetsStreakRegardlessOfFreezes() {
        let calendar = Calendar(identifier: .gregorian)
        let day1 = Date(timeIntervalSince1970: 1_790_812_800)
        let day5 = calendar.date(byAdding: .day, value: 4, to: day1)!

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM-dd"
        let day1String = formatter.string(from: day1)

        let provider = FixedDateProvider(now: day5, calendar: calendar)

        let result = StreakEngine.evaluatePractice(
            currentStreak: 20,
            longestStreak: 25,
            lastPracticeDay: day1String,
            streakFreezes: 2,
            dateProvider: provider
        )

        #expect(result.newStreak == 1)
        #expect(result.newLongestStreak == 25)
    }

    @Test("Midnight transition (23:59:30 to 00:00:10 next day) advances streak")
    func midnightTransitionIncrementsAcrossDays() {
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

        let morning = night.addingTimeInterval(40) // 00:00:10 next day

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let nightString = formatter.string(from: night)

        let provider = FixedDateProvider(now: morning, calendar: calendar)

        let result = StreakEngine.evaluatePractice(
            currentStreak: 7,
            longestStreak: 7,
            lastPracticeDay: nightString,
            streakFreezes: 0,
            dateProvider: provider
        )

        #expect(result.newStreak == 8)
        #expect(result.isNewDay == true)
        #expect(result.freezeUsed == false)
    }

    @Test("Time-zone travel westward is handled safely without negative days")
    func westwardTimeZoneTravelMaintainsStreak() {
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
            currentStreak: 9,
            longestStreak: 12,
            lastPracticeDay: todayHawaiian,
            streakFreezes: 1,
            dateProvider: provider
        )

        #expect(result.newStreak == 9)
        #expect(result.isNewDay == false)
    }

    @Test("7-day milestone awards a freeze capped at 2")
    func sevenDayMilestoneAwardsFreezeCappedAtTwo() {
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

        // Case B: already at max 2 freezes -> stays at 2 on Day 14
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

    @Test("StreakEngine.inspectStatus accurately reflects status before practice today")
    func inspectStatusReflectsActiveProtectedOrBrokenState() {
        let calendar = Calendar(identifier: .gregorian)
        let day1 = Date(timeIntervalSince1970: 1_790_812_800)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM-dd"
        let day1String = formatter.string(from: day1)

        // Practiced yesterday (day 2 inspecting)
        let day2 = calendar.date(byAdding: .day, value: 1, to: day1)!
        let p2 = FixedDateProvider(now: day2, calendar: calendar)
        let s2 = StreakEngine.inspectStatus(currentStreak: 4, lastPracticeDay: day1String, streakFreezes: 1, dateProvider: p2)
        #expect(s2.activeStreak == 4)
        #expect(s2.freezeUsed == false)
        #expect(s2.isBroken == false)

        // Missed yesterday (day 3 inspecting) with freeze
        let day3 = calendar.date(byAdding: .day, value: 2, to: day1)!
        let p3 = FixedDateProvider(now: day3, calendar: calendar)
        let s3 = StreakEngine.inspectStatus(currentStreak: 4, lastPracticeDay: day1String, streakFreezes: 1, dateProvider: p3)
        #expect(s3.activeStreak == 4)
        #expect(s3.freezesRemaining == 0)
        #expect(s3.freezeUsed == true)
        #expect(s3.isBroken == false)

        // Missed yesterday without freeze
        let s3NoFreeze = StreakEngine.inspectStatus(currentStreak: 4, lastPracticeDay: day1String, streakFreezes: 0, dateProvider: p3)
        #expect(s3NoFreeze.activeStreak == 0)
        #expect(s3NoFreeze.isBroken == true)
    }
}

// MARK: - 2. XP, Levels & Explorer Tiers

@Suite("Learning Logic - XP, Levels & Explorer Tiers")
struct LearningLogicXPTests {

    @Test("ExplorerLevel maps cumulative XP to correct levels and titles across all 8 tiers")
    func explorerTiersProgressionMap() {
        // Tier 1: Explorer I (0 - 99 XP)
        #expect(ExplorerLevel.level(forXP: 0) == 1)
        #expect(ExplorerLevel.tierTitle(forXP: 0) == "Explorer I")
        #expect(ExplorerLevel.level(forXP: 99) == 1)

        // Tier 2: Explorer II (100 - 249 XP)
        #expect(ExplorerLevel.level(forXP: 100) == 2)
        #expect(ExplorerLevel.tierTitle(forXP: 100) == "Explorer II")
        #expect(ExplorerLevel.level(forXP: 249) == 2)

        // Tier 3: Explorer III (250 - 499 XP)
        #expect(ExplorerLevel.level(forXP: 250) == 3)
        #expect(ExplorerLevel.tierTitle(forXP: 250) == "Explorer III")

        // Tier 4: Pathfinder I (500 - 899 XP)
        #expect(ExplorerLevel.level(forXP: 500) == 4)
        #expect(ExplorerLevel.tierTitle(forXP: 500) == "Pathfinder I")

        // Tier 5: Pathfinder II (900 - 1399 XP)
        #expect(ExplorerLevel.level(forXP: 900) == 5)
        #expect(ExplorerLevel.tierTitle(forXP: 900) == "Pathfinder II")

        // Tier 6: Pioneer (1400 - 1999 XP)
        #expect(ExplorerLevel.level(forXP: 1400) == 6)
        #expect(ExplorerLevel.tierTitle(forXP: 1400) == "Pioneer")

        // Tier 7: Navigator (2000 - 2999 XP)
        #expect(ExplorerLevel.level(forXP: 2000) == 7)
        #expect(ExplorerLevel.tierTitle(forXP: 2000) == "Navigator")

        // Tier 8: Master Explorer (3000+ XP)
        #expect(ExplorerLevel.level(forXP: 3000) == 8)
        #expect(ExplorerLevel.tierTitle(forXP: 3000) == "Master Explorer")
        #expect(ExplorerLevel.level(forXP: 10_000) == 8)
    }

    @Test("ExplorerLevel calculates accurate fractional tier progress")
    func progressFractionWithinTier() {
        // In Tier 1 (0 to 100 XP span)
        #expect(ExplorerLevel.progressFraction(forXP: 0) == 0.0)
        #expect(ExplorerLevel.progressFraction(forXP: 50) == 0.50)
        #expect(ExplorerLevel.progressFraction(forXP: 100) == 0.0) // At start of Tier 2

        // In Tier 2 (100 to 250 XP span of 150)
        #expect(ExplorerLevel.progressFraction(forXP: 175) == 0.50)

        // Top Tier (Master Explorer, unbounded) returns 1.0
        #expect(ExplorerLevel.progressFraction(forXP: 3500) == 1.0)
    }

    @Test("ExplorerLevel returns next level threshold target")
    func nextLevelXPBoundary() {
        #expect(ExplorerLevel.nextLevelXP(forXP: 40) == 100)
        #expect(ExplorerLevel.nextLevelXP(forXP: 150) == 250)
        #expect(ExplorerLevel.nextLevelXP(forXP: 450) == 500)
        #expect(ExplorerLevel.nextLevelXP(forXP: 800) == 900)
    }

    @Test("Negative XP clamps safely to Tier 1 Explorer I")
    func negativeXPHandledGracefully() {
        #expect(ExplorerLevel.level(forXP: -50) == 1)
        #expect(ExplorerLevel.tierTitle(forXP: -50) == "Explorer I")
        #expect(ExplorerLevel.progressFraction(forXP: -50) == 0.0)
    }
}

// MARK: - 3. Sign Mastery Rules

@Suite("Learning Logic - Sign Mastery Rules")
struct LearningLogicMasteryTests {

    @Test("SignProgress: Mastery strictly requires >= 5 correct attempts and >= 75% accuracy")
    func masteryRequiresAtLeastFiveCorrectAttemptsAnd75PercentAccuracy() {
        var progress = SignProgress(signId: "sign-letter-test")

        // 1 to 4 correct attempts: high accuracy (100%) but not enough attempts
        for attemptIndex in 1...4 {
            progress.applyAttempt(isCorrect: true)
            #expect(progress.isMastered == false, "Attempt \(attemptIndex) should not unlock mastery yet")
        }

        // 5th correct attempt unlocks mastery
        progress.applyAttempt(isCorrect: true)
        #expect(progress.isMastered == true)
        #expect(progress.attempts == 5)
        #expect(progress.correct == 5)
    }

    @Test("Low accuracy prevents mastery even if 5 correct attempts are achieved")
    func lowAccuracyPreventsMasteryEvenWithFiveCorrect() {
        var progress = SignProgress(signId: "sign-letter-hard")

        // 4 mistakes, 4 correct -> 4/8 = 50%
        progress.applyAttempt(isCorrect: true)
        progress.applyAttempt(isCorrect: false)
        progress.applyAttempt(isCorrect: true)
        progress.applyAttempt(isCorrect: false)
        progress.applyAttempt(isCorrect: true)
        progress.applyAttempt(isCorrect: false)
        progress.applyAttempt(isCorrect: true)
        progress.applyAttempt(isCorrect: false)
        #expect(progress.isMastered == false)

        // 9th attempt correct -> 5 correct out of 9 (55.6% < 75%) -> Still not mastered
        progress.applyAttempt(isCorrect: true)
        #expect(progress.correct == 5)
        #expect(progress.isMastered == false)

        // 10th attempt correct -> 6 correct out of 10 (60% < 75%) -> Still not mastered
        progress.applyAttempt(isCorrect: true)
        #expect(progress.isMastered == false)

        // 11th attempt correct -> 7 correct out of 11 (63.6% < 75%) -> Still not mastered
        progress.applyAttempt(isCorrect: true)
        #expect(progress.isMastered == false)

        // 12th attempt correct -> 8 correct out of 12 (66.7% < 75%) -> Still not mastered
        progress.applyAttempt(isCorrect: true)
        #expect(progress.isMastered == false)

        // 13th attempt correct -> 9 correct out of 13 (69.2% < 75%) -> Still not mastered
        progress.applyAttempt(isCorrect: true)
        #expect(progress.isMastered == false)

        // 14th attempt correct -> 10 correct out of 14 (71.4% < 75%) -> Still not mastered
        progress.applyAttempt(isCorrect: true)
        #expect(progress.isMastered == false)

        // 15th attempt correct -> 11 correct out of 15 (73.3% < 75%) -> Still not mastered
        progress.applyAttempt(isCorrect: true)
        #expect(progress.isMastered == false)

        // 16th attempt correct -> 12 correct out of 16 (75.0% >= 75%) -> Mastered!
        progress.applyAttempt(isCorrect: true)
        #expect(progress.isMastered == true)
    }

    @Test("Attempt logs lastPracticedAt timestamp and detectedAs error label")
    func timestampAndFailureDetectionLogged() {
        var progress = SignProgress(signId: "sign-letter-k")
        let date = Date(timeIntervalSince1970: 1_790_812_800)

        progress.applyAttempt(isCorrect: false, detectedAs: "V", timestamp: date)

        #expect(progress.attempts == 1)
        #expect(progress.correct == 0)
        #expect(progress.lastDetectedAs == "V")
        #expect(progress.lastPracticedAt == date)
        #expect(progress.isMastered == false)
    }

    @Test("ProgressRepository.fetchMistakes returns only unmastered items with past errors")
    func mistakesFilteringExcludesMasteredSigns() async throws {
        let repo = StubProgressRepository(initialStore: [
            "user-1": [
                "sign-1": SignProgress(signId: "sign-1", attempts: 4, correct: 2, isMastered: false), // Mistake!
                "sign-2": SignProgress(signId: "sign-2", attempts: 5, correct: 5, isMastered: true),  // Mastered
                "sign-3": SignProgress(signId: "sign-3", attempts: 2, correct: 2, isMastered: false)  // Perfect so far (no mistakes)
            ]
        ])

        let mistakes = try await repo.fetchMistakes(userId: "user-1")
        #expect(mistakes.count == 1)
        #expect(mistakes.first?.signId == "sign-1")
    }
}

// MARK: - 4. Quiz Scoring & Lives

@Suite("Learning Logic - Quiz Scoring & Lives")
struct LearningLogicQuizTests {

    private func makeSampleSigns() -> [Sign] {
        [
            Sign(id: "sign-letter-a", name: "A", category: "alphabet", recognition: .staticSign, description: "A", howToSteps: ["Make a fist"]),
            Sign(id: "sign-letter-b", name: "B", category: "alphabet", recognition: .staticSign, description: "B", howToSteps: ["Extend 4 fingers"]),
            Sign(id: "sign-letter-c", name: "C", category: "alphabet", recognition: .staticSign, description: "C", howToSteps: ["Curve hand"]),
            Sign(id: "sign-letter-d", name: "D", category: "alphabet", recognition: .staticSign, description: "D", howToSteps: ["Index up"]),
            Sign(id: "sign-hello", name: "Hello", category: "greetings", recognition: .none, description: "Hello", howToSteps: ["Wave hand"])
        ]
    }

    @Test("Quiz starts with 3 lives and score 0")
    func initialBudgetThreeHearts() {
        let signs = makeSampleSigns()
        let questions = [
            QuizQuestion(targetSign: signs[0], mode: .watchAndChoose, options: ["A", "B", "C", "D"], correctAnswer: "A")
        ]

        let engine = QuizEngine(questions: questions, initialLives: 3)
        #expect(engine.lives == 3)
        #expect(engine.score == 0)
        #expect(engine.totalXP == 0)
        #expect(engine.currentStreak == 0)
        #expect(engine.isGameOver == false)
    }

    @Test("Incorrect answer decrements lives and resets streak")
    func incorrectAnswerDecrementsLifeAndResetsStreak() {
        let signs = makeSampleSigns()
        let questions = [
            QuizQuestion(targetSign: signs[0], mode: .watchAndChoose, options: ["A", "B", "C", "D"], correctAnswer: "A")
        ]

        var engine = QuizEngine(questions: questions, initialLives: 3)
        let outcome = engine.answerWatchAndChoose(selectedOption: "Wrong")

        #expect(outcome.isCorrect == false)
        #expect(outcome.livesRemaining == 2)
        #expect(outcome.streak == 0)
        #expect(engine.lives == 2)
    }

    @Test("Losing 3 lives triggers game over")
    func gameOverTriggeredAtZeroLives() {
        let signs = makeSampleSigns()
        let questions = [
            QuizQuestion(targetSign: signs[0], mode: .watchAndChoose, options: ["A", "B", "C", "D"], correctAnswer: "A"),
            QuizQuestion(targetSign: signs[1], mode: .watchAndChoose, options: ["A", "B", "C", "D"], correctAnswer: "B"),
            QuizQuestion(targetSign: signs[2], mode: .watchAndChoose, options: ["A", "B", "C", "D"], correctAnswer: "C")
        ]

        var engine = QuizEngine(questions: questions, initialLives: 3)

        _ = engine.answerWatchAndChoose(selectedOption: "Wrong1")
        #expect(engine.lives == 2)
        #expect(!engine.isGameOver)
        engine.advance()

        _ = engine.answerWatchAndChoose(selectedOption: "Wrong2")
        #expect(engine.lives == 1)
        #expect(!engine.isGameOver)
        engine.advance()

        let r3 = engine.answerWatchAndChoose(selectedOption: "Wrong3")
        #expect(engine.lives == 0)
        #expect(engine.isGameOver)
        #expect(r3.isGameOver)
    }

    @Test("Scoring awards 10 XP base and +5 XP streak bonus for streak >= 3")
    func scoringBaseAndStreakBonus() {
        let signs = makeSampleSigns()
        let questions = [
            QuizQuestion(targetSign: signs[0], mode: .watchAndChoose, options: ["A", "B", "C", "D"], correctAnswer: "A"),
            QuizQuestion(targetSign: signs[1], mode: .watchAndChoose, options: ["A", "B", "C", "D"], correctAnswer: "B"),
            QuizQuestion(targetSign: signs[2], mode: .watchAndChoose, options: ["A", "B", "C", "D"], correctAnswer: "C")
        ]

        var engine = QuizEngine(questions: questions, initialLives: 3)

        // Q1: 10 XP
        let r1 = engine.answerWatchAndChoose(selectedOption: "A")
        #expect(r1.xpEarned == 10)
        #expect(engine.totalXP == 10)
        engine.advance()

        // Q2: 10 XP
        let r2 = engine.answerWatchAndChoose(selectedOption: "B")
        #expect(r2.xpEarned == 10)
        #expect(engine.totalXP == 20)
        engine.advance()

        // Q3: streak is 3 -> 10 + 5 = 15 XP
        let r3 = engine.answerWatchAndChoose(selectedOption: "C")
        #expect(r3.xpEarned == 15)
        #expect(engine.totalXP == 35)
    }

    @Test("Watch and Choose questions always provide 4 distinct options containing the correct answer")
    func watchAndChooseFourOptionsWithCorrectAnswer() {
        let signs = makeSampleSigns()
        let questions = QuizEngine.generateQuestions(from: signs, allCatalogSigns: signs, count: 4, preferredMode: .watchAndChoose)

        for q in questions {
            #expect(q.options.count == 4)
            #expect(Set(q.options).count == 4)
            #expect(q.options.contains(q.correctAnswer))
        }
    }

    @Test("Non-recognizable signs are never placed in Sign It mode")
    func nonRecognizableSignsFallback() {
        let signs = makeSampleSigns()
        let hello = signs.first(where: { $0.id == "sign-hello" })!

        let questions = QuizEngine.generateQuestions(from: [hello], allCatalogSigns: signs, count: 1, preferredMode: .signIt)
        #expect(questions.count == 1)
        #expect(questions[0].mode == .watchAndChoose)
    }
}

// MARK: - 5. Lesson Unlocking Progression

@Suite("Learning Logic - Lesson Unlocking Progression")
struct LearningLogicLessonUnlockingTests {

    private func makeSampleLessons() -> [Lesson] {
        [
            Lesson(
                id: "lesson-1",
                unitId: "unit-alpha",
                title: "Lesson 1: A–E",
                subtitle: "Vowels",
                category: "alphabet",
                signIds: ["sign-a", "sign-b", "sign-c", "sign-d", "sign-e"],
                order: 1
            ),
            Lesson(
                id: "lesson-2",
                unitId: "unit-alpha",
                title: "Lesson 2: F–J",
                subtitle: "Curves",
                category: "alphabet",
                signIds: ["sign-f", "sign-g", "sign-h", "sign-i", "sign-j"],
                order: 2
            ),
            Lesson(
                id: "lesson-3",
                unitId: "unit-alpha",
                title: "Lesson 3: K–O",
                subtitle: "Crossings",
                category: "alphabet",
                signIds: ["sign-k", "sign-l", "sign-m", "sign-n", "sign-o"],
                order: 3
            )
        ]
    }

    @Test("First lesson is always unlocked by default while subsequent lessons are locked")
    func firstLessonAlwaysUnlockedByDefault() {
        let lessons = makeSampleLessons()
        let progress: [String: SignProgress] = [:]

        let summaries = LessonProgressionEngine.evaluate(lessons: lessons, progress: progress)

        #expect(summaries.count == 3)
        #expect(summaries[0].status == .inProgress)
        #expect(summaries[0].isUnlocked == true)
        #expect(summaries[0].masteredCount == 0)

        #expect(summaries[1].status == .locked)
        #expect(summaries[1].isUnlocked == false)

        #expect(summaries[2].status == .locked)
        #expect(summaries[2].isUnlocked == false)
    }

    @Test("Completing Lesson 1 unlocks Lesson 2 and marks Lesson 1 as completed")
    func completingLessonOneUnlocksLessonTwo() {
        let lessons = makeSampleLessons()
        var progress: [String: SignProgress] = [:]

        // Master all 5 signs of Lesson 1
        for id in ["sign-a", "sign-b", "sign-c", "sign-d", "sign-e"] {
            progress[id] = SignProgress(signId: id, attempts: 5, correct: 5, isMastered: true)
        }

        let summaries = LessonProgressionEngine.evaluate(lessons: lessons, progress: progress)

        #expect(summaries[0].status == .completed)
        #expect(summaries[0].progressFraction == 1.0)
        #expect(summaries[0].masteredCount == 5)

        #expect(summaries[1].status == .inProgress)
        #expect(summaries[1].isUnlocked == true)
        #expect(summaries[1].masteredCount == 0)

        #expect(summaries[2].status == .locked)
        #expect(summaries[2].isUnlocked == false)
    }

    @Test("Partial progress in Lesson 1 keeps Lesson 2 locked")
    func partialProgressDoesNotUnlockNextLesson() {
        let lessons = makeSampleLessons()
        var progress: [String: SignProgress] = [:]

        // Master only 4 of 5 signs in Lesson 1
        for id in ["sign-a", "sign-b", "sign-c", "sign-d"] {
            progress[id] = SignProgress(signId: id, attempts: 5, correct: 5, isMastered: true)
        }

        let summaries = LessonProgressionEngine.evaluate(lessons: lessons, progress: progress)

        #expect(summaries[0].status == .inProgress)
        #expect(summaries[0].masteredCount == 4)
        #expect(summaries[0].progressFraction == 0.80)

        #expect(summaries[1].status == .locked)
    }

    @Test("Sequential prerequisites prevent unlocking downstream lessons if an earlier lesson is incomplete")
    func sequentialLockingPreventsSkipping() {
        let lessons = makeSampleLessons()
        var progress: [String: SignProgress] = [:]

        // Master Lesson 3 signs out of order, but Lesson 1 and 2 are incomplete!
        for id in ["sign-k", "sign-l", "sign-m", "sign-n", "sign-o"] {
            progress[id] = SignProgress(signId: id, attempts: 5, correct: 5, isMastered: true)
        }

        let summaries = LessonProgressionEngine.evaluate(lessons: lessons, progress: progress)

        // Lesson 1 is in progress (first lesson)
        #expect(summaries[0].status == .inProgress)
        // Lesson 2 is locked (Lesson 1 is not completed)
        #expect(summaries[1].status == .locked)
        // Lesson 3 is locked (Preceding lessons not completed)
        #expect(summaries[2].status == .locked)
    }

    @Test("Progressing through all lessons marks all as completed and fully unlocked")
    func fullCurriculumProgressionUnlocksAllLessons() {
        let lessons = makeSampleLessons()
        var progress: [String: SignProgress] = [:]

        let allSigns = ["sign-a", "sign-b", "sign-c", "sign-d", "sign-e",
                        "sign-f", "sign-g", "sign-h", "sign-i", "sign-j",
                        "sign-k", "sign-l", "sign-m", "sign-n", "sign-o"]

        for id in allSigns {
            progress[id] = SignProgress(signId: id, attempts: 5, correct: 5, isMastered: true)
        }

        let summaries = LessonProgressionEngine.evaluate(lessons: lessons, progress: progress)

        for summary in summaries {
            #expect(summary.status == .completed)
            #expect(summary.isUnlocked == true)
            #expect(summary.progressFraction == 1.0)
        }
    }

    @Test("LessonProgressionEngine.summary lookup finds matching summary for a lesson ID")
    func summaryLookupFindsSpecificLesson() {
        let lessons = makeSampleLessons()
        var progress: [String: SignProgress] = [:]

        for id in ["sign-a", "sign-b", "sign-c", "sign-d", "sign-e"] {
            progress[id] = SignProgress(signId: id, attempts: 5, correct: 5, isMastered: true)
        }

        let l2Summary = LessonProgressionEngine.summary(forLesson: "lesson-2", in: lessons, progress: progress)
        #expect(l2Summary != nil)
        #expect(l2Summary?.lessonId == "lesson-2")
        #expect(l2Summary?.status == .inProgress)
        #expect(l2Summary?.isUnlocked == true)
    }
}
