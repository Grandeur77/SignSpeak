import SwiftUI

/// Detailed view for studying an individual American Sign Language sign.
/// Matches designs `45-sign-detail-hello` and `33-sign-detail-letter-m`.
/// Embeds `SignMediaPlayer`, step-by-step breakdown cards, common mistakes,
/// mnemonic tips, real mastery status, and provides direct entry points to
/// camera practice (for recognizable signs) or watch-and-choose quiz.
public struct SignDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies

    public let initialSign: Sign?
    public let signId: String
    public var onPractice: ((Sign) -> Void)?

    @State private var viewModel: SignDetailViewModel?
    @State private var isPresentingCameraPractice: Bool = false
    @State private var isPresentingWatchAndChoose: Bool = false
    @State private var isPresentingFavouritesList: Bool = false

    // MARK: - Initializers

    public init(sign: Sign, onPractice: ((Sign) -> Void)? = nil) {
        self.initialSign = sign
        self.signId = sign.id
        self.onPractice = onPractice
    }

    public init(signId: String, onPractice: ((Sign) -> Void)? = nil) {
        self.initialSign = nil
        self.signId = signId
        self.onPractice = onPractice
    }

    public init(viewModel: SignDetailViewModel, onPractice: ((Sign) -> Void)? = nil) {
        self.initialSign = viewModel.sign
        self.signId = viewModel.signId
        self.onPractice = onPractice
        _viewModel = State(initialValue: viewModel)
    }

    public var sign: Sign? {
        viewModel?.sign ?? initialSign
    }

    public var body: some View {
        Group {
            if let vm = viewModel, let currentSign = vm.sign {
                detailContent(sign: currentSign, vm: vm)
            } else if let fallbackSign = initialSign {
                // Temporary fallback while loading
                detailContent(sign: fallbackSign, vm: nil)
            } else {
                loadingOrMissingView
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Sign Detail")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                // 1. Bookmark / Save Button
                Button {
                    toggleBookmark()
                } label: {
                    let isBookmarked = viewModel?.isBookmarked ?? false
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16))
                        .foregroundStyle(isBookmarked ? Color.brandTurquoise : Color.textPrimary)
                }
                .accessibilityLabel((viewModel?.isBookmarked ?? false) ? "Remove bookmark" : "Bookmark sign")

                // 2. Share Link
                if let vm = viewModel {
                    ShareLink(
                        item: vm.shareText,
                        subject: Text("ASL Sign: \(vm.sign?.name ?? "Sign")"),
                        message: Text("Check out how to sign '\(vm.sign?.name ?? "this sign")' in ASL on SignSpeak!")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.textPrimary)
                    }
                    .accessibilityLabel("Share sign details")
                } else if let s = initialSign {
                    ShareLink(
                        item: "\(s.name) — American Sign Language (\(s.category))\n\n\(s.description)",
                        subject: Text("ASL Sign: \(s.name)"),
                        message: Text("Check out how to sign '\(s.name)' in ASL on SignSpeak!")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.textPrimary)
                    }
                    .accessibilityLabel("Share sign details")
                }

                // 3. Overflow Menu
                Menu {
                    Button {
                        isPresentingFavouritesList = true
                    } label: {
                        Label("View All Favourites", systemImage: "heart")
                    }

                    if let currentSign = sign, currentSign.isRecognizable {
                        Button {
                            startWatchAndChoose()
                        } label: {
                            Label("Watch & Choose Quiz", systemImage: "checkmark.circle.badge.questionmark")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.textPrimary)
                }
                .accessibilityLabel("More sign options")
            }
        }
        .task {
            await setupViewModel()
        }
        .fullScreenCover(isPresented: $isPresentingCameraPractice) {
            if let activeSign = sign {
                PracticeView(signs: [activeSign], lessonTitle: activeSign.name)
            }
        }
        .fullScreenCover(isPresented: $isPresentingWatchAndChoose) {
            if let vm = viewModel, let q = vm.makeWatchAndChooseQuestion() {
                QuizView(
                    questions: [q],
                    quizTitle: "Practise: \(vm.sign?.name ?? "Sign")"
                )
            }
        }
        .sheet(isPresented: $isPresentingFavouritesList) {
            FavouritesView()
        }
    }

    // MARK: - Main Scroll Content

    private func detailContent(sign: Sign, vm: SignDetailViewModel?) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                // 1. Interactive Sign Media Player
                SignMediaPlayer(sign: sign)
                    .padding(.top, Theme.Spacing.s)

                // 2. Sign Header & Identity
                headerSection(sign: sign, vm: vm)

                // 3. Mastery & Practice Stats Pill
                masteryStatsRow(sign: sign, vm: vm)

                // 4. Badges Section
                badgesSection(sign: sign)

                // 5. Description Card
                descriptionSection(sign: sign)

                // 6. How to Sign Section
                howToSignSection(sign: sign)

                // 7. Common Mistake Callout (if present)
                if let commonMistake = sign.commonMistake, !commonMistake.isEmpty {
                    commonMistakeCallout(commonMistake)
                }

                // 8. Mnemonic Tip Callout (if present)
                if let mnemonicTip = sign.mnemonicTip, !mnemonicTip.isEmpty {
                    mnemonicTipCallout(mnemonicTip)
                }

                // Bottom Spacer to prevent overlap with sticky CTA
                Spacer(minLength: 90)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.l)
        }
        .safeAreaInset(edge: .bottom) {
            bottomPracticeButton(sign: sign, vm: vm)
        }
    }

    // MARK: - Header Section

    private func headerSection(sign: Sign, vm: SignDetailViewModel?) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(sign.name)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)

                    if let hint = sign.pronunciationHint, !hint.isEmpty {
                        Text(hint.hasPrefix("/") ? hint : "/\(hint)/")
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                // Category Subtitle
                HStack(spacing: 6) {
                    Image(systemName: vm?.subtitleIconName ?? "hand.wave")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.brandTurquoise)

                    Text(vm?.subtitleText ?? "\(sign.category.capitalized) ASL Sign")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                }
            }

            Spacer()

            // Favorite Button (Heart)
            Button {
                toggleBookmark()
            } label: {
                let isFav = vm?.isFavourite ?? false
                ZStack {
                    Circle()
                        .fill(Color.cardBackground)
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(Color.gray.opacity(0.18), lineWidth: 1))

                    Image(systemName: isFav ? "heart.fill" : "heart")
                        .font(.system(size: 20))
                        .foregroundStyle(isFav ? Color.danger : Color.textSecondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel((vm?.isFavourite ?? false) ? "Remove from favourites" : "Add to favourites")
        }
    }

    // MARK: - Mastery Stats Row

    private func masteryStatsRow(sign: Sign, vm: SignDetailViewModel?) -> some View {
        HStack(spacing: 10) {
            // Mastery Status Pill
            let statusTitle = vm?.masteryStatusTitle ?? "New Sign"
            let statusColor = vm?.masteryStatusColor ?? Color.brandTurquoise

            HStack(spacing: 6) {
                Image(systemName: statusIcon(for: statusTitle))
                    .font(.system(size: 12, weight: .bold))

                Text(statusTitle)
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(statusTitle == "Mastered" ? Color.black : Color.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusColor, in: Capsule())

            // Accuracy Pill if available
            if let accuracy = vm?.accuracyPercentageText {
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 10))
                    Text(accuracy)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.cardBackground, in: Capsule())
                .overlay(Capsule().stroke(Color.gray.opacity(0.18), lineWidth: 1))
            }

            // Attempts Count if available
            if let attempts = vm?.attemptsCountText {
                Text(attempts)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()
        }
    }

    private func statusIcon(for title: String) -> String {
        switch title {
        case "Mastered": return "checkmark.seal.fill"
        case "Learning": return "flame.fill"
        default: return "sparkles"
        }
    }

    // MARK: - Badges Section

    private func badgesSection(sign: Sign) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Category Badge
                Text(sign.category.capitalized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.brandTurquoise, in: Capsule())

                // Level Badge
                Text("ASL Level \(levelNumber(sign.level))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.cardBackground, in: Capsule())
                    .overlay(Capsule().stroke(Color.gray.opacity(0.2), lineWidth: 1))

                // Frequency Badge
                if let freq = sign.frequencyTag {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                        Text(freq)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.brandYellow, in: Capsule())
                }

                // Handedness Badge
                HStack(spacing: 4) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 10))
                    Text(sign.handedness.displayName)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.cardBackground, in: Capsule())
                .overlay(Capsule().stroke(Color.gray.opacity(0.15), lineWidth: 1))

                // Recognition Engine Badge
                HStack(spacing: 4) {
                    Image(systemName: recognitionIcon(sign.recognition))
                        .font(.system(size: 10))
                    Text(recognitionTitle(sign.recognition))
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Color.brandTurquoise)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.brandTurquoise.opacity(0.12), in: Capsule())
            }
        }
    }

    private func recognitionIcon(_ type: SignRecognitionType) -> String {
        switch type {
        case .motionSign: return "waveform"
        case .staticSign: return "camera.fill"
        case .none: return "eye.fill"
        }
    }

    private func recognitionTitle(_ type: SignRecognitionType) -> String {
        switch type {
        case .motionSign: return "Dynamic Motion Gesture"
        case .staticSign: return "Static Pose Recognizable"
        case .none: return "Visual Study Sign"
        }
    }

    // MARK: - Description Section

    private func descriptionSection(sign: Sign) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overview")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.textSecondary)
                .textCase(.uppercase)

            Text(sign.description)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.textPrimary)
                .lineSpacing(4)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.gray.opacity(0.14), lineWidth: 1)
        )
    }

    // MARK: - How to Sign Section

    private func howToSignSection(sign: Sign) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            // Section Header
            HStack {
                HStack(spacing: 8) {
                    Capsule()
                        .fill(Color.brandTurquoise)
                        .frame(width: 4, height: 18)

                    Text("How to sign")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                }

                Spacer()

                Text("\(sign.howToSteps.count) simple steps")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.brandTurquoise)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.brandTurquoise.opacity(0.12), in: Capsule())
            }

            // Steps List
            VStack(spacing: 12) {
                ForEach(Array(sign.howToSteps.enumerated()), id: \.offset) { index, stepText in
                    stepCard(number: index + 1, content: stepText)
                }
            }
        }
    }

    private func stepCard(number: Int, content: String) -> some View {
        let (stepTitle, stepBody) = parseStep(content)

        return HStack(alignment: .top, spacing: 14) {
            // Step Number Badge
            ZStack {
                Circle()
                    .fill(Color.brandNavy)
                    .frame(width: 28, height: 28)

                Text("\(number)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white)
            }
            .padding(.top, 2)

            // Step Content
            VStack(alignment: .leading, spacing: 4) {
                if let stepTitle {
                    Text(stepTitle)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                }

                Text(stepBody)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
                    .lineSpacing(3)
            }

            Spacer()
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.gray.opacity(0.14), lineWidth: 1)
        )
    }

    // MARK: - Callouts

    private func commonMistakeCallout(_ mistake: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.brandYellow.opacity(0.3))
                    .frame(width: 32, height: 32)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.brandYellow)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Common mistake")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Text(mistake)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textPrimary.opacity(0.85))
                    .lineSpacing(3)
            }

            Spacer()
        }
        .padding(Theme.Spacing.m)
        .background(Color.brandYellow.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.brandYellow.opacity(0.35), lineWidth: 1)
        )
    }

    private func mnemonicTipCallout(_ tip: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.brandTurquoise.opacity(0.25))
                    .frame(width: 32, height: 32)

                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.brandTurquoise)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Mnemonic tip")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Text(tip)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textPrimary.opacity(0.85))
                    .lineSpacing(3)
            }

            Spacer()
        }
        .padding(Theme.Spacing.m)
        .background(Color.brandTurquoise.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.brandTurquoise.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Bottom Sticky CTA

    private func bottomPracticeButton(sign: Sign, vm: SignDetailViewModel?) -> some View {
        let isRecognizable = sign.isRecognizable

        return HStack(spacing: 12) {
            // Primary Practice Button
            Button {
                triggerHaptic()
                if let onPractice {
                    onPractice(sign)
                } else if isRecognizable {
                    isPresentingCameraPractice = true
                } else {
                    isPresentingWatchAndChoose = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isRecognizable ? "video.fill" : "checkmark.circle.badge.questionmark")
                        .font(.system(size: 16, weight: .semibold))

                    Text(isRecognizable ? "Practise with camera" : "Practise (Watch & Choose)")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.brandTurquoise, in: Capsule())
                .shadow(color: Color.brandTurquoise.opacity(0.35), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRecognizable ? "Practise \(sign.name) with camera" : "Practise \(sign.name) with watch and choose quiz")

            // Mode Selector Pill if recognizable
            if isRecognizable {
                Menu {
                    Button {
                        isPresentingCameraPractice = true
                    } label: {
                        Label("Camera Recognition", systemImage: "video")
                    }

                    Button {
                        isPresentingWatchAndChoose = true
                    } label: {
                        Label("Watch & Choose Quiz", systemImage: "checkmark.circle.badge.questionmark")
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .frame(width: 50, height: 50)
                        .background(Color.cardBackground, in: Circle())
                        .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                }
                .accessibilityLabel("Select practice mode")
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
        .background(
            Color.appBackground
                .opacity(0.95)
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Loading / Missing View

    private var loadingOrMissingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Color.brandTurquoise)

            Text("Loading sign...")
                .font(.system(size: 15))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions & Helpers

    private func setupViewModel() async {
        if viewModel == nil {
            let userId = dependencies.authService.currentUserId ?? "default"
            let vm: SignDetailViewModel
            if let initialSign {
                vm = SignDetailViewModel(
                    sign: initialSign,
                    favouritesRepository: dependencies.favouritesRepository,
                    progressRepository: dependencies.progressRepository,
                    signCatalogService: dependencies.signCatalogService,
                    userId: userId
                )
            } else {
                vm = SignDetailViewModel(
                    signId: signId,
                    favouritesRepository: dependencies.favouritesRepository,
                    progressRepository: dependencies.progressRepository,
                    signCatalogService: dependencies.signCatalogService,
                    userId: userId
                )
            }
            self.viewModel = vm
        }

        await viewModel?.load()
    }

    private func toggleBookmark() {
        triggerHaptic()
        Task {
            await viewModel?.toggleFavourite()
        }
    }

    private func startWatchAndChoose() {
        isPresentingWatchAndChoose = true
    }

    private func levelNumber(_ level: SignLevel) -> Int {
        switch level {
        case .beginner: return 1
        case .intermediate: return 2
        case .advanced: return 3
        }
    }

    private func parseStep(_ rawText: String) -> (title: String?, body: String) {
        let parts = rawText.components(separatedBy: ": ")
        if parts.count >= 2 {
            let title = parts[0].trimmingCharacters(in: .whitespaces)
            let body = parts.dropFirst().joined(separator: ": ").trimmingCharacters(in: .whitespaces)
            return (title, body)
        }
        return (nil, rawText)
    }

    private func triggerHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
}

#Preview("Sign Detail - Hello") {
    NavigationStack {
        SignDetailView(
            sign: Sign(
                id: "sign-word-hello",
                name: "Hello",
                pronunciationHint: "HEH-loh",
                category: "greetings",
                level: .beginner,
                frequencyTag: "Top 10",
                handedness: .oneHanded,
                recognition: .motionSign,
                description: "A friendly salute gesture moving away from your forehead.",
                howToSteps: [
                    "Open Hand: Place the flat side of your dominant open hand near your temple (like a salute).",
                    "Forward Wave: Move your hand forward and outward away from your forehead with a gentle, smooth arc.",
                    "Expression: Smile and make friendly eye contact."
                ],
                commonMistake: "Don't flick your hand too abruptly or touch your forehead too roughly.",
                mnemonicTip: "A warm military salute to a friend."
            )
        )
        .environment(\.dependencies, .preview)
    }
}

#Preview("Sign Detail - Letter M") {
    NavigationStack {
        SignDetailView(
            sign: Sign(
                id: "sign-letter-m",
                name: "M",
                pronunciationHint: "EM",
                category: "alphabet",
                level: .beginner,
                frequencyTag: "Fingerspelling",
                handedness: .oneHanded,
                recognition: .staticSign,
                description: "Thumb tucked under the first three curled fingers (index, middle, ring).",
                howToSteps: [
                    "Thumb across palm: Tuck your thumb across your palm.",
                    "Three fingers over: Fold index, middle, and ring fingers over top of the thumb.",
                    "Rest pinky: Pinky curls into the palm beside them."
                ],
                commonMistake: "Confusing with N (M covers 3 fingers; N covers 2).",
                mnemonicTip: "Three fingers over thumb like the three downward humps of an 'm'."
            )
        )
        .environment(\.dependencies, .preview)
    }
}
