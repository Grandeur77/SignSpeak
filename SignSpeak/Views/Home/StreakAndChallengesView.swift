import SwiftUI

/// Screen 20: Streak & Challenges view per Step 9.2 specifications.
/// Displays current & longest streaks, freeze protections, interactive month calendar heat map,
/// next milestone progress, daily challenge with XP reward, why streaks matter card, and ShareLink.
public struct StreakAndChallengesView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: StreakAndChallengesViewModel

    public init(viewModel: StreakAndChallengesViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? StreakAndChallengesViewModel())
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                // MARK: - Streak Hero Card
                streakHeroSection

                // MARK: - Freezes & Milestone Row
                HStack(spacing: Theme.Spacing.m) {
                    freezesCard
                    nextMilestoneCard
                }

                // MARK: - Month Calendar Heatmap
                calendarHeatmapCard

                // MARK: - Daily Challenge Card
                dailyChallengeCard

                // MARK: - Why Streaks Matter Card
                whyStreaksMatterCard

                // MARK: - Share Streak Action
                ShareLink(item: viewModel.shareMessage) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up.fill")
                        Text("Share Streak to Friends")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(Color.brandNavy)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.brandYellow, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, Theme.Spacing.s)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.m)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Streaks & Challenges")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let uid = dependencies.authService.currentUserId ?? "guest"
            viewModel.update(
                userProfileRepository: dependencies.userProfileRepository,
                userId: uid,
                dateProvider: dependencies.dateProvider
            )
            await viewModel.loadData()
        }
    }

    // MARK: - Streak Hero Section
    private var streakHeroSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 16/255, green: 40/255, blue: 74/255),
                            Color(red: 10/255, green: 26/255, blue: 50/255)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: Theme.Spacing.m) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CURRENT PRACTICE STREAK")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.brandTurquoise)
                            .tracking(0.8)

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(viewModel.currentStreak)")
                                .font(.system(size: 48, weight: .black, design: .rounded))
                                .foregroundStyle(.white)

                            Text("DAYS")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.brandYellow)
                        }
                    }

                    Spacer()

                    // Flame Emblem
                    ZStack {
                        Circle()
                            .fill(Color.brandYellow.opacity(0.18))
                            .frame(width: 64, height: 64)

                        Image(systemName: "flame.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.brandYellow)
                    }
                }

                Divider()
                    .overlay(Color.white.opacity(0.12))

                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(Color.brandYellow)
                            .font(.system(size: 13))
                        Text("Personal Best: \(viewModel.longestStreak) Days")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    Spacer()

                    Text("Active Streak 🔥")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.brandTurquoise)
                }
            }
            .padding(Theme.Spacing.l)
        }
    }

    // MARK: - Freezes Card
    private var freezesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "snowflake")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.brandTurquoise)
                Spacer()
                Text("\(viewModel.streakFreezes) / 2")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.brandTurquoise)
            }

            Text("Streak Freezes")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            Text("Auto-protects streak if you miss 1 day")
                .font(.system(size: 11))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    // MARK: - Next Milestone Card
    private var nextMilestoneCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.brandYellow)
                Spacer()
                Text("\(viewModel.daysUntilNextMilestone)d left")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.brandYellow)
            }

            Text("\(viewModel.nextMilestoneTarget)-Day Goal")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            // Progress bar
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)

                    Capsule()
                        .fill(Color.brandYellow)
                        .frame(width: proxy.size.width * CGFloat(viewModel.milestoneProgress), height: 6)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    // MARK: - Month Calendar Heatmap
    private var calendarHeatmapCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                Text("This Month's Activity")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                HStack(spacing: 8) {
                    legendDot(color: Color.brandTurquoise, label: "Practiced")
                    legendDot(color: Color.brandYellow, label: "Freeze")
                }
            }

            // Weekday headers
            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
            let weekHeaders = ["S", "M", "T", "W", "T", "F", "S"]

            HStack {
                ForEach(weekHeaders, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Month days grid (31 days)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(1...31, id: \.self) { day in
                    let isPracticed = viewModel.monthPracticedDays.contains(day)
                    let isFreeze = viewModel.monthFreezeDays.contains(day)

                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                isPracticed ? Color.brandTurquoise :
                                (isFreeze ? Color.brandYellow.opacity(0.8) : Color.cardBackground.opacity(0.6))
                            )
                            .frame(height: 34)

                        Text("\(day)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(
                                isPracticed ? Color.brandNavy :
                                (isFreeze ? Color.brandNavy : Color.textSecondary)
                            )
                    }
                }
            }
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Daily Challenge Card
    private var dailyChallengeCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "target")
                        .foregroundStyle(Color.brandYellow)
                    Text("DAILY CHALLENGE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.brandYellow)
                        .tracking(0.8)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color.brandYellow)
                        .font(.system(size: 12))
                    Text("+\(viewModel.dailyChallenge.xpReward) XP")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.brandYellow.opacity(0.18), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.dailyChallenge.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Text(viewModel.dailyChallenge.description)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
            }

            // Progress bar & completion button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(viewModel.dailyChallenge.currentCount) of \(viewModel.dailyChallenge.targetCount) Completed")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.15))
                                .frame(height: 8)

                            Capsule()
                                .fill(Color.brandTurquoise)
                                .frame(width: proxy.size.width * CGFloat(viewModel.dailyChallenge.progress), height: 8)
                        }
                    }
                    .frame(height: 8)
                }

                Spacer()

                Button {
                    Task {
                        await viewModel.completeDailyChallenge()
                    }
                } label: {
                    Text(viewModel.dailyChallenge.isCompleted ? "Claimed ✓" : "Claim XP")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(viewModel.dailyChallenge.isCompleted ? Color.white : Color.brandNavy)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.dailyChallenge.isCompleted ? Color.brandTurquoise : Color.brandYellow,
                            in: Capsule()
                        )
                }
                .disabled(viewModel.dailyChallenge.isCompleted)
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.m)
        .background(
            LinearGradient(
                colors: [Color.brandYellow.opacity(0.08), Color.cardBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: Theme.Radius.card)
        )
    }

    // MARK: - Why Streaks Matter Card
    private var whyStreaksMatterCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.brandTurquoise)
                Text("Why Daily Streaks Matter")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
            }

            Text("Sign language engages physical muscle memory and visual processing in the brain. Practicing 5 minutes every day builds permanent neuromuscular pathways far more effectively than a 1-hour session once a week.")
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
                .lineSpacing(3)
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}
