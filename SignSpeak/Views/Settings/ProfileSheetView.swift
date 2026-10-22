import SwiftUI

/// Displays user statistics (streak, XP, level), self-chosen role, and quick settings access.
public struct ProfileSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies
    @Environment(AppRouter.self) private var router

    @State private var profile: UserProfile?

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.l) {
                    // MARK: - Avatar & Identity Header
                    VStack(spacing: Theme.Spacing.s) {
                        ZStack(alignment: .bottomTrailing) {
                            Image("UserAvatar")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 88, height: 88)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.brandTurquoise, lineWidth: 3)
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 8, y: 4)

                            // Edit badge
                            Circle()
                                .fill(Color.brandNavy)
                                .frame(width: 26, height: 26)
                                .overlay(
                                    Image(systemName: "pencil")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                )
                        }

                        Text(profile?.displayName ?? "Alex Rivera")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.textPrimary)

                        // Role badge
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.brandTurquoise)
                                .frame(width: 6, height: 6)

                            Text((profile?.role ?? "Learner").uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.brandTurquoise)
                                .tracking(1.0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.brandTurquoise.opacity(0.12), in: Capsule())
                    }
                    .padding(.top, Theme.Spacing.m)

                    // MARK: - Core Stats Grid
                    HStack(spacing: 12) {
                        statCard(icon: "flame.fill", color: Color.brandYellow, value: "\(profile?.currentStreak ?? 7)", label: "Day Streak")
                        statCard(icon: "star.fill", color: Color.brandYellow, value: "\(profile?.xp ?? 420)", label: "Total XP")
                        statCard(icon: "chart.line.uptrend.xyaxis", color: Color.brandTurquoise, value: "Lvl \(profile?.level ?? 3)", label: "Fluency")
                    }
                    .padding(.horizontal, Theme.Spacing.l)

                    // MARK: - Daily Goal Card
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        HStack {
                            Image(systemName: "target")
                                .foregroundStyle(Color.brandTurquoise)
                            Text("Daily Learning Goal")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            Text("\(profile?.dailyGoalMinutes ?? 10) min/day")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.textSecondary)
                        }

                        // Goal progress bar
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(height: 8)

                                Capsule()
                                    .fill(Color.brandTurquoise)
                                    .frame(width: proxy.size.width * 0.7, height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(Theme.Spacing.m)
                    .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                    .padding(.horizontal, Theme.Spacing.l)

                    // MARK: - Sign Out Action
                    Button(role: .destructive) {
                        dismiss()
                        router.signOut()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(Color.danger)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.Radius.button))
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.top, Theme.Spacing.s)
                }
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brandNavy)
                }
            }
            .task {
                if let userId = dependencies.authService.currentUserId {
                    profile = try? await dependencies.userProfileRepository.fetchProfile(userId: userId)
                }
            }
        }
    }

    private func statCard(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}

#Preview("Profile Sheet") {
    ProfileSheetView()
        .environment(\.dependencies, .preview)
        .environment(
            AppRouter(
                authService: StubAuthService(initialUserId: "preview-user"),
                userProfileRepository: StubUserProfileRepository(),
                biometricAuthService: StubBiometricAuthService()
            )
        )
}
