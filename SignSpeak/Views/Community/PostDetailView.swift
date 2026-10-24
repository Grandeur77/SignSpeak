import SwiftUI

/// Screen 47: Post Detail & Comments view (`47-post-detail-comments`).
/// Displays full post content, reaction pills with React Sheet launcher,
/// sorted comments (Top / Newest), add and delete own comments, and post sharing.
public struct PostDetailView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    public let initialPost: CommunityPost
    @State private var post: CommunityPost
    @State private var comments: [CommunityComment] = []
    @State private var sortOrder: CommentSortOrder = .top
    @State private var newCommentText: String = ""
    @State private var isShowingReactionPicker = false
    @State private var isSubmittingComment = false
    @State private var commentErrorMessage: String? = nil

    public init(post: CommunityPost) {
        self.initialPost = post
        self._post = State(initialValue: post)
    }

    private var currentUserId: String {
        dependencies.authService.currentUserId ?? "guest"
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Theme.Spacing.l) {
                    // MARK: - Post Header & Body Card
                    postHeroCard

                    // MARK: - Comments Header & Sorting
                    commentsHeaderBar

                    // MARK: - Comments List
                    if comments.isEmpty {
                        emptyCommentsView
                    } else {
                        VStack(spacing: Theme.Spacing.m) {
                            ForEach(comments) { comment in
                                commentRow(comment)
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, Theme.Spacing.m)
            }

            // MARK: - Bottom Comment Composer
            commentInputBar
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: "\(post.authorName) on SignSpeak: \(post.body)") {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.brandTurquoise)
                }
            }
        }
        .task {
            await loadComments()
        }
        .sheet(isPresented: $isShowingReactionPicker) {
            ReactionPickerSheetView(post: post) { reaction in
                Task {
                    let updated = try? await dependencies.communityRepository.setReaction(
                        postId: post.id,
                        userId: currentUserId,
                        reaction: reaction
                    )
                    if let updated {
                        post.reactions = updated.reactions
                        post.userReaction = updated.userReaction
                    }
                }
            }
        }
    }

    // MARK: - Post Hero Card
    private var postHeroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author row
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.brandTurquoise.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(String(post.authorName.prefix(1)))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.brandTurquoise)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(post.authorName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.textPrimary)

                        roleBadge(post.authorRole)
                    }

                    Text(post.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()
            }

            // Milestone Banner if applicable
            if let badge = post.milestoneBadge {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.brandNavy)
                    Text(badge)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.brandNavy)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.brandYellow, in: Capsule())
            }

            // Post body
            Text(post.body)
                .font(.system(size: 15))
                .foregroundStyle(Color.textPrimary)
                .lineSpacing(4)

            // Video Demo card if any
            if let signName = post.demonstrationSignName {
                HStack(spacing: 12) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.brandTurquoise)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Demonstration Clip: '\(signName)'")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                        Text("Tap to review motion in the dictionary")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                }
                .padding(Theme.Spacing.m)
                .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 10))
            }

            Divider()

            // Reaction Pills Row & React Button
            HStack(spacing: 8) {
                Button {
                    isShowingReactionPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.bubble")
                            .font(.system(size: 12, weight: .bold))
                        Text("React")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Color.brandTurquoise)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.brandTurquoise.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(CommunityReactionType.allCases) { reaction in
                            if let count = post.reactions[reaction], count > 0 {
                                let isSelected = post.userReaction == reaction

                                Button {
                                    Task {
                                        let updated = try? await dependencies.communityRepository.setReaction(
                                            postId: post.id,
                                            userId: currentUserId,
                                            reaction: reaction
                                        )
                                        if let updated {
                                            post.reactions = updated.reactions
                                            post.userReaction = updated.userReaction
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(reaction.emoji)
                                            .font(.system(size: 12))
                                        Text("\(count)")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(isSelected ? Color.brandNavy : Color.textPrimary)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(
                                        isSelected ? Color.brandYellow : Color.appBackground,
                                        in: Capsule()
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .padding(Theme.Spacing.l)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    // MARK: - Comments Header Bar
    private var commentsHeaderBar: some View {
        HStack {
            Text("Comments (\(comments.count))")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            Spacer()

            Picker("Sort", selection: $sortOrder) {
                ForEach(CommentSortOrder.allCases) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.brandTurquoise)
            .onChange(of: sortOrder) { _, _ in
                Task { await loadComments() }
            }
        }
    }

    // MARK: - Comments Empty View
    private var emptyCommentsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 32))
                .foregroundStyle(Color.textSecondary)
            Text("No comments yet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
            Text("Be the first to leave an encouraging message!")
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
    }

    // MARK: - Comment Row
    private func commentRow(_ comment: CommunityComment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.brandTurquoise.opacity(0.18))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Text(String(comment.authorName.prefix(1)))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.brandTurquoise)
                    }

                Text(comment.authorName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                roleBadge(comment.authorRole)

                Spacer()

                Text(comment.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)

                // Delete own comment button
                if comment.authorId == currentUserId {
                    Button {
                        Task {
                            try? await dependencies.communityRepository.deleteComment(
                                postId: post.id,
                                commentId: comment.id,
                                userId: currentUserId
                            )
                            comments.removeAll { $0.id == comment.id }
                            post.commentCount = max(0, post.commentCount - 1)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.danger)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(comment.text)
                .font(.system(size: 13))
                .foregroundStyle(Color.textPrimary)
                .lineSpacing(2)
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Comment Input Bar
    private var commentInputBar: some View {
        VStack(spacing: 4) {
            if let commentErrorMessage {
                Text(commentErrorMessage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Spacing.l)
            }

            HStack(spacing: 10) {
                TextField("Add an encouraging comment…", text: $newCommentText)
                    .font(.system(size: 14))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.cardBackground, in: Capsule())

                Button {
                    Task { await submitComment() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(newCommentText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.textSecondary.opacity(0.3) : Color.brandTurquoise)
                            .frame(width: 38, height: 38)

                        if isSubmittingComment {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.brandNavy)
                        }
                    }
                }
                .disabled(newCommentText.trimmingCharacters(in: .whitespaces).isEmpty || isSubmittingComment)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, 8)
            .background(Color.appBackground)
        }
    }

    // MARK: - Role Badge
    private func roleBadge(_ role: String) -> some View {
        Text(role.capitalized)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(role == "deaf" ? Color.brandNavy : Color.brandTurquoise)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                role == "deaf" ? Color.brandYellow : Color.brandTurquoise.opacity(0.15),
                in: Capsule()
            )
    }

    // MARK: - Actions
    private func loadComments() async {
        if let list = try? await dependencies.communityRepository.fetchComments(postId: post.id, sortBy: sortOrder) {
            self.comments = list
        }
    }

    private func submitComment() async {
        commentErrorMessage = nil
        let text = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Moderate prohibited words
        let prohibited = ["hate", "spam", "idiot", "fuck", "shit"]
        for p in prohibited {
            if text.lowercased().contains(p) {
                commentErrorMessage = "Comment contains inappropriate words."
                return
            }
        }

        isSubmittingComment = true
        defer { isSubmittingComment = false }

        let profile = try? await dependencies.userProfileRepository.fetchProfile(userId: currentUserId)
        let name = profile?.displayName ?? "Learner"
        let role = profile?.role ?? "learner"

        let comment = CommunityComment(
            id: UUID().uuidString,
            postId: post.id,
            authorId: currentUserId,
            authorName: name,
            authorRole: role,
            text: text,
            createdAt: Date(),
            upvotes: 0
        )

        if let added = try? await dependencies.communityRepository.addComment(postId: post.id, comment: comment) {
            comments.insert(added, at: 0)
            post.commentCount += 1
            newCommentText = ""
        }
    }
}
