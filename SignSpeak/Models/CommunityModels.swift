import Foundation

/// Reaction types available in the SignSpeak community (`49-reaction-picker-sheet`).
public enum CommunityReactionType: String, CaseIterable, Identifiable, Codable, Sendable {
    case wave = "wave"
    case fire = "fire"
    case love = "love"
    case party = "party"
    case power = "power"
    case ily = "ily"

    public var id: String { rawValue }

    public var emoji: String {
        switch self {
        case .wave: return "👋"
        case .fire: return "🔥"
        case .love: return "❤️"
        case .party: return "🎉"
        case .power: return "💪"
        case .ily: return "🤟"
        }
    }

    public var title: String {
        switch self {
        case .wave: return "Wave"
        case .fire: return "Fire"
        case .love: return "Love"
        case .party: return "Party"
        case .power: return "Power"
        case .ily: return "ILY Sign"
        }
    }

    public var meaning: String {
        switch self {
        case .wave: return "Saying Hello"
        case .fire: return "On Fire Streak!"
        case .love: return "Warm Support"
        case .party: return "Celebrate Achievement"
        case .power: return "Strength & Motivation"
        case .ily: return "Deaf I Love You"
        }
    }
}

/// Type of community feed post.
public enum CommunityPostType: String, Codable, Sendable, Hashable {
    case text = "text"
    case milestone = "milestone"
    case dailyChallenge = "daily_challenge"
    case videoDemo = "video_demo"
}

/// A social feed post within the community (`48-community-feed`).
public struct CommunityPost: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let authorId: String
    public let authorName: String
    public let authorRole: String // "deaf", "learner", "interpreter", "educator"
    public let authorAvatarUrl: String?
    public let postType: CommunityPostType
    public let title: String?
    public let body: String
    public let milestoneBadge: String? // e.g. "🔥 7-Day Streak", "🔤 Alphabet Master"
    public let mediaUrl: String?
    public let demonstrationSignName: String?
    public let createdAt: Date
    public var reactions: [CommunityReactionType: Int]
    public var userReaction: CommunityReactionType?
    public var commentCount: Int

    public var totalReactionCount: Int {
        reactions.values.reduce(0, +)
    }

    public init(
        id: String = UUID().uuidString,
        authorId: String,
        authorName: String,
        authorRole: String = "learner",
        authorAvatarUrl: String? = nil,
        postType: CommunityPostType = .text,
        title: String? = nil,
        body: String,
        milestoneBadge: String? = nil,
        mediaUrl: String? = nil,
        demonstrationSignName: String? = nil,
        createdAt: Date = Date(),
        reactions: [CommunityReactionType: Int] = [:],
        userReaction: CommunityReactionType? = nil,
        commentCount: Int = 0
    ) {
        self.id = id
        self.authorId = authorId
        self.authorName = authorName
        self.authorRole = authorRole
        self.authorAvatarUrl = authorAvatarUrl
        self.postType = postType
        self.title = title
        self.body = body
        self.milestoneBadge = milestoneBadge
        self.mediaUrl = mediaUrl
        self.demonstrationSignName = demonstrationSignName
        self.createdAt = createdAt
        self.reactions = reactions
        self.userReaction = userReaction
        self.commentCount = commentCount
    }
}

/// Comment on a community post (`47-post-detail-comments`).
public struct CommunityComment: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let postId: String
    public let authorId: String
    public let authorName: String
    public let authorRole: String
    public let authorAvatarUrl: String?
    public let text: String
    public let createdAt: Date
    public var upvotes: Int

    public init(
        id: String = UUID().uuidString,
        postId: String,
        authorId: String,
        authorName: String,
        authorRole: String = "learner",
        authorAvatarUrl: String? = nil,
        text: String,
        createdAt: Date = Date(),
        upvotes: Int = 0
    ) {
        self.id = id
        self.postId = postId
        self.authorId = authorId
        self.authorName = authorName
        self.authorRole = authorRole
        self.authorAvatarUrl = authorAvatarUrl
        self.text = text
        self.createdAt = createdAt
        self.upvotes = upvotes
    }
}

/// Report reasons for moderation (`46-report-sheet`).
public enum CommunityReportReason: String, CaseIterable, Identifiable, Codable, Sendable, Hashable {
    case spam = "Spam or Commercial Content"
    case offensive = "Offensive or Inappropriate Language"
    case harassment = "Harassment or Bullying"
    case misleadingSign = "Incorrect or Misleading Sign Demonstration"
    case other = "Other Issue"

    public var id: String { rawValue }
}

/// Content moderation report document (`46-report-sheet`).
public struct CommunityReport: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let reporterId: String
    public let targetId: String
    public let targetType: String // "post" | "comment"
    public let reason: CommunityReportReason
    public let details: String?
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        reporterId: String,
        targetId: String,
        targetType: String,
        reason: CommunityReportReason,
        details: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.reporterId = reporterId
        self.targetId = targetId
        self.targetType = targetType
        self.reason = reason
        self.details = details
        self.createdAt = createdAt
    }
}

/// Feed filter tab.
public enum CommunityFeedFilter: String, CaseIterable, Identifiable, Sendable, Hashable {
    case forYou = "For You"
    case friends = "Friends"

    public var id: String { rawValue }
}

/// Comment sorting options.
public enum CommentSortOrder: String, CaseIterable, Identifiable, Sendable, Hashable {
    case newest = "Newest"
    case top = "Top Comments"

    public var id: String { rawValue }
}
