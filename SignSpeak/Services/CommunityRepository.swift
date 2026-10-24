import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Protocol abstracting social feed interactions, reactions, comments, reports, and follow graph in Firestore.
public protocol CommunityRepository: Sendable {
    func fetchPosts(page: Int, limit: Int, filter: CommunityFeedFilter, userId: String) async throws -> [CommunityPost]
    func fetchPost(postId: String, userId: String) async throws -> CommunityPost?
    func createPost(userId: String, post: CommunityPost) async throws -> CommunityPost
    func deletePost(postId: String, userId: String) async throws
    func setReaction(postId: String, userId: String, reaction: CommunityReactionType?) async throws -> (reactions: [CommunityReactionType: Int], userReaction: CommunityReactionType?)
    func fetchComments(postId: String, sortBy: CommentSortOrder) async throws -> [CommunityComment]
    func addComment(postId: String, comment: CommunityComment) async throws -> CommunityComment
    func deleteComment(postId: String, commentId: String, userId: String) async throws
    func reportContent(report: CommunityReport) async throws
    func followUser(currentUserId: String, targetUserId: String) async throws
    func unfollowUser(currentUserId: String, targetUserId: String) async throws
    func isFollowing(currentUserId: String, targetUserId: String) async throws -> Bool
    func fetchFollowingUserIds(userId: String) async throws -> Set<String>
    func blockUser(currentUserId: String, targetUserId: String) async throws
    func fetchBlockedUserIds(currentUserId: String) async throws -> Set<String>
}

public extension CommunityRepository {
    func fetchPosts(
        page: Int = 0,
        limit: Int = 20,
        filter: CommunityFeedFilter = .forYou,
        userId: String = ""
    ) async throws -> [CommunityPost] {
        try await fetchPosts(page: page, limit: limit, filter: filter, userId: userId)
    }
}

// MARK: - In-Memory Community Repository Stub

/// Thread-safe in-memory community repository with pre-seeded posts,
/// one-per-user-per-post transactional reactions, comments, follow relationships, and blocking.
public final class StubCommunityRepository: CommunityRepository, @unchecked Sendable {
    private let lock = NSRecursiveLock()
    private var posts: [CommunityPost] = []
    private var baseReactions: [String: [CommunityReactionType: Int]] = [:]
    private var postReactions: [String: [String: CommunityReactionType]] = [:] // [postId: [userId: reaction]]
    private var comments: [String: [CommunityComment]] = [:] // [postId: comments]
    private var following: [String: Set<String>] = [:] // [userId: followedUserIds]
    private var blockedUsers: [String: Set<String>] = [:] // [userId: blockedUserIds]
    private var reports: [CommunityReport] = []

    public init(initialPosts: [CommunityPost] = []) {
        if !initialPosts.isEmpty {
            self.posts = initialPosts
        } else {
            self.posts = Self.defaults
            for post in self.posts {
                self.comments[post.id] = Self.defaultComments(for: post.id)
            }
        }
        for post in self.posts {
            self.baseReactions[post.id] = post.reactions
        }
    }

    public func fetchPosts(page: Int = 0, limit: Int = 20, filter: CommunityFeedFilter = .forYou, userId: String = "") async throws -> [CommunityPost] {
        lock.lock()
        defer { lock.unlock() }

        let blocked = blockedUsers[userId] ?? []
        let followed = following[userId] ?? []

        var filtered = posts.filter { post in
            !blocked.contains(post.authorId)
        }

        if filter == .friends {
            filtered = filtered.filter { post in
                followed.contains(post.authorId) || post.authorId == userId
            }
        }

        // Attach current user's reaction & updated reaction counts
        var result: [CommunityPost] = []
        for post in filtered {
            var copy = post
            let reactionsForPost = postReactions[post.id] ?? [:]
            copy.userReaction = reactionsForPost[userId]
            var counts = baseReactions[post.id] ?? post.reactions
            for reaction in reactionsForPost.values {
                counts[reaction, default: 0] += 1
            }
            copy.reactions = counts
            copy.commentCount = comments[post.id]?.count ?? post.commentCount
            result.append(copy)
        }

        let startIndex = max(0, page * limit)
        guard startIndex < result.count else { return [] }
        let endIndex = min(result.count, startIndex + limit)
        return Array(result[startIndex..<endIndex])
    }

    public func fetchPost(postId: String, userId: String) async throws -> CommunityPost? {
        lock.lock()
        defer { lock.unlock() }

        guard var post = posts.first(where: { $0.id == postId }) else { return nil }
        let reactionsForPost = postReactions[postId] ?? [:]
        post.userReaction = reactionsForPost[userId]
        var counts = baseReactions[postId] ?? post.reactions
        for reaction in reactionsForPost.values {
            counts[reaction, default: 0] += 1
        }
        post.reactions = counts
        post.commentCount = comments[postId]?.count ?? post.commentCount
        return post
    }

    public func createPost(userId: String, post: CommunityPost) async throws -> CommunityPost {
        lock.lock()
        defer { lock.unlock() }

        posts.insert(post, at: 0)
        baseReactions[post.id] = post.reactions
        comments[post.id] = []
        return post
    }

    public func deletePost(postId: String, userId: String) async throws {
        lock.lock()
        defer { lock.unlock() }

        posts.removeAll { $0.id == postId && $0.authorId == userId }
        postReactions.removeValue(forKey: postId)
        comments.removeValue(forKey: postId)
    }

    public func setReaction(
        postId: String,
        userId: String,
        reaction: CommunityReactionType?
    ) async throws -> (reactions: [CommunityReactionType: Int], userReaction: CommunityReactionType?) {
        lock.lock()
        defer { lock.unlock() }

        var userMap = postReactions[postId] ?? [:]
        if let current = userMap[userId], current == reaction {
            // Toggling the same reaction removes it
            userMap.removeValue(forKey: userId)
        } else if let reaction {
            userMap[userId] = reaction
        } else {
            userMap.removeValue(forKey: userId)
        }
        postReactions[postId] = userMap

        // Compute updated tally preserving initial base counts
        var counts = baseReactions[postId] ?? [:]
        for r in userMap.values {
            counts[r, default: 0] += 1
        }

        // Update post in store
        if let idx = posts.firstIndex(where: { $0.id == postId }) {
            posts[idx].reactions = counts
            posts[idx].userReaction = userMap[userId]
        }

        return (counts, userMap[userId])
    }

    public func fetchComments(postId: String, sortBy: CommentSortOrder = .top) async throws -> [CommunityComment] {
        lock.lock()
        defer { lock.unlock() }

        let list = comments[postId] ?? []
        switch sortBy {
        case .newest:
            return list.sorted { $0.createdAt > $1.createdAt }
        case .top:
            return list.sorted { $0.upvotes > $1.upvotes }
        }
    }

    public func addComment(postId: String, comment: CommunityComment) async throws -> CommunityComment {
        lock.lock()
        defer { lock.unlock() }

        var list = comments[postId] ?? []
        list.append(comment)
        comments[postId] = list

        if let idx = posts.firstIndex(where: { $0.id == postId }) {
            posts[idx].commentCount = list.count
        }

        return comment
    }

    public func deleteComment(postId: String, commentId: String, userId: String) async throws {
        lock.lock()
        defer { lock.unlock() }

        var list = comments[postId] ?? []
        list.removeAll { $0.id == commentId && $0.authorId == userId }
        comments[postId] = list

        if let idx = posts.firstIndex(where: { $0.id == postId }) {
            posts[idx].commentCount = list.count
        }
    }

    public func reportContent(report: CommunityReport) async throws {
        lock.lock()
        defer { lock.unlock() }

        reports.append(report)
    }

    public func followUser(currentUserId: String, targetUserId: String) async throws {
        lock.lock()
        defer { lock.unlock() }

        var set = following[currentUserId] ?? []
        set.insert(targetUserId)
        following[currentUserId] = set
    }

    public func unfollowUser(currentUserId: String, targetUserId: String) async throws {
        lock.lock()
        defer { lock.unlock() }

        var set = following[currentUserId] ?? []
        set.remove(targetUserId)
        following[currentUserId] = set
    }

    public func isFollowing(currentUserId: String, targetUserId: String) async throws -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return following[currentUserId]?.contains(targetUserId) ?? false
    }

    public func fetchFollowingUserIds(userId: String) async throws -> Set<String> {
        lock.lock()
        defer { lock.unlock() }

        return following[userId] ?? []
    }

    public func blockUser(currentUserId: String, targetUserId: String) async throws {
        lock.lock()
        defer { lock.unlock() }

        var set = blockedUsers[currentUserId] ?? []
        set.insert(targetUserId)
        blockedUsers[currentUserId] = set
    }

    public func fetchBlockedUserIds(currentUserId: String) async throws -> Set<String> {
        lock.lock()
        defer { lock.unlock() }

        return blockedUsers[currentUserId] ?? []
    }

    // MARK: - Default Seed Data
    public static var defaults: [CommunityPost] {
        let now = Date()
        return [
            CommunityPost(
                id: "post-1-milestone",
                authorId: "user-maya",
                authorName: "Maya Chen",
                authorRole: "deaf",
                postType: .milestone,
                title: "14-Day Streak Unlocked! 🔥",
                body: "Two weeks of daily signing with SignSpeak! The real-time camera feedback on fingerspelling has made my confidence jump significantly. Keep practicing everyone!",
                milestoneBadge: "🔥 14-Day Streak",
                createdAt: now.addingTimeInterval(-3600 * 2),
                reactions: [.fire: 24, .party: 18, .wave: 9, .ily: 15],
                commentCount: 5
            ),
            CommunityPost(
                id: "post-2-video-demo",
                authorId: "user-jordan",
                authorName: "Jordan Hayes",
                authorRole: "interpreter",
                postType: .videoDemo,
                title: "Demonstrating 'Coffee' ☕️",
                body: "A gentle reminder that the dominant hand mimics grinding beans over the stationary non-dominant fist. Notice the subtle circular wrist movement!",
                demonstrationSignName: "Coffee",
                createdAt: now.addingTimeInterval(-3600 * 5),
                reactions: [.love: 31, .power: 19, .wave: 12],
                commentCount: 8
            ),
            CommunityPost(
                id: "post-3-challenge",
                authorId: "user-elena",
                authorName: "Elena Rostova",
                authorRole: "learner",
                postType: .dailyChallenge,
                title: "Daily Challenge Complete 🤝",
                body: "Finished today's daily challenge: 'Sign 3 Greetings' with 98% average accuracy! Earned +50 XP and a badge boost toward the Century Club badge.",
                milestoneBadge: "⚡️ Daily Challenge",
                createdAt: now.addingTimeInterval(-3600 * 12),
                reactions: [.party: 14, .fire: 10, .power: 8],
                commentCount: 3
            ),
            CommunityPost(
                id: "post-4-question",
                authorId: "user-liam",
                authorName: "Liam O'Connor",
                authorRole: "learner",
                postType: .text,
                title: "Facial Expressions in ASL",
                body: "Quick question for the Deaf community members: when signing 'Where', is the brow furrow held during the entire question or only at the end? Thanks for any advice!",
                createdAt: now.addingTimeInterval(-3600 * 24),
                reactions: [.wave: 7, .love: 12],
                commentCount: 6
            )
        ]
    }

    public static func defaultComments(for postId: String) -> [CommunityComment] {
        let now = Date()
        return [
            CommunityComment(
                id: "c1-\(postId)",
                postId: postId,
                authorId: "user-jordan",
                authorName: "Jordan Hayes",
                authorRole: "interpreter",
                text: "Fantastic progress! Consistency is the number one secret to natural fluency in ASL.",
                createdAt: now.addingTimeInterval(-3600 * 1),
                upvotes: 12
            ),
            CommunityComment(
                id: "c2-\(postId)",
                postId: postId,
                authorId: "user-maya",
                authorName: "Maya Chen",
                authorRole: "deaf",
                text: "Hold the brow furrow through the entire WH-question! It signals grammar in ASL. 🤟",
                createdAt: now.addingTimeInterval(-1800),
                upvotes: 24
            )
        ]
    }
}
