import SwiftUI

/// Notifications Inbox view (`21-notifications-inbox`).
/// Displays incoming and recent notifications categorized by Milestones, Community, and Learning,
/// grouped into Today and Earlier with mark-all-read and deep-linking actions.
public struct NotificationsInboxView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Environment(DeepLinkRouter.self) private var deepLinkRouter: DeepLinkRouter?

    @State private var viewModel: NotificationsInboxViewModel?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            if let vm = viewModel {
                // Top Filter Header Bar
                filterHeaderBar(vm)

                // Main Content List
                if vm.isLoading && vm.notifications.isEmpty {
                    VStack {
                        Spacer()
                        ProgressView("Loading notifications…")
                            .tint(Color.brandTurquoise)
                            .foregroundStyle(Color.textSecondary)
                        Spacer()
                    }
                } else if vm.filteredNotifications.isEmpty {
                    emptyStateView(vm)
                } else {
                    notificationsListView(vm)
                }
            } else {
                ProgressView()
                    .tint(Color.brandTurquoise)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let vm = viewModel, vm.unreadCount > 0 {
                    Button("Mark all read") {
                        Task {
                            await vm.markAllAsRead()
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brandTurquoise)
                }
            }
        }
        .task {
            if viewModel == nil {
                let vm = NotificationsInboxViewModel(
                    inboxRepository: dependencies.inboxRepository,
                    userId: dependencies.authService.currentUserId ?? "guest",
                    dateProvider: dependencies.dateProvider
                )
                viewModel = vm
                await vm.loadNotifications()
            }
        }
    }

    // MARK: - Filter Bar

    private func filterHeaderBar(_ vm: NotificationsInboxViewModel) -> some View {
        HStack(spacing: 8) {
            ForEach(InboxFilter.allCases) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        vm.selectedFilter = filter
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(filter.rawValue)
                            .font(.system(size: 13, weight: .semibold))

                        if filter == .unread && vm.unreadCount > 0 {
                            Text("\(vm.unreadCount)")
                                .font(.system(size: 11, weight: .heavy))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    vm.selectedFilter == filter ? Color.black.opacity(0.3) : Color.brandTurquoise,
                                    in: Capsule()
                                )
                                .foregroundStyle(vm.selectedFilter == filter ? Color.black : Color.white)
                        }
                    }
                    .foregroundStyle(vm.selectedFilter == filter ? Color.black : Color.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        vm.selectedFilter == filter ? Color.brandTurquoise : Color.cardBackground,
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, 10)
        .background(Color.appBackground)
    }

    // MARK: - Notifications List (Today & Earlier)

    private func notificationsListView(_ vm: NotificationsInboxViewModel) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // 1. Today's Notifications
                if !vm.todayNotifications.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader(title: "TODAY", count: vm.todayNotifications.count)

                        ForEach(vm.todayNotifications) { item in
                            notificationCard(item, vm: vm)
                        }
                    }
                }

                // 2. Earlier Notifications
                if !vm.earlierNotifications.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader(title: "EARLIER", count: vm.earlierNotifications.count)

                        ForEach(vm.earlierNotifications) { item in
                            notificationCard(item, vm: vm)
                        }
                    }
                }

                Spacer(minLength: 30)
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.top, 6)
        }
        .refreshable {
            await vm.loadNotifications()
        }
    }

    private func sectionHeader(title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Color.textSecondary)
                .tracking(0.8)

            Text("(\(count))")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.textSecondary.opacity(0.7))

            Spacer()
        }
        .padding(.top, 6)
    }

    // MARK: - Notification Card

    private func notificationCard(_ item: InboxNotificationItem, vm: NotificationsInboxViewModel) -> some View {
        Button {
            if let router = deepLinkRouter {
                Task {
                    await vm.handleNotificationTap(item, router: router)
                    dismiss()
                }
            } else {
                Task {
                    await vm.markAsRead(item)
                }
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Category Icon Badge
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(item.category.accentColor.opacity(0.18))
                        .frame(width: 42, height: 42)

                    Image(systemName: item.category.iconName)
                        .font(.system(size: 18))
                        .foregroundStyle(item.category.accentColor)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.title)
                            .font(.system(size: 15, weight: item.isRead ? .semibold : .bold))
                            .foregroundStyle(Color.white)
                            .lineLimit(1)

                        Spacer()

                        // Relative timestamp
                        Text(item.relativeTimeString)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textSecondary)
                    }

                    Text(item.body)
                        .font(.system(size: 13))
                        .foregroundStyle(item.isRead ? Color.textSecondary : Color.white.opacity(0.9))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let deepLink = item.actionDeepLink {
                        HStack(spacing: 4) {
                            Text(actionButtonTitle(for: deepLink))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(item.category.accentColor)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(item.category.accentColor)
                        }
                        .padding(.top, 4)
                    }
                }

                // Unread Blue Dot
                if !item.isRead {
                    Circle()
                        .fill(Color.brandTurquoise)
                        .frame(width: 8, height: 8)
                        .padding(.top, 4)
                }
            }
            .padding(14)
            .background(
                item.isRead ? Color.cardBackground : Color.cardBackground.opacity(0.9),
                in: RoundedRectangle(cornerRadius: Theme.Radius.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(
                        item.isRead ? Color.white.opacity(0.06) : Color.brandTurquoise.opacity(0.35),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task {
                    await vm.deleteNotification(item)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func actionButtonTitle(for deepLink: String) -> String {
        if deepLink.contains("learn") || deepLink.contains("practice") {
            return "Practise Now"
        } else if deepLink.contains("community") {
            return "View in Community"
        } else {
            return "View Details"
        }
    }

    // MARK: - Empty State View

    private func emptyStateView(_ vm: NotificationsInboxViewModel) -> some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.brandTurquoise.opacity(0.12))
                    .frame(width: 84, height: 84)

                Image(systemName: "bell.slash.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.brandTurquoise)
            }

            VStack(spacing: 6) {
                Text(vm.selectedFilter == .unread ? "No Unread Notifications" : "All Caught Up!")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white)

                Text(vm.selectedFilter == .unread
                     ? "You have read all your notifications."
                     : "Notifications about your streak, lessons, and community will appear here.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }
}
