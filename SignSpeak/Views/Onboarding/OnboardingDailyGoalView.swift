import SwiftUI

/// Daily goal pacing screen (`18-onboarding-daily-goal`).
public struct OnboardingDailyGoalView: View {
    @Bindable var viewModel: OnboardingViewModel

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
                        Text("PACING & RHYTHM • STEP 2 OF 3")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.brandTurquoise)
                            .tracking(1.0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.brandTurquoise.opacity(0.12), in: Capsule())

                    Text("Set a daily goal")
                        .font(.appLargeTitle)
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)

                    Text("Consistent daily practice builds spatial muscle memory and visual confidence. You can adjust this anytime in your preferences.")
                        .font(.appBody)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.m)
                }

                // Goal Cards List
                VStack(spacing: Theme.Spacing.m) {
                    ForEach(DailyGoalOption.allCases) { goal in
                        goalCard(goal)
                    }
                }

                // Tip Card
                HStack(alignment: .top, spacing: Theme.Spacing.m) {
                    ZStack {
                        Circle()
                            .fill(Color.brandYellow.opacity(0.2))
                            .frame(width: 36, height: 36)
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.brandYellow)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("SignSpeak Tip")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.textPrimary)

                        Text("Just 10 minutes daily is enough to retain over 300 signs in your first month with hands-free camera feedback!")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                            .lineSpacing(2)
                    }
                }
                .padding(Theme.Spacing.m)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))

                // Continue Button
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        viewModel.advance()
                    }
                } label: {
                    HStack(spacing: Theme.Spacing.s) {
                        Text("Continue")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.onPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.primaryFill, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.top, Theme.Spacing.s)
                .accessibilityLabel("Continue to permission setup")
            }
            .padding(Theme.Spacing.l)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }

    private func goalCard(_ goal: DailyGoalOption) -> some View {
        let isSelected = viewModel.selectedDailyGoal == goal

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.selectedDailyGoal = goal
            }
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                // Minutes badge
                VStack(spacing: 0) {
                    Text("\(goal.minutes)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(isSelected ? Color.brandTurquoise : Color.textPrimary)
                    Text("min")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(width: 52, height: 52)
                .background(isSelected ? Color.brandTurquoise.opacity(0.15) : Color.appBackground, in: RoundedRectangle(cornerRadius: 12))

                // Details
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(goal.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.textPrimary)

                        if goal.isRecommended {
                            Text("★ RECOMMENDED")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color(red: 11/255, green: 42/255, blue: 74/255))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.brandYellow, in: Capsule())
                        }
                    }

                    Text(goal.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                // Radio Button
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.brandTurquoise : Color.textSecondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(Color.brandTurquoise)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(Theme.Spacing.m)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Color.brandTurquoise : Color.clear, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(isSelected ? 0.08 : 0.02), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(goal.name) goal, \(goal.minutes) minutes daily. \(goal.subtitle)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
