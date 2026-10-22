import SwiftUI

/// Role selection screen allowing users to personalize their learning and communication experience
public struct OnboardingRoleView: View {
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
                        Text("ONBOARDING • STEP 1 OF 3")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.brandTurquoise)
                            .tracking(1.0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.brandTurquoise.opacity(0.12), in: Capsule())

                    Text("How will you use SignSpeak?")
                        .font(.appLargeTitle)
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)

                    Text("Personalize your journey and communication tools. You can change this anytime.")
                        .font(.appBody)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.m)
                }

                // Role Options List
                VStack(spacing: Theme.Spacing.m) {
                    ForEach(OnboardingRole.allCases) { role in
                        roleCard(role)
                    }
                }

                // Personalization Note Pill
                HStack(spacing: Theme.Spacing.s) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.brandTurquoise)
                    Text("Instant Personalization: Tools and lessons adapt to your selected profile.")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.s)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12))

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
                .accessibilityLabel("Continue to daily goal setup")
            }
            .padding(Theme.Spacing.l)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }

    private func roleCard(_ role: OnboardingRole) -> some View {
        let isSelected = viewModel.selectedRole == role

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.selectedRole = role
            }
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.brandTurquoise.opacity(0.18) : Color.cardBackground)
                        .frame(width: 48, height: 48)

                    Image(systemName: role.iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.brandTurquoise : Color.textSecondary)
                }

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text(role.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)

                    Text(role.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                // Selection Radio / Checkmark
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
        .accessibilityLabel("\(role.title), \(role.subtitle)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
