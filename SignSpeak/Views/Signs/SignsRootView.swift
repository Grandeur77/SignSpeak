import SwiftUI

/// Signs Directory view supporting adaptive grid display, search, tabs, multi-criteria filters,
/// learning status badges, bookmarks, camera practice banner, empty state, and sign requests.
/// Matches designs `43-signs-directory` and `42-search-results-empty`.
public struct SignsRootView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Bindable var deepLinkRouter: DeepLinkRouter

    @State private var viewModel: SignsDirectoryViewModel?
    @State private var isShowingCameraPractice: Bool = false
    @State private var requestTerm: String = ""
    @State private var requestCategory: String = "General"
    @State private var requestNotes: String = ""
    @State private var selectedSignForDetail: Sign?
    @State private var isShowingFavourites: Bool = false

    private var columns: [GridItem] {
        if horizontalSizeClass == .regular {
            return [GridItem(.adaptive(minimum: 180, maximum: 280), spacing: 16)]
        } else {
            return [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ]
        }
    }

    public init(deepLinkRouter: DeepLinkRouter) {
        self.deepLinkRouter = deepLinkRouter
    }

    public var body: some View {
        Group {
            if let viewModel {
                if horizontalSizeClass == .regular {
                    ipadSplitSignsView(viewModel)
                } else {
                    mainContentView(viewModel)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .task {
            if viewModel == nil {
                let vm = SignsDirectoryViewModel(
                    signCatalogService: dependencies.signCatalogService,
                    progressRepository: dependencies.progressRepository,
                    favouritesRepository: dependencies.favouritesRepository,
                    signRequestRepository: dependencies.signRequestRepository,
                    authService: dependencies.authService
                )
                await vm.load()
                viewModel = vm
            } else {
                await viewModel?.load()
            }
        }
        .onChange(of: deepLinkRouter.activeDestination) { _, newDest in
            handleDestination(newDest)
        }
        .sheet(isPresented: Binding(
            get: { viewModel?.isFilterSheetPresented ?? false },
            set: { viewModel?.isFilterSheetPresented = $0 }
        )) {
            if let viewModel {
                FilterSheetView(viewModel: viewModel)
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel?.isRequestSheetPresented ?? false },
            set: { viewModel?.isRequestSheetPresented = $0 }
        )) {
            if let viewModel {
                RequestSignSheetView(
                    viewModel: viewModel,
                    term: $requestTerm,
                    category: $requestCategory,
                    notes: $requestNotes
                )
            }
        }
        .sheet(isPresented: $isShowingCameraPractice) {
            CameraPracticeLauncher(dependencies: dependencies)
        }
        .sheet(isPresented: $isShowingFavourites) {
            FavouritesView()
        }
        .navigationDestination(for: Sign.self) { sign in
            SignDetailView(sign: sign)
        }
    }

    // MARK: - iPad List-Detail Split View (Step 14.1)

    private func ipadSplitSignsView(_ vm: SignsDirectoryViewModel) -> some View {
        HStack(spacing: 0) {
            // Left Pane: Search, Category Chips and Adaptive Grid
            mainContentView(vm)
                .frame(maxWidth: .infinity)

            Divider()

            // Right Pane: Sign Video & Detail Pane
            VStack {
                if let sign = selectedSignForDetail ?? vm.filteredSigns.first {
                    SignDetailView(sign: sign)
                        .id(sign.id)
                } else {
                    ContentUnavailableView(
                        "Select a Sign",
                        systemImage: "hand.raised.fill",
                        description: Text("Choose any sign from the directory to view its video demonstration, tips, and practice actions.")
                    )
                }
            }
            .frame(width: 460)
            .background(Color.appBackground)
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func mainContentView(_ vm: SignsDirectoryViewModel) -> some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.m) {
                // 1. Header with Title, Counts and Profile Avatar
                headerSection(vm)
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.top, Theme.Spacing.s)

                // 2. "Practise with Camera" Banner
                cameraPracticeBanner
                    .padding(.horizontal, Theme.Spacing.l)

                // 3. Search Bar
                searchBarView(vm)
                    .padding(.horizontal, Theme.Spacing.l)

                // 4. Tabs (All / ASL Dictionary / Phrases)
                tabsSection(vm)
                    .padding(.horizontal, Theme.Spacing.l)

                // 5. Filter Chips & Sheet Trigger
                filterBarSection(vm)

                // Success notification banner if present
                if let banner = vm.requestSuccessBanner {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.brandTurquoise)
                        Text(banner)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Button {
                            vm.requestSuccessBanner = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                    .padding(Theme.Spacing.m)
                    .background(Color.brandTurquoise.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, Theme.Spacing.l)
                }

                // 6. Sign Cards Grid or Empty State
                if vm.filteredSigns.isEmpty {
                    emptyStateView(vm)
                        .padding(.top, Theme.Spacing.l)
                } else {
                    signsGridView(vm)
                        .padding(.horizontal, Theme.Spacing.l)
                        .padding(.top, Theme.Spacing.xs)
                }
            }
            .padding(.bottom, Theme.Spacing.xl)
        }
    }

    // MARK: - Subviews

    private func headerSection(_ vm: SignsDirectoryViewModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Signs Directory")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)

                HStack(spacing: 6) {
                    Text("\(vm.totalCount) signs total")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)

                    Text("•")
                        .foregroundStyle(Color.textSecondary.opacity(0.5))

                    Text("\(vm.masteredCount) mastered")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.brandTurquoise)
                }
            }

            Spacer()

            Button {
                isShowingFavourites = true
                triggerHaptic()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.cardBackground)
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke(Color.gray.opacity(0.18), lineWidth: 1))

                    Image(systemName: "heart.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.danger)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View favourites")

            ProfileAvatarButton {
                deepLinkRouter.openProfile()
            }
        }
    }

    private var cameraPracticeBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.brandTurquoise.opacity(0.18))
                    .frame(width: 44, height: 44)

                Image(systemName: "camera.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.brandTurquoise)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Practise with Camera")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Text("Real-time computer vision recognition")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            Button {
                isShowingCameraPractice = true
                triggerHaptic()
            } label: {
                Text("Start")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.brandNavy, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.m)
        .background(
            LinearGradient(
                colors: [Color.brandTurquoise.opacity(0.15), Color.brandNavy.opacity(0.08)],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.brandTurquoise.opacity(0.3), lineWidth: 1)
        )
    }

    private func searchBarView(_ vm: SignsDirectoryViewModel) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textSecondary)

            TextField("Search signs, categories, or glosses", text: Binding(
                get: { vm.searchQuery },
                set: { vm.searchQuery = $0 }
            ))
            .font(.system(size: 15))
            .accessibilityLabel("Search signs")

            if !vm.searchQuery.isEmpty {
                Button {
                    vm.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.textSecondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.gray.opacity(0.18), lineWidth: 1)
        )
    }

    private func tabsSection(_ vm: SignsDirectoryViewModel) -> some View {
        HStack(spacing: 6) {
            ForEach(DirectoryTab.allCases) { tab in
                let isSelected = vm.selectedTab == tab
                Button {
                    vm.selectedTab = tab
                    triggerHaptic()
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? Color.black : Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            isSelected ? Color.brandTurquoise : Color.cardBackground,
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(isSelected ? 0 : 0.15), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func filterBarSection(_ vm: SignsDirectoryViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Filter Sheet Trigger Button with Active Badge
                Button {
                    vm.isFilterSheetPresented = true
                    triggerHaptic()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 13, weight: .semibold))

                        Text("Filters")
                            .font(.system(size: 13, weight: .semibold))

                        if vm.activeFilterCount > 0 {
                            Text("\(vm.activeFilterCount)")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.brandNavy, in: Capsule())
                        }
                    }
                    .foregroundStyle(vm.activeFilterCount > 0 ? Color.brandTurquoise : Color.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.cardBackground, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(vm.activeFilterCount > 0 ? Color.brandTurquoise : Color.gray.opacity(0.18), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Sort Menu Button
                Menu {
                    Picker("Sort By", selection: Binding(
                        get: { vm.selectedSort },
                        set: { vm.selectedSort = $0 }
                    )) {
                        ForEach(DirectorySort.allCases) { sort in
                            Text(sort.rawValue).tag(sort)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 11))
                        Text(vm.selectedSort.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.cardBackground, in: Capsule())
                    .overlay(Capsule().stroke(Color.gray.opacity(0.18), lineWidth: 1))
                }

                // Category Quick Chips
                ForEach(["All", "Alphabet", "Greetings", "Courtesy", "Everyday", "Family", "Feelings", "Food & Drink", "Emergency", "Numbers"], id: \.self) { catName in
                    let isSelected = (catName == "All" && vm.selectedCategory == nil) ||
                                     (vm.selectedCategory?.localizedCaseInsensitiveCompare(catName) == .orderedSame)

                    Button {
                        vm.selectedCategory = catName == "All" ? nil : catName
                        triggerHaptic()
                    } label: {
                        Text(catName)
                            .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? Color.black : Color.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(isSelected ? Color.brandTurquoise : Color.cardBackground, in: Capsule())
                            .overlay(Capsule().stroke(Color.gray.opacity(isSelected ? 0 : 0.18), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
        }
    }

    // MARK: - Signs Grid

    private func signsGridView(_ vm: SignsDirectoryViewModel) -> some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(vm.filteredSigns) { sign in
                Group {
                    if horizontalSizeClass == .regular {
                        Button {
                            selectedSignForDetail = sign
                            triggerHaptic()
                        } label: {
                            signGridCard(sign, vm: vm)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(selectedSignForDetail?.id == sign.id ? Color.brandTurquoise : Color.clear, lineWidth: 2.5)
                                )
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink(value: sign) {
                            signGridCard(sign, vm: vm)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .hoverEffect(.lift)
            }
        }
    }

    private func signGridCard(_ sign: Sign, vm: SignsDirectoryViewModel) -> some View {
        let status = vm.status(for: sign)
        let isBookmarked = vm.isBookmarked(sign: sign)

        return VStack(alignment: .leading, spacing: 8) {
            // Card Thumbnail & Overlays
            ZStack(alignment: .topTrailing) {
                // Background Image or Placeholder
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

                // Top Left Overlay: Category Tag & Motion Hint
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(sign.category.capitalized)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.65), in: Capsule())

                        if sign.recognition == .motionSign {
                            Image(systemName: "waveform")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.brandYellow)
                                .padding(4)
                                .background(Color.black.opacity(0.65), in: Circle())
                                .accessibilityLabel("Motion gesture")
                        } else if sign.recognition == .staticSign {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Color.brandTurquoise)
                                .padding(4)
                                .background(Color.black.opacity(0.65), in: Circle())
                                .accessibilityLabel("Camera recognizable")
                        }
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .topLeading)

                // Top Right: Bookmark Button
                Button {
                    Task {
                        await vm.toggleBookmark(sign: sign)
                        triggerHaptic()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 28, height: 28)

                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(isBookmarked ? Color.brandYellow : Color.white)
                    }
                }
                .buttonStyle(.plain)
                .padding(6)
                .accessibilityLabel(isBookmarked ? "Remove bookmark for \(sign.name)" : "Bookmark \(sign.name)")
            }

            // Card Body: Name, Pronunciation, and Status Badge
            VStack(alignment: .leading, spacing: 4) {
                Text(sign.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                if let hint = sign.pronunciationHint, !hint.isEmpty {
                    Text(hint)
                        .font(.system(size: 11, design: .serif))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }

                // Status Badge Pill
                HStack(spacing: 4) {
                    switch status {
                    case .mastered:
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                            Text("Mastered")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(Color.brandTurquoise)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.brandTurquoise.opacity(0.14), in: Capsule())

                    case .learning:
                        HStack(spacing: 3) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 10))
                            Text("Learning")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.brandYellow, in: Capsule())

                    case .newSign, .all:
                        Text("New")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.gray.opacity(0.12), in: Capsule())
                    }

                    Spacer()

                    // Level indicator (e.g. Beginner)
                    Text(sign.level.displayName.prefix(1))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.textSecondary)
                        .padding(4)
                        .background(Color.gray.opacity(0.1), in: Circle())
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
        }
        .padding(8)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Empty State (42-search-results-empty)

    private func emptyStateView(_ vm: SignsDirectoryViewModel) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .foregroundStyle(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 80)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.textSecondary.opacity(0.7))
            }

            VStack(spacing: 6) {
                Text(vm.searchQuery.isEmpty ? "No Signs Found" : "No results for '\(vm.searchQuery)'")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)

                Text("Try different search terms or explore our foundational ASL manual alphabet.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.l)
            }

            VStack(spacing: 10) {
                // Action 1: Browse Alphabet
                Button {
                    vm.browseAlphabet()
                    triggerHaptic()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.raised.fill")
                        Text("Browse Alphabet")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.brandNavy, in: Capsule())
                }
                .buttonStyle(.plain)

                // Action 2: Request a Sign (writes to signRequests)
                Button {
                    requestTerm = vm.searchQuery
                    vm.isRequestSheetPresented = true
                    triggerHaptic()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Request a Sign")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.brandTurquoise)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.brandTurquoise.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)

                // Reset Filters
                Button("Reset all filters") {
                    vm.resetFilters()
                    triggerHaptic()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
                .padding(.top, 4)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.s)
        }
        .padding(Theme.Spacing.l)
    }

    // MARK: - Deep Link Destination Handler

    private func handleDestination(_ destination: DeepLinkDestination?) {
        guard let destination else { return }

        switch destination {
        case .signsSearch(let query):
            viewModel?.searchQuery = query
            deepLinkRouter.activeDestination = nil

        case .signDetail(let signId):
            if let match = dependencies.signCatalogService.sign(byId: signId) {
                selectedSignForDetail = match
            }
            deepLinkRouter.activeDestination = nil

        default:
            break
        }
    }

    private func triggerHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

// MARK: - Filter Sheet

struct FilterSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: SignsDirectoryViewModel

    var body: some View {
        NavigationStack {
            Form {
                // 1. Difficulty Level
                Section("Difficulty Level") {
                    Picker("Level", selection: $viewModel.selectedLevel) {
                        Text("All Levels").tag(SignLevel?.none)
                        ForEach(SignLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(SignLevel?.some(level))
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // 2. Learning Status
                Section("Learning Status") {
                    Picker("Status", selection: $viewModel.selectedStatus) {
                        ForEach(SignStatusFilter.allCases) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                }

                // 3. Camera Recognizability
                Section("Camera Recognition") {
                    Picker("Recognition", selection: $viewModel.selectedRecognition) {
                        Text("All Signs").tag(SignRecognitionType?.none)
                        Text("Static Poses").tag(SignRecognitionType?.some(.staticSign))
                        Text("Motion Gestures").tag(SignRecognitionType?.some(.motionSign))
                        Text("Visual Only").tag(SignRecognitionType?.some(.none))
                    }
                }

                // 4. Bookmarks Only
                Section {
                    Toggle("Only Bookmarked Signs", isOn: $viewModel.onlyBookmarked)
                }

                // 5. Sort By
                Section("Sort Options") {
                    Picker("Sort Order", selection: $viewModel.selectedSort) {
                        ForEach(DirectorySort.allCases) { sort in
                            Text(sort.rawValue).tag(sort)
                        }
                    }
                }
            }
            .navigationTitle("Filter Signs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        viewModel.resetFilters()
                    }
                    .foregroundStyle(Color.red)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Request Sign Sheet

struct RequestSignSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: SignsDirectoryViewModel
    @Binding var term: String
    @Binding var category: String
    @Binding var notes: String
    @State private var errorMessage: String? = nil

    private let commonCategories = [
        "General", "Alphabet", "Greetings", "Courtesy",
        "Everyday", "Family", "Food & Drink", "Emergency", "Healthcare"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Can't find a sign?")
                            .font(.system(size: 16, weight: .bold))
                        Text("Request a sign to be added to the SignSpeak dictionary. Our team reviews submissions regularly.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Sign Word or Phrase") {
                    TextField("e.g. Congratulations, Cat, Coffee", text: $term)
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(commonCategories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                }

                Section("Context or Usage Notes (Optional)") {
                    TextField("e.g. Used when congratulating friends", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.red)
                    }
                }
            }
            .navigationTitle("Request a Sign")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        submit()
                    } label: {
                        if viewModel.isSubmittingRequest {
                            ProgressView()
                        } else {
                            Text("Submit")
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(term.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSubmittingRequest)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func submit() {
        Task {
            do {
                try await viewModel.submitSignRequest(term: term, category: category, notes: notes)
                dismiss()
            } catch {
                errorMessage = "Failed to submit request: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Camera Practice Launcher

private struct CameraPracticeLauncher: View {
    @Environment(\.dismiss) private var dismiss
    let dependencies: AppDependencies

    var body: some View {
        NavigationStack {
            CameraTestView()
                .navigationTitle("Camera Practice")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

#Preview("Signs Directory") {
    NavigationStack {
        SignsRootView(deepLinkRouter: DeepLinkRouter())
            .environment(\.dependencies, .preview)
    }
}
