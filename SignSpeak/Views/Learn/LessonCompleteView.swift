import SwiftUI

/// Lesson completion celebration view displaying accuracy ring, session stats,
/// streak milestone, unlocked badge, spatial depth accuracy feedback, and mistakes review.
/// Matches design `35-lesson-complete`.
public struct LessonCompleteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public let summary: LessonCompletionSummary
    public var onContinue: (() -> Void)?
    public var onReviewMistakes: (() -> Void)?

    @State private var animatedRingProgress: Double = 0.0
    @State private var isShowingReviewMistakes: Bool = false

    public init(
        summary: LessonCompletionSummary,
        onContinue: (() -> Void)? = nil,
        onReviewMistakes: (() -> Void)? = nil
    ) {
        self.summary = summary
        self.onContinue = onContinue
        self.onReviewMistakes = onReviewMistakes
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                // Accessible celebration confetti (suppressed if Reduce Motion is enabled)
                if !reduceMotion {
                    ConfettiView()
                }

                ScrollView {
                    VStack(spacing: Theme.Spacing.l) {
                        // 1. Milestone Pill & Lesson Complete Header
                        headerSection
                            .padding(.horizontal, Theme.Spacing.l)
                            .padding(.top, Theme.Spacing.xs)

                        // 2. Large Circular Accuracy Ring Card
                        accuracyRingCard
                            .padding(.horizontal, Theme.Spacing.l)

                        // 3. Three Session Stat Cards (Signs, Time, Streak)
                        sessionStatCardsRow
                            .padding(.horizontal, Theme.Spacing.l)

                        // 4. New Badge Unlocked Card
                        if let badge = summary.unlockedBadge {
                            badgeUnlockedCard(badge: badge)
                                .padding(.horizontal, Theme.Spacing.l)
                        }

                        // 5. Spatial Accuracy Feedback Note
                        if let note = summary.spatialAccuracyNote {
                            spatialAccuracyCard(note: note)
                                .padding(.horizontal, Theme.Spacing.l)
                        }

                        // 6. Action Buttons (Continue & Review Mistakes)
                        actionButtons
                            .padding(.horizontal, Theme.Spacing.l)
                            .padding(.top, Theme.Spacing.s)
                            .padding(.bottom, Theme.Spacing.xl)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if let onContinue {
                            onContinue()
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                    }
                    .accessibilityLabel("Back")
                }

                ToolbarItem(placement: .principal) {
                    Text(summary.unitTitle)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            // Milestone info modal
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.textSecondary)
                        }
                        .accessibilityLabel("Milestone Information")

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
            .sheet(isPresented: $isShowingReviewMistakes) {
                LessonReviewMistakesView(summary: summary)
            }
            .onAppear {
                let targetProgress = Double(summary.accuracyPercentage) / 100.0
                if reduceMotion {
                    animatedRingProgress = targetProgress
                } else {
                    withAnimation(.easeOut(duration: 1.2).delay(0.2)) {
                        animatedRingProgress = targetProgress
                    }
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            // Milestone Achieved Pill
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.brandTurquoise)

                Text("Milestone Achieved")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.brandTurquoise)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.brandTurquoise.opacity(0.12), in: Capsule())

            // Title & Subtitle
            HStack(spacing: 6) {
                Text("Lesson complete!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)

                Text("🎉")
                    .font(.system(size: 26))
            }

            Text("Fantastic work on \(summary.lessonTitle)")
                .font(.system(size: 15))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Accuracy Ring Card

    private var accuracyRingCard: some View {
        VStack(spacing: 16) {
            // Circular Progress Ring
            ZStack {
                // Background Track
                Circle()
                    .stroke(Color.brandTurquoise.opacity(0.15), lineWidth: 16)
                    .frame(width: 170, height: 170)

                // Animated Progress Stroke
                Circle()
                    .trim(from: 0.0, to: animatedRingProgress)
                    .stroke(
                        Color.brandTurquoise,
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 170, height: 170)

                // Inside Ring: Badge & Percentage
                VStack(spacing: 4) {
                    Circle()
                        .fill(Color.brandTurquoise.opacity(0.15))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "rosette")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.brandTurquoise)
                        }

                    Text("\(summary.accuracyPercentage)%")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.brandNavy)
                }
            }
            .padding(.top, Theme.Spacing.m)

            // Rating & Percentile Badge
            VStack(spacing: 8) {
                Text(summary.accuracyRatingText)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Color.textSecondary)

                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.brandTurquoise)

                    Text(summary.percentileText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.appBackground, in: Capsule())
            }
            .padding(.bottom, Theme.Spacing.m)
        }
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    // MARK: - Three Session Stat Cards (Signs, Time, Streak)

    private var sessionStatCardsRow: some View {
        HStack(spacing: 12) {
            // Card 1: Signs
            statCard(
                iconName: "target",
                iconColor: Color.brandTurquoise,
                value: "\(summary.completedSignsCount)/\(summary.totalSignsCount)",
                label: "Signs"
            )

            // Card 2: Paced Time
            statCard(
                iconName: "stopwatch",
                iconColor: Color(red: 0.56, green: 0.35, blue: 0.96),
                value: summary.formattedPacedTime,
                label: "Paced Time"
            )

            // Card 3: Streak
            statCard(
                iconName: "flame.fill",
                iconColor: Color.brandYellow,
                value: "+\(summary.streakIncrementDays) Day",
                label: "Streak",
                valueColor: Color.brandYellow
            )
        }
    }

    private func statCard(
        iconName: String,
        iconColor: Color,
        value: String,
        label: String,
        valueColor: Color = Color.textPrimary
    ) -> some View {
        VStack(spacing: 8) {
            Circle()
                .fill(iconColor.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(iconColor)
                }

            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)

            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 96)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }

    // MARK: - New Badge Unlocked Card

    private func badgeUnlockedCard(badge: LessonBadge) -> some View {
        HStack(spacing: 14) {
            // Trophy badge icon with checkmark
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.brandNavy)
                    .frame(width: 52, height: 52)
                    .overlay {
                        Image(systemName: badge.iconName)
                            .font(.system(size: 24))
                            .foregroundStyle(Color.brandYellow)
                    }

                Circle()
                    .fill(Color.brandTurquoise)
                    .frame(width: 16, height: 16)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 4, y: -4)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("NEW BADGE UNLOCKED!")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.0)
                    .foregroundStyle(Color(red: 0.55, green: 0.38, blue: 0.05))

                Text(badge.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.brandNavy)

                Text(badge.description)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.brandNavy.opacity(0.8))
                    .lineLimit(2)
            }

            Spacer()

            // XP Pill
            Text("+\(badge.xpReward) XP")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.brandTurquoise)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.brandNavy, in: Capsule())
        }
        .padding(Theme.Spacing.m)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.88, blue: 0.52),
                    Color(red: 0.99, green: 0.78, blue: 0.32)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: Theme.Radius.card)
        )
        .shadow(color: Color.brandYellow.opacity(0.2), radius: 8, x: 0, y: 3)
    }

    // MARK: - Spatial Accuracy Feedback Card

    private func spatialAccuracyCard(note: String) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.brandTurquoise)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                }

            Text(note)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)

            Spacer()

            Button {
                // Replay or detail tip
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            .accessibilityLabel("Replay spatial accuracy breakdown")
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Continue Button
            Button {
                if let onContinue {
                    onContinue()
                } else {
                    dismiss()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Continue")
                        .fontWeight(.bold)
                    Image(systemName: "arrow.right")
                        .fontWeight(.bold)
                }
                .font(.appButton)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Color.brandNavy, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
            }

            // Review Mistakes Button (if mistakes exist)
            if !summary.mistakes.isEmpty {
                Button {
                    if let onReviewMistakes {
                        onReviewMistakes()
                    } else {
                        isShowingReviewMistakes = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "list.clipboard")
                            .font(.system(size: 16))
                        Text("Review mistakes (\(summary.mistakes.count))")
                            .fontWeight(.semibold)
                    }
                    .font(.appButton)
                    .foregroundStyle(Color.brandNavy)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.brandNavy.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.Radius.button))
                }
            }
        }
    }
}
