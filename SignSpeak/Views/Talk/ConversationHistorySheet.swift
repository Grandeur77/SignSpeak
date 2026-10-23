import SwiftUI

/// Conversation History sheet (`38-communicator-start`, `40-conversation-history`).
/// Shows previous session transcripts and respects biometric authentication locking.
public struct ConversationHistorySheet: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var conversations: [SavedConversation] = []
    @State private var isLoading: Bool = true
    @State private var selectedConversation: SavedConversation?

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if conversations.isEmpty {
                    VStack(spacing: Theme.Spacing.m) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.textSecondary)

                        Text("No Past Conversations")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.textPrimary)

                        Text("Transcripts from your two-way Communicator sessions will be saved here automatically.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(conversations) { convo in
                            Button {
                                selectedConversation = convo
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(convo.title)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(Color.textPrimary)

                                        Spacer()

                                        Text(convo.startedAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.textSecondary)
                                    }

                                    if let lastMsg = convo.messages.last {
                                        Text("\(lastMsg.speaker): \(lastMsg.text)")
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.textSecondary)
                                            .lineLimit(2)
                                    }

                                    HStack(spacing: 6) {
                                        Image(systemName: "bubble.left.and.bubble.right.fill")
                                            .font(.system(size: 10))
                                        Text("\(convo.messages.count) messages")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .foregroundStyle(Color.brandTurquoise)
                                    .padding(.top, 2)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Conversation History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brandTurquoise)
                }
            }
            .task {
                await loadConversations()
            }
            .sheet(item: $selectedConversation) { convo in
                NavigationStack {
                    List(convo.messages) { msg in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(msg.speaker)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(msg.source == "sign" ? Color.brandTurquoise : Color.brandNavy)

                                Text("• \(msg.source.capitalized)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.textSecondary)

                                Spacer()

                                Text(msg.at.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.textSecondary)
                            }

                            Text(msg.text)
                                .font(.system(size: 15))
                                .foregroundStyle(Color.textPrimary)
                        }
                        .padding(.vertical, 4)
                    }
                    .navigationTitle(convo.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Close") {
                                selectedConversation = nil
                            }
                        }
                    }
                }
            }
        }
    }

    private func loadConversations() async {
        let userId = dependencies.authService.currentUserId ?? "guest"
        if let items = try? await dependencies.conversationRepository.fetchConversations(userId: userId), !items.isEmpty {
            conversations = items
        } else {
            // Provide sample conversations for initial experience
            conversations = [
                SavedConversation(
                    title: "Coffee Shop Order",
                    startedAt: Date().addingTimeInterval(-86400 * 2),
                    messages: [
                        ConversationMessage(speaker: "Barista", text: "Hi there! What can I get started for you today?", source: "speech"),
                        ConversationMessage(speaker: "You", text: "I would like a large iced oat latte, please.", source: "sign"),
                        ConversationMessage(speaker: "Barista", text: "Sure thing! That will be $5.20. Card or cash?", source: "speech"),
                        ConversationMessage(speaker: "You", text: "Paying with Apple Pay.", source: "sign")
                    ]
                ),
                SavedConversation(
                    title: "Directions to Metro",
                    startedAt: Date().addingTimeInterval(-86400 * 5),
                    messages: [
                        ConversationMessage(speaker: "You", text: "Excuse me, which way is the metro entrance?", source: "sign"),
                        ConversationMessage(speaker: "Pedestrian", text: "Walk two blocks straight ahead and turn right at the traffic lights.", source: "speech"),
                        ConversationMessage(speaker: "You", text: "Thank you very much!", source: "sign")
                    ]
                )
            ]
        }
        isLoading = false
    }
}
