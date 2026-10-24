import SwiftUI

/// Fingerspelling Path screen showing letter mastery grid (A–Z) and lessons 1–5.
/// Matches design `26-alphabet-lessons`.
public struct FingerspellingPathView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies

    @State private var allAlphabetSigns: [Sign] = []
    @State private var alphabetLessons: [Lesson] = []
    @State private var userProgress: [String: SignProgress] = [:]
    @State private var summaries: [LessonProgressSummary] = []
    @State private var selectedSign: Sign?
    @State private var selectedLesson: Lesson?
    @State private var isShowingInfoAlert = false

    private let alphabetLetters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map(String.init)

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                // 1. Sub-Header Bar
                subHeaderView
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.top, Theme.Spacing.s)

                // 2. Letter Mastery (A–Z) Grid Card
                letterMasteryCard
                    .padding(.horizontal, Theme.Spacing.l)

                // 3. Lessons Progression (1 to 5)
                lessonsListSection
                    .padding(.horizontal, Theme.Spacing.l)

                Spacer(minLength: Theme.Spacing.xl)
            }
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Unit Overview")
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
                .accessibilityLabel("Fingerspelling unit info")

                ProfileAvatarButton {}
            }
        }
        .alert("Manual Alphabet Unit", isPresented: $isShowingInfoAlert) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text("Master all 26 letters of the American Sign Language fingerspelling alphabet. Practice with real-time computer vision joint tracking.")
        }
        .navigationDestination(for: Sign.self) { sign in
            SignDetailView(sign: sign)
        }
        .navigationDestination(for: Lesson.self) { lesson in
            LessonIntroView(lesson: lesson)
        }
        .onAppear {
            loadCatalogSync()
        }
        .task {
            await loadCatalog()
        }
    }

    // MARK: - Subviews

    private var subHeaderView: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.brandTurquoise)

                Text("Fingerspelling Path")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.brandYellow)

                Text("12 Mastered")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.brandYellow.opacity(0.18), in: Capsule())
        }
    }

    private var letterMasteryCard: some View {
        VStack(spacing: 12) {
            // Header Row
            HStack {
                Text("Letter Mastery (A–Z)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Text("46% Complete")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.brandTurquoise)
            }

            // Grid of 26 letters (9 items per row)
            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 9)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(alphabetLetters, id: \.self) { letter in
                    letterTile(letter)
                }
            }
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
    }

    private func letterTile(_ letter: String) -> some View {
        let isMastered = isLetterMastered(letter)
        let isCurrent = letter == "A" || letter == "M"
        let sign = allAlphabetSigns.first(where: { $0.name.uppercased() == letter })
            ?? dependencies.signCatalogService.sign(byId: "sign-letter-\(letter.lowercased())")

        return Group {
            if let sign {
                NavigationLink {
                    SignDetailView(sign: sign)
                } label: {
                    letterTileContent(letter: letter, isMastered: isMastered, isCurrent: isCurrent)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    // Fallback
                } label: {
                    letterTileContent(letter: letter, isMastered: isMastered, isCurrent: isCurrent)
                }
                .buttonStyle(.plain)
            }
        }
        .hoverEffect(.lift)
    }

    private func letterTileContent(letter: String, isMastered: Bool, isCurrent: Bool) -> some View {
        VStack(spacing: 2) {
            Text(letter)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(isMastered ? Color.white : (isCurrent ? Color.black : Color.textPrimary))

            if isMastered {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(Color.white)
            } else if isCurrent {
                Circle()
                    .fill(Color.black)
                    .frame(width: 4, height: 4)
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 38)
        .background(
            isMastered ? Color.brandTurquoise : (isCurrent ? Color.brandYellow : Color.cardBackground),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isMastered ? Color.clear : Color.gray.opacity(0.18), lineWidth: 1)
        )
        .accessibilityLabel("Letter \(letter), \(isMastered ? "Mastered" : (isCurrent ? "In Progress" : "Available"))")
    }

    private var lessonsListSection: some View {
        VStack(spacing: 14) {
            ForEach(alphabetLessons) { lesson in
                let summary = summaries.first(where: { $0.lessonId == lesson.id })
                    ?? LessonProgressionEngine.summary(forLesson: lesson.id, in: alphabetLessons, progress: userProgress)
                    ?? LessonProgressSummary(
                        lessonId: lesson.id,
                        status: lesson.id == "lesson-alphabet-1" ? .inProgress : .locked,
                        masteredCount: 0,
                        totalSignsCount: lesson.signIds.count
                    )

                switch summary.status {
                case .completed:
                    completedLessonCard(lesson: lesson, summary: summary)
                case .inProgress:
                    inProgressLessonCard(lesson: lesson, summary: summary)
                case .locked:
                    lockedLessonCard(title: lesson.title, subtitle: lesson.subtitle)
                }
            }
        }
    }

    // MARK: - Lesson Cards

    private func completedLessonCard(lesson: Lesson, summary: LessonProgressSummary) -> some View {
        NavigationLink {
            LessonIntroView(lesson: lesson)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    ZStack {
                        Circle()
                            .fill(Color.brandTurquoise.opacity(0.15))
                            .frame(width: 36, height: 36)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.brandTurquoise)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(lesson.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.textPrimary)

                        Text(lesson.subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                    }

                    Spacer()

                    Text("COMPLETED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.brandTurquoise)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.brandTurquoise.opacity(0.14), in: Capsule())
                }

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.brandTurquoise)

                        Text("\(summary.masteredCount) of \(summary.totalSignsCount) mastered")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.textPrimary)
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Text("Review Lesson")
                            .font(.system(size: 13, weight: .bold))
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.brandTurquoise, in: Capsule())
                }
            }
            .padding(Theme.Spacing.m)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
    }

    private func inProgressLessonCard(lesson: Lesson, summary: LessonProgressSummary) -> some View {
        NavigationLink {
            LessonIntroView(lesson: lesson)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    ZStack {
                        Circle()
                            .fill(Color.brandYellow.opacity(0.2))
                            .frame(width: 36, height: 36)

                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.brandYellow)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(lesson.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.textPrimary)

                        Text(lesson.subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                    }

                    Spacer()

                    Text("IN PROGRESS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.brandYellow, in: Capsule())
                }

                // Current Goal Box
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CURRENT GOAL")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.6)
                            .foregroundStyle(Color.textSecondary)

                        Text("\(summary.masteredCount) of \(summary.totalSignsCount) learned (\(Int(summary.progressFraction * 100))%)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                    }

                    Spacer()
                }
                .padding(Theme.Spacing.m)
                .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

                // Big CTA Button: vibrant turquoise with bold high-contrast text!
                HStack(spacing: 8) {
                    Text("Continue Lesson: Letters A – E")
                        .font(.system(size: 15, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.brandTurquoise, in: Capsule())
                .shadow(color: Color.brandTurquoise.opacity(0.35), radius: 8, y: 3)
            }
            .padding(Theme.Spacing.m)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                VStack {
                    Rectangle()
                        .fill(Color.brandTurquoise)
                        .frame(height: 3)
                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: 18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.brandTurquoise.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
    }

    private func lockedLessonCard(title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: "lock.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary.opacity(0.7))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.textSecondary.opacity(0.4))
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func isLetterMastered(_ letter: String) -> Bool {
        let signId = "sign-letter-\(letter.lowercased())"
        if let progress = userProgress[signId] {
            return progress.isMastered
        }
        // Fallback for default seed preview (A through L)
        guard let char = letter.first, let aChar = "A".first, let lChar = "L".first else { return false }
        return char >= aChar && char <= lChar
    }

    private func loadCatalog() async {
        allAlphabetSigns = dependencies.signCatalogService.signs(forCategory: "alphabet")
        alphabetLessons = dependencies.signCatalogService.lessons(forUnit: "unit-alphabet")

        let userId = dependencies.authService.currentUserId ?? "default"
        if let list = try? await dependencies.progressRepository.fetchProgress(userId: userId) {
            var dict: [String: SignProgress] = [:]
            for item in list {
                dict[item.signId] = item
            }
            userProgress = dict
            summaries = LessonProgressionEngine.evaluate(lessons: alphabetLessons, progress: dict)
        }
    }

    private func loadCatalogSync() {
        if allAlphabetSigns.isEmpty {
            allAlphabetSigns = dependencies.signCatalogService.signs(forCategory: "alphabet")
        }
        if alphabetLessons.isEmpty {
            alphabetLessons = dependencies.signCatalogService.lessons(forUnit: "unit-alphabet")
        }
    }
}

#Preview("Fingerspelling Path") {
    NavigationStack {
        FingerspellingPathView()
            .environment(\.dependencies, .preview)
    }
}
