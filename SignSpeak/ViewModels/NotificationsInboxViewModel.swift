import SwiftUI
import Foundation

/// Filter options for user inbox screen.
public enum InboxFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case unread = "Unread"
    case milestones = "Milestones"
    case community = "Community"

    public var id: String { rawValue }
}

/// View model driving the Notifications Inbox (`21-notifications-inbox`).
@Observable
@MainActor
public final class NotificationsInboxViewModel {
    public var selectedFilter: InboxFilter = .all
    public var notifications: [InboxNotificationItem] = []
    public var isLoading: Bool = false
    public var unreadCount: Int = 0

    private let inboxRepository: any InboxRepository
    private let userId: String
    private let dateProvider: any DateProviding

    public init(
        inboxRepository: any InboxRepository,
        userId: String,
        dateProvider: any DateProviding = SystemDateProvider()
    ) {
        self.inboxRepository = inboxRepository
        self.userId = userId
        self.dateProvider = dateProvider
    }

    public func loadNotifications() async {
        isLoading = true
        defer { isLoading = false }
        do {
            self.notifications = try await inboxRepository.fetchNotifications(userId: userId)
            self.unreadCount = try await inboxRepository.unreadCount(userId: userId)
        } catch {
            self.notifications = []
            self.unreadCount = 0
        }
    }

    // MARK: - Filtered Views

    public var filteredNotifications: [InboxNotificationItem] {
        switch selectedFilter {
        case .all:
            return notifications
        case .unread:
            return notifications.filter { !$0.isRead }
        case .milestones:
            return notifications.filter { $0.category == .milestones || $0.category == .streak }
        case .community:
            return notifications.filter { $0.category == .community }
        }
    }

    /// Items created on the same calendar day as `dateProvider.now`.
    public var todayNotifications: [InboxNotificationItem] {
        let calendar = Calendar.current
        let today = dateProvider.now
        return filteredNotifications.filter { calendar.isDate($0.createdAt, inSameDayAs: today) }
    }

    /// Items created before today.
    public var earlierNotifications: [InboxNotificationItem] {
        let calendar = Calendar.current
        let today = dateProvider.now
        return filteredNotifications.filter { !calendar.isDate($0.createdAt, inSameDayAs: today) }
    }

    // MARK: - Actions

    public func markAsRead(_ item: InboxNotificationItem) async {
        guard !item.isRead else { return }
        try? await inboxRepository.markAsRead(notificationId: item.id, userId: userId)
        if let idx = notifications.firstIndex(where: { $0.id == item.id }) {
            notifications[idx].isRead = true
        }
        unreadCount = max(0, unreadCount - 1)
    }

    public func markAllAsRead() async {
        try? await inboxRepository.markAllAsRead(userId: userId)
        for i in 0..<notifications.count {
            notifications[i].isRead = true
        }
        unreadCount = 0
    }

    public func deleteNotification(_ item: InboxNotificationItem) async {
        try? await inboxRepository.deleteNotification(notificationId: item.id, userId: userId)
        notifications.removeAll { $0.id == item.id }
        if !item.isRead {
            unreadCount = max(0, unreadCount - 1)
        }
    }

    public func handleNotificationTap(_ item: InboxNotificationItem, router: DeepLinkRouter) async {
        await markAsRead(item)
        if let link = item.actionDeepLink, let url = URL(string: link) {
            router.handle(url: url)
        }
    }
}
