import SwiftUI

/// Screen 48: Community Feed view (`48-community-feed`).
/// Features real-time feed with For You / Friends tabs, milestone cards, text posts,
/// daily-challenge posts, author avatar and role badges, relative times, pull to refresh,
/// infinite scroll, loading skeleton, empty states, composer, reaction pills, and streak nudge banner.
public struct CommunityFeedView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(DeepLinkRouter.self) private var deepLinkRouter: DeepLinkRouter?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorSchemeContrast) private var contrast

    @State private var viewModel: CommunityFeedViewModel

    public init(viewModel: CommunityFeedViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? CommunityFeedViewModel())
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Tab Filter Bar (For You / Friends)
                tabFilterBar

                // MARK: - Main Feed Content
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.m) {
                        // Streak Nudge Banner
                        streakNudgeBanner

                        // Feed List or Skeleton / Empty State
                        if viewModel.isLoading && viewModel.posts.isEmpty {
                            loadingSkeleton
                        } else if viewModel.posts.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(viewModel.posts) { post in
                                postCard(post)
                                    .onAppear {
                                        if post.id == viewModel.posts.last?.id {
                                            Task { await viewModel.loadMore() }
                                        }
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.vertical, Theme.Spacing.m)
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.isShowingComposer = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.pencil")
                            Text("Share")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.brandTurquoise)
                    }
                }
            }
            .task {
                let uid = dependencies.authService.currentUserId ?? "guest"
                viewModel.update(
                    communityRepository: dependencies.communityRepository,
                    userProfileRepository: dependencies.userProfileRepository,
                    userId: uid,
                    dateProvider: dependencies.dateProvider
                )
                await viewModel.loadData()
            }
            .sheet(isPresented: $viewModel.isShowingComposer) {
                CommunityComposerView(viewModel: viewModel)
            }
            .sheet(item: $viewModel.activeReactionPickerPost) { post in
                ReactionPickerSheetView(post: post) { reaction in
                    Task {
                        await viewModel.toggleReaction(postId: post.id, reaction: reaction)
                    }
                }
            }
            .sheet(item: $viewModel.activeReportPost) { post in
                ReportSheetView(post: post) { reason, details, alsoBlock in
                    Task {
                        let uid = dependencies.authService.currentUserId ?? "guest"
                        let report = CommunityReport(
                            reporterId: uid,
                            targetId: post.id,
                            targetType: "post",
                            reason: reason,
                            details: details
                        )
                        try? await dependencies.communityRepository.reportContent(report: report)
                        if alsoBlock {
                            await viewModel.blockUser(targetUserId: post.authorId)
                        }
                    }
                }
            }
            .navigationDestination(item: $viewModel.activeDetailPost) { post in
                PostDetailView(post: post)
            }
        }
    }

    // MARK: - Tab Filter Bar
    private var tabFilterBar: some View {
        HStack(spacing: 0) {
            ForEach(CommunityFeedFilter.allCases) { filter in
                let isSelected = viewModel.selectedTab == filter

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedTab = filter
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(filter.rawValue)
                            .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? Color.brandTurquoise : Color.textSecondary)

                        Rectangle()
                            .fill(isSelected ? Color.brandTurquoise : Color.clear)
                            .frame(height: 2.5)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 8)
        .background(Color.cardBackground)
    }

    // MARK: - Streak Nudge Banner
    private var streakNudgeBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.brandYellow.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: "flame.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.brandYellow)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.userStreak)-Day Streak Burning! 🔥")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Text("Keep your practice active today to celebrate with friends.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            NavigationLink {
                CameraTestView()
            } label: {
                Text("Practice")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.brandNavy)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.brandYellow, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card)
                        .stroke(Color.brandYellow.opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: - Post Card
    private func postCard(_ post: CommunityPost) -> some View {
        let label = "Post by \(post.authorName), \(post.authorRole.capitalized): \(post.body). \(post.totalReactionCount) reactions, \(post.commentCount) comments."
        let strokeColor = (contrast == .increased) ? Color.textPrimary : Color.clear
        let strokeWidth: CGFloat = (contrast == .increased) ? 1.5 : 0

        return VStack(alignment: .leading, spacing: 12) {
            postAuthorRow(post)

            if let badge = post.milestoneBadge {
                postMilestoneBadge(badge)
            }

            Text(post.body)
                .font(.system(size: 14))
                .foregroundStyle(Color.textPrimary)
                .lineSpacing(3)

            if let signName = post.demonstrationSignName {
                postDemonstrationBox(signName)
            }

            Divider()

            postActionBar(post)
        }
        .padding(Theme.Spacing.l)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(strokeColor, lineWidth: strokeWidth)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityAction(named: "React to post") {
            viewModel.activeReactionPickerPost = post
        }
        .accessibilityAction(named: "View comments") {
            viewModel.activeDetailPost = post
        }
    }

    private func postAuthorRow(_ post: CommunityPost) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.brandTurquoise.opacity(0.18))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(String(post.authorName.prefix(1)))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.brandTurquoise)
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(post.authorName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.textPrimary)

                    roleBadge(post.authorRole)
                }

                Text(viewModel.relativeTimeString(from: post.createdAt))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            // Ellipsis menu
            Menu {
                Button {
                    Task { await viewModel.toggleFollow(targetUserId: post.authorId) }
                } label: {
                    Label("Follow / Unfollow", systemImage: "person.badge.plus")
                }

                Button(role: .destructive) {
                    viewModel.activeReportPost = post
                } label: {
                    Label("Report Post", systemImage: "exclamationmark.bubble")
                }

                Button(role: .destructive) {
                    Task { await viewModel.blockUser(targetUserId: post.authorId) }
                } label: {
                    Label("Block Author", systemImage: "hand.raised.slash")
                }

                if post.authorId == (dependencies.authService.currentUserId ?? "guest") {
                    Button(role: .destructive) {
                        Task { await viewModel.deletePost(postId: post.id) }
                    } label: {
                        Label("Delete Post", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 28, height: 28)
            }
        }
    }

    private func postMilestoneBadge(_ badge: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 11))
                .foregroundStyle(Color.brandNavy)
            Text(badge)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.brandNavy)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.brandYellow, in: Capsule())
    }

    private func postDemonstrationBox(_ signName: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(Color.brandTurquoise)

            VStack(alignment: .leading, spacing: 2) {
                Text("Demonstration: '\(signName)'")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Text("Tap to practice this sign")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
        }
        .padding(Theme.Spacing.m)
        .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Post Actions Bar
    private func postActionBar(_ post: CommunityPost) -> some View {
        let reactionText = post.userReaction != nil
            ? "Reaction: \(post.userReaction?.emoji ?? ""). Total reactions: \(post.totalReactionCount)"
            : "Add reaction. Current total: \(post.totalReactionCount)"

        return HStack(spacing: 12) {
            // Reaction summary & React button
            Button {
                viewModel.activeReactionPickerPost = post
            } label: {
                HStack(spacing: 5) {
                    if let userReact = post.userReaction {
                        Text(userReact.emoji)
                            .font(.system(size: 15))
                    } else {
                        Image(systemName: "hand.thumbsup")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Text("\(post.totalReactionCount)")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(post.userReaction != nil ? Color.brandTurquoise : Color.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.appBackground, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(reactionText)
            .accessibilityInputLabels(["React", "Like post"])

            // Comments button
            Button {
                viewModel.activeDetailPost = post
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 13))
                    Text("\(post.commentCount)")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.appBackground, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Comments: \(post.commentCount)")
            .accessibilityInputLabels(["Comments", "Reply"])

            Spacer()

            // Share button
            ShareLink(item: "\(post.authorName) on SignSpeak: \(post.body)") {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share post by \(post.authorName)")
            .accessibilityInputLabels(["Share", "Share post"])
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

    // MARK: - Loading Skeleton
    private var loadingSkeleton: some View {
        VStack(spacing: Theme.Spacing.m) {
            ForEach(0..<3) { _ in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.textSecondary.opacity(0.15))
                            .frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 4) {
                            Rectangle()
                                .fill(Color.textSecondary.opacity(0.15))
                                .frame(width: 120, height: 14)
                                .cornerRadius(4)
                            Rectangle()
                                .fill(Color.textSecondary.opacity(0.1))
                                .frame(width: 60, height: 10)
                                .cornerRadius(4)
                        }
                        Spacer()
                    }
                    Rectangle()
                        .fill(Color.textSecondary.opacity(0.1))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .cornerRadius(6)
                }
                .padding(Theme.Spacing.l)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            }
        }
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: viewModel.selectedTab == .friends ? "person.2.slash" : "bubble.left.and.bubble.right")
                .font(.system(size: 44))
                .foregroundStyle(Color.textSecondary)
                .padding(.top, Theme.Spacing.xl)

            Text(viewModel.selectedTab == .friends ? "No Friends Posts Yet" : "No Community Posts")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            Text(viewModel.selectedTab == .friends ? "Follow signers from the 'For You' tab to see their practice milestones here." : "Be the first to share an inspiring signing milestone!")
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.l)

            if viewModel.selectedTab == .friends {
                Button("Switch to For You") {
                    viewModel.selectedTab = .forYou
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.brandTurquoise)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
    }
}

#Preview("Community Feed View") {
    NavigationStack {
        CommunityFeedView()
    }
}
