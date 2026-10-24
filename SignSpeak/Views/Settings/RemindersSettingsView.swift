import SwiftUI

/// Reminders & Notifications settings screen (`51-reminders-notifications`).
/// Controls daily practice scheduling, active days, evening streak preservation,
/// app alerts toggles (streak, community, new lessons, weekly reports), and live notification preview.
public struct RemindersSettingsView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: RemindersViewModel?
    @State private var practiceDate: Date = Date()
    @State private var eveningDate: Date = Date()

    public init() {}

    public var body: some View {
        ScrollView {
            if let vm = viewModel {
                VStack(spacing: Theme.Spacing.l) {
                    // 1. Permission Warning Banner if Denied
                    if vm.isPermissionDenied {
                        permissionDeniedBanner
                    } else if vm.authorizationStatus == .notDetermined {
                        permissionPrimerBanner(vm)
                    }

                    // 2. Interactive Notification Preview
                    notificationPreviewCard(vm)

                    // 3. Daily Practice Reminder Card
                    dailyPracticeCard(vm)

                    // 4. Evening Review & Streak Preservation Card
                    eveningReviewCard(vm)

                    // 5. App Alerts & Categories Card
                    appAlertsCard(vm)

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.top, Theme.Spacing.m)
            } else {
                ProgressView()
                    .tint(Color.brandTurquoise)
                    .padding(.top, 40)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Reminders & Alerts")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                let vm = RemindersViewModel(
                    notificationService: dependencies.notificationService,
                    userProfileRepository: dependencies.userProfileRepository,
                    userId: dependencies.authService.currentUserId ?? "guest"
                )
                viewModel = vm
                await vm.onAppear()
                practiceDate = vm.practiceTimeDate
                eveningDate = vm.eveningTimeDate
            }
        }
    }

    // MARK: - 1. Permission Banners

    private var permissionDeniedBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.danger)

            VStack(alignment: .leading, spacing: 3) {
                Text("Notifications are Disabled")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white)

                Text("SignSpeak cannot deliver practice reminders. Please enable notifications in iOS Settings.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.brandTurquoise)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.12), in: Capsule())
        }
        .padding(Theme.Spacing.m)
        .background(Color.danger.opacity(0.18), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Color.danger.opacity(0.35), lineWidth: 1)
        )
    }

    private func permissionPrimerBanner(_ vm: RemindersViewModel) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.brandYellow)

            VStack(alignment: .leading, spacing: 3) {
                Text("Enable Reminders")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white)

                Text("Allow SignSpeak to send daily sign practice reminders and streak alerts.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            Button("Allow") {
                Task {
                    await vm.requestPermission()
                }
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color(red: 11/255, green: 42/255, blue: 74/255))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.brandTurquoise, in: Capsule())
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    // MARK: - 2. Notification Preview Card

    private func notificationPreviewCard(_ vm: RemindersViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("NOTIFICATION PREVIEW")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.brandTurquoise)
                    .tracking(0.8)

                Spacer()

                if vm.showTestAlertBanner {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.brandYellow)
                        Text("Sent!")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.brandYellow)
                    }
                    .transition(.opacity)
                }
            }

            // Preview Type Selector Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ReminderPreviewType.allCases) { type in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                vm.selectedPreviewType = type
                            }
                        } label: {
                            Text(type.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(vm.selectedPreviewType == type ? Color.black : Color.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    vm.selectedPreviewType == type ? Color.brandTurquoise : Color.white.opacity(0.1),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Realistic iOS Notification Mockup
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.brandNavy)
                            .frame(width: 20, height: 20)
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.brandTurquoise)
                    }

                    Text("SignSpeak")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.85))

                    Spacer()

                    Text("now")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.4))
                }

                Text(vm.selectedPreviewType.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white)

                Text(vm.selectedPreviewType.sampleBody)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .lineLimit(2)
            }
            .padding(14)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )

            // Send Test Notification Button
            Button {
                Task {
                    await vm.sendTestNotification()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 12))
                    Text("Send Test Preview Notification")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color.brandTurquoise)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Color.brandTurquoise.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    // MARK: - 3. Daily Practice Reminder Card

    private func dailyPracticeCard(_ vm: RemindersViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header with Master Toggle
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(Color.brandTurquoise)
                    Text("Daily Practice Reminder")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.white)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { vm.settings.enabled },
                    set: { vm.setDailyReminderEnabled($0) }
                ))
                .labelsHidden()
                .tint(Color.brandTurquoise)
            }

            if vm.settings.enabled {
                Divider().background(Color.white.opacity(0.1))

                // Time Picker
                HStack {
                    Text("Reminder Time")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textSecondary)

                    Spacer()

                    DatePicker(
                        "",
                        selection: $practiceDate,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .colorScheme(.dark)
                    .onChange(of: practiceDate) { _, newDate in
                        let hour = Calendar.current.component(.hour, from: newDate)
                        let minute = Calendar.current.component(.minute, from: newDate)
                        vm.setPracticeTime(hour: hour, minute: minute)
                    }
                }

                Divider().background(Color.white.opacity(0.1))

                // Active Days Multi-Select Chips
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Days")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textSecondary)

                    HStack(spacing: 6) {
                        let days = [
                            (1, "S", "Sunday"),
                            (2, "M", "Monday"),
                            (3, "T", "Tuesday"),
                            (4, "W", "Wednesday"),
                            (5, "T", "Thursday"),
                            (6, "F", "Friday"),
                            (7, "S", "Saturday")
                        ]

                        ForEach(days, id: \.0) { day in
                            let isSelected = vm.settings.activeDays.contains(day.0)
                            Button {
                                vm.toggleDay(day.0)
                            } label: {
                                Text(day.1)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(isSelected ? Color.black : Color.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 38)
                                    .background(
                                        isSelected ? Color.brandTurquoise : Color.white.opacity(0.1),
                                        in: RoundedRectangle(cornerRadius: 10)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(day.2)
                        }
                    }
                }
            }
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    // MARK: - 4. Evening Review & Streak Preservation Card

    private func eveningReviewCard(_ vm: RemindersViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(Color.brandYellow)
                    Text("Evening Streak Check-in")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.white)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { vm.settings.eveningEnabled },
                    set: { vm.setEveningEnabled($0) }
                ))
                .labelsHidden()
                .tint(Color.brandYellow)
            }

            Text("A gentle evening nudge to protect your streak before midnight if you haven't completed your daily sign.")
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)

            if vm.settings.eveningEnabled {
                Divider().background(Color.white.opacity(0.1))

                HStack {
                    Text("Evening Time")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textSecondary)

                    Spacer()

                    DatePicker(
                        "",
                        selection: $eveningDate,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .colorScheme(.dark)
                    .onChange(of: eveningDate) { _, newDate in
                        let hour = Calendar.current.component(.hour, from: newDate)
                        let minute = Calendar.current.component(.minute, from: newDate)
                        vm.setEveningTime(hour: hour, minute: minute)
                    }
                }
            }
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    // MARK: - 5. App Alerts & Categories Card

    private func appAlertsCard(_ vm: RemindersViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("APP NOTIFICATIONS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.brandTurquoise)
                .tracking(0.8)

            VStack(spacing: 0) {
                alertToggleRow(
                    icon: "flame.fill",
                    color: Color.brandYellow,
                    title: "Streak-at-Risk Alerts",
                    subtitle: "Receive warnings when your streak is about to freeze or expire",
                    isOn: Binding(
                        get: { vm.settings.streakAlertsEnabled },
                        set: { vm.toggleStreakAlerts($0) }
                    )
                )

                Divider().padding(.leading, 44).background(Color.white.opacity(0.08))

                alertToggleRow(
                    icon: "bubble.left.and.bubble.right.fill",
                    color: Color.brandTurquoise,
                    title: "Community Reactions",
                    subtitle: "Get notified when someone reacts or replies to your sign requests",
                    isOn: Binding(
                        get: { vm.settings.communityReactionsEnabled },
                        set: { vm.toggleCommunityReactions($0) }
                    )
                )

                Divider().padding(.leading, 44).background(Color.white.opacity(0.08))

                alertToggleRow(
                    icon: "sparkles.rectangle.stack.fill",
                    color: Color.brandNavy,
                    title: "New Lessons & Signs",
                    subtitle: "Discover new vocabulary packs and learning achievements",
                    isOn: Binding(
                        get: { vm.settings.newLessonsEnabled },
                        set: { vm.toggleNewLessons($0) }
                    )
                )

                Divider().padding(.leading, 44).background(Color.white.opacity(0.08))

                alertToggleRow(
                    icon: "chart.bar.fill",
                    color: Color.green,
                    title: "Weekly Progress Report",
                    subtitle: "Every Sunday, see your signs mastered and accuracy improvements",
                    isOn: Binding(
                        get: { vm.settings.weeklyReportEnabled },
                        set: { vm.toggleWeeklyReport($0) }
                    )
                )
            }
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private func alertToggleRow(
        icon: String,
        color: Color,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.brandTurquoise)
        }
        .padding(.vertical, 10)
    }
}
