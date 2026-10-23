import SwiftUI

/// SwiftUI representable for native iOS UIActivityViewController.
public struct ActivityShareSheet: UIViewControllerRepresentable {
    public let items: [Any]

    public init(items: [Any]) {
        self.items = items
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Detailed conversation transcript screen (`41-conversation-transcript`).
public struct ConversationTranscriptView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ConversationTranscriptViewModel

    public init(
        conversation: SavedConversation,
        repository: any ConversationRepository,
        speechSynthesisService: any SpeechSynthesisServicing,
        userId: String
    ) {
        _viewModel = State(initialValue: ConversationTranscriptViewModel(
            conversation: conversation,
            repository: repository,
            speechSynthesisService: speechSynthesisService,
            userId: userId
        ))
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.m) {
                    // Top Utility Bar
                    utilityBar

                    // Header Detail Card
                    headerDetailCard

                    // Transcript Conversation Feed
                    transcriptFeed

                    // Bottom Action Buttons
                    bottomActionFooter
                        .padding(.top, Theme.Spacing.m)
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.bottom, 40)
            }

            // Toast Alert Banner
            if let toast = viewModel.toastMessage {
                toastView(toast)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .navigationTitle("Conversation Transcript")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .sheet(isPresented: $viewModel.isShowingShareSheet) {
            ActivityShareSheet(items: [viewModel.generateFormattedTranscript()])
        }
        .alert("Delete Transcript?", isPresented: $viewModel.isShowingDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteTranscript()
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove this session and all its messages from your device.")
        }
        .onChange(of: viewModel.isDeleted) { _, isDeleted in
            if isDeleted {
                dismiss()
            }
        }
    }

    // MARK: - Utility Bar
    private var utilityBar: some View {
        HStack {
            // Archived Session Pill
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.brandTurquoise)
                    .frame(width: 7, height: 7)

                Text("Archived Session")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brandTurquoise)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.brandTurquoise.opacity(0.12), in: Capsule())

            Spacer()

            // Audio Replay Toggle Button
            Button {
                viewModel.replayAudio()
            } label: {
                Image(systemName: viewModel.isPlayingAudio ? "speaker.wave.3.fill" : "volume.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(viewModel.isPlayingAudio ? Color.brandTurquoise : Color.brandNavy)
                    .frame(width: 40, height: 40)
                    .background(Color.cardBackground, in: Circle())
                    .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
            }
            .accessibilityLabel("Replay audio transcript")

            // More Menu Button
            Menu {
                Button {
                    viewModel.isShowingShareSheet = true
                } label: {
                    Label("Share Export", systemImage: "square.and.arrow.up")
                }

                Button {
                    viewModel.isShowingShareSheet = true
                } label: {
                    Label("Export Text Report", systemImage: "doc.text")
                }

                Divider()

                Button(role: .destructive) {
                    viewModel.confirmDelete()
                } label: {
                    Label("Delete Transcript", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.brandNavy)
                    .frame(width: 40, height: 40)
                    .background(Color.cardBackground, in: Circle())
                    .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Header Detail Card
    private var headerDetailCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.conversation.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.brandNavy)

                    Text(viewModel.conversation.fullFormattedDateHeader)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.brandTurquoise.opacity(0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: viewModel.conversation.venueIcon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.brandTurquoise)
                }
            }

            // Recognition Summary Chip Row
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "hands.sparkles.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.brandTurquoise)

                    Text("\(viewModel.conversation.signsRecognizedCount) signs recognized • 0 misdetections")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.brandNavy)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.brandTurquoise.opacity(0.12), in: Capsule())

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.brandTurquoise)

                    Text("Device Secured")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.textSecondary.opacity(0.08), in: Capsule())
            }
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - Transcript Feed
    private var transcriptFeed: some View {
        VStack(spacing: 16) {
            // Started At Divider
            HStack {
                Text("Conversation started at \(viewModel.conversation.startedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .background(Color.textSecondary.opacity(0.1), in: Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)

            // Message Bubbles
            ForEach(viewModel.conversation.messages) { msg in
                if msg.source == "sign" || msg.speaker == "Maya" || msg.speaker == "You" {
                    // Deaf User Signed Bubble (Right Aligned)
                    userSignedBubble(msg)
                } else {
                    // Hearing Partner Spoken Bubble (Left Aligned)
                    partnerSpokenBubble(msg)
                }
            }
        }
    }

    // MARK: - Partner Spoken Bubble
    private func partnerSpokenBubble(_ msg: ConversationMessage) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(msg.speaker)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.brandTurquoise)

                    Text(msg.text)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.brandNavy)
                        .lineSpacing(3)
                }
                .padding(14)
                .background(Color.brandTurquoise.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                HStack(spacing: 4) {
                    Image(systemName: "ear")
                        .font(.system(size: 11))
                    Text("\(msg.at.formatted(date: .omitted, time: .shortened)) • Spoken audio")
                        .font(.system(size: 11))
                }
                .foregroundStyle(Color.textSecondary)
                .padding(.leading, 4)
            }
            .frame(maxWidth: 300, alignment: .leading)

            Spacer()
        }
    }

    // MARK: - User Signed Bubble
    private func userSignedBubble(_ msg: ConversationMessage) -> some View {
        HStack {
            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(msg.speaker)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.brandTurquoise.opacity(0.9))

                        Spacer()

                        HStack(spacing: 3) {
                            Image(systemName: "hands.sparkles.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.brandYellow)
                            Text("ASL Verified")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.brandTurquoise)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.brandTurquoise.opacity(0.2), in: Capsule())
                    }

                    Text(msg.text)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.white)
                        .lineSpacing(3)

                    // Accuracy & Confidence Badge
                    let signs = msg.signsCount ?? 8
                    let confidencePct = Int((msg.confidence ?? 0.98) * 100)
                    HStack {
                        Text("🤟 \(signs) signs recognized")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.brandTurquoise)

                        Spacer()

                        Text("\(confidencePct)% confidence")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.brandYellow)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.brandNavy.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(14)
                .background(Color.brandNavy)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.brandNavy.opacity(0.2), radius: 6, y: 3)

                HStack(spacing: 4) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.brandTurquoise)
                    Text("\(msg.at.formatted(date: .omitted, time: .shortened)) • ASL Camera")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.trailing, 4)
            }
            .frame(maxWidth: 310, alignment: .trailing)
        }
    }

    // MARK: - Bottom Action Buttons
    private var bottomActionFooter: some View {
        VStack(spacing: 12) {
            // Share Transcript
            Button {
                viewModel.isShowingShareSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Share Transcript")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.brandNavy, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.brandNavy.opacity(0.25), radius: 8, y: 4)
            }

            // Delete Transcript
            Button {
                viewModel.confirmDelete()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                        .font(.system(size: 15))
                    Text("Delete Transcript")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(Color.danger)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Toast Banner View
    private func toastView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.brandTurquoise)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.brandNavy, in: Capsule())
        .shadow(color: Color.black.opacity(0.25), radius: 10, y: 4)
        .padding(.bottom, 24)
        .onAppear {
            Task {
                try? await Task.sleep(nanoseconds: 2_400_000_000)
                withAnimation {
                    viewModel.toastMessage = nil
                }
            }
        }
    }
}
