import Testing
import Foundation
@testable import SignSpeak

/// Step 8.3 test suite validating local notification scheduling, smart alerts,
/// inbox repository filters, and deep-link routing.
@Suite("Notification & Inbox Test Suite")
struct NotificationTests {

    // MARK: - 1. Scheduling on Active Days

    @Test("Scheduling on active days registers daily reminders on specified weekdays plus evening check-in")
    func testSchedulingOnActiveDays() async throws {
        let stub = StubNotificationService()
        let settings = ReminderSettings(
            enabled: true,
            practiceTime: "08:30",
            activeDays: [2, 3, 4, 5, 6], // Mon-Fri
            eveningEnabled: true,
            eveningTime: "21:00",
            streakAlertsEnabled: true
        )

        try await stub.scheduleReminders(settings: settings)

        // Verify daily reminders for Mon-Fri
        for day in [2, 3, 4, 5, 6] {
            let id = NotificationIdentifier.dailyReminder(weekday: day)
            let req = stub.scheduledRequests[id]
            #expect(req != nil, "Expected scheduled reminder for weekday \(day)")
            #expect(req?.hour == 8)
            #expect(req?.minute == 30)
            #expect(req?.weekdays == [day])
        }

        // Verify excluded days (Sunday = 1, Saturday = 7) are not scheduled
        #expect(stub.scheduledRequests[NotificationIdentifier.dailyReminder(weekday: 1)] == nil)
        #expect(stub.scheduledRequests[NotificationIdentifier.dailyReminder(weekday: 7)] == nil)

        // Verify evening reminder
        let eveningReq = stub.scheduledRequests[NotificationIdentifier.eveningReminder]
        #expect(eveningReq != nil)
        #expect(eveningReq?.hour == 21)
        #expect(eveningReq?.minute == 0)
    }

    // MARK: - 2. Streak at Risk Conditions

    @Test("Streak-at-risk alert is cancelled when user has already practiced today")
    @MainActor
    func testStreakAtRiskCancelledWhenPracticedToday() async throws {
        let stubNotificationService = StubNotificationService()
        let stubInbox = StubInboxRepository()
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 1_790_000_000))

        let scheduler = SmartNotificationScheduler(
            notificationService: stubNotificationService,
            inboxRepository: stubInbox,
            dateProvider: clock
        )

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: clock.now)

        let practicedProfile = UserProfile(
            id: "user_123",
            displayName: "Maya",
            role: "learner",
            currentStreak: 5,
            lastPracticeDay: todayString
        )
        let settings = ReminderSettings(streakAlertsEnabled: true)

        await scheduler.evaluateStreakAtRisk(
            userId: "user_123",
            profile: practicedProfile,
            settings: settings
        )

        // Should cancel any pending streak alert
        #expect(stubNotificationService.cancelledIdentifiers.contains(NotificationIdentifier.streakAtRisk))
    }

    @Test("Streak-at-risk alert is not scheduled if streak alerts are disabled in settings")
    @MainActor
    func testStreakAtRiskDisabledInSettings() async throws {
        let stubNotificationService = StubNotificationService()
        let stubInbox = StubInboxRepository()
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 1_790_000_000))

        let scheduler = SmartNotificationScheduler(
            notificationService: stubNotificationService,
            inboxRepository: stubInbox,
            dateProvider: clock
        )

        let unpracticedProfile = UserProfile(
            id: "user_123",
            displayName: "Maya",
            role: "learner",
            currentStreak: 5,
            lastPracticeDay: "2020-01-01" // Past date
        )
        let settings = ReminderSettings(streakAlertsEnabled: false)

        await scheduler.evaluateStreakAtRisk(
            userId: "user_123",
            profile: unpracticedProfile,
            settings: settings
        )

        // Nothing scheduled because user toggled streakAlerts off
        #expect(stubNotificationService.scheduledRequests[NotificationIdentifier.streakAtRisk] == nil)
    }

    // MARK: - 3. Weekly Report & Smart Deliverables Content

    @Test("Weekly progress report contains signs learned, accuracy percentage, and practice minutes")
    func testWeeklyReportContent() async throws {
        let stubNotification = StubNotificationService()
        let stubInbox = StubInboxRepository()
        let clock = ControllableClock()

        let scheduler = SmartNotificationScheduler(
            notificationService: stubNotification,
            inboxRepository: stubInbox,
            dateProvider: clock
        )

        await scheduler.deliverWeeklyReport(
            userId: "user_abc",
            signsLearned: 18,
            accuracyPercentage: 94,
            practiceMinutes: 45
        )

        let notifications = try await stubInbox.fetchNotifications(userId: "user_abc")
        #expect(notifications.count == 1)
        let report = notifications[0]
        #expect(report.title.contains("Weekly Progress Report"))
        #expect(report.body.contains("18 signs learned"))
        #expect(report.body.contains("94% average accuracy"))
        #expect(report.body.contains("45 mins of practice"))
        #expect(report.category == .milestones)
        #expect(report.actionDeepLink == "signspeak://home")
    }

    @Test("Sign of the day and community reactions log to inbox with valid deep links")
    func testSignOfTheDayAndCommunityReactions() async throws {
        let stubNotification = StubNotificationService()
        let stubInbox = StubInboxRepository()
        let clock = ControllableClock()

        let scheduler = SmartNotificationScheduler(
            notificationService: stubNotification,
            inboxRepository: stubInbox,
            dateProvider: clock
        )

        await scheduler.scheduleSignOfTheDay(
            userId: "user_abc",
            signId: "thank_you",
            signName: "Thank You",
            category: "Polite Expressions"
        )

        await scheduler.deliverCommunityReaction(
            userId: "user_abc",
            authorName: "Maya",
            signName: "Hello",
            reactionEmoji: "🔥"
        )

        let items = try await stubInbox.fetchNotifications(userId: "user_abc")
        #expect(items.count == 2)

        let signItem = items.first(where: { $0.category == .learning })
        #expect(signItem != nil)
        #expect(signItem?.title.contains("Thank You") == true)
        #expect(signItem?.actionDeepLink == "signspeak://learn?sign=thank_you")

        let communityItem = items.first(where: { $0.category == .community })
        #expect(communityItem != nil)
        #expect(communityItem?.title.contains("Maya reacted 🔥") == true)
        #expect(communityItem?.actionDeepLink == "signspeak://community")
    }

    // MARK: - 4. Deep Link Parsing

    @Test("DeepLinkRouter correctly handles notification deep link routes")
    @MainActor
    func testDeepLinkParsing() {
        let router = DeepLinkRouter()

        // 1. Inbox deep link
        let inboxURL = URL(string: "signspeak://inbox")!
        let handledInbox = router.handle(url: inboxURL)
        #expect(handledInbox == true)
        #expect(router.selectedTab == .home)
        #expect(router.activeDestination == .inbox)

        // 2. Practice deep link with sign query
        let practiceURL = URL(string: "signspeak://practice?sign=apple")!
        let handledPractice = router.handle(url: practiceURL)
        #expect(handledPractice == true)
        #expect(router.selectedTab == .learn)
        #expect(router.activeDestination == .practice(signId: "apple"))

        // 3. Two-way communicator deep link
        let communicatorURL = URL(string: "signspeak://communicator")!
        let handledCommunicator = router.handle(url: communicatorURL)
        #expect(handledCommunicator == true)
        #expect(router.selectedTab == .talk)
        #expect(router.activeDestination == .communicator)

        // 4. Community route
        let communityURL = URL(string: "signspeak://community")!
        let handledCommunity = router.handle(url: communityURL)
        #expect(handledCommunity == true)
        #expect(router.selectedTab == .home)
        #expect(router.activeDestination == .community)
    }

    // MARK: - 5. Inbox Filters and Read State

    @Test("NotificationsInboxViewModel filters correctly by category and read status")
    @MainActor
    func testInboxFiltersAndReadState() async throws {
        let repo = StubInboxRepository()
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 1_790_000_000))
        let userId = "user_test"

        let item1 = InboxNotificationItem(
            id: "item1",
            userId: userId,
            title: "Achievement 1",
            body: "Great job!",
            category: .milestones,
            isRead: false,
            createdAt: clock.now
        )
        let item2 = InboxNotificationItem(
            id: "item2",
            userId: userId,
            title: "Lesson Unlocked",
            body: "New signs",
            category: .learning,
            isRead: true,
            createdAt: clock.now
        )
        let item3 = InboxNotificationItem(
            id: "item3",
            userId: userId,
            title: "Reaction received",
            body: "Nice sign",
            category: .community,
            isRead: false,
            createdAt: clock.now.addingTimeInterval(-86400 * 3) // Earlier
        )

        try await repo.addNotification(item1)
        try await repo.addNotification(item2)
        try await repo.addNotification(item3)

        let vm = NotificationsInboxViewModel(
            inboxRepository: repo,
            userId: userId,
            dateProvider: clock
        )

        await vm.loadNotifications()
        #expect(vm.notifications.count == 3)
        #expect(vm.unreadCount == 2)

        // Filter: All
        vm.selectedFilter = .all
        #expect(vm.filteredNotifications.count == 3)

        // Filter: Unread
        vm.selectedFilter = .unread
        #expect(vm.filteredNotifications.count == 2)
        #expect(vm.filteredNotifications.allSatisfy { !$0.isRead })

        // Filter: Milestones
        vm.selectedFilter = .milestones
        #expect(vm.filteredNotifications.count == 1)
        #expect(vm.filteredNotifications.first?.id == "item1")

        // Filter: Community
        vm.selectedFilter = .community
        #expect(vm.filteredNotifications.count == 1)
        #expect(vm.filteredNotifications.first?.id == "item3")

        // Today vs Earlier
        vm.selectedFilter = .all
        #expect(vm.todayNotifications.count == 2)
        #expect(vm.earlierNotifications.count == 1)

        // Mark single as read
        await vm.markAsRead(item1)
        #expect(vm.unreadCount == 1)
        #expect(vm.notifications.first(where: { $0.id == "item1" })?.isRead == true)

        // Mark all as read
        await vm.markAllAsRead()
        #expect(vm.unreadCount == 0)
        #expect(vm.notifications.allSatisfy { $0.isRead })

        // Delete notification
        await vm.deleteNotification(item2)
        #expect(vm.notifications.count == 2)
        #expect(vm.notifications.first(where: { $0.id == "item2" }) == nil)
    }

    // MARK: - 6. Reschedule on Change

    @Test("RemindersViewModel cancels all pending reminders and reschedules cleanly on changes")
    @MainActor
    func testRescheduleOnChange() async throws {
        let stubNotification = StubNotificationService()
        let profileRepo = MockUserProfileRepository(initialProfiles: [
            UserProfile(id: "user_777", displayName: "Alex", role: "learner")
        ])

        let vm = RemindersViewModel(
            notificationService: stubNotification,
            userProfileRepository: profileRepo,
            userId: "user_777",
            initialSettings: ReminderSettings(
                enabled: true,
                practiceTime: "07:00",
                activeDays: [1, 3, 5]
            )
        )

        await vm.onAppear()
        await vm.rescheduleNotifications()

        #expect(stubNotification.scheduledRequests[NotificationIdentifier.dailyReminder(weekday: 1)] != nil)
        #expect(stubNotification.scheduledRequests[NotificationIdentifier.dailyReminder(weekday: 3)] != nil)
        #expect(stubNotification.scheduledRequests[NotificationIdentifier.dailyReminder(weekday: 5)] != nil)
        #expect(stubNotification.scheduledRequests[NotificationIdentifier.dailyReminder(weekday: 7)] == nil)

        // Update practice time
        vm.setPracticeTime(hour: 10, minute: 45)
        #expect(vm.settings.practiceTime == "10:45")

        // Toggle day
        vm.toggleDay(7) // Add Saturday
        #expect(vm.settings.activeDays.contains(7))

        // Trigger reschedule
        await vm.rescheduleNotifications()

        let saturdayReq = stubNotification.scheduledRequests[NotificationIdentifier.dailyReminder(weekday: 7)]
        #expect(saturdayReq != nil)
        #expect(saturdayReq?.hour == 10)
        #expect(saturdayReq?.minute == 45)

        let weekday1Req = stubNotification.scheduledRequests[NotificationIdentifier.dailyReminder(weekday: 1)]
        #expect(weekday1Req?.hour == 10)
        #expect(weekday1Req?.minute == 45)
    }
}
