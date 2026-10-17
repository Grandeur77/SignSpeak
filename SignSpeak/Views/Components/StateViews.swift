import SwiftUI

/// Reusable empty state view displaying an icon, title, message, and an optional call-to-action button.
/// Designed for 44pt minimum tap targets, full VoiceOver navigation, and Dynamic Type scaling.
struct EmptyStateView: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var systemImage: String = "tray"
    var actionTitle: LocalizedStringKey? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(.brandTurquoise)
                .frame(width: 80, height: 80)
                .background(.cardBackground, in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.s) {
                Text(title)
                    .font(.appSectionTitle)
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(message)
                    .font(.appBody)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 320)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.secondary)
                    .frame(maxWidth: 240)
                    .padding(.top, Theme.Spacing.xs)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}

/// Reusable error state view providing a clear explanation of what went wrong and a retry button.
/// Fully accessible, adhering to Deaf Flag styling and WCAG contrast.
struct ErrorStateView: View {
    var title: LocalizedStringKey = "Something went wrong"
    let message: LocalizedStringKey
    var systemImage: String = "exclamationmark.triangle.fill"
    var retryTitle: LocalizedStringKey = "Try Again"
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(.danger)
                .frame(width: 80, height: 80)
                .background(Color.danger.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.s) {
                Text(title)
                    .font(.appSectionTitle)
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(message)
                    .font(.appBody)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 320)

            Button(action: onRetry) {
                HStack(spacing: Theme.Spacing.s) {
                    Image(systemName: "arrow.clockwise")
                        .accessibilityHidden(true)
                    Text(retryTitle)
                }
            }
            .buttonStyle(.primary)
            .frame(maxWidth: 240)
            .padding(.top, Theme.Spacing.xs)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}

/// Reusable loading state view with accessible status announcements.
struct LoadingView: View {
    var message: LocalizedStringKey? = "Loading..."

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            ProgressView()
                .tint(.brandTurquoise)
                .scaleEffect(1.2)
                .accessibilityHidden(true)

            if let message {
                Text(message)
                    .font(.appBody)
                    .foregroundStyle(.textSecondary)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message ?? "Loading")
    }
}

#Preview("Light Mode") {
    VStack(spacing: Theme.Spacing.xl) {
        EmptyStateView(
            title: "No Signs Found",
            message: "Try searching with a different keyword or browse categories.",
            systemImage: "hand.raised.slash",
            actionTitle: "Browse Directory",
            action: {}
        )
    }
    .background(.appBackground)
}

#Preview("Dark Mode") {
    VStack(spacing: Theme.Spacing.xl) {
        ErrorStateView(
            message: "We couldn't connect to retrieve your progress. Please check your connection.",
            onRetry: {}
        )
    }
    .background(.appBackground)
    .preferredColorScheme(.dark)
}

#Preview("Accessibility Extra Large Text") {
    ScrollView {
        VStack(spacing: Theme.Spacing.xl) {
            EmptyStateView(
                title: "No Signs Found",
                message: "Try searching with a different keyword or browse categories.",
                systemImage: "hand.raised.slash",
                actionTitle: "Browse Directory",
                action: {}
            )
            LoadingView()
        }
        .padding()
    }
    .background(.appBackground)
    .dynamicTypeSize(.accessibility5)
}
