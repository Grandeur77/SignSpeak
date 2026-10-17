import SwiftUI

private struct DesignSystemGallery: View {
    private let swatches: [(name: String, color: Color)] = [
        ("Navy", .brandNavy),
        ("Turquoise", .brandTurquoise),
        ("Yellow", .brandYellow),
        ("Success", .success),
        ("Danger", .danger),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                Text("Learn to sign")
                    .font(.appLargeTitle)
                    .foregroundStyle(.textPrimary)

                HStack(spacing: Theme.Spacing.m) {
                    ForEach(swatches, id: \.name) { swatch in
                        VStack(spacing: Theme.Spacing.xs) {
                            Circle()
                                .fill(swatch.color)
                                .frame(width: 40, height: 40)
                            Text(swatch.name)
                                .font(.caption2)
                                .foregroundStyle(.textSecondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }

                CardView {
                    Text("Daily streak")
                        .appTextStyle(.headline)
                        .foregroundStyle(.textPrimary)
                    Text("5 days in a row. Keep it going!")
                        .appTextStyle(.body)
                        .foregroundStyle(.textSecondary)
                    Text("See progress")
                        .appTextStyle(.caption)
                        .foregroundStyle(.accentText)
                }

                Button("Start lesson") {}
                    .buttonStyle(.primary)
                Button("Continue as guest") {}
                    .buttonStyle(.secondary)
                Button("Delete account") {}
                    .buttonStyle(.destructive)
                Button("Disabled") {}
                    .buttonStyle(.primary)
                    .disabled(true)

                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    Text("State Views")
                        .appTextStyle(.headline)
                        .foregroundStyle(.textPrimary)

                    CardView {
                        EmptyStateView(
                            title: "No Signs Found",
                            message: "Try searching with a different keyword.",
                            systemImage: "magnifyingglass",
                            actionTitle: "Clear Search",
                            action: {}
                        )
                    }

                    CardView {
                        ErrorStateView(
                            message: "Unable to load lessons. Please retry.",
                            onRetry: {}
                        )
                    }

                    CardView {
                        LoadingView(message: "Syncing progress...")
                    }
                }
            }
            .padding(Theme.Spacing.m)
        }
        .background(.appBackground)
    }
}

#Preview("Light") {
    DesignSystemGallery()
}

#Preview("Dark") {
    DesignSystemGallery()
        .preferredColorScheme(.dark)
}

#Preview("Largest text") {
    DesignSystemGallery()
        .dynamicTypeSize(.accessibility3)
}
