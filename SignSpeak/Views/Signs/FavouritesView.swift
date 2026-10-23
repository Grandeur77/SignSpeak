import SwiftUI

/// Screen displaying user's saved and bookmarked ASL signs.
/// Matches design `44-favourites`.
/// Features real-time Firestore synchronization, direct entry to sign detail,
/// bookmark removal, and a quick launch to practice all favourites.
public struct FavouritesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies

    @State private var favouriteRecords: [FavouriteRecord] = []
    @State private var signs: [Sign] = []
    @State private var searchQuery: String = ""
    @State private var isLoading: Bool = true
    @State private var isPresentingPracticeAll: Bool = false

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    public init() {}

    public var filteredSigns: [Sign] {
        guard !searchQuery.isEmpty else { return signs }
        let q = searchQuery.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return signs.filter { sign in
            sign.name.lowercased().contains(q) ||
            sign.category.lowercased().contains(q) ||
            sign.description.lowercased().contains(q)
        }
    }

    public var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if signs.isEmpty {
                    emptyStateView
                } else {
                    favouriteSignsContent
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Favourites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                if !signs.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Text("\(signs.count) \(signs.count == 1 ? "sign" : "signs")")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
            .task {
                await loadFavourites()
            }
            .fullScreenCover(isPresented: $isPresentingPracticeAll) {
                if !signs.isEmpty {
                    let recognizable = signs.filter(\.isRecognizable)
                    if !recognizable.isEmpty {
                        PracticeView(signs: recognizable, lessonTitle: "Favourites Practice")
                    } else {
                        // Watch and choose session for visual signs
                        let catalog = dependencies.signCatalogService.allSigns()
                        let questions = QuizEngine.generateQuestions(
                            from: signs,
                            allCatalogSigns: catalog,
                            count: min(5, signs.count),
                            preferredMode: .watchAndChoose
                        )
                        QuizView(questions: questions, quizTitle: "Favourites Quiz")
                    }
                }
            }
        }
    }

    // MARK: - Main Content

    private var favouriteSignsContent: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.m) {
                // Practise All Banner
                practiceAllBanner
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.top, Theme.Spacing.s)

                // Search Bar
                searchBar
                    .padding(.horizontal, Theme.Spacing.l)

                // Grid of Favourites
                if filteredSigns.isEmpty {
                    noSearchResultsView
                        .padding(.top, Theme.Spacing.xl)
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(filteredSigns) { sign in
                            NavigationLink {
                                SignDetailView(sign: sign)
                            } label: {
                                favouriteCard(sign: sign)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.bottom, Theme.Spacing.xl)
                }
            }
        }
    }

    // MARK: - Practise All Banner

    private var practiceAllBanner: some View {
        Button {
            triggerHaptic()
            isPresentingPracticeAll = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.brandYellow)
                        .frame(width: 44, height: 44)

                    Image(systemName: "play.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.black)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Practise All Favourites")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)

                    Text("Review your \(signs.count) saved signs")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.8))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            .padding(Theme.Spacing.m)
            .background(Color.brandNavy, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.brandNavy.opacity(0.2), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Practise all \(signs.count) favourites")
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textSecondary)

            TextField("Search in favourites...", text: $searchQuery)
                .font(.system(size: 15))

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.gray.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Favourite Card

    private func favouriteCard(sign: Sign) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                // Thumbnail
                ZStack {
                    Color.cardBackground.opacity(0.5)

                    if let imageName = sign.imageName {
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 110)
                            .clipped()
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: "hand.raised.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Color.brandTurquoise.opacity(0.6))
                            Text(sign.name)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.textSecondary)
                        }
                        .frame(height: 110)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Remove Bookmark Button
                Button {
                    removeFavourite(sign: sign)
                } label: {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.danger)
                        .padding(6)
                        .background(Color.black.opacity(0.6), in: Circle())
                }
                .padding(6)
                .accessibilityLabel("Remove \(sign.name) from favourites")
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(sign.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(sign.category.capitalized)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
        }
        .padding(6)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.14), lineWidth: 1)
        )
    }

    // MARK: - Empty States

    private var emptyStateView: some View {
        VStack(spacing: Theme.Spacing.l) {
            ZStack {
                Circle()
                    .fill(Color.brandYellow.opacity(0.15))
                    .frame(width: 88, height: 88)

                Image(systemName: "heart.slash")
                    .font(.system(size: 38))
                    .foregroundStyle(Color.brandYellow)
            }
            .padding(.top, Theme.Spacing.xl)

            VStack(spacing: 8) {
                Text("No favourites yet")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)

                Text("Tap the heart or bookmark icon on any sign detail to save it here for quick access.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
            }

            Button {
                dismiss()
            } label: {
                Text("Browse Signs Directory")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.brandNavy, in: Capsule())
            }
            .padding(.top, Theme.Spacing.m)

            Spacer()
        }
    }

    private var noSearchResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(Color.textSecondary)

            Text("No favourites match '\(searchQuery)'")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            Button("Clear search") {
                searchQuery = ""
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color.brandTurquoise)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Color.brandTurquoise)
            Text("Loading favourites...")
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func loadFavourites() async {
        isLoading = true
        defer { isLoading = false }

        let userId = dependencies.authService.currentUserId ?? "default"
        do {
            let records = try await dependencies.favouritesRepository.fetchFavourites(userId: userId)
            self.favouriteRecords = records

            let catalog = dependencies.signCatalogService
            self.signs = records.compactMap { catalog.sign(byId: $0.signId) }
        } catch {
            self.favouriteRecords = []
            self.signs = []
        }
    }

    private func removeFavourite(sign: Sign) {
        triggerHaptic()
        let userId = dependencies.authService.currentUserId ?? "default"
        signs.removeAll(where: { $0.id == sign.id })
        favouriteRecords.removeAll(where: { $0.signId == sign.id })

        Task {
            try? await dependencies.favouritesRepository.removeFavourite(userId: userId, signId: sign.id)
        }
    }

    private func triggerHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

#Preview("Favourites View") {
    FavouritesView()
        .environment(\.dependencies, .preview)
}
