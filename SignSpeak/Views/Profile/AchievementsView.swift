import SwiftUI

/// Screen 23: Achievements and Badges view per Step 9.4 specifications.
/// Features all 16 badges with Bronze/Silver/Gold tiers, filters (`All`, `Milestones`, `Vocabulary`),
/// progress bars, unlocked status, and badge boost from the daily challenge.
public struct AchievementsView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: AchievementCategory = .all
    @State private var achievements: [Achievement] = AchievementCatalog.all
    @State private var totalXP: Int = 420
    @State private var newlyUnlockedBadge: Achievement?

    public init() {}

    private var filteredAchievements: [Achievement] {
        switch selectedCategory {
        case .all:
            return achievements
        case .milestones:
            return achievements.filter { $0.category == .milestones || $0.category == .habits }
        case .vocabulary:
            return achievements.filter { $0.category == .vocabulary }
        case .habits:
            return achievements.filter { $0.category == .habits }
        }
    }

    private var unlockedCount: Int {
        achievements.filter(\.isUnlocked).count
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                // MARK: - Header Progress Card
                achievementsHeaderCard

                // MARK: - Daily Challenge Badge Boost Banner
                badgeBoostBanner

                // MARK: - Category Filters
                categoryPills

                // MARK: - Badges Grid
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14)
                    ],
                    spacing: 14
                ) {
                    ForEach(filteredAchievements) { badge in
                        badgeCard(badge)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.m)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAchievements()
        }
    }

    // MARK: - Header Card
    private var achievementsHeaderCard: some View {
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

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("YOUR TROPHY CASE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.brandTurquoise)
                        .tracking(0.8)

                    Text("\(unlockedCount) of 16 Unlocked")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Earn badges by building streaks, learning signs, and chatting in live sessions.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.75))
                }

                Spacer()

                // Circular Progress Ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 8)
                        .frame(width: 72, height: 72)

                    Circle()
                        .trim(from: 0, to: CGFloat(Double(unlockedCount) / 16.0))
                        .stroke(Color.brandYellow, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 72, height: 72)

                    Text("\(Int((Double(unlockedCount) / 16.0) * 100))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(Theme.Spacing.l)
        }
    }

    // MARK: - Badge Boost Banner
    private var badgeBoostBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.brandYellow.opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.brandYellow)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Daily Challenge Boost Active!")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Text("+20% XP bonus on all badge unlocks today.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()
        }
        .padding(Theme.Spacing.m)
        .background(
            Color.brandYellow.opacity(0.1),
            in: RoundedRectangle(cornerRadius: Theme.Radius.card)
        )
    }

    // MARK: - Category Filter Pills
    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach([AchievementCategory.all, .milestones, .vocabulary, .habits]) { cat in
                    Button {
                        selectedCategory = cat
                    } label: {
                        Text(cat.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(selectedCategory == cat ? Color.brandNavy : Color.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedCategory == cat ? Color.brandTurquoise : Color.cardBackground,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Badge Card
    private func badgeCard(_ badge: Achievement) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                // Tier Icon
                ZStack {
                    Circle()
                        .fill(badge.isUnlocked ? badge.tier.color.opacity(0.2) : Color.gray.opacity(0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: badge.iconName)
                        .font(.system(size: 20))
                        .foregroundStyle(badge.isUnlocked ? badge.tier.color : Color.textSecondary.opacity(0.5))
                }

                Spacer()

                // Tier Pill
                Text(badge.tier.rawValue.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(badge.tier.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(badge.tier.color.opacity(0.14), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(badge.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(badge.isUnlocked ? Color.textPrimary : Color.textSecondary)

                Text(badge.description)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            if badge.isUnlocked {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.brandTurquoise)
                        .font(.system(size: 12))
                    Text("Unlocked • +\(badge.xpReward) XP")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.brandTurquoise)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(badge.currentCount)/\(badge.targetCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.textSecondary)
                        Spacer()
                        Text("+\(badge.xpReward) XP")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.brandYellow)
                    }

                    // Progress bar
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.15))
                                .frame(height: 5)

                            Capsule()
                                .fill(badge.tier.color)
                                .frame(width: proxy.size.width * CGFloat(badge.progress), height: 5)
                        }
                    }
                    .frame(height: 5)
                }
            }
        }
        .padding(Theme.Spacing.m)
        .frame(minHeight: 175)
        .background(
            Color.cardBackground,
            in: RoundedRectangle(cornerRadius: Theme.Radius.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(badge.isUnlocked ? badge.tier.color.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
    }

    private func loadAchievements() async {
        let uid = dependencies.authService.currentUserId ?? "guest"
        let profile = try? await dependencies.userProfileRepository.fetchProfile(userId: uid)
        let progress = (try? await dependencies.progressRepository.fetchProgress(userId: uid)) ?? []

        let context = AchievementEvaluationContext(
            profile: profile ?? UserProfile(id: uid, displayName: "Learner", currentStreak: 7, xp: 420),
            progressList: progress,
            totalAttempts: 35,
            latestSessionAccuracy: 0.96,
            completedConversationCount: 2,
            communityReactionsCount: 3,
            quickPhrasesUsedCount: 4,
            isCalibrationCompleted: true
        )

        let result = AchievementEngine.evaluate(context: context)
        self.achievements = result.updated
    }
}
