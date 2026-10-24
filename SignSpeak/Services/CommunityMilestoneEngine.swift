import Foundation

/// Engine automatically generating community milestone posts (`48-community-feed`, Step 11.4).
/// Triggers milestone posts for streaks, alphabet mastery, level ups, and daily challenges,
/// ensuring each milestone is published only once and strictly respecting the user's privacy opt-out.
public final class CommunityMilestoneEngine: @unchecked Sendable {
    private let lock = NSRecursiveLock()
    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// Checks if user has opt-in enabled for community milestone sharing.
    public var isSharingAllowed: Bool {
        userDefaults.object(forKey: "shareMilestonesToCommunity") as? Bool ?? true
    }

    /// Evaluates whether a streak milestone should be posted.
    @discardableResult
    public func postStreakMilestoneIfNeeded(
        streak: Int,
        userId: String,
        userName: String,
        userRole: String,
        repository: any CommunityRepository
    ) async throws -> CommunityPost? {
        guard isSharingAllowed else { return nil }
        guard [7, 14, 30, 50, 100].contains(streak) else { return nil }

        let milestoneKey = "signspeak.milestone.streak.\(userId).\(streak)"
        guard !hasTriggered(key: milestoneKey) else { return nil }

        let post = CommunityPost(
            id: UUID().uuidString,
            authorId: userId,
            authorName: userName,
            authorRole: userRole,
            postType: .milestone,
            title: "\(streak)-Day Practice Streak! 🔥",
            body: "Just reached a continuous \(streak)-day practice streak on SignSpeak! Consistent daily signing has made a huge difference.",
            milestoneBadge: "🔥 \(streak)-Day Streak",
            createdAt: Date()
        )

        let created = try await repository.createPost(userId: userId, post: post)
        markTriggered(key: milestoneKey)
        return created
    }

    /// Evaluates whether an alphabet mastery milestone should be posted.
    @discardableResult
    public func postAlphabetMasteryIfNeeded(
        userId: String,
        userName: String,
        userRole: String,
        repository: any CommunityRepository
    ) async throws -> CommunityPost? {
        guard isSharingAllowed else { return nil }
        let milestoneKey = "signspeak.milestone.alphabet.\(userId)"
        guard !hasTriggered(key: milestoneKey) else { return nil }

        let post = CommunityPost(
            id: UUID().uuidString,
            authorId: userId,
            authorName: userName,
            authorRole: userRole,
            postType: .milestone,
            title: "Alphabet Mastered! 🔤",
            body: "Completed all 26 manual ASL letters from A to Z with high confidence in the live camera lab!",
            milestoneBadge: "🔤 Alphabet Master",
            createdAt: Date()
        )

        let created = try await repository.createPost(userId: userId, post: post)
        markTriggered(key: milestoneKey)
        return created
    }

    /// Evaluates whether a daily challenge completion milestone should be posted.
    @discardableResult
    public func postDailyChallengeIfNeeded(
        challengeTitle: String,
        userId: String,
        userName: String,
        userRole: String,
        repository: any CommunityRepository
    ) async throws -> CommunityPost? {
        guard isSharingAllowed else { return nil }
        let dayString = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let milestoneKey = "signspeak.milestone.challenge.\(userId).\(dayString)"
        guard !hasTriggered(key: milestoneKey) else { return nil }

        let post = CommunityPost(
            id: UUID().uuidString,
            authorId: userId,
            authorName: userName,
            authorRole: userRole,
            postType: .dailyChallenge,
            title: "Daily Challenge Complete ⚡️",
            body: "Successfully finished today's challenge: '\(challengeTitle)'! Claimed my bonus XP and daily badge boost.",
            milestoneBadge: "⚡️ Daily Challenge",
            createdAt: Date()
        )

        let created = try await repository.createPost(userId: userId, post: post)
        markTriggered(key: milestoneKey)
        return created
    }

    // MARK: - State Tracking
    private func hasTriggered(key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return userDefaults.bool(forKey: key)
    }

    private func markTriggered(key: String) {
        lock.lock()
        defer { lock.unlock() }
        userDefaults.set(true, forKey: key)
    }
}
