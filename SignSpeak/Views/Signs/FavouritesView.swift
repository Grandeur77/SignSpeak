import SwiftUI

/// Screen displaying user's saved and bookmarked ASL signs with SM-2 spaced repetition schedules.
/// Matches design `44-favourites`.
/// Features real-time Firestore synchronization, due-date badges, review interval stats,
/// filtering by due status or category, sorting, and a "Practise Due Favourites" session.
public struct FavouritesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies

    @State private var viewModel: FavouritesViewModel?
    @State private var isPresentingPracticeSession: Bool = false
    @State private var sessionMode: PracticeSessionMode = .dueOnly

    private enum PracticeSessionMode {
        case dueOnly
        case allFavourites
    }

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    if vm.isLoading {
                        loadingView
                    } else if vm.records.isEmpty {
                        emptyStateView
                    } else {
                        favouritesContent(vm)
                    }
                } else {
                    loadingView
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

                if let vm = viewModel, !vm.records.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Picker("Sort Options", selection: Binding(
                                get: { vm.selectedSort },
                                set: { vm.selectedSort = $0 }
                            )) {
                                ForEach(FavouritesSortOption.allCases) { opt in
                                    Text(opt.rawValue).tag(opt)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down.circle")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.textPrimary)
                        }
                        .accessibilityLabel("Sort favourites")
                    }
                }
            }
            .task {
                await setupViewModel()
            }
            .fullScreenCover(isPresented: $isPresentingPracticeSession) {
                if let vm = viewModel, !vm.sessionSigns.isEmpty {
                    let recognizable = vm.sessionSigns.filter(\.isRecognizable)
                    if !recognizable.isEmpty {
                        PracticeView(
                            signs: recognizable,
                            lessonTitle: sessionMode == .dueOnly ? "Due Reviews" : "Favourites Practice"
                        )
                    } else {
                        let catalog = dependencies.signCatalogService.allSigns()
                        let questions = QuizEngine.generateQuestions(
                            from: vm.sessionSigns,
                            allCatalogSigns: catalog,
                            count: min(5, vm.sessionSigns.count),
                            preferredMode: .watchAndChoose
                        )
                        QuizView(
                            questions: questions,
                            quizTitle: sessionMode == .dueOnly ? "Due Reviews Quiz" : "Favourites Quiz"
                        )
                    }
                }
            }
        }
    }

    // MARK: - Main Content

    private func favouritesContent(_ vm: FavouritesViewModel) -> some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.m) {
                // 1. Practise Banner
                practiceBanner(vm)
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.top, Theme.Spacing.s)

                // 2. Search Bar
                searchBar(vm)
                    .padding(.horizontal, Theme.Spacing.l)

                // 3. Filter Tabs
                filterTabs(vm)
                    .padding(.horizontal, Theme.Spacing.l)

                // 4. Grid of Favourite Cards
                let items = vm.filteredItems
                if items.isEmpty {
                    if vm.selectedTab == .due {
                        allCaughtUpView
                            .padding(.top, Theme.Spacing.xl)
                    } else {
                        noSearchResultsView(vm)
                            .padding(.top, Theme.Spacing.xl)
                    }
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(items) { item in
                            NavigationLink {
                                SignDetailView(sign: item.sign)
                            } label: {
                                favouriteCard(item: item, vm: vm)
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

    // MARK: - Practise Banner

    private func practiceBanner(_ vm: FavouritesViewModel) -> some View {
        let due = vm.dueCount
        let hasDue = due > 0

        return Button {
            triggerHaptic()
            if hasDue {
                sessionMode = .dueOnly
                vm.prepareDueReviewSession()
            } else {
                sessionMode = .allFavourites
                vm.prepareAllFavouritesSession()
            }
            isPresentingPracticeSession = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(hasDue ? Color.brandYellow : Color.brandTurquoise)
                        .frame(width: 48, height: 48)

                    Image(systemName: hasDue ? "clock.badge.checkmark" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.black)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(hasDue ? "Review Due Favourites" : "Practise All Favourites")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.white)

                        if hasDue {
                            Text("\(due)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.brandYellow, in: Capsule())
                        }
                    }

                    Text(hasDue ? "\(due) \(due == 1 ? "sign is" : "signs are") due for spaced-repetition review" : "Keep memory fresh with all \(vm.totalCount) saved signs")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .lineLimit(1)
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
        .accessibilityLabel(hasDue ? "Review \(due) due favourites" : "Practise all \(vm.totalCount) favourites")
    }

    // MARK: - Search Bar

    private func searchBar(_ vm: FavouritesViewModel) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textSecondary)

            TextField("Search in favourites...", text: Binding(
                get: { vm.searchQuery },
                set: { vm.searchQuery = $0 }
            ))
            .font(.system(size: 15))

            if !vm.searchQuery.isEmpty {
                Button {
                    vm.searchQuery = ""
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

    // MARK: - Filter Tabs

    private func filterTabs(_ vm: FavouritesViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FavouritesFilterTab.allCases) { tab in
                    let isSelected = vm.selectedTab == tab
                    Button {
                        vm.selectedTab = tab
                        triggerHaptic()
                    } label: {
                        HStack(spacing: 6) {
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))

                            if tab == .due && vm.dueCount > 0 {
                                Text("\(vm.dueCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(isSelected ? Color.black : Color.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(isSelected ? Color.black.opacity(0.2) : Color.brandYellow, in: Capsule())
                            }
                        }
                        .foregroundStyle(isSelected ? Color.black : Color.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            isSelected ? Color.brandTurquoise : Color.cardBackground,
                            in: Capsule()
                        )
                        .overlay(
                            Capsule().stroke(Color.gray.opacity(0.18), lineWidth: isSelected ? 0 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Favourite Card

    private func favouriteCard(item: FavouriteSignItem, vm: FavouritesViewModel) -> some View {
        let sign = item.sign
        let record = item.record
        let dueStatus = SpacedRepetitionScheduler.dueStatus(record: record)
        let isDueNow = SpacedRepetitionScheduler.isDue(record: record)

        return VStack(alignment: .leading, spacing: 8) {
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
                    removeFavourite(signId: sign.id, vm: vm)
                } label: {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.danger)
                        .padding(6)
                        .background(Color.black.opacity(0.6), in: Circle())
                }
                .padding(6)
                .accessibilityLabel("Remove \(sign.name) from favourites")

                // Top Left: Due Badge
                VStack {
                    HStack {
                        Text(dueStatus)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(isDueNow ? Color.black : Color.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                isDueNow ? Color.brandYellow : Color.black.opacity(0.65),
                                in: Capsule()
                            )
                        Spacer()
                    }
                    .padding(6)
                    Spacer()
                }
            }

            // Info & SM-2 Metadata
            VStack(alignment: .leading, spacing: 3) {
                Text(sign.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(sign.category.capitalized)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)

                // Spaced Repetition Interval line
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 9))
                    Text(intervalDescription(record: record))
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(Color.brandTurquoise)
                .padding(.top, 2)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
        }
        .padding(6)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isDueNow ? Color.brandYellow.opacity(0.4) : Color.gray.opacity(0.14), lineWidth: 1)
        )
    }

    private func intervalDescription(record: FavouriteRecord) -> String {
        if record.intervalDays <= 1 {
            return "1 day interval"
        } else {
            return "\(record.intervalDays) days interval"
        }
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

                Text("Tap the heart or bookmark icon on any sign detail to save it here for spaced-repetition review.")
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

    private var allCaughtUpView: some View {
        VStack(spacing: Theme.Spacing.m) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 72, height: 72)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.green)
            }
            .padding(.top, Theme.Spacing.l)

            VStack(spacing: 6) {
                Text("All caught up!")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)

                Text("No signs are due for review today. Keep your streak going or practise ahead!")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
            }

            Button {
                viewModel?.selectedTab = .all
            } label: {
                Text("View All Saved Signs")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brandTurquoise)
            }
            .padding(.top, 4)
        }
    }

    private func noSearchResultsView(_ vm: FavouritesViewModel) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(Color.textSecondary)

            Text("No favourites match '\(vm.searchQuery)'")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            Button("Clear search") {
                vm.searchQuery = ""
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color.brandTurquoise)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Color.brandTurquoise)
            Text("Loading favourites & review schedule...")
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func setupViewModel() async {
        if viewModel == nil {
            let userId = dependencies.authService.currentUserId ?? "default"
            let vm = FavouritesViewModel(
                favouritesRepository: dependencies.favouritesRepository,
                signCatalogService: dependencies.signCatalogService,
                progressRepository: dependencies.progressRepository,
                userId: userId,
                nowProvider: { dependencies.dateProvider.now }
            )
            self.viewModel = vm
        }
        await viewModel?.load()
    }

    private func removeFavourite(signId: String, vm: FavouritesViewModel) {
        triggerHaptic()
        Task {
            await vm.removeFavourite(signId: signId)
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
