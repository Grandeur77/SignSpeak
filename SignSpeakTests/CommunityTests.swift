import Testing
import Foundation
@testable import SignSpeak

@Suite("Community Tests (Phase 11)")
@MainActor
struct CommunityTests {

    // MARK: - Step 11.1 Repository & Pagination Tests

    @Test("Repository fetchPosts pagination respects page index and page limit")
    func testFetchPostsPagination() async throws {
        let repo = StubCommunityRepository()
        let page0 = try await repo.fetchPosts(page: 0, limit: 2, filter: .forYou, userId: "tester")
        let page1 = try await repo.fetchPosts(page: 1, limit: 2, filter: .forYou, userId: "tester")
        let pageOut = try await repo.fetchPosts(page: 99, limit: 2, filter: .forYou, userId: "tester")

        #expect(page0.count == 2)
        #expect(page1.count == 2)
        #expect(pageOut.isEmpty)
        #expect(page0[0].id != page1[0].id)
    }

    @Test("Single post fetch returns post with correct comment and reaction tally")
    func testFetchSinglePost() async throws {
        let repo = StubCommunityRepository()
        let post = try await repo.fetchPost(postId: "post-1-milestone", userId: "tester")

        #expect(post != nil)
        #expect(post?.authorName == "Maya Chen")
        #expect(post?.milestoneBadge == "🔥 14-Day Streak")
        #expect((post?.totalReactionCount ?? 0) > 0)
    }

    // MARK: - Step 11.3 Reaction & Comment Tests

    @Test("Reaction toggling enforces one reaction per user per post with transactional tally integrity")
    func testReactionTogglingIntegrity() async throws {
        let repo = StubCommunityRepository()
        let postId = "post-1-milestone"
        let userId = "user-alice"

        // 1. Initial state: alice has no reaction
        let postInitial = try await repo.fetchPost(postId: postId, userId: userId)
        let initialWaveCount = postInitial?.reactions[.wave] ?? 0
        let initialFireCount = postInitial?.reactions[.fire] ?? 0

        // 2. Alice adds .wave
        let result1 = try await repo.setReaction(postId: postId, userId: userId, reaction: .wave)
        #expect(result1.userReaction == .wave)
        #expect(result1.reactions[.wave] == initialWaveCount + 1)

        // 3. Alice switches reaction to .fire: wave decrements, fire increments
        let result2 = try await repo.setReaction(postId: postId, userId: userId, reaction: .fire)
        #expect(result2.userReaction == .fire)
        #expect(result2.reactions[.wave] == initialWaveCount)
        #expect(result2.reactions[.fire] == initialFireCount + 1)

        // 4. Alice taps .fire again to toggle off: fire decrements, userReaction becomes nil
        let result3 = try await repo.setReaction(postId: postId, userId: userId, reaction: .fire)
        #expect(result3.userReaction == nil)
        #expect(result3.reactions[.fire] == initialFireCount)
    }

    @Test("Comments can be added, sorted by newest or top, and deleted by author")
    func testCommentsSortingAndDeletion() async throws {
        let repo = StubCommunityRepository()
        let postId = "post-test-comments"
        let dummyPost = CommunityPost(
            id: postId,
            authorId: "post-author",
            authorName: "Post Author",
            body: "Testing comments functionality"
        )
        _ = try await repo.createPost(userId: "post-author", post: dummyPost)

        let c1 = CommunityComment(
            id: "c-1",
            postId: postId,
            authorId: "user-bob",
            authorName: "Bob",
            text: "First comment",
            createdAt: Date().addingTimeInterval(-100),
            upvotes: 5
        )
        let c2 = CommunityComment(
            id: "c-2",
            postId: postId,
            authorId: "user-alice",
            authorName: "Alice",
            text: "Second comment with more upvotes",
            createdAt: Date(),
            upvotes: 20
        )

        _ = try await repo.addComment(postId: postId, comment: c1)
        _ = try await repo.addComment(postId: postId, comment: c2)

        // Sort by newest: c2 first
        let newest = try await repo.fetchComments(postId: postId, sortBy: .newest)
        #expect(newest.first?.id == "c-2")

        // Sort by top upvotes: c2 first
        let top = try await repo.fetchComments(postId: postId, sortBy: .top)
        #expect(top.first?.id == "c-2")
        #expect(top.first?.upvotes == 20)

        // Alice deletes own comment
        try await repo.deleteComment(postId: postId, commentId: "c-2", userId: "user-alice")
        let afterDelete = try await repo.fetchComments(postId: postId, sortBy: .newest)
        #expect(!afterDelete.contains(where: { $0.id == "c-2" }))

        // Bob cannot delete non-owned comments (simulate unauthorized attempt)
        try await repo.deleteComment(postId: postId, commentId: "c-1", userId: "impostor")
        let afterFailedDelete = try await repo.fetchComments(postId: postId, sortBy: .newest)
        #expect(afterFailedDelete.contains(where: { $0.id == "c-1" }))
    }

    // MARK: - Step 11.2 & 11.4 Follow, Block, Friends Filter, and Reporting

    @Test("Follow graph properly populates Friends feed tab")
    func testFollowAndFriendsFilter() async throws {
        let repo = StubCommunityRepository()
        let currentUserId = "my-user-id"
        let followedAuthorId = "user-maya" // Maya Chen has post-1-milestone

        // 1. Without following, Maya's post does NOT show in friends feed
        let friendsBefore = try await repo.fetchPosts(page: 0, limit: 10, filter: .friends, userId: currentUserId)
        #expect(!friendsBefore.contains(where: { $0.authorId == followedAuthorId }))

        // 2. Follow Maya
        try await repo.followUser(currentUserId: currentUserId, targetUserId: followedAuthorId)
        let isFollowing = try await repo.isFollowing(currentUserId: currentUserId, targetUserId: followedAuthorId)
        #expect(isFollowing == true)

        let followingList = try await repo.fetchFollowingUserIds(userId: currentUserId)
        #expect(followingList.contains(followedAuthorId))

        // 3. Maya's post now appears in friends feed
        let friendsAfter = try await repo.fetchPosts(page: 0, limit: 10, filter: .friends, userId: currentUserId)
        #expect(friendsAfter.contains(where: { $0.authorId == followedAuthorId }))

        // 4. Unfollow Maya
        try await repo.unfollowUser(currentUserId: currentUserId, targetUserId: followedAuthorId)
        let friendsAfterUnfollow = try await repo.fetchPosts(page: 0, limit: 10, filter: .friends, userId: currentUserId)
        #expect(!friendsAfterUnfollow.contains(where: { $0.authorId == followedAuthorId }))
    }

    @Test("Blocking a user removes their posts from feed")
    func testBlockUserFiltersFeed() async throws {
        let repo = StubCommunityRepository()
        let currentUserId = "my-user-id"
        let blockedAuthorId = "user-jordan" // Jordan has post-2-video-demo

        let feedBefore = try await repo.fetchPosts(page: 0, limit: 10, filter: .forYou, userId: currentUserId)
        #expect(feedBefore.contains(where: { $0.authorId == blockedAuthorId }))

        try await repo.blockUser(currentUserId: currentUserId, targetUserId: blockedAuthorId)
        let blockedList = try await repo.fetchBlockedUserIds(currentUserId: currentUserId)
        #expect(blockedList.contains(blockedAuthorId))

        let feedAfter = try await repo.fetchPosts(page: 0, limit: 10, filter: .forYou, userId: currentUserId)
        #expect(!feedAfter.contains(where: { $0.authorId == blockedAuthorId }))
    }

    @Test("Content reports are recorded successfully")
    func testReportContent() async throws {
        let repo = StubCommunityRepository()
        let report = CommunityReport(
            reporterId: "user-reporter",
            targetId: "post-1-milestone",
            targetType: "post",
            reason: .offensive,
            details: "Contains inappropriate wording"
        )
        try await repo.reportContent(report: report)
        // If no error thrown, passes.
    }

    // MARK: - Step 11.4 Milestone Engine Tests

    @Test("Milestone engine generates streak milestone post only for threshold values and only once")
    func testMilestoneEngineStreakPublishing() async throws {
        let suite = "test.milestone.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let engine = CommunityMilestoneEngine(userDefaults: defaults)
        let repo = StubCommunityRepository()

        // Streak 5 is not an eligible threshold (7, 14, 30, 50, 100)
        let nonEligible = try await engine.postStreakMilestoneIfNeeded(
            streak: 5,
            userId: "u1",
            userName: "Alice",
            userRole: "learner",
            repository: repo
        )
        #expect(nonEligible == nil)

        // Streak 7 triggers a milestone post
        let post7 = try await engine.postStreakMilestoneIfNeeded(
            streak: 7,
            userId: "u1",
            userName: "Alice",
            userRole: "learner",
            repository: repo
        )
        #expect(post7 != nil)
        #expect(post7?.milestoneBadge == "🔥 7-Day Streak")
        #expect(post7?.title == "7-Day Practice Streak! 🔥")

        // Triggering streak 7 again must NOT produce a duplicate
        let post7Duplicate = try await engine.postStreakMilestoneIfNeeded(
            streak: 7,
            userId: "u1",
            userName: "Alice",
            userRole: "learner",
            repository: repo
        )
        #expect(post7Duplicate == nil)
    }

    @Test("Milestone engine respects shareMilestonesToCommunity privacy opt-out")
    func testMilestoneEnginePrivacyOptOut() async throws {
        let suite = "test.milestone.privacy.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        // Disable sharing
        defaults.set(false, forKey: "shareMilestonesToCommunity")

        let engine = CommunityMilestoneEngine(userDefaults: defaults)
        let repo = StubCommunityRepository()

        #expect(engine.isSharingAllowed == false)

        let post = try await engine.postStreakMilestoneIfNeeded(
            streak: 14,
            userId: "u1",
            userName: "Alice",
            userRole: "learner",
            repository: repo
        )
        #expect(post == nil)

        let alphabetPost = try await engine.postAlphabetMasteryIfNeeded(
            userId: "u1",
            userName: "Alice",
            userRole: "learner",
            repository: repo
        )
        #expect(alphabetPost == nil)
    }

    @Test("Alphabet and daily challenge milestones publish exactly once")
    func testAlphabetAndDailyChallengeMilestones() async throws {
        let suite = "test.milestone.challenges.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let engine = CommunityMilestoneEngine(userDefaults: defaults)
        let repo = StubCommunityRepository()

        // Alphabet
        let p1 = try await engine.postAlphabetMasteryIfNeeded(
            userId: "u2",
            userName: "Bob",
            userRole: "learner",
            repository: repo
        )
        #expect(p1 != nil)
        #expect(p1?.milestoneBadge == "🔤 Alphabet Master")

        let p1Dup = try await engine.postAlphabetMasteryIfNeeded(
            userId: "u2",
            userName: "Bob",
            userRole: "learner",
            repository: repo
        )
        #expect(p1Dup == nil)

        // Daily Challenge
        let c1 = try await engine.postDailyChallengeIfNeeded(
            challengeTitle: "Finger Spell 5 Words",
            userId: "u2",
            userName: "Bob",
            userRole: "learner",
            repository: repo
        )
        #expect(c1 != nil)
        #expect(c1?.milestoneBadge == "⚡️ Daily Challenge")

        let c1Dup = try await engine.postDailyChallengeIfNeeded(
            challengeTitle: "Finger Spell 5 Words",
            userId: "u2",
            userName: "Bob",
            userRole: "learner",
            repository: repo
        )
        #expect(c1Dup == nil)
    }

    // MARK: - Step 11.2 ViewModel & Composer Moderation Tests

    @Test("ViewModel validates composer text length and inappropriate language")
    @MainActor
    func testViewModelComposerModeration() async {
        let vm = CommunityFeedViewModel()

        // Empty text is invalid
        vm.composerText = "   "
        #expect(vm.isComposerValid == false)

        // Valid text
        vm.composerText = "Just learned numbers 1 to 10 in ASL!"
        #expect(vm.isComposerValid == true)
        #expect(vm.remainingCharacters == 280 - vm.composerText.count)

        // Profanity / slur filter blocks publishing
        vm.composerText = "This is a spam message with offensive badword"
        #expect(vm.isComposerValid == false)
        #expect(vm.composerErrorMessage != nil)

        // Over 280 characters is invalid
        vm.composerText = String(repeating: "A", count: 281)
        #expect(vm.isComposerValid == false)
    }

    @Test("ViewModel formats relative timestamps cleanly")
    func testViewModelRelativeTimeFormatting() {
        let vm = CommunityFeedViewModel()
        let now = Date()

        #expect(vm.relativeTimeString(from: now.addingTimeInterval(-10)) == "Just now")
        #expect(vm.relativeTimeString(from: now.addingTimeInterval(-180)) == "3m ago")
        #expect(vm.relativeTimeString(from: now.addingTimeInterval(-7200)) == "2h ago")
        #expect(vm.relativeTimeString(from: now.addingTimeInterval(-86400 * 3)) == "3d ago")
    }

    @Test("ViewModel loadPosts populates posts and toggleReaction updates post inline")
    func testViewModelLoadAndReact() async {
        let repo = StubCommunityRepository()
        let vm = CommunityFeedViewModel(communityRepository: repo, userId: "vm-tester")

        await vm.loadPosts(reset: true)
        #expect(!vm.posts.isEmpty)

        guard let firstPost = vm.posts.first else {
            Issue.record("Expected posts to be populated")
            return
        }

        let initialParty = firstPost.reactions[.party] ?? 0
        await vm.toggleReaction(postId: firstPost.id, reaction: .party)

        if let updatedPost = vm.posts.first(where: { $0.id == firstPost.id }) {
            #expect(updatedPost.userReaction == .party)
            #expect(updatedPost.reactions[.party] == initialParty + 1)
        } else {
            Issue.record("Updated post not found")
        }
    }
}
