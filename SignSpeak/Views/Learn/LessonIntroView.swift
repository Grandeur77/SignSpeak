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
                Text("Lesson Intro Video")
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
                Text("Signs in this lesson")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Text("Tap to inspect")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }

            // Horizontal Carousel of Cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(lessonSigns) { sign in
                        NavigationLink(value: sign) {
                            signLessonCard(sign)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func signLessonCard(_ sign: Sign) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Sign Photo Box
            ZStack(alignment: .topTrailing) {
                Group {
                    if let imageName = sign.imageName, let _ = UIImage(named: imageName) {
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Color.brandNavy.opacity(0.08)
                            .overlay(
                                Text(sign.name)
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.brandTurquoise)
                            )
                    }
                }
                .frame(width: 96, height: 96)
                .background(Color.gray.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Star Badge Overlay
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .shadow(radius: 2)

                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.brandYellow)
                }
                .padding(6)
            }

            // Bottom Name & Tag Row
            HStack {
                Text(sign.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Text("ASL")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            }
            .frame(width: 96)
        }
        .padding(8)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
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
            // 1. Start Practice Button
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
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.brandNavy, in: Capsule())
                .shadow(color: Color.black.opacity(0.18), radius: 8, y: 4)
            }
            .buttonStyle(.plain)

            // 2. Take Quiz Button
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
                .foregroundStyle(Color.brandTurquoise)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.brandTurquoise.opacity(0.14), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
        .background(
            Color.appBackground
                .opacity(0.95)
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
        .sheet(isPresented: $isShowingPracticeSheet) {
            lessonPracticePlaceholder
        }
        .sheet(isPresented: $isShowingQuizSheet) {
            lessonQuizPlaceholder
        }
    }

    private var lessonPracticePlaceholder: some View {
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
                    Text("Practice \(lesson.title)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)

                    Text("Live gesture practice with Vision recognition launches in Step 5.3.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.l)
                }

                Spacer()

                Button("Dismiss") {
                    isShowingPracticeSheet = false
                }
                .font(.headline)
                .foregroundStyle(Color.brandTurquoise)
                .padding(.bottom, Theme.Spacing.l)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        isShowingPracticeSheet = false
                    }
                }
            }
        }
    }

    private var lessonQuizPlaceholder: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.l) {
                ZStack {
                    Circle()
                        .fill(Color.brandYellow.opacity(0.2))
                        .frame(width: 80, height: 80)

                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(Color.brandYellow)
                }
                .padding(.top, Theme.Spacing.xl)

                VStack(spacing: 8) {
                    Text("Lesson Quiz: \(lesson.title)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)

                    Text("Watch-and-choose and sign-it quizzes arrive in Step 5.4.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.l)
                }

                Spacer()

                Button("Dismiss") {
                    isShowingQuizSheet = false
                }
                .font(.headline)
                .foregroundStyle(Color.brandTurquoise)
                .padding(.bottom, Theme.Spacing.l)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        isShowingQuizSheet = false
                    }
                }
            }
        }
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
