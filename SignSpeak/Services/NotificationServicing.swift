import Foundation

/// Protocol abstracting local notification scheduling via UNUserNotificationCenter.
public protocol NotificationServicing: Sendable {
    /// Requests authorization to display local notifications.
    func requestAuthorization() async throws -> Bool

    /// Schedules a recurring daily practice reminder.
    func scheduleDailyReminder(hour: Int, minute: Int) async throws

    /// Cancels all scheduled local notifications.
    func cancelAllReminders() async
}

/// Fallback local notification service stub.
public struct StubNotificationService: NotificationServicing {
    public init() {}
    public func requestAuthorization() async throws -> Bool { true }
    public func scheduleDailyReminder(hour: Int, minute: Int) async throws {}
    public func cancelAllReminders() async {}
}

#if canImport(UserNotifications)
import UserNotifications

/// Production local notification service wrapping UNUserNotificationCenter.
public final class LiveNotificationService: NotificationServicing, @unchecked Sendable {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    public func scheduleDailyReminder(hour: Int, minute: Int) async throws {
        center.removeAllPendingNotificationRequests()

        let content = UNMutableNotificationContent()
        content.title = "Time for Daily Sign ✋"
        content.body = "Keep your practice streak alive! Spend a few moments with SignSpeak."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_practice_reminder", content: content, trigger: trigger)
        try await center.add(request)
    }

    public func cancelAllReminders() async {
        center.removeAllPendingNotificationRequests()
    }
}
#endif
