import SwiftUI

/// Lesson introduction view showing lesson overview, sign cards carousel, vision tips, and action triggers.
/// Matches design `29-lesson-intro-f-j`.
public struct LessonIntroView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies

    public let lesson: Lesson

    @State private var lessonSigns: [Sign] = []
    @State private var isShowingPracticeSheet: Bool = false
    @State private var isShowingQuizSheet: Bool = false
    @State private var isShowingInfoAlert: Bool = false

    public init(lesson: Lesson) {
        self.lesson = lesson
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                // 1. Header Information
                headerSection
                    .padding(.top, Theme.Spacing.s)

                // 2. Signs in this Lesson Carousel
                signsInLessonSection

                // 3. Gesture Detection Callout Card
                gestureDetectionCard

                // 4. Pro Tip Callout Card
                proTipCard

                // Space for bottom action buttons
                Spacer(minLength: 120)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.l)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(lesson.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isShowingInfoAlert = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color.textPrimary)
                }

                ProfileAvatarButton {}
            }
        }
        .alert(lesson.title, isPresented: $isShowingInfoAlert) {
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text(lesson.subtitle)
        }
        .safeAreaInset(edge: .bottom) {
            bottomActionButtons
        }
        .navigationDestination(for: Sign.self) { sign in
            SignDetailView(sign: sign)
        }
        .onAppear {
            loadSigns()
        }
        .task {
            loadSigns()
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Module Tag & XP
            HStack {
                Text("ASL ALPHABET MODULE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Color.brandTurquoise)

                Spacer()

                Text("XP +50")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.brandTurquoise)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.brandTurquoise.opacity(0.14), in: Capsule())
            }

            // Lesson Title
            Text(lesson.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)

            // Badges Row
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text("5 min")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.cardBackground, in: Capsule())
                .overlay(Capsule().stroke(Color.gray.opacity(0.15), lineWidth: 1))

                HStack(spacing: 4) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 11))
                    Text("\(lessonSigns.count) signs")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.cardBackground, in: Capsule())
                .overlay(Capsule().stroke(Color.gray.opacity(0.15), lineWidth: 1))

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.brandYellow)
                    Text("Level 1")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.cardBackground, in: Capsule())
                .overlay(Capsule().stroke(Color.gray.opacity(0.15), lineWidth: 1))
            }
        }
    }

    private var signsInLessonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Letters in this lesson")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Text("Tap to learn & practice")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brandTurquoise)
            }

            // Horizontal Carousel of Cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(lessonSigns) { sign in
                        NavigationLink {
                            SignDetailView(sign: sign)
                        } label: {
                            signLessonCard(sign)
                        }
                        .buttonStyle(.plain)
                        .hoverEffect(.lift)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func signLessonCard(_ sign: Sign) -> some View {
        VStack(spacing: 8) {
            // Sign Photo Box
            ZStack(alignment: .topTrailing) {
                Group {
                    if let imageName = sign.imageName, let _ = UIImage(named: imageName) {
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Color.brandNavy.opacity(0.12)
                            .overlay(
                                Text(sign.name)
                                    .font(.system(size: 38, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.brandTurquoise)
                            )
                    }
                }
                .frame(width: 104, height: 104)
                .background(Color.gray.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Star Badge Overlay
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 22, height: 22)
                        .shadow(radius: 2)

                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.brandYellow)
                }
                .padding(6)
            }

            // Bottom Name & Tag Row
            HStack {
                Text(sign.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Text("ASL")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.brandTurquoise)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.brandTurquoise.opacity(0.16), in: RoundedRectangle(cornerRadius: 4))
            }
            .frame(width: 104)

            // Learn & Practice CTA Pill
            HStack(spacing: 4) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("Learn & Practice")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(Color.brandNavy)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.brandTurquoise.opacity(0.22), in: Capsule())
            .overlay(
                Capsule().stroke(Color.brandTurquoise.opacity(0.4), lineWidth: 1)
            )
        }
        .padding(10)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.gray.opacity(0.14), lineWidth: 1)
        )
    }

    private var gestureDetectionCard: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.brandTurquoise.opacity(0.14))
                    .frame(width: 44, height: 44)

                Image(systemName: "camera.metering.matrix")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.brandTurquoise)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Gesture Detection Active")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Text("Real-time computer vision will track 21 hand joints to calibrate your handshape.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                    .lineSpacing(3)
            }

            Spacer()
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
    }

    private var proTipCard: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.brandYellow.opacity(0.3))
                    .frame(width: 36, height: 36)

                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.brandYellow)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Pro Tip")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Text(lesson.proTip ?? "Good lighting helps recognition. Face your camera directly and ensure fingers are clearly separated against a plain background.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textPrimary.opacity(0.9))
                    .lineSpacing(3)
            }

            Spacer()
        }
        .padding(Theme.Spacing.m)
        .background(Color.brandYellow.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.brandYellow.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Bottom Sticky CTA Buttons

    private var bottomActionButtons: some View {
        VStack(spacing: 10) {
            // 1. Start Practice Button (Primary CTA)
            Button {
                triggerHaptic()
                isShowingPracticeSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text("Start practice")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.brandTurquoise, in: Capsule())
                .shadow(color: Color.brandTurquoise.opacity(0.3), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .hoverEffect(.lift)

            // 2. Take Quiz Button (Secondary CTA)
            Button {
                triggerHaptic()
                isShowingQuizSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.square")
                        .font(.system(size: 15, weight: .bold))
                    Text("Take quiz")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.cardBackground, in: Capsule())
                .overlay(Capsule().stroke(Color.gray.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .hoverEffect(.lift)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
        .background(
            Color.appBackground
                .opacity(0.95)
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
        .fullScreenCover(isPresented: $isShowingPracticeSheet) {
            PracticeView(
                signs: !lessonSigns.isEmpty ? lessonSigns : fallbackSignsForLesson(),
                lessonTitle: lesson.title
            )
        }
        .fullScreenCover(isPresented: $isShowingQuizSheet) {
            let pool = !lessonSigns.isEmpty ? lessonSigns : fallbackSignsForLesson()
            let questions = QuizEngine.generateQuestions(
                from: pool,
                allCatalogSigns: dependencies.signCatalogService.allSigns(),
                count: max(3, pool.count)
            )
            QuizView(
                questions: questions,
                quizTitle: "Quiz: \(lesson.title)"
            )
        }
    }

    private func fallbackSignsForLesson() -> [Sign] {
        let signs = lesson.signIds.compactMap { dependencies.signCatalogService.sign(byId: $0) }
        if !signs.isEmpty { return signs }
        return dependencies.signCatalogService.signs(forCategory: "alphabet")
    }

    // MARK: - Actions

    private func loadSigns() {
        let signs = dependencies.signCatalogService.signs(forLesson: lesson.id)
        if !signs.isEmpty {
            lessonSigns = signs
        } else {
            // Resolve from signIds directly
            lessonSigns = lesson.signIds.compactMap { dependencies.signCatalogService.sign(byId: $0) }
        }
    }

    private func triggerHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
}

#Preview("Lesson Intro") {
    NavigationStack {
        LessonIntroView(lesson: Lesson(
            id: "lesson-alphabet-2",
            unitId: "unit-alphabet",
            title: "Lesson 2 · Letters F–J",
            subtitle: "Fingertip Precision & Curves",
            category: "alphabet",
            signIds: ["sign-letter-f", "sign-letter-g", "sign-letter-h", "sign-letter-i", "sign-letter-j"],
            order: 2,
            proTip: "Good lighting helps recognition. Face your camera directly and ensure fingers are clearly separated against a plain background."
        ))
        .environment(\.dependencies, .preview)
    }
}
