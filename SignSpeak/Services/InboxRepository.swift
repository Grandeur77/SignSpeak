import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Protocol managing user inbox notifications at `users/{uid}/inbox`.
public protocol InboxRepository: Sendable {
    /// Fetches all inbox notifications for the given user, ordered by creation date descending.
    func fetchNotifications(userId: String) async throws -> [InboxNotificationItem]

    /// Marks a single notification as read.
    func markAsRead(notificationId: String, userId: String) async throws

    /// Marks all notifications as read for the user.
    func markAllAsRead(userId: String) async throws

    /// Adds a new notification item to the user's inbox.
    func addNotification(_ item: InboxNotificationItem) async throws

    /// Deletes a notification item from the inbox.
    func deleteNotification(notificationId: String, userId: String) async throws

    /// Returns the number of unread notifications for badge presentation.
    func unreadCount(userId: String) async throws -> Int
}

// MARK: - In-Memory Stub Implementation

public final class StubInboxRepository: InboxRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: [InboxNotificationItem]] = [:]

    public init(initialItems: [InboxNotificationItem]? = nil) {
        if let initialItems {
            for item in initialItems {
                storage[item.userId, default: []].append(item)
            }
        } else {
            seedSampleData()
        }
    }

    private func seedSampleData() {
        let now = Date()
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now) ?? now

        let samples: [InboxNotificationItem] = [
            InboxNotificationItem(
                id: "notif-1",
                userId: "test-user",
                title: "3-Day Streak Master! 🔥",
                body: "You've practiced 3 days in a row! You're building a solid habit.",
                category: .milestones,
                actionDeepLink: "signspeak://practice",
                isRead: false,
                createdAt: now.addingTimeInterval(-1800) // 30 min ago
            ),
            InboxNotificationItem(
                id: "notif-2",
                userId: "test-user",
                title: "Sign of the Day: 'Hello' ✋",
                body: "Learn how to greet someone in American Sign Language with a simple wave.",
                category: .learning,
                actionDeepLink: "signspeak://learn?sign=hello",
                isRead: false,
                createdAt: now.addingTimeInterval(-7200) // 2 hours ago
            ),
            InboxNotificationItem(
                id: "notif-3",
                userId: "test-user",
                title: "Maya reacted to your sign 👏",
                body: "Maya gave you high praise on your fingerspelling accuracy in Community.",
                category: .community,
                actionDeepLink: "signspeak://community",
                isRead: true,
                createdAt: yesterday
            ),
            InboxNotificationItem(
                id: "notif-4",
                userId: "test-user",
                title: "Weekly Progress Report 📊",
                body: "Last week you learned 12 signs with 89% accuracy. Keep up the momentum!",
                category: .milestones,
                actionDeepLink: "signspeak://home",
                isRead: true,
                createdAt: twoDaysAgo
            )
        ]

        for s in samples {
            storage[s.userId, default: []].append(s)
            storage["guest", default: []].append(s)
        }
    }

    public func fetchNotifications(userId: String) async throws -> [InboxNotificationItem] {
        lock.lock()
        defer { lock.unlock() }
        let items = storage[userId] ?? []
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    public func markAsRead(notificationId: String, userId: String) async throws {
        lock.lock()
        defer { lock.unlock() }
        guard let index = storage[userId]?.firstIndex(where: { $0.id == notificationId }) else { return }
        storage[userId]?[index].isRead = true
    }

    public func markAllAsRead(userId: String) async throws {
        lock.lock()
        defer { lock.unlock() }
        guard let items = storage[userId] else { return }
        storage[userId] = items.map {
            var copy = $0
            copy.isRead = true
            return copy
        }
    }

    public func addNotification(_ item: InboxNotificationItem) async throws {
        lock.lock()
        defer { lock.unlock() }
        storage[item.userId, default: []].append(item)
    }

    public func deleteNotification(notificationId: String, userId: String) async throws {
        lock.lock()
        defer { lock.unlock() }
        storage[userId]?.removeAll { $0.id == notificationId }
    }

    public func unreadCount(userId: String) async throws -> Int {
        lock.lock()
        defer { lock.unlock() }
        return storage[userId]?.filter { !$0.isRead }.count ?? 0
    }
}

// MARK: - Firestore Production Implementation

#if canImport(FirebaseFirestore)
public final class FirestoreInboxRepository: InboxRepository, @unchecked Sendable {
    private let db: Firestore

    public init(firestore: Firestore = .firestore()) {
        self.db = firestore
    }

    private func collection(userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("inbox")
    }

    public func fetchNotifications(userId: String) async throws -> [InboxNotificationItem] {
        let snapshot = try await collection(userId: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> InboxNotificationItem? in
            try? doc.data(as: InboxNotificationItem.self)
        }
    }

    public func markAsRead(notificationId: String, userId: String) async throws {
        try await collection(userId: userId)
            .document(notificationId)
            .updateData(["isRead": true])
    }

    public func markAllAsRead(userId: String) async throws {
        let unreadDocs = try await collection(userId: userId)
            .whereField("isRead", isEqualTo: false)
            .getDocuments()

        let batch = db.batch()
        for doc in unreadDocs.documents {
            batch.updateData(["isRead": true], forDocument: doc.reference)
        }
        try await batch.commit()
    }

    public func addNotification(_ item: InboxNotificationItem) async throws {
        try collection(userId: item.userId)
            .document(item.id)
            .setData(from: item)
    }

    public func deleteNotification(notificationId: String, userId: String) async throws {
        try await collection(userId: userId)
            .document(notificationId)
            .delete()
    }

    public func unreadCount(userId: String) async throws -> Int {
        let snapshot = try await collection(userId: userId)
            .whereField("isRead", isEqualTo: false)
            .getDocuments()
        return snapshot.documents.count
    }
}
#endif
