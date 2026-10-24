import SwiftUI

/// Screen 22: Profile view per Step 9.4 specifications.
/// Displays avatar, fluency level, learning since date, core practice stats,
/// direct link to Progress Analytics (`24-analytics`), Achievements trophy preview (`23-achievements`),
/// and accessibility preferences summary (dominant hand, sound alerts, skeleton viewfinder).
public struct ProfileView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var profile: UserProfile?
    @State private var achievements: [Achievement] = AchievementCatalog.all

    public init() {}

    private var unlockedCount: Int {
        achievements.filter(\.isUnlocked).count
    }

    private var learningSinceString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: profile?.createdAt ?? Date())
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.l) {
                    // MARK: - Identity & Level Header
                    identitySection

                    // MARK: - Core Stats Grid
                    coreStatsGrid

                    // MARK: - View Analytics CTA Card
                    viewAnalyticsCard

                    // MARK: - Achievements Preview
                    achievementsPreviewSection

                    // MARK: - Accessibility Preferences Summary
                    accessibilityPreferencesCard
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, Theme.Spacing.m)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brandTurquoise)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        EditProfileView()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("Edit")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.brandTurquoise)
                    }
                }
            }
            .task {
                await loadProfileData()
            }
        }
    }

    // MARK: - Identity Section
    private var identitySection: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                Image("UserAvatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 88, height: 88)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.brandTurquoise, lineWidth: 3))
                    .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)

                // Fluency Level Badge
                Text("Lvl \(profile?.level ?? 3)")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(Color.brandNavy)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.brandYellow, in: Capsule())
                    .offset(x: 4, y: 4)
            }

            Text(profile?.displayName ?? "Alex Rivera")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)

            HStack(spacing: 8) {
                // Role Badge
                Text((profile?.role ?? "Learner").uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.brandTurquoise)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.brandTurquoise.opacity(0.12), in: Capsule())

                Text("•")
                    .foregroundStyle(Color.textSecondary)

                Text("Learning since \(learningSinceString)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.top, Theme.Spacing.s)
    }

    // MARK: - Core Stats Grid
    private var coreStatsGrid: some View {
        HStack(spacing: 10) {
            statTile(icon: "flame.fill", color: Color.brandYellow, value: "\(profile?.currentStreak ?? 7)", label: "Day Streak")
            statTile(icon: "star.fill", color: Color.brandYellow, value: "\(profile?.xp ?? 420)", label: "Total XP")
            statTile(icon: "clock.fill", color: Color.brandTurquoise, value: "3.4h", label: "Practiced")
        }
    }

    private func statTile(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - View Analytics CTA Card
    private var viewAnalyticsCard: some View {
        NavigationLink {
            AnalyticsView()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.brandTurquoise.opacity(0.18))
                        .frame(width: 42, height: 42)
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.brandTurquoise)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("View Progress Analytics")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.textPrimary)

                    Text("Swift Charts, accuracy trends & strongest signs")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.brandTurquoise)
            }
            .padding(Theme.Spacing.m)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Achievements Preview
    private var achievementsPreviewSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(Color.brandYellow)
                    Text("Achievements (\(unlockedCount)/16)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                }

                Spacer()

                NavigationLink {
                    AchievementsView()
                } label: {
                    Text("See All →")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.brandTurquoise)
                }
                .buttonStyle(.plain)
            }

            // Preview top 3 badges
            HStack(spacing: 10) {
                ForEach(achievements.prefix(3)) { badge in
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(badge.isUnlocked ? badge.tier.color.opacity(0.18) : Color.gray.opacity(0.1))
                                .frame(width: 44, height: 44)

                            Image(systemName: badge.iconName)
                                .font(.system(size: 20))
                                .foregroundStyle(badge.isUnlocked ? badge.tier.color : Color.textSecondary.opacity(0.4))
                        }

                        Text(badge.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)

                        Text(badge.isUnlocked ? "Unlocked" : "\(badge.currentCount)/\(badge.targetCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(badge.isUnlocked ? Color.brandTurquoise : Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.cardBackground.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    // MARK: - Accessibility Preferences Summary
    private var accessibilityPreferencesCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Accessibility & Signing Settings")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            VStack(spacing: 10) {
                preferenceRow(
                    icon: "hand.raised.fill",
                    title: "Dominant Signing Hand",
                    value: profile?.dominantHand == "left" ? "Left-Handed" : "Right-Handed"
                )

                preferenceRow(
                    icon: "waveform",
                    title: "Visual Flash & Sound Alerts",
                    value: (profile?.soundAlertsEnabled ?? true) ? "Active" : "Disabled"
                )

                preferenceRow(
                    icon: "viewfinder",
                    title: "Hand Skeleton Viewfinder",
                    value: "21 Landmark Points"
                )
            }
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private func preferenceRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.brandTurquoise)
                .frame(width: 20)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textPrimary)

            Spacer()

            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.vertical, 4)
    }

    private func loadProfileData() async {
        let uid = dependencies.authService.currentUserId ?? "guest"
        self.profile = try? await dependencies.userProfileRepository.fetchProfile(userId: uid)

        let context = AchievementEvaluationContext(
            profile: profile ?? UserProfile(id: uid, displayName: "Learner", currentStreak: 7, xp: 420),
            totalAttempts: 35,
            latestSessionAccuracy: 0.96,
            completedConversationCount: 2,
            communityReactionsCount: 3,
            isCalibrationCompleted: true
        )
        let eval = AchievementEngine.evaluate(context: context)
        self.achievements = eval.updated
    }
}
