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

                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text("Daily streak")
                        .font(.appSectionTitle)
                        .foregroundStyle(.textPrimary)
                    Text("5 days in a row. Keep it going!")
                        .foregroundStyle(.textSecondary)
                    Text("See progress")
                        .foregroundStyle(.accentText)
                }
                .cardStyle()

                Button("Start lesson") {}
                    .buttonStyle(.primary)
                Button("Continue as guest") {}
                    .buttonStyle(.secondary)
                Button("Disabled") {}
                    .buttonStyle(.primary)
                    .disabled(true)
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
