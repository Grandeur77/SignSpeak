import SwiftUI
import Foundation

/// Categorization of an inbox notification item for filtering and iconography.
public enum InboxCategory: String, Codable, Sendable, CaseIterable, Equatable {
    case milestones = "Milestones"
    case community = "Community"
    case learning = "Learning"
    case streak = "Streak"
    case system = "System"

    public var iconName: String {
        switch self {
        case .milestones: return "trophy.fill"
        case .community: return "bubble.left.and.bubble.right.fill"
        case .learning: return "book.fill"
        case .streak: return "flame.fill"
        case .system: return "bell.fill"
        }
    }

    public var accentColor: Color {
        switch self {
        case .milestones: return Color.brandYellow
        case .community: return Color.brandTurquoise
        case .learning: return Color.brandNavy
        case .streak: return Color.orange
        case .system: return Color.textSecondary
        }
    }
}

/// A stored inbox notification item document residing at `users/{uid}/inbox/{id}`.
public struct InboxNotificationItem: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let userId: String
    public var title: String
    public var body: String
    public var category: InboxCategory
    public var actionDeepLink: String?
    public var isRead: Bool
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        userId: String,
        title: String,
        body: String,
        category: InboxCategory,
        actionDeepLink: String? = nil,
        isRead: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.body = body
        self.category = category
        self.actionDeepLink = actionDeepLink
        self.isRead = isRead
        self.createdAt = createdAt
    }

    /// User-friendly relative time string (e.g. "Just now", "25m ago", "Yesterday").
    public var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}
