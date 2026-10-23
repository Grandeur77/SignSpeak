import SwiftUI

/// Detailed view for studying an individual American Sign Language sign.
/// Matches designs `45-sign-detail-hello` and `33-sign-detail-letter-m`.
/// Embeds `SignMediaPlayer`, step-by-step breakdown cards, common mistakes,
/// mnemonic tips, and provides a direct entry point to live camera practice.
public struct SignDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies

    public let sign: Sign
    public var onPractice: ((Sign) -> Void)?

    @State private var isBookmarked: Bool = false
    @State private var isFavorited: Bool = false
    @State private var showingPracticeSheet: Bool = false

    public init(sign: Sign, onPractice: ((Sign) -> Void)? = nil) {
        self.sign = sign
        self.onPractice = onPractice
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                // 1. Interactive Sign Media Player
                SignMediaPlayer(sign: sign)
                    .padding(.top, Theme.Spacing.s)

                // 2. Sign Header & Identity
                headerSection

                // 3. Category & Difficulty Badges
                badgesSection

                // 4. Description
                Text(sign.description)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color.textPrimary)
                    .lineSpacing(4)

                // 5. How to Sign Section
                howToSignSection

                // 6. Common Mistake Callout (if present)
                if let commonMistake = sign.commonMistake, !commonMistake.isEmpty {
                    commonMistakeCallout(commonMistake)
                }

                // 7. Mnemonic Tip Callout (if present)
                if let mnemonicTip = sign.mnemonicTip, !mnemonicTip.isEmpty {
                    mnemonicTipCallout(mnemonicTip)
                }

                // Spacing for bottom button clearance
                Spacer(minLength: 80)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.l)
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
                // Bookmark / Save Button
                Button {
                    isBookmarked.toggle()
                    triggerHaptic()
                } label: {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16))
                        .foregroundStyle(isBookmarked ? Color.brandTurquoise : Color.textPrimary)
                }
                .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Bookmark sign")

                // Share Link
                ShareLink(
                    item: "\(sign.name) — American Sign Language (\(sign.category))\n\n\(sign.description)",
                    subject: Text("ASL Sign: \(sign.name)"),
                    message: Text("Check out how to sign '\(sign.name)' in ASL on SignSpeak!")
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.textPrimary)
                }
                .accessibilityLabel("Share sign details")
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomPracticeButton
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(sign.name)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)

                    if let hint = sign.pronunciationHint, !hint.isEmpty {
                        Text(hint)
                            .font(.system(size: 18, weight: .medium, design: .serif))
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                // Category Subtitle
                HStack(spacing: 6) {
                    Image(systemName: subtitleIconName)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.brandTurquoise)

                    Text(subtitleText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                }
            }

            Spacer()

            // Favorite Button
            Button {
                isFavorited.toggle()
                triggerHaptic()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.cardBackground)
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(Color.gray.opacity(0.18), lineWidth: 1))

                    Image(systemName: isFavorited ? "heart.fill" : "heart")
                        .font(.system(size: 20))
                        .foregroundStyle(isFavorited ? Color.danger : Color.textSecondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorited ? "Remove from favourites" : "Add to favourites")
        }
    }

    // MARK: - Badges Section

    private var badgesSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Category Badge
                Text(sign.category)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.brandTurquoise, in: Capsule())

                // Level Badge
                Text("ASL Level \(levelNumber)")
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
                    Image(systemName: sign.recognition == .motionSign ? "video.badge.waveform" : "camera.metering.matrix")
                        .font(.system(size: 10))
                    Text(sign.recognition.title)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Color.brandTurquoise)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.brandTurquoise.opacity(0.12), in: Capsule())
            }
        }
    }

    // MARK: - How to Sign Section

    private var howToSignSection: some View {
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

    private var bottomPracticeButton: some View {
        Button {
            triggerHaptic()
            if let onPractice {
                onPractice(sign)
            } else {
                showingPracticeSheet = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "video.fill")
                    .font(.system(size: 16, weight: .semibold))

                Text("Practise this sign")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.brandNavy, in: Capsule())
            .shadow(color: Color.black.opacity(0.18), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
        .background(
            Color.appBackground
                .opacity(0.95)
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
        .accessibilityLabel("Practise \(sign.name) with camera")
        .sheet(isPresented: $showingPracticeSheet) {
            practicePlaceholderSheet
        }
    }

    private var practicePlaceholderSheet: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.l) {
                ZStack {
                    Circle()
                        .fill(Color.brandTurquoise.opacity(0.15))
                        .frame(width: 80, height: 80)

                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 38))
                        .foregroundStyle(Color.brandTurquoise)
                }
                .padding(.top, Theme.Spacing.xl)

                VStack(spacing: 8) {
                    Text("Practise \(sign.name)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)

                    Text("Live gesture recognition will guide your hand shapes in Phase 5.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.l)
                }

                SignMediaPlayer(sign: sign)
                    .padding(.horizontal, Theme.Spacing.l)

                Spacer()

                Button("Done") {
                    showingPracticeSheet = false
                }
                .font(.headline)
                .foregroundStyle(Color.brandTurquoise)
                .padding(.bottom, Theme.Spacing.l)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        showingPracticeSheet = false
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var levelNumber: Int {
        switch sign.level {
        case .beginner: return 1
        case .intermediate: return 2
        case .advanced: return 3
        }
    }

    private var subtitleIconName: String {
        if sign.category.lowercased().contains("alphabet") {
            return "character.textbox"
        } else if sign.category.lowercased().contains("number") {
            return "number"
        } else {
            return "hand.wave"
        }
    }

    private var subtitleText: String {
        if sign.category.lowercased().contains("alphabet") {
            return "Manual Alphabet Finger-spelling"
        } else if sign.category.lowercased().contains("greeting") {
            return "Formal & Informal ASL Greeting"
        } else {
            return "\(sign.category) ASL Sign"
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
