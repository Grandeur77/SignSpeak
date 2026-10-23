import SwiftUI

/// Conversation History sheet wrapper (`38-communicator-start`, `40-conversation-history`).
/// Shows previous session transcripts and respects biometric authentication locking.
public struct ConversationHistorySheet: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(AppRouter.self) private var router

    public init() {}

    public var body: some View {
        NavigationStack {
            ConversationHistoryView(
                repository: dependencies.conversationRepository,
                speechRecognitionService: dependencies.speechRecognitionService,
                userId: dependencies.authService.currentUserId ?? "guest"
            )
        }
    }
}
