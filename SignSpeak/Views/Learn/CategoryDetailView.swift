import SwiftUI

/// Category Detail screen for exploring and practicing signs within a category.
/// Matches design `28-category-detail-greetings`.
/// Shows category hero video, mastery progress, segmented status bars, and core signs list.
public struct CategoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies

    public let category: SignCategory

    @State private var categorySigns: [Sign] = []
    @State private var isMuted: Bool = false
    @State private var isShowingHeroVideo: Bool = false
    @State private var isShowingPracticeSheet: Bool = false
    @State private var isShowingInfoAlert: Bool = false

    public init(category: SignCategory) {
        self.category = category
    }

    private var learnedCount: Int {
        min(4, categorySigns.count)
    }

    private var totalCount: Int {
        max(10, categorySigns.count)
    }

    private var completionPercent: Int {
        Int((Double(learnedCount) / Double(totalCount)) * 100)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                // 1. Sub-Header Bar
                subHeaderView
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.top, Theme.Spacing.s)

                // 2. Hero Video Card
                heroVideoCard
                    .padding(.horizontal, Theme.Spacing.l)

                // 3. Category Mastery Card
                categoryMasteryCard
                    .padding(.horizontal, Theme.Spacing.l)

                // 4. Core Signs List
                coreSignsSection
                    .padding(.horizontal, Theme.Spacing.l)

                Spacer(minLength: 80)
            }
            .padding(.bottom, Theme.Spacing.l)
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

                ProfileAvatarButton {}
            }
        }
        .alert(category.name, isPresented: $isShowingInfoAlert) {
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text(category.description)
        }
        .safeAreaInset(edge: .bottom) {
            bottomPracticeButton
        }
        .navigationDestination(for: Sign.self) { sign in
            SignDetailView(sign: sign)
        }
        .task {
            loadSigns()
        }
    }

    // MARK: - Subviews

    private var subHeaderView: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.brandTurquoise)

                Text("LEVEL 1 • EVERYDAY ASL")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    isMuted.toggle()
                    triggerHaptic()
                } label: {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textPrimary)
                        .padding(8)
                        .background(Color.gray.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)

                ShareLink(item: "Mastering \(category.name) ASL on SignSpeak!") {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textPrimary)
                        .padding(8)
                        .background(Color.gray.opacity(0.12), in: Circle())
                }
            }
        }
    }

    private var heroVideoCard: some View {
        ZStack(alignment: .bottomLeading) {
            // Background Image/Thumbnail
            Group {
                if let _ = UIImage(named: "sign_hello") {
                    Image("sign_hello")
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [Color.brandNavy.opacity(0.7), Color.brandNavy],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .clipped()

            // Dark Scrim Overlay
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.85)],
                startPoint: .center,
                endPoint: .bottom
            )

            // Top-right 4K Badge
            VStack {
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 10))
                        Text("4K Video")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6), in: Capsule())
                }
                Spacer()
            }
            .padding(Theme.Spacing.m)

            // Bottom Content Row
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ESSENTIAL PACK")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.brandTurquoise, in: Capsule())

                    Text("Mastering \(category.name)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.white)

                    Text("Build personal warmth through face & hand alignment")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .lineLimit(2)
                }

                Spacer()

                // Yellow Play Button Circle
                Button {
                    isShowingHeroVideo = true
                    triggerHaptic()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.brandYellow)
                            .frame(width: 48, height: 48)

                        Image(systemName: "play.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.black)
                            .offset(x: 2)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.Spacing.m)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 3)
    }

    private var categoryMasteryCard: some View {
        VStack(spacing: 12) {
            // Header Row
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.brandTurquoise)

                    Text("Category Mastery")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                }

                Spacer()

                Text("\(learnedCount) of \(totalCount) learned")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.brandTurquoise)
            }

            // Segmented Progress Bar (10 segments)
            HStack(spacing: 4) {
                ForEach(0..<10, id: \.self) { idx in
                    Capsule()
                        .fill(idx < 4 ? Color.brandTurquoise : Color.gray.opacity(0.2))
                        .frame(height: 6)
                }
            }

            // Footer Row
            HStack {
                Text("\(completionPercent)% completed")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11))
                    Text("+150 XP on completion")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Color.brandTurquoise)
            }
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
    }

    private var coreSignsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Core Signs")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Text("Tap to inspect motion")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }

            // Signs List
            VStack(spacing: 10) {
                ForEach(Array(categorySigns.prefix(8).enumerated()), id: \.element.id) { index, sign in
                    NavigationLink(value: sign) {
                        signItemRow(sign, index: index)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func signItemRow(_ sign: Sign, index: Int) -> some View {
        let isLearned = index < 2
        let isLearning = index >= 2 && index < 4

        return HStack(spacing: 12) {
            // Thumbnail with Corner Badge
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let imageName = sign.imageName, let _ = UIImage(named: imageName) {
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.brandNavy.opacity(0.1)
                            .overlay(
                                Image(systemName: "hand.raised.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.brandTurquoise)
                            )
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Corner Status Badge
                Circle()
                    .fill(isLearned ? Color.brandTurquoise : (isLearning ? Color.brandYellow : Color.gray.opacity(0.6)))
                    .frame(width: 16, height: 16)
                    .overlay(
                        Image(systemName: isLearned ? "checkmark" : (isLearning ? "arrow.triangle.2.circlepath" : "plus"))
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(isLearning ? Color.black : Color.white)
                    )
                    .offset(x: 2, y: 2)
            }

            // Info Column
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(sign.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.textPrimary)

                    if isLearned {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 9))
                            Text("Learned")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(Color.brandTurquoise)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.brandTurquoise.opacity(0.14), in: Capsule())
                    } else if isLearning {
                        HStack(spacing: 3) {
                            Circle()
                                .trim(from: 0, to: 0.5)
                                .stroke(Color.black, lineWidth: 1.5)
                                .frame(width: 7, height: 7)
                            Text("Learning")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.brandYellow, in: Capsule())
                    } else {
                        Text("New")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.15), in: Capsule())
                    }
                }

                Text(sign.howToSteps.first ?? sign.description)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Play Icon Circle
            Image(systemName: "play.circle")
                .font(.system(size: 22))
                .foregroundStyle(Color.textSecondary.opacity(0.8))
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Bottom Sticky CTA

    private var bottomPracticeButton: some View {
        Button {
            triggerHaptic()
            isShowingPracticeSheet = true
        } label: {
            HStack(spacing: 8) {
                Text("Practise this category")
                    .font(.system(size: 16, weight: .bold))

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
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
        .fullScreenCover(isPresented: $isShowingPracticeSheet) {
            PracticeView(
                signs: !categorySigns.isEmpty ? categorySigns : dependencies.signCatalogService.signs(forCategory: category.id),
                lessonTitle: category.name
            )
        }
    }

    // MARK: - Actions

    private func loadSigns() {
        let signs = dependencies.signCatalogService.signs(forCategory: category.id)
        if !signs.isEmpty {
            categorySigns = signs
        } else {
            categorySigns = dependencies.signCatalogService.allSigns().filter {
                $0.category.localizedCaseInsensitiveContains(category.name)
            }
        }
    }

    private func triggerHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
}

#Preview("Category Detail") {
    NavigationStack {
        CategoryDetailView(category: SignCategory(
            id: "greetings",
            name: "Greetings",
            iconName: "hand.wave",
            description: "Essential greetings and introductory conversation starters.",
            order: 3
        ))
        .environment(\.dependencies, .preview)
    }
}
