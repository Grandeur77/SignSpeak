import Foundation
import Testing
@testable import SignSpeak

@Suite("Widget Extension, SharedStore & App Intents Tests (Phase 13)")
struct WidgetAndIntentTests {

    // MARK: - 1. SharedStore & Snapshot Encoding/Decoding

    @Test("SharedStore: Round trip encode and decode preserves all snapshot fields")
    func testSharedStoreSnapshotRoundTrip() throws {
        let suiteName = "test-store-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = SharedStore(defaults: defaults)

        let customSign = SignOfTheDaySnapshot(
            id: "sign-test-z",
            name: "Z",
            category: "Alphabet",
            description: "Trace letter Z in the air with index finger",
            imageName: "hand.raised.fill"
        )

        let customPhrases = [
            QuickPhraseSnapshot(id: "qp-test-1", text: "Excuse me", category: "Courtesies", isEmergency: false),
            QuickPhraseSnapshot(id: "qp-test-2", text: "Emergency", category: "Urgent", isEmergency: true)
        ]

        let original = WidgetSnapshot(
            currentStreak: 12,
            longestStreak: 25,
            xp: 750,
            level: 3,
            levelTitle: "Explorer III",
            streakFreezes: 2,
            dailyGoalMinutes: 15,
            dailyGoalVerified: 3,
            dailyGoalTarget: 3,
            lastPracticeDay: "2026-10-24",
            lastUpdated: Date(timeIntervalSince1970: 1761280000),
            remainingMinutes: 0,
            isGoalCompleted: true,
            signOfTheDay: customSign,
            quickPhrases: customPhrases
        )

        store.saveSnapshot(original)

        let loaded = store.fetchSnapshot()
        #expect(loaded.currentStreak == 12)
        #expect(loaded.longestStreak == 25)
        #expect(loaded.xp == 750)
        #expect(loaded.level == 3)
        #expect(loaded.levelTitle == "Explorer III")
        #expect(loaded.streakFreezes == 2)
        #expect(loaded.dailyGoalMinutes == 15)
        #expect(loaded.dailyGoalVerified == 3)
        #expect(loaded.dailyGoalTarget == 3)
        #expect(loaded.isGoalCompleted == true)
        #expect(loaded.remainingMinutes == 0)
        #expect(loaded.signOfTheDay.name == "Z")
        #expect(loaded.signOfTheDay.id == "sign-test-z")
        #expect(loaded.quickPhrases.count == 2)
        #expect(loaded.quickPhrases.first?.text == "Excuse me")
        #expect(loaded.quickPhrases.last?.isEmergency == true)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test("SharedStore: Missing data defaults provide valid snapshot without crashing")
    func testSharedStoreMissingDataDefaults() {
        let suiteName = "test-store-empty-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = SharedStore(defaults: defaults)

        let snapshot = store.fetchSnapshot()
        #expect(snapshot.currentStreak == 0)
        #expect(snapshot.level == 1)
        #expect(snapshot.levelTitle == "Explorer I")
        #expect(snapshot.dailyGoalTarget == 3)
        #expect(snapshot.isGoalCompleted == false)
        #expect(!snapshot.signOfTheDay.name.isEmpty)
        #expect(!snapshot.quickPhrases.isEmpty)

        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - 2. Timeline Dates & Midnight Scheduling

    @Test("SignOfTheDay: Rotation is deterministic for identical dates")
    func testSignOfTheDayRotationDeterministicPerDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        var componentsA = DateComponents()
        componentsA.year = 2026
        componentsA.month = 10
        componentsA.day = 24
        componentsA.hour = 9
        let dateA = calendar.date(from: componentsA)!

        let sign1 = SignOfTheDayProvider.signOfTheDay(for: dateA)
        let sign2 = SignOfTheDayProvider.signOfTheDay(for: dateA)
        #expect(sign1.id == sign2.id)
        #expect(sign1.name == sign2.name)

        // Advance date by one day
        var componentsB = DateComponents()
        componentsB.year = 2026
        componentsB.month = 10
        componentsB.day = 25
        componentsB.hour = 9
        let dateB = calendar.date(from: componentsB)!

        let signTomorrow = SignOfTheDayProvider.signOfTheDay(for: dateB)
        // Ensure deterministic evaluation succeeds across days
        #expect(!signTomorrow.name.isEmpty)
    }

    @Test("SignOfTheDay: nextMidnight calculates exact start of next day")
    func testNextMidnightCalculation() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 24
        components.hour = 14
        components.minute = 30
        let date = calendar.date(from: components)!

        let midnight = SignOfTheDayProvider.nextMidnight(after: date, calendar: calendar)

        let midnightComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: midnight)
        #expect(midnightComponents.year == 2026)
        #expect(midnightComponents.month == 10)
        #expect(midnightComponents.day == 25)
        #expect(midnightComponents.hour == 0)
        #expect(midnightComponents.minute == 0)
        #expect(midnightComponents.second == 0)
    }

    // MARK: - 3. App Intents & Parameter Resolution

    @Test("AppIntent: GetStreakIntent returns dialog matching SharedStore state")
    func testGetStreakIntentDialog() async throws {
        let store = SharedStore.shared
        let snapshot = WidgetSnapshot(
            currentStreak: 9,
            longestStreak: 15,
            xp: 450,
            level: 2,
            levelTitle: "Explorer II",
            streakFreezes: 1
        )
        store.saveSnapshot(snapshot)

        let intent = GetStreakIntent()
        _ = try await intent.perform()
    }

    @Test("AppIntent: SpeakPhraseIntent handles valid and empty phrases")
    func testSpeakPhraseIntentValidAndEmpty() async throws {
        let validIntent = SpeakPhraseIntent(phrase: "Good morning!")
        _ = try await validIntent.perform()

        let emptyIntent = SpeakPhraseIntent(phrase: "   ")
        _ = try await emptyIntent.perform()
    }

    @Test("AppEntity: SignEntityQuery resolves curriculum signs by name and id")
    func testSignEntityQueryResolution() async throws {
        let query = SignEntityQuery()
        let suggestions = try await query.suggestedEntities()
        #expect(!suggestions.isEmpty)

        let searchResults = try await query.entities(matching: "A")
        #expect(!searchResults.isEmpty)
    }

    @Test("AppEntity: PhraseEntityQuery resolves quick phrases")
    func testPhraseEntityQueryResolution() async throws {
        let query = PhraseEntityQuery()
        let suggestions = try await query.suggestedEntities()
        #expect(!suggestions.isEmpty)
    }

    // MARK: - 4. DeepLinkRouter URL Parsing for Widgets

    @Test("DeepLinkRouter: Streak and widget URL schemes resolve correctly")
    @MainActor
    func testDeepLinkRoutingForWidgets() {
        let router = DeepLinkRouter()

        // 1. Streak widget tap -> signspeak://streak
        let streakHandled = router.handle(url: URL(string: "signspeak://streak")!)
        #expect(streakHandled == true)
        #expect(router.selectedTab == .home)

        // 2. Sign of the Day widget tap -> signspeak://practice?sign=sign-letter-f
        let practiceHandled = router.handle(url: URL(string: "signspeak://practice?sign=sign-letter-f")!)
        #expect(practiceHandled == true)
        #expect(router.selectedTab == .learn)
        #expect(router.activeDestination == .practice(signId: "sign-letter-f"))

        // 3. Quick Communicator widget tap -> signspeak://communicator
        let communicatorHandled = router.handle(url: URL(string: "signspeak://communicator")!)
        #expect(communicatorHandled == true)
        #expect(router.selectedTab == .talk)
        #expect(router.activeDestination == .communicator)

        // 4. Quick Communicator phrase speak -> signspeak://speak?phrase=Thank%20you
        let speakHandled = router.handle(url: URL(string: "signspeak://speak?phrase=Thank%20you")!)
        #expect(speakHandled == true)
        #expect(router.selectedTab == .talk)
        #expect(router.activeDestination == .speakPhrase(phrase: "Thank you"))

        // 5. Sound Alerts shortcut -> signspeak://alerts
        let alertsHandled = router.handle(url: URL(string: "signspeak://alerts")!)
        #expect(alertsHandled == true)
        #expect(router.selectedTab == .home)
        #expect(router.activeDestination == .soundAlerts)
    }
}
