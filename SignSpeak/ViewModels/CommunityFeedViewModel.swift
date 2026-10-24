import SwiftUI
import Foundation

/// Driving view model for Step 11.2 Community Feed (`48-community-feed`).
@Observable
@MainActor
public final class CommunityFeedViewModel {
    public var selectedTab: CommunityFeedFilter = .forYou {
        didSet {
            Task { await loadPosts(reset: true) }
        }
    }

    public var posts: [CommunityPost] = []
    public var isLoading: Bool = false
    public var isRefreshing: Bool = false
    public var userStreak: Int = 7
    public var isShowingComposer: Bool = false
    public var activeAuthorSheetPost: CommunityPost? = nil
    public var activeReportPost: CommunityPost? = nil
    public var activeReactionPickerPost: CommunityPost? = nil
    public var activeDetailPost: CommunityPost? = nil

    // Composer State
    public var composerText: String = "" {
        didSet {
            validateComposerText()
        }
    }
    public var composerMilestoneType: CommunityPostType = .text
    public var composerErrorMessage: String? = nil
    public var isPublishing: Bool = false

    private var communityRepository: any CommunityRepository
    private var userProfileRepository: any UserProfileRepository
    private var dateProvider: any DateProviding
    private var userId: String
    private var currentPage: Int = 0
    private let pageSize: Int = 20
    private var hasMorePages: Bool = true

    public let maxCharacters: Int = 280

    public var remainingCharacters: Int {
        maxCharacters - composerText.count
    }

    public var isComposerValid: Bool {
        let clean = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !clean.isEmpty && composerText.count <= maxCharacters && composerErrorMessage == nil
    }

    public init(
        communityRepository: (any CommunityRepository)? = nil,
        userProfileRepository: (any UserProfileRepository)? = nil,
        userId: String = "guest",
        dateProvider: (any DateProviding)? = nil
    ) {
        self.communityRepository = communityRepository ?? StubCommunityRepository()
        self.userProfileRepository = userProfileRepository ?? StubUserProfileRepository()
        self.userId = userId
        self.dateProvider = dateProvider ?? SystemDateProvider()
    }

    public func update(
        communityRepository: any CommunityRepository,
        userProfileRepository: any UserProfileRepository,
        userId: String,
        dateProvider: any DateProviding
    ) {
        self.communityRepository = communityRepository
        self.userProfileRepository = userProfileRepository
        self.userId = userId
        self.dateProvider = dateProvider
    }

    public func loadData() async {
        if let profile = try? await userProfileRepository.fetchProfile(userId: userId) {
            self.userStreak = profile.currentStreak
        }
        await loadPosts(reset: true)
    }

    public func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await loadPosts(reset: true)
    }

    public func loadMore() async {
        guard !isLoading && hasMorePages else { return }
        currentPage += 1
        await loadPosts(reset: false)
    }

    public func loadPosts(reset: Bool = false) async {
        if reset {
            currentPage = 0
            hasMorePages = true
            isLoading = true
        }
        defer { isLoading = false }

        do {
            let fetched = try await communityRepository.fetchPosts(
                page: currentPage,
                limit: pageSize,
                filter: selectedTab,
                userId: userId
            )
            if reset {
                self.posts = fetched
            } else {
                self.posts.append(contentsOf: fetched)
            }
            self.hasMorePages = fetched.count >= pageSize
        } catch {
            // Keep existing posts
        }
    }

    // MARK: - Post Actions
    public func toggleReaction(postId: String, reaction: CommunityReactionType) async {
        do {
            let updated = try await communityRepository.setReaction(
                postId: postId,
                userId: userId,
                reaction: reaction
            )
            if let index = posts.firstIndex(where: { $0.id == postId }) {
                posts[index].reactions = updated.reactions
                posts[index].userReaction = updated.userReaction
            }
            if activeDetailPost?.id == postId {
                activeDetailPost?.reactions = updated.reactions
                activeDetailPost?.userReaction = updated.userReaction
            }
        } catch {
            // Ignored
        }
    }

    public func toggleFollow(targetUserId: String) async {
        do {
            let currentlyFollowing = try await communityRepository.isFollowing(
                currentUserId: userId,
                targetUserId: targetUserId
            )
            if currentlyFollowing {
                try await communityRepository.unfollowUser(currentUserId: userId, targetUserId: targetUserId)
            } else {
                try await communityRepository.followUser(currentUserId: userId, targetUserId: targetUserId)
            }
            if selectedTab == .friends {
                await refresh()
            }
        } catch {}
    }

    public func isFollowing(targetUserId: String) async -> Bool {
        (try? await communityRepository.isFollowing(currentUserId: userId, targetUserId: targetUserId)) ?? false
    }

    public func blockUser(targetUserId: String) async {
        try? await communityRepository.blockUser(currentUserId: userId, targetUserId: targetUserId)
        posts.removeAll { $0.authorId == targetUserId }
    }

    public func deletePost(postId: String) async {
        try? await communityRepository.deletePost(postId: postId, userId: userId)
        posts.removeAll { $0.id == postId }
    }

    // MARK: - Composer & Word Moderation
    public func validateComposerText() {
        composerErrorMessage = nil
        let clean = composerText.lowercased()

        // Basic word filter for inappropriate or offensive language
        let prohibitedWords = ["hate", "spam", "scam", "idiot", "stupid", "fuck", "shit", "bitch", "badword"]
        for word in prohibitedWords {
            if clean.contains(word) {
                composerErrorMessage = "Please keep community discourse respectful and polite."
                return
            }
        }

        if composerText.count > maxCharacters {
            composerErrorMessage = "Post exceeds 280 characters limit."
        }
    }

    public func publishPost() async -> Bool {
        validateComposerText()
        guard isComposerValid else { return false }

        isPublishing = true
        defer { isPublishing = false }

        let profile = try? await userProfileRepository.fetchProfile(userId: userId)
        let authorName = profile?.displayName ?? "Learner"
        let authorRole = profile?.role ?? "learner"

        let badge: String? = {
            switch composerMilestoneType {
            case .milestone: return "🔥 \(userStreak)-Day Streak"
            case .dailyChallenge: return "⚡️ Daily Challenge"
            default: return nil
            }
        }()

        let newPost = CommunityPost(
            id: UUID().uuidString,
            authorId: userId,
            authorName: authorName,
            authorRole: authorRole,
            postType: composerMilestoneType,
            title: nil,
            body: composerText.trimmingCharacters(in: .whitespacesAndNewlines),
            milestoneBadge: badge,
            createdAt: dateProvider.now,
            reactions: [:],
            commentCount: 0
        )

        do {
            let created = try await communityRepository.createPost(userId: userId, post: newPost)
            posts.insert(created, at: 0)
            composerText = ""
            composerMilestoneType = .text
            composerErrorMessage = nil
            isShowingComposer = false
            return true
        } catch {
            composerErrorMessage = "Failed to publish post: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Relative Time Formatter
    public func relativeTimeString(from date: Date) -> String {
        let diff = max(0, dateProvider.now.timeIntervalSince(date))
        if diff < 60 {
            return "Just now"
        } else if diff < 3600 {
            let minutes = Int(diff / 60)
            return "\(minutes)m ago"
        } else if diff < 86400 {
            let hours = Int(diff / 3600)
            return "\(hours)h ago"
        } else if diff < 86400 * 7 {
            let days = Int(diff / 86400)
            return "\(days)d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}
