import SwiftUI

/// Main Conversation History screen (`40-conversation-history`).
public struct ConversationHistoryView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var viewModel: ConversationHistoryViewModel
    @State private var selectedConversation: SavedConversation?
    @State private var isShowingExportSheet: Bool = false
    @State private var exportText: String = ""

    public init(
        repository: any ConversationRepository,
        speechRecognitionService: any SpeechRecognitionServicing,
        userId: String
    ) {
        _viewModel = State(initialValue: ConversationHistoryViewModel(
            repository: repository,
            speechRecognitionService: speechRecognitionService,
            userId: userId
        ))
    }

    public var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                ipadSplitView
            } else {
                iphoneListView
            }
        }
        .navigationTitle("Conversation History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.brandTurquoise)
                .hoverEffect(.highlight)
            }
        }
        .task {
            await viewModel.loadConversations()
        }
        .sheet(item: Binding(
            get: { horizontalSizeClass == .regular ? nil : selectedConversation },
            set: { selectedConversation = $0 }
        )) { convo in
            NavigationStack {
                ConversationTranscriptView(
                    conversation: convo,
                    repository: dependencies.conversationRepository,
                    speechSynthesisService: dependencies.speechSynthesisService,
                    userId: viewModel.userId
                )
            }
        }
        .sheet(isPresented: $isShowingExportSheet) {
            ActivityShareSheet(items: [exportText])
        }
    }

    // MARK: - iPad List-Detail Split View (Step 14.1)

    private var ipadSplitView: some View {
        HStack(spacing: 0) {
            // Left Pane: Conversation List & Filters
            ZStack(alignment: .bottom) {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.m) {
                        securityPrivacyBanner
                        searchDictationBar
                        filterChipsBar
                        swipeTipRow
                        conversationCardsStack
                        weeklyDigestCard
                        endOfFeedIndicator
                    }
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.bottom, 40)
                }

                if let toast = viewModel.toastMessage {
                    toastView(toast)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(10)
                }
            }
            .frame(maxWidth: .infinity)

            Divider()

            // Right Pane: Transcript & Playback
            VStack {
                if let convo = selectedConversation ?? viewModel.conversations.first {
                    ConversationTranscriptView(
                        conversation: convo,
                        repository: dependencies.conversationRepository,
                        speechSynthesisService: dependencies.speechSynthesisService,
                        userId: viewModel.userId
                    )
                    .id(convo.id)
                } else {
                    ContentUnavailableView(
                        "No Conversation Selected",
                        systemImage: "bubble.left.and.bubble.right.fill",
                        description: Text("Choose a conversation from the left to view messages, play back speech, or export transcript.")
                    )
                }
            }
            .frame(width: 480)
            .background(Color.appBackground)
        }
    }

    // MARK: - iPhone Compact List View

    private var iphoneListView: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.m) {
                    securityPrivacyBanner
                    searchDictationBar
                    filterChipsBar
                    swipeTipRow
                    conversationCardsStack
                    weeklyDigestCard
                    endOfFeedIndicator
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.bottom, 40)
            }

            if let toast = viewModel.toastMessage {
                toastView(toast)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
    }

    // MARK: - 1. Security Privacy Banner
    private var securityPrivacyBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.brandTurquoise.opacity(0.12))
                    .frame(width: 34, height: 34)

                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.brandTurquoise)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(router.protectConversationHistory ? "\(router.biometricName) Protected" : "Security Shield Active")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.brandNavy)

                    Circle()
                        .fill(Color.brandTurquoise)
                        .frame(width: 4, height: 4)

                    Text("E2E Encrypted")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }

                Text("Device-only neural sign logs")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: router.biometricType == .faceID ? "faceid" : "touchid")
                    .font(.system(size: 16))
                Image(systemName: "lock.fill")
                    .font(.system(size: 13))
            }
            .foregroundStyle(Color.brandTurquoise)
        }
        .padding(Theme.Spacing.s)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)
        .padding(.top, 4)
    }

    // MARK: - 2. Search & Voice Dictation Bar
    private var searchDictationBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(Color.textSecondary)

            TextField("Search conversations, places or signs...", text: $viewModel.searchQuery)
                .font(.system(size: 14))
                .foregroundStyle(Color.brandNavy)

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.textSecondary)
                }
            }

            Button {
                viewModel.toggleDictationSearch()
            } label: {
                Image(systemName: viewModel.isDictatingSearch ? "mic.fill" : "mic")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(viewModel.isDictatingSearch ? Color.danger : Color.brandTurquoise)
                    .frame(width: 30, height: 30)
                    .background(viewModel.isDictatingSearch ? Color.danger.opacity(0.12) : Color.clear, in: Circle())
            }
            .accessibilityLabel("Audio Search")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)
    }

    // MARK: - 3. Filter Chips Bar
    private var filterChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ConversationHistoryFilter.allCases) { filter in
                    let isSelected = viewModel.selectedFilter == filter
                    Button {
                        viewModel.selectedFilter = filter
                    } label: {
                        HStack(spacing: 6) {
                            if filter == .saved {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(isSelected ? Color.brandNavy : Color.brandYellow)
                            } else if filter == .thisWeek {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12))
                            } else if filter == .transcripts {
                                Image(systemName: "captions.bubble.fill")
                                    .font(.system(size: 12))
                            }

                            if filter == .all {
                                Text("All (\(viewModel.conversations.count))")
                            } else {
                                Text(filter.rawValue)
                            }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.white : Color.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.brandNavy : Color.cardBackground, in: Capsule())
                        .shadow(color: Color.black.opacity(0.04), radius: 3, y: 1)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - 4. Swipe Tip Row
    private var swipeTipRow: some View {
        HStack {
            HStack(spacing: 5) {
                Image(systemName: "hand.draw")
                    .font(.system(size: 12))
                Text("Swipe cards left to reveal quick actions")
                    .font(.system(size: 11))
            }
            .foregroundStyle(Color.textSecondary)

            Spacer()

            Text("AUTO-BACKED UP")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.brandTurquoise)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - 5. Conversation Cards Stack
    private var conversationCardsStack: some View {
        LazyVStack(spacing: 12) {
            if viewModel.filteredConversations.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.exclamationmark.bubble.right.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.textSecondary.opacity(0.4))
                        .padding(.top, 24)

                    Text("No Conversations Found")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.brandNavy)

                    Text("No sessions match your search or selected filter.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(viewModel.filteredConversations) { convo in
                    conversationCard(convo)
                }
            }
        }
    }

    // MARK: - Conversation Card
    private func conversationCard(_ convo: SavedConversation) -> some View {
        Button {
            selectedConversation = convo
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                // Header Row
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.brandTurquoise)
                            .frame(width: 7, height: 7)

                        Text(convo.formattedDateWithDuration)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                    }

                    Spacer()

                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10))
                        Text("Swipe")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(Color.textSecondary.opacity(0.7))
                }

                // Venue Title & Star Button
                HStack(alignment: .center, spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.brandTurquoise.opacity(0.12))
                            .frame(width: 36, height: 36)

                        Image(systemName: convo.venueIcon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.brandTurquoise)
                    }

                    Text(convo.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.brandNavy)
                        .lineLimit(1)

                    Spacer()

                    Button {
                        Task {
                            await viewModel.toggleSaved(conversation: convo)
                        }
                    } label: {
                        Image(systemName: convo.isSaved ? "star.fill" : "star")
                            .font(.system(size: 18))
                            .foregroundStyle(convo.isSaved ? Color.brandYellow : Color.textSecondary.opacity(0.4))
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }

                // Dialog Preview Box
                VStack(alignment: .leading, spacing: 6) {
                    if let partner = convo.partnerPreview {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(partner.speaker):")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.brandNavy)

                            Text(partner.text)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    if let user = convo.userPreview {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            HStack(spacing: 3) {
                                Image(systemName: "hands.sparkles.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.brandTurquoise)
                                Text("\(user.speaker):")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.brandTurquoise)
                            }

                            Text("[Signed] \(user.text)")
                                .font(.system(size: 12))
                                .italic()
                                .foregroundStyle(Color.brandNavy)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Meta Badges & Review Action
                HStack {
                    HStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11))
                            Text("\(convo.signsRecognizedCount) signs recognized")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Color.brandTurquoise)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.brandTurquoise.opacity(0.12), in: Capsule())

                        HStack(spacing: 3) {
                            Image(systemName: "speedometer")
                                .font(.system(size: 11))
                            Text("\(convo.accuracyPercentage)% accuracy")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Color.brandNavy)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.brandYellow.opacity(0.2), in: Capsule())
                    }

                    Spacer()

                    HStack(spacing: 3) {
                        Text("Review")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(Color.brandTurquoise)
                }
            }
            .padding(Theme.Spacing.m)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(selectedConversation?.id == convo.id && horizontalSizeClass == .regular ? Color.brandTurquoise : Color.clear, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task {
                    await viewModel.deleteConversation(id: convo.id)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                Task {
                    await viewModel.toggleSaved(conversation: convo)
                }
            } label: {
                Label(convo.isSaved ? "Unstar" : "Save", systemImage: convo.isSaved ? "star.slash" : "bookmark.fill")
            }
            .tint(Color.brandYellow)
        }
    }

    // MARK: - 6. Weekly Digest Summary Card
    private var weeklyDigestCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WEEKLY SIGN MILESTONE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.brandTurquoise)

                    Text("\(viewModel.weeklySignsCaptured) Signs Captured")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.white)

                    Text("Real-time accuracy increased by 6.4% this week with zero packet loss.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.75))
                        .lineSpacing(2)
                }

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.brandYellow)
                }
            }

            Divider()
                .background(Color.white.opacity(0.15))

            HStack {
                Text("Encrypted cloud sync: Active")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.65))

                Spacer()

                Button {
                    exportText = viewModel.generateExportSummary()
                    isShowingExportSheet = true
                } label: {
                    HStack(spacing: 5) {
                        Text("Export Logs")
                            .font(.system(size: 12, weight: .bold))
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(Color.brandNavy)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.brandTurquoise, in: Capsule())
                }
            }
        }
        .padding(Theme.Spacing.m)
        .background(
            LinearGradient(
                colors: [Color.brandNavy, Color(red: 0.05, green: 0.15, blue: 0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.brandNavy.opacity(0.2), radius: 8, y: 4)
    }

    // MARK: - 7. End of Feed Indicator
    private var endOfFeedIndicator: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.cardBackground)
                    .frame(width: 36, height: 36)

                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.textSecondary)
            }

            Text("All caught up")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.brandNavy)

            Text("Past 30 days of conversation sessions are stored locally")
                .font(.system(size: 11))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }

    // MARK: - Toast View
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
