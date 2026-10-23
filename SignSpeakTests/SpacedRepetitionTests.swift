import Testing
import Foundation
@testable import SignSpeak

@MainActor
struct SpacedRepetitionTests {

    private let baseDate = Date(timeIntervalSince1970: 1_790_812_800) // Fixed reference time

    // MARK: - 1. SM-2 Algorithm Unit Tests

    @Test("First successful review sets interval to 1 day and increments repetition")
    func firstSuccessfulReview() {
        let initial = FavouriteRecord(
            signId: "sign-hello",
            savedAt: baseDate,
            intervalDays: 1,
            easeFactor: 2.5,
            repetitions: 0,
            nextDueDate: baseDate
        )

        let updated = SpacedRepetitionScheduler.evaluate(current: initial, quality: 5, reviewDate: baseDate)

        #expect(updated.repetitions == 1)
        #expect(updated.intervalDays == 1)
        #expect(updated.easeFactor == 2.6) // 2.5 + (0.1 - 0) = 2.6
        #expect(updated.nextDueDate == Calendar.current.date(byAdding: .day, value: 1, to: baseDate))
        #expect(updated.lastQuality == 5)
    }

    @Test("Second successful review sets interval to 6 days")
    func secondSuccessfulReview() {
        let current = FavouriteRecord(
            signId: "sign-hello",
            savedAt: baseDate,
            intervalDays: 1,
            easeFactor: 2.6,
            repetitions: 1,
            nextDueDate: baseDate
        )

        let updated = SpacedRepetitionScheduler.evaluate(current: current, quality: 4, reviewDate: baseDate)

        #expect(updated.repetitions == 2)
        #expect(updated.intervalDays == 6)
        #expect(updated.nextDueDate == Calendar.current.date(byAdding: .day, value: 6, to: baseDate))
    }

    @Test("Third successful review multiplies interval by ease factor")
    func thirdSuccessfulReviewMultiplication() {
        let current = FavouriteRecord(
            signId: "sign-hello",
            savedAt: baseDate,
            intervalDays: 6,
            easeFactor: 2.5,
            repetitions: 2,
            nextDueDate: baseDate
        )

        let updated = SpacedRepetitionScheduler.evaluate(current: current, quality: 4, reviewDate: baseDate)

        #expect(updated.repetitions == 3)
        // 6 * 2.5 = 15 days
        #expect(updated.intervalDays == 15)
        #expect(updated.nextDueDate == Calendar.current.date(byAdding: .day, value: 15, to: baseDate))
    }

    @Test("Failed review resets interval to 1 day and repetitions to 0")
    func failedReviewReset() {
        let current = FavouriteRecord(
            signId: "sign-hello",
            savedAt: baseDate,
            intervalDays: 15,
            easeFactor: 2.5,
            repetitions: 4,
            nextDueDate: baseDate
        )

        // Quality < 3 is a failure
        let updated = SpacedRepetitionScheduler.evaluate(current: current, quality: 2, reviewDate: baseDate)

        #expect(updated.repetitions == 0)
        #expect(updated.intervalDays == 1)
        #expect(updated.easeFactor == 2.3) // 2.5 - 0.2
        #expect(updated.nextDueDate == Calendar.current.date(byAdding: .day, value: 1, to: baseDate))
        #expect(updated.lastQuality == 2)
    }

    @Test("Ease factor never drops below minimum threshold of 1.3")
    func easeFactorMinimumClamp() {
        let current = FavouriteRecord(
            signId: "sign-hello",
            savedAt: baseDate,
            intervalDays: 1,
            easeFactor: 1.35,
            repetitions: 0,
            nextDueDate: baseDate
        )

        let updated = SpacedRepetitionScheduler.evaluate(current: current, quality: 1, reviewDate: baseDate)

        #expect(updated.easeFactor == 1.3) // Clamped at 1.3 instead of 1.15
        #expect(updated.intervalDays == 1)
        #expect(updated.repetitions == 0)
    }

    // MARK: - 2. Due Date Evaluation Tests

    @Test("isDue correctly evaluates overdue, due today, and future dates")
    func dueEvaluation() {
        let overdueRecord = FavouriteRecord(
            signId: "s1",
            nextDueDate: baseDate.addingTimeInterval(-86400 * 2)
        )
        let dueTodayRecord = FavouriteRecord(
            signId: "s2",
            nextDueDate: baseDate
        )
        let futureRecord = FavouriteRecord(
            signId: "s3",
            nextDueDate: baseDate.addingTimeInterval(86400 * 3)
        )

        #expect(SpacedRepetitionScheduler.isDue(record: overdueRecord, asOf: baseDate) == true)
        #expect(SpacedRepetitionScheduler.isDue(record: dueTodayRecord, asOf: baseDate) == true)
        #expect(SpacedRepetitionScheduler.isDue(record: futureRecord, asOf: baseDate) == false)

        #expect(SpacedRepetitionScheduler.dueStatus(record: overdueRecord, asOf: baseDate).contains("Overdue"))
        #expect(SpacedRepetitionScheduler.dueStatus(record: dueTodayRecord, asOf: baseDate) == "Due today")
        #expect(SpacedRepetitionScheduler.dueStatus(record: futureRecord, asOf: baseDate).contains("Due in"))
    }

    @Test("Quality score derivation from practice accuracy")
    func qualityScoreDerivation() {
        #expect(SpacedRepetitionScheduler.qualityScore(isCorrect: true, firstTry: true, confidence: 0.95) == 5)
        #expect(SpacedRepetitionScheduler.qualityScore(isCorrect: true, firstTry: true, confidence: 0.75) == 4)
        #expect(SpacedRepetitionScheduler.qualityScore(isCorrect: true, firstTry: false) == 3)
        #expect(SpacedRepetitionScheduler.qualityScore(isCorrect: false, attempts: 1) == 2)
        #expect(SpacedRepetitionScheduler.qualityScore(isCorrect: false, attempts: 3) == 1)
    }

    // MARK: - 3. FavouritesViewModel Tests

    @Test("FavouritesViewModel loads, groups and counts due signs")
    func viewModelLoadingAndDueCounts() async {
        let sign1 = Sign(
            id: "s1",
            name: "Hello",
            category: "greetings",
            level: .beginner,
            recognition: .motionSign,
            description: "Hello",
            howToSteps: []
        )
        let sign2 = Sign(
            id: "s2",
            name: "A",
            category: "alphabet",
            level: .beginner,
            recognition: .staticSign,
            description: "Letter A",
            howToSteps: []
        )

        let catalog = StubSignCatalogService(payload: SignCatalogPayload(signs: [sign1, sign2]))

        let repo = StubFavouritesRepository(initialStore: [
            "test-user": [
                "s1": FavouriteRecord(signId: "s1", nextDueDate: baseDate), // Due today
                "s2": FavouriteRecord(signId: "s2", nextDueDate: baseDate.addingTimeInterval(86400 * 5)) // In 5 days
            ]
        ])

        let vm = FavouritesViewModel(
            favouritesRepository: repo,
            signCatalogService: catalog,
            userId: "test-user",
            nowProvider: { [baseDate] in baseDate }
        )

        await vm.load()

        #expect(vm.totalCount == 2)
        #expect(vm.dueCount == 1)

        // Tab: All
        vm.selectedTab = .all
        #expect(vm.filteredItems.count == 2)

        // Tab: Due
        vm.selectedTab = .due
        #expect(vm.filteredItems.count == 1)
        #expect(vm.filteredItems.first?.sign.id == "s1")

        // Tab: Alphabet
        vm.selectedTab = .alphabet
        #expect(vm.filteredItems.count == 1)
        #expect(vm.filteredItems.first?.sign.id == "s2")

        // Tab: Words
        vm.selectedTab = .words
        #expect(vm.filteredItems.count == 1)
        #expect(vm.filteredItems.first?.sign.id == "s1")
    }

    @Test("Sorting by due date and alphabetical orders items accurately")
    func viewModelSorting() async {
        let signA = Sign(id: "sa", name: "Apple", category: "food", level: .beginner, recognition: .none, description: "A", howToSteps: [])
        let signZ = Sign(id: "sz", name: "Zebra", category: "animals", level: .beginner, recognition: .none, description: "Z", howToSteps: [])

        let catalog = StubSignCatalogService(payload: SignCatalogPayload(signs: [signA, signZ]))

        let repo = StubFavouritesRepository(initialStore: [
            "u1": [
                "sa": FavouriteRecord(signId: "sa", intervalDays: 10, nextDueDate: baseDate.addingTimeInterval(86400 * 10)),
                "sz": FavouriteRecord(signId: "sz", intervalDays: 2, nextDueDate: baseDate.addingTimeInterval(86400 * 1))
            ]
        ])

        let vm = FavouritesViewModel(
            favouritesRepository: repo,
            signCatalogService: catalog,
            userId: "u1",
            nowProvider: { [baseDate] in baseDate }
        )
        await vm.load()

        // 1. Due earliest
        vm.selectedSort = .dueEarliest
        #expect(vm.filteredItems.first?.sign.id == "sz")

        // 2. Alphabetical
        vm.selectedSort = .alphabetical
        #expect(vm.filteredItems.first?.sign.id == "sa")

        // 3. Highest interval
        vm.selectedSort = .highestInterval
        #expect(vm.filteredItems.first?.sign.id == "sa")
    }

    @Test("Session preparation filters due signs and updates SRS records on practice review")
    func sessionPreparationAndReviewRecording() async {
        let sign1 = Sign(id: "s1", name: "Hello", category: "greetings", level: .beginner, recognition: .staticSign, description: "", howToSteps: [])
        let sign2 = Sign(id: "s2", name: "World", category: "greetings", level: .beginner, recognition: .staticSign, description: "", howToSteps: [])

        let catalog = StubSignCatalogService(payload: SignCatalogPayload(signs: [sign1, sign2]))
        let repo = StubFavouritesRepository(initialStore: [
            "u1": [
                "s1": FavouriteRecord(signId: "s1", intervalDays: 1, repetitions: 0, nextDueDate: baseDate), // Due
                "s2": FavouriteRecord(signId: "s2", intervalDays: 6, repetitions: 1, nextDueDate: baseDate.addingTimeInterval(86400 * 5)) // Not due
            ]
        ])

        let vm = FavouritesViewModel(
            favouritesRepository: repo,
            signCatalogService: catalog,
            userId: "u1",
            nowProvider: { [baseDate] in baseDate }
        )
        await vm.load()

        // Prepare due session
        vm.prepareDueReviewSession()
        #expect(vm.sessionSigns.count == 1)
        #expect(vm.sessionSigns.first?.id == "s1")
        #expect(vm.isPresentingSession == true)

        // Record a quality 5 review
        await vm.recordPracticeReview(sign: sign1, quality: 5)
        let updatedRecord = vm.records["s1"]
        #expect(updatedRecord?.repetitions == 1)
        #expect(updatedRecord?.nextDueDate == Calendar.current.date(byAdding: .day, value: 1, to: baseDate))

        // Remove favourite
        await vm.removeFavourite(signId: "s2")
        #expect(vm.records["s2"] == nil)
        #expect(vm.totalCount == 1)
    }

    // MARK: - 4. Codable Schema Compatibility

    @Test("FavouriteRecord supports alternative Firestore keys srsInterval and dueAt")
    func codableCompatibility() throws {
        let json = """
        {
            "signId": "sign-test",
            "addedAt": 1700000000,
            "srsInterval": 6,
            "srsEase": 2.6,
            "repetitions": 2,
            "dueAt": 1700518400
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(FavouriteRecord.self, from: json)

        #expect(decoded.signId == "sign-test")
        #expect(decoded.intervalDays == 6)
        #expect(decoded.easeFactor == 2.6)
        #expect(decoded.repetitions == 2)
    }

    // MARK: - 5. Multi-Step Review Sequence & Lapse Recovery (Step 6.4)

    @Test("Multi-step review sequence accurately models retention growth and lapse recovery")
    func multiStepReviewSequenceAndLapseRecovery() {
        var record = FavouriteRecord(signId: "test-sign", savedAt: baseDate)
        var currentDate = baseDate

        // Review 1: quality 5 -> interval 1 day
        record = SpacedRepetitionScheduler.evaluate(current: record, quality: 5, reviewDate: currentDate)
        #expect(record.repetitions == 1)
        #expect(record.intervalDays == 1)

        // Advance date by 1 day
        currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!

        // Review 2: quality 4 -> interval 6 days
        record = SpacedRepetitionScheduler.evaluate(current: record, quality: 4, reviewDate: currentDate)
        #expect(record.repetitions == 2)
        #expect(record.intervalDays == 6)

        // Advance date by 6 days
        currentDate = Calendar.current.date(byAdding: .day, value: 6, to: currentDate)!

        // Review 3: quality 4 -> interval ~16 days (6 * 2.6 = 15.6 -> 16)
        record = SpacedRepetitionScheduler.evaluate(current: record, quality: 4, reviewDate: currentDate)
        #expect(record.repetitions == 3)
        #expect(record.intervalDays >= 15)

        // Advance date to when it's due
        currentDate = Calendar.current.date(byAdding: .day, value: record.intervalDays, to: currentDate)!

        // Review 4: LAPSE! User misses the sign (quality 1)
        record = SpacedRepetitionScheduler.evaluate(current: record, quality: 1, reviewDate: currentDate)
        #expect(record.repetitions == 0) // Repetitions reset to 0
        #expect(record.intervalDays == 1) // Interval drops back to 1 day
        #expect(record.easeFactor < 2.6) // Ease factor is penalized

        // Advance 1 day
        currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!

        // Review 5: Recovery! Quality 5
        record = SpacedRepetitionScheduler.evaluate(current: record, quality: 5, reviewDate: currentDate)
        #expect(record.repetitions == 1) // Restarts streak
        #expect(record.intervalDays == 1)
    }
}
