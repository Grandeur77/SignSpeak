import SwiftUI

/// Composer modal sheet for publishing posts to the community feed (`48-community-feed`).
public struct CommunityComposerView: View {
    @Bindable var viewModel: CommunityFeedViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: CommunityFeedViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.m) {
                // Post Type Picker
                Picker("Post Type", selection: $viewModel.composerMilestoneType) {
                    Text("General Share").tag(CommunityPostType.text)
                    Text("Streak Milestone 🔥").tag(CommunityPostType.milestone)
                    Text("Daily Challenge ⚡️").tag(CommunityPostType.dailyChallenge)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.m)

                // Error Message if any
                if let error = viewModel.composerErrorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.danger)
                        Text(error)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.danger)
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Text Editor
                ZStack(alignment: .topLeading) {
                    if viewModel.composerText.isEmpty {
                        Text("Share your signing milestone, ask for signing advice, or celebrate progress with the community…")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.textSecondary.opacity(0.7))
                            .padding(.top, 8)
                            .padding(.leading, 5)
                    }

                    TextEditor(text: $viewModel.composerText)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.textPrimary)
                        .scrollContentBackground(.hidden)
                        .onChange(of: viewModel.composerText) { _, _ in
                            viewModel.validateComposerText()
                        }
                }
                .padding(Theme.Spacing.m)
                .frame(maxHeight: 220)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, Theme.Spacing.l)

                // Character Counter & Guidelines Note
                HStack {
                    Text("Respect Deaf culture & maintain supportive discourse.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textSecondary)

                    Spacer()

                    Text("\(viewModel.remainingCharacters)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(viewModel.remainingCharacters < 20 ? Color.danger : Color.textSecondary)
                }
                .padding(.horizontal, Theme.Spacing.l)

                Spacer()
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            let success = await viewModel.publishPost()
                            if success {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isPublishing {
                            ProgressView()
                                .tint(Color.brandNavy)
                        } else {
                            Text("Post")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.brandNavy)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(
                                    viewModel.isComposerValid ? Color.brandYellow : Color.brandYellow.opacity(0.4),
                                    in: Capsule()
                                )
                        }
                    }
                    .disabled(!viewModel.isComposerValid || viewModel.isPublishing)
                }
            }
        }
    }
}
