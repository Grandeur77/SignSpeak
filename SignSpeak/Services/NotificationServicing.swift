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
