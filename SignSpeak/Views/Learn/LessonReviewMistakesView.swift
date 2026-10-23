import SwiftUI

/// Screen presenting targeted review for missed signs during lessons and practice.
/// Matches design `37-review-mistakes`.
public struct LessonReviewMistakesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies

    public let summary: LessonCompletionSummary
    public var onStartPractice: (([Sign]) -> Void)?
    public var onPracticeSingleSign: ((Sign) -> Void)?

    @State private var selectedSignForPractice: Sign?
    @State private var isShowingPracticeSession: Bool = false

    public init(
        summary: LessonCompletionSummary,
        onStartPractice: (([Sign]) -> Void)? = nil,
        onPracticeSingleSign: ((Sign) -> Void)? = nil
    ) {
        self.summary = summary
        self.onStartPractice = onStartPractice
        self.onPracticeSingleSign = onPracticeSingleSign
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.l) {
                        // 1. Targeted Mastery Header
                        headerSection
                            .padding(.horizontal, Theme.Spacing.l)
                            .padding(.top, Theme.Spacing.s)

                        // 2. Missed Sign Cards List
                        missedSignsList
                            .padding(.horizontal, Theme.Spacing.l)

                        // 3. Bonus XP Card
                        bonusXPCard
                            .padding(.horizontal, Theme.Spacing.l)

                        Spacer(minLength: 40)
                    }
                    .padding(.bottom, 100)
                }

                // 4. Floating Bottom Action Button
                VStack {
                    Spacer()
                    bottomActionBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                    }
                    .accessibilityLabel("Back")
                }

                ToolbarItem(placement: .principal) {
                    Text("Lesson Review")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            // Info action
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.textSecondary)
                        }
                        .accessibilityLabel("Review Information")

                        Circle()
                            .fill(Color.brandNavy.opacity(0.1))
                            .frame(width: 32, height: 32)
                            .overlay {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.brandNavy)
                            }
                    }
                }
            }
            .fullScreenCover(item: $selectedSignForPractice) { sign in
                PracticeView(
                    signs: [sign],
                    lessonTitle: "Review: \(sign.name)"
                )
            }
            .fullScreenCover(isPresented: $isShowingPracticeSession) {
                let signsToPractice = resolvedMistakeSigns()
                PracticeView(
                    signs: !signsToPractice.isEmpty ? signsToPractice : dependencies.signCatalogService.signs(forCategory: "alphabet"),
                    lessonTitle: "Targeted Mistakes Review"
                )
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TARGETED MASTERY")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color.brandTurquoise)

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.brandYellow)
                        .frame(width: 8, height: 8)

                    Text("\(summary.mistakes.count) signs to master")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.brandYellow.opacity(0.2), in: Capsule())
            }

            Text("Focus on these \(summary.mistakes.count) signs to reach 100% accuracy")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)

            // Dual Progress Bar: Current vs Goal
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track (Goal up to 100%)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.brandYellow.opacity(0.35))
                            .frame(height: 10)

                        // Current Accuracy Progress Fill
                        let fraction = max(0.1, min(1.0, Double(summary.accuracyPercentage) / 100.0))
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.brandTurquoise)
                            .frame(width: geo.size.width * fraction, height: 10)
                    }
                }
                .frame(height: 10)

                HStack {
                    Text("Current: \(summary.accuracyPercentage)%")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.textSecondary)

                    Spacer()

                    Text("Goal: 100%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Missed Signs Cards

    private var missedSignsList: some View {
        VStack(spacing: Theme.Spacing.m) {
            if summary.mistakes.isEmpty {
                emptyMistakesView
            } else {
                ForEach(summary.mistakes) { mistake in
                    missedSignCard(mistake: mistake)
                }
            }
        }
    }

    private func missedSignCard(mistake: LessonMistakeItem) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                // Sign Thumbnail
                signThumbnail(for: mistake)

                // Sign Title, Detected Tag, and Hint
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.brandTurquoise)

                        Text(mistake.displayTitle)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.textPrimary)
                    }

                    // Detected as Tag
                    HStack(spacing: 4) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 9))
                        Text("Detected as '\(mistake.detectedAs)'")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Color.danger)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.danger.opacity(0.12), in: Capsule())

                    // Hint Text
                    Text(mistake.hint)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                // Single Sign Practice Refresh Button
                Button {
                    let targetSign = mistake.sign ?? dependencies.signCatalogService.sign(byId: mistake.signId) ?? dependencies.signCatalogService.sign(named: mistake.signName)
                    if let targetSign {
                        if let onPracticeSingleSign {
                            onPracticeSingleSign(targetSign)
                        } else {
                            selectedSignForPractice = targetSign
                        }
                    }
                } label: {
                    Circle()
                        .fill(Color.brandTurquoise.opacity(0.18))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.brandTurquoise)
                        }
                }
                .accessibilityLabel("Practise \(mistake.signName) now")
            }

            // Bottom Pill Inside Card: Category Aspect & Miss Count
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: aspectIcon(for: mistake.categoryAspect))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)

                    Text(mistake.categoryAspect)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                Text(mistake.missCountText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.danger)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.appBackground.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    private func signThumbnail(for mistake: LessonMistakeItem) -> some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.brandNavy.opacity(0.08))
                .frame(width: 84, height: 84)

            // Image from catalog or letter monogram
            if let sign = mistake.sign ?? dependencies.signCatalogService.sign(byId: mistake.signId),
               let imageName = sign.imageName,
               !imageName.isEmpty {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                Text(mistake.signName)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.brandNavy)
            }

            // Eye / media icon in bottom right corner matching design
            Circle()
                .fill(Color.black.opacity(0.65))
                .frame(width: 20, height: 20)
                .overlay {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white)
                }
                .padding(4)
        }
    }

    private func aspectIcon(for aspect: String) -> String {
        switch aspect {
        case "Cadence & Repetition":
            return "arrow.triangle.2.circlepath"
        case "Palm Orientation":
            return "hand.raised.fill"
        case "Spatial Depth":
            return "viewfinder"
        default:
            return "gearshape.fill"
        }
    }

    private var emptyMistakesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.brandTurquoise)

            Text("No Mistakes to Review!")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            Text("You nailed all the signs in this session with perfect accuracy.")
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.xl)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    // MARK: - Bonus XP Card

    private var bonusXPCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.brandYellow.opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.brandYellow)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text("+\(summary.reviewBonusXP) XP Bonus Waiting")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)

                Text(summary.mistakes.count > 1
                     ? "Mastering both sign cards unlocks the Precision Badge."
                     : "Mastering this sign card unlocks the Precision Badge.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    // MARK: - Floating Bottom Action Bar

    private var bottomActionBar: some View {
        VStack {
            Button {
                let signsToPractice = resolvedMistakeSigns()
                if let onStartPractice {
                    onStartPractice(signsToPractice)
                } else {
                    isShowingPracticeSession = true
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Start practice session (3m)")
                        .fontWeight(.bold)
                    Image(systemName: "arrow.right")
                        .fontWeight(.bold)
                }
                .font(.appButton)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Color.brandNavy, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.l)
        }
        .background(
            LinearGradient(
                colors: [Color.appBackground.opacity(0.0), Color.appBackground, Color.appBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private func resolvedMistakeSigns() -> [Sign] {
        summary.mistakes.compactMap { mistake in
            mistake.sign ??
            dependencies.signCatalogService.sign(byId: mistake.signId) ??
            dependencies.signCatalogService.sign(named: mistake.signName)
        }
    }
}
