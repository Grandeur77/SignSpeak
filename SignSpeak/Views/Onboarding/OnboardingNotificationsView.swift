import SwiftUI

/// Practice reminders & notification primer screen (`14-permission-notifications-stay-on-track`).
public struct OnboardingNotificationsView: View {
    @Bindable var viewModel: OnboardingViewModel

    private let weekDays: [(name: String, id: Int)] = [
        ("M", 2), ("T", 3), ("W", 4), ("T", 5), ("F", 6), ("S", 7), ("S", 1)
    ]

    public init(viewModel: OnboardingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                // Top Bar
                HStack {
                    Button {
                        viewModel.goBack()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.appBody)
                        .foregroundStyle(Color.textSecondary)
                    }

                    Spacer()

                    Button("Skip") {
                        viewModel.skip()
                    }
                    .font(.appBody)
                    .foregroundStyle(Color.textSecondary)
                }
                .padding(.horizontal, Theme.Spacing.s)

                // Header Stepper
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.brandTurquoise)
                            .frame(width: 8, height: 8)
                        Text("STEP 3 OF 4 • PRACTICE RHYTHM")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.brandTurquoise)
                            .tracking(1.0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.brandTurquoise.opacity(0.12), in: Capsule())

                    Text("Stay on track")
                        .font(.appLargeTitle)
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)

                    Text("Building sign fluency takes small, steady daily moments. Choose a time that fits your daily rhythm for a friendly prompt.")
                        .font(.appBody)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.m)
                }

                // Motivation Badges
                HStack(spacing: 8) {
                    badge(icon: "flame.fill", label: "Streak Keeper", color: Color.brandYellow)
                    badge(icon: "bolt.fill", label: "+ Streak Boost", color: Color.brandTurquoise)
                    badge(icon: "bell.badge.fill", label: "Visual Alert", color: Color.green)
                }

                // Practice Time Card
                VStack(spacing: Theme.Spacing.m) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Daily Practice Time")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.textPrimary)
                            Text("Evening Slot")
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
                        }

                        Spacer()

                        DatePicker(
                            "",
                            selection: $viewModel.practiceTime,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .tint(Color.brandTurquoise)
                    }

                    Divider()

                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.brandTurquoise)
                        Text("Recommended: 74% of active signers practice at 7:00 PM after dinner.")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Theme.Spacing.m)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))

                // Active Reminder Days
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text("Active Reminder Days")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)

                    HStack(spacing: 8) {
                        ForEach(weekDays, id: \.id) { day in
                            let isActive = viewModel.activeDays.contains(day.id)
                            Button {
                                if isActive {
                                    if viewModel.activeDays.count > 1 {
                                        viewModel.activeDays.remove(day.id)
                                    }
                                } else {
                                    viewModel.activeDays.insert(day.id)
                                }
                            } label: {
                                Text(day.name)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(isActive ? Color.onPrimary : Color.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(isActive ? Color.primaryFill : Color.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(isActive ? Color.clear : Color.textSecondary.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // No Spam Guarantee
                HStack(alignment: .top, spacing: Theme.Spacing.m) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.title2)
                        .foregroundStyle(Color.brandTurquoise)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("No spam, ever")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.textPrimary)

                        Text("SignSpeak sends only 1 thoughtful ping per day with interactive micro-flashcards. Snooze or customize anytime in Settings.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                            .lineSpacing(2)
                    }
                }
                .padding(Theme.Spacing.m)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))

                // Action Buttons
                VStack(spacing: Theme.Spacing.s) {
                    Button {
                        Task {
                            await viewModel.requestNotificationAccess()
                        }
                    } label: {
                        HStack(spacing: Theme.Spacing.s) {
                            Image(systemName: "bell.fill")
                            Text("Turn On Reminders")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.onPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.primaryFill, in: RoundedRectangle(cornerRadius: 14))
                    }

                    Button("Maybe later") {
                        withAnimation {
                            viewModel.advance()
                        }
                    }
                    .font(.appBody)
                    .foregroundStyle(Color.textSecondary)
                    .frame(minHeight: Theme.minTapTarget)
                }
                .padding(.top, Theme.Spacing.s)
            }
            .padding(Theme.Spacing.l)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }

    private func badge(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.cardBackground, in: Capsule())
    }
}
