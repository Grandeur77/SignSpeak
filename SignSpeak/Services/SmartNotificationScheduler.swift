import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Service implementing Step 8.2 smart notification logic:
/// - Streak-at-risk evaluation (only if today's practice goal unmet)
/// - Sign of the Day rotation & scheduling
/// - Achievement unlocked & new lesson alerts
/// - Community reactions & comment notifications with deep links
/// - Weekly progress reports with signs learned and accuracy
public final class SmartNotificationScheduler: Sendable {
    private let notificationService: any NotificationServicing
    private let inboxRepository: any InboxRepository
    private let dateProvider: any DateProviding

    public init(
        notificationService: any NotificationServicing,
        inboxRepository: any InboxRepository,
        dateProvider: any DateProviding = SystemDateProvider()
    ) {
        self.notificationService = notificationService
        self.inboxRepository = inboxRepository
        self.dateProvider = dateProvider
    }

    // MARK: - 1. Streak-at-Risk Notification

    /// Evaluates user practice progress today.
    /// If user hasn't practiced, schedules an evening streak-at-risk alert.
    /// If user already practiced today, cancels any pending streak alert immediately.
    public func evaluateStreakAtRisk(
        userId: String,
        profile: UserProfile,
        settings: ReminderSettings
    ) async {
        let todayString = formattedDate(dateProvider.now)
        let hasPracticedToday = (profile.lastPracticeDay == todayString)

        if hasPracticedToday {
            // Goal met! Cancel pending streak-at-risk notification
            await notificationService.cancelReminder(identifier: NotificationIdentifier.streakAtRisk)
        } else if settings.streakAlertsEnabled {
            // Hasn't practiced today: schedule evening reminder
            let eveParts = settings.eveningTime.split(separator: ":").compactMap { Int($0) }
            let hour = eveParts.count > 0 ? eveParts[0] : 20
            let minute = eveParts.count > 1 ? eveParts[1] : 30

            let streakCount = max(1, profile.currentStreak)
            let title = "Streak at Risk! 🔥"
            let body = "Your \(streakCount)-day practice streak will freeze or reset at midnight. Complete 1 quick practice to keep it safe!"

            #if canImport(UserNotifications)
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.categoryIdentifier = NotificationCategoryIdentifier.streakAlert

            var components = Calendar.current.dateComponents([.year, .month, .day], from: dateProvider.now)
            components.hour = hour
            components.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: NotificationIdentifier.streakAtRisk,
                content: content,
                trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(request)
            #endif
        }
    }

    // MARK: - 2. Sign of the Day

    /// Schedules and logs the Sign of the Day for the learner.
    public func scheduleSignOfTheDay(
        userId: String,
        signId: String,
        signName: String,
        category: String
    ) async {
        let title = "Sign of the Day: '\(signName)' ✋"
        let body = "Expand your ASL vocabulary today with '\(signName)' in \(category). Tap to practice!"
        let deepLink = "signspeak://learn?sign=\(signId)"

        // Add to Inbox
        let item = InboxNotificationItem(
            userId: userId,
            title: title,
            body: body,
            category: .learning,
            actionDeepLink: deepLink,
            createdAt: dateProvider.now
        )
        try? await inboxRepository.addNotification(item)

        // Schedule Notification Request
        #if canImport(UserNotifications)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = NotificationCategoryIdentifier.practiceReminder

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.signOfTheDay,
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
        #endif
    }

    // MARK: - 3. Achievements & Milestones

    /// Delivers an achievement unlocked alert and archives it in user's inbox.
    public func deliverAchievementUnlocked(
        userId: String,
        achievementTitle: String,
        description: String
    ) async {
        let title = "Achievement Unlocked! 🏆"
        let body = "\(achievementTitle): \(description)"
        let deepLink = "signspeak://home"

        let item = InboxNotificationItem(
            userId: userId,
            title: title,
            body: body,
            category: .milestones,
            actionDeepLink: deepLink,
            createdAt: dateProvider.now
        )
        try? await inboxRepository.addNotification(item)

        #if canImport(UserNotifications)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = NotificationCategoryIdentifier.streakAlert

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(
            identifier: "milestone_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
        #endif
    }

    // MARK: - 4. New Lessons & Content

    /// Notifies the learner when a new vocabulary unit or lesson is unlocked.
    public func deliverNewLessonUnlocked(
        userId: String,
        lessonTitle: String,
        categoryName: String
    ) async {
        let title = "New Lesson Unlocked! 📚"
        let body = "You can now practice '\(lessonTitle)' in \(categoryName)."
        let deepLink = "signspeak://learn"

        let item = InboxNotificationItem(
            userId: userId,
            title: title,
            body: body,
            category: .learning,
            actionDeepLink: deepLink,
            createdAt: dateProvider.now
        )
        try? await inboxRepository.addNotification(item)

        #if canImport(UserNotifications)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = NotificationCategoryIdentifier.newLesson

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(
            identifier: "new_lesson_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
        #endif
    }

    // MARK: - 5. Community Reactions & Comments

    /// Notifies the user when another community member reacts to or comments on their sign request.
    public func deliverCommunityReaction(
        userId: String,
        authorName: String,
        signName: String,
        reactionEmoji: String
    ) async {
        let title = "\(authorName) reacted \(reactionEmoji)"
        let body = "\(authorName) gave you a reaction on your '\(signName)' demonstration in Community."
        let deepLink = "signspeak://community"

        let item = InboxNotificationItem(
            userId: userId,
            title: title,
            body: body,
            category: .community,
            actionDeepLink: deepLink,
            createdAt: dateProvider.now
        )
        try? await inboxRepository.addNotification(item)

        #if canImport(UserNotifications)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = NotificationCategoryIdentifier.communityReaction

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(
            identifier: "community_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
        #endif
    }

    // MARK: - 6. Weekly Progress Report

    /// Delivers the Sunday weekly progress report with signs learned and average accuracy.
    public func deliverWeeklyReport(
        userId: String,
        signsLearned: Int,
        accuracyPercentage: Int,
        practiceMinutes: Int
    ) async {
        let title = "Your Weekly Progress Report 📊"
        let body = "This week: \(signsLearned) signs learned with \(accuracyPercentage)% average accuracy across \(practiceMinutes) mins of practice."
        let deepLink = "signspeak://home"

        let item = InboxNotificationItem(
            userId: userId,
            title: title,
            body: body,
            category: .milestones,
            actionDeepLink: deepLink,
            createdAt: dateProvider.now
        )
        try? await inboxRepository.addNotification(item)

        #if canImport(UserNotifications)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = NotificationCategoryIdentifier.weeklyReport

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.weeklyReport,
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
        #endif
    }

    // MARK: - Helper

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}
