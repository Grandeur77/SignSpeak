import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Authorization status for local notifications.
public enum NotificationAuthorizationStatus: String, Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
    case provisional
}

/// Standard notification categories recognized by the app.
public enum NotificationCategoryIdentifier {
    public static let practiceReminder = "PRACTICE_REMINDER"
    public static let streakAlert = "STREAK_ALERT"
    public static let communityReaction = "COMMUNITY_REACTION"
    public static let newLesson = "NEW_LESSON"
    public static let weeklyReport = "WEEKLY_REPORT"
}

/// Action identifiers attached to notification categories.
public enum NotificationActionIdentifier {
    public static let practiseNow = "PRACTISE_NOW"
    public static let remind1Hour = "REMIND_1_HOUR"
    public static let reply = "REPLY"
}

/// Unique identifiers for recurring or smart scheduled notifications.
public enum NotificationIdentifier {
    public static func dailyReminder(weekday: Int) -> String {
        "signspeak_daily_reminder_day_\(weekday)"
    }
    public static let eveningReminder = "signspeak_evening_streak_reminder"
    public static let streakAtRisk = "signspeak_streak_at_risk"
    public static let signOfTheDay = "signspeak_sign_of_the_day"
    public static let weeklyReport = "signspeak_weekly_report"
    public static let testPreview = "signspeak_test_preview"
}

/// Protocol abstracting local notification scheduling via UNUserNotificationCenter.
public protocol NotificationServicing: Sendable {
    /// Requests authorization to display local notifications.
    func requestAuthorization() async throws -> Bool

    /// Checks the current authorization status.
    func getAuthorizationStatus() async -> NotificationAuthorizationStatus

    /// Schedules recurring reminders based on user preferences.
    func scheduleReminders(settings: ReminderSettings) async throws

    /// Schedules a recurring daily practice reminder.
    func scheduleDailyReminder(hour: Int, minute: Int) async throws

    /// Schedules a recurring daily practice reminder on specific weekdays (1 = Sunday... 7 = Saturday).
    func scheduleDailyReminder(hour: Int, minute: Int, activeDays: [Int]) async throws

    /// Schedules an evening session / streak alert reminder.
    func scheduleEveningReminder(hour: Int, minute: Int) async throws

    /// Immediately schedules a test notification preview (fires after 1 second).
    func scheduleTestPreview(title: String, body: String) async throws

    /// Cancels all scheduled local notifications.
    func cancelAllReminders() async

    /// Cancels a specific scheduled reminder by identifier.
    func cancelReminder(identifier: String) async

    /// Returns list of pending scheduled reminder identifiers.
    func getPendingReminderIdentifiers() async -> [String]
}

// MARK: - Stub Implementation

/// In-memory notification service stub for tests and previews.
public final class StubNotificationService: NotificationServicing, @unchecked Sendable {
    private let lock = NSLock()
    public var authorizationStatus: NotificationAuthorizationStatus = .authorized
    public var scheduledRequests: [String: (hour: Int, minute: Int, weekdays: [Int], title: String, body: String)] = [:]
    public var cancelledIdentifiers: [String] = []
    public var allRemindersCancelled: Bool = false

    public init(status: NotificationAuthorizationStatus = .authorized) {
        self.authorizationStatus = status
    }

    public func requestAuthorization() async throws -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if authorizationStatus == .denied { return false }
        authorizationStatus = .authorized
        return true
    }

    public func getAuthorizationStatus() async -> NotificationAuthorizationStatus {
        lock.lock()
        defer { lock.unlock() }
        return authorizationStatus
    }

    public func scheduleReminders(settings: ReminderSettings) async throws {
        lock.lock()
        defer { lock.unlock() }

        // Remove old daily reminders
        for day in 1...7 {
            scheduledRequests.removeValue(forKey: NotificationIdentifier.dailyReminder(weekday: day))
        }
        scheduledRequests.removeValue(forKey: NotificationIdentifier.eveningReminder)

        guard settings.enabled else { return }

        // Parse practice time "HH:mm"
        let parts = settings.practiceTime.split(separator: ":").compactMap { Int($0) }
        let hour = parts.count > 0 ? parts[0] : 19
        let minute = parts.count > 1 ? parts[1] : 0

        for day in settings.activeDays {
            scheduledRequests[NotificationIdentifier.dailyReminder(weekday: day)] = (
                hour: hour,
                minute: minute,
                weekdays: [day],
                title: "Time for Daily Sign ✋",
                body: "Keep your practice streak alive! Spend a few moments with SignSpeak."
            )
        }

        if settings.eveningEnabled {
            let eveParts = settings.eveningTime.split(separator: ":").compactMap { Int($0) }
            let eveHour = eveParts.count > 0 ? eveParts[0] : 20
            let eveMinute = eveParts.count > 1 ? eveParts[1] : 30
            scheduledRequests[NotificationIdentifier.eveningReminder] = (
                hour: eveHour,
                minute: eveMinute,
                weekdays: Array(1...7),
                title: "Evening Practice Check-in 🌙",
                body: "Review today's signs and secure your streak before midnight!"
            )
        }
    }

    public func scheduleDailyReminder(hour: Int, minute: Int) async throws {
        try await scheduleDailyReminder(hour: hour, minute: minute, activeDays: Array(1...7))
    }

    public func scheduleDailyReminder(hour: Int, minute: Int, activeDays: [Int]) async throws {
        lock.lock()
        defer { lock.unlock() }
        for day in activeDays {
            scheduledRequests[NotificationIdentifier.dailyReminder(weekday: day)] = (
                hour: hour,
                minute: minute,
                weekdays: [day],
                title: "Time for Daily Sign ✋",
                body: "Keep your practice streak alive! Spend a few moments with SignSpeak."
            )
        }
    }

    public func scheduleEveningReminder(hour: Int, minute: Int) async throws {
        lock.lock()
        defer { lock.unlock() }
        scheduledRequests[NotificationIdentifier.eveningReminder] = (
            hour: hour,
            minute: minute,
            weekdays: Array(1...7),
            title: "Evening Practice Check-in 🌙",
            body: "Review today's signs and secure your streak before midnight!"
        )
    }

    public func scheduleTestPreview(title: String, body: String) async throws {
        lock.lock()
        defer { lock.unlock() }
        scheduledRequests[NotificationIdentifier.testPreview] = (
            hour: 0,
            minute: 0,
            weekdays: [],
            title: title,
            body: body
        )
    }

    public func cancelAllReminders() async {
        lock.lock()
        defer { lock.unlock() }
        scheduledRequests.removeAll()
        allRemindersCancelled = true
    }

    public func cancelReminder(identifier: String) async {
        lock.lock()
        defer { lock.unlock() }
        scheduledRequests.removeValue(forKey: identifier)
        cancelledIdentifiers.append(identifier)
    }

    public func getPendingReminderIdentifiers() async -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(scheduledRequests.keys)
    }
}

// MARK: - Live Production Implementation

#if canImport(UserNotifications)
/// Production notification service wrapping UNUserNotificationCenter.
public final class LiveNotificationService: NotificationServicing, @unchecked Sendable {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    public func getAuthorizationStatus() async -> NotificationAuthorizationStatus {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized: return .authorized
        case .denied: return .denied
        case .provisional: return .provisional
        case .notDetermined: return .notDetermined
        case .ephemeral: return .authorized
        @unknown default: return .notDetermined
        }
    }

    public func scheduleReminders(settings: ReminderSettings) async throws {
        // 1. Clear previous daily reminders
        let dailyIds = (1...7).map { NotificationIdentifier.dailyReminder(weekday: $0) }
        center.removePendingNotificationRequests(withIdentifiers: dailyIds)
        center.removePendingNotificationRequests(withIdentifiers: [NotificationIdentifier.eveningReminder])

        guard settings.enabled else { return }

        // 2. Parse daily practice time
        let parts = settings.practiceTime.split(separator: ":").compactMap { Int($0) }
        let hour = parts.count > 0 ? parts[0] : 19
        let minute = parts.count > 1 ? parts[1] : 0

        // 3. Schedule for each active day
        try await scheduleDailyReminder(hour: hour, minute: minute, activeDays: settings.activeDays)

        // 4. Schedule evening review if enabled
        if settings.eveningEnabled {
            let eveParts = settings.eveningTime.split(separator: ":").compactMap { Int($0) }
            let eveHour = eveParts.count > 0 ? eveParts[0] : 20
            let eveMinute = eveParts.count > 1 ? eveParts[1] : 30
            try await scheduleEveningReminder(hour: eveHour, minute: eveMinute)
        }
    }

    public func scheduleDailyReminder(hour: Int, minute: Int) async throws {
        try await scheduleDailyReminder(hour: hour, minute: minute, activeDays: Array(1...7))
    }

    public func scheduleDailyReminder(hour: Int, minute: Int, activeDays: [Int]) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Time for Daily Sign ✋"
        content.body = "Keep your practice streak alive! Spend a few moments with SignSpeak."
        content.sound = .default
        content.categoryIdentifier = NotificationCategoryIdentifier.practiceReminder

        for day in activeDays {
            var dateComponents = DateComponents()
            dateComponents.weekday = day // 1 = Sunday, 2 = Monday, ..., 7 = Saturday
            dateComponents.hour = hour
            dateComponents.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let identifier = NotificationIdentifier.dailyReminder(weekday: day)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try await center.add(request)
        }
    }

    public func scheduleEveningReminder(hour: Int, minute: Int) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Evening Practice Check-in 🌙"
        content.body = "Secure your streak before midnight! A quick 3-minute session counts."
        content.sound = .default
        content.categoryIdentifier = NotificationCategoryIdentifier.streakAlert

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.eveningReminder,
            content: content,
            trigger: trigger
        )
        try await center.add(request)
    }

    public func scheduleTestPreview(title: String, body: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = NotificationCategoryIdentifier.practiceReminder

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.testPreview,
            content: content,
            trigger: trigger
        )
        try await center.add(request)
    }

    public func cancelAllReminders() async {
        center.removeAllPendingNotificationRequests()
    }

    public func cancelReminder(identifier: String) async {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    public func getPendingReminderIdentifiers() async -> [String] {
        let requests = await center.pendingNotificationRequests()
        return requests.map(\.identifier)
    }
}
#endif
