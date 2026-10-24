import SwiftUI

/// Screen 49: Reaction Picker Sheet (`49-reaction-picker-sheet`).
/// Allows selecting from 6 community reactions: Wave, Fire, Love, Party, Power, and ILY sign.
public struct ReactionPickerSheetView: View {
    public let post: CommunityPost
    public let onSelect: (CommunityReactionType) -> Void
    @Environment(\.dismiss) private var dismiss

    public init(post: CommunityPost, onSelect: @escaping (CommunityReactionType) -> Void) {
        self.post = post
        self.onSelect = onSelect
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    public var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            // Drag handle
            Capsule()
                .fill(Color.textSecondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, Theme.Spacing.s)

            VStack(spacing: 4) {
                Text("React to Post")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Text("Choose an encouraging gesture for \(post.authorName)")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(CommunityReactionType.allCases) { reaction in
                    let isSelected = post.userReaction == reaction

                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        onSelect(reaction)
                        dismiss()
                    } label: {
                        VStack(spacing: 6) {
                            Text(reaction.emoji)
                                .font(.system(size: 34))

                            Text(reaction.title)
                                .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                                .foregroundStyle(isSelected ? Color.brandNavy : Color.textPrimary)

                            Text(reaction.meaning)
                                .font(.system(size: 10))
                                .foregroundStyle(isSelected ? Color.brandNavy.opacity(0.8) : Color.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 8)
                        .background(
                            isSelected ? Color.brandYellow : Color.cardBackground,
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isSelected ? Color.brandYellow : Color.brandTurquoise.opacity(0.2), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.m)

            Button("Cancel") {
                dismiss()
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.textSecondary)
            .padding(.bottom, Theme.Spacing.m)
        }
        .padding(.vertical, Theme.Spacing.s)
        .background(Color.appBackground.ignoresSafeArea())
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.hidden)
    }
}
