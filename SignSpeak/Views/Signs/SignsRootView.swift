import SwiftUI

/// Supports direct search, category browsing, and opens sign demonstration details.
/// Powered by `SignCatalogServicing` and deep link navigation to `SignDetailView`.
public struct SignsRootView: View {
    @Environment(\.dependencies) private var dependencies
    @Bindable var deepLinkRouter: DeepLinkRouter

    @State private var searchQuery = ""
    @State private var selectedCategory = "All"
    @State private var allSigns: [Sign] = []
    @State private var allCategories: [SignCategory] = []
    @State private var navigatedSign: Sign?

    public init(deepLinkRouter: DeepLinkRouter) {
        self.deepLinkRouter = deepLinkRouter
    }

    private var availableCategoryNames: [String] {
        var names = ["All"]
        names.append(contentsOf: allCategories.map(\.name))
        return names
    }

    private var filteredSigns: [Sign] {
        let searched: [Sign]
        if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            searched = allSigns
        } else {
            searched = dependencies.signCatalogService.search(query: searchQuery)
        }

        if selectedCategory == "All" {
            return searched
        }

        return searched.filter { $0.category.localizedCaseInsensitiveContains(selectedCategory) }
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.m) {
                // Header
                headerView
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.top, Theme.Spacing.s)

                // Search Bar
                searchBarView
                    .padding(.horizontal, Theme.Spacing.l)

                // Category Chips
                categorySelectorView

                // Sign List or Empty State
                if filteredSigns.isEmpty {
                    emptyStateView
                        .padding(.top, Theme.Spacing.xl)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredSigns) { sign in
                            NavigationLink(value: sign) {
                                signRow(sign)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.top, Theme.Spacing.s)
                }
            }
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationDestination(for: Sign.self) { sign in
            SignDetailView(sign: sign)
        }
        .task {
            loadCatalog()
        }
        .onChange(of: deepLinkRouter.activeDestination) { _, newDest in
            handleDestination(newDest)
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Signs Directory")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)

                Text("Explore ASL vocabulary, gestures & finger-spelling")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            ProfileAvatarButton {
                deepLinkRouter.openProfile()
            }
        }
    }

    private var searchBarView: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textSecondary)

            TextField("Search signs (e.g. Hello, Thank You, A–Z)", text: $searchQuery)
                .font(.system(size: 15))
                .accessibilityLabel("Search signs")

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
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

    private var categorySelectorView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableCategoryNames, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(selectedCategory == category ? Color.black : Color.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                selectedCategory == category ? Color.brandTurquoise : Color.cardBackground,
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.gray.opacity(selectedCategory == category ? 0 : 0.18), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Filter by \(category)")
                    .accessibilityAddTraits(selectedCategory == category ? .isSelected : [])
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
        }
    }

    private func signRow(_ sign: Sign) -> some View {
        HStack(spacing: 12) {
            // Sign Thumbnail Photo or Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.brandTurquoise.opacity(0.12))
                    .frame(width: 48, height: 48)

                if let imageName = sign.imageName {
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.brandTurquoise)
                }
            }

            // Title & Subtitle
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(sign.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)

                    if sign.frontVideoName != nil {
                        Image(systemName: "video.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.brandTurquoise)
                    }
                }

                Text(sign.category)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            // Level Pill
            Text(sign.level.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.brandTurquoise)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.brandTurquoise.opacity(0.12), in: Capsule())

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(Color.textSecondary.opacity(0.6))

            Text("No Signs Found")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            Text("Try searching with different terms or selecting 'All' categories.")
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.l)

            Button("Reset Filters") {
                searchQuery = ""
                selectedCategory = "All"
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.brandTurquoise)
            .padding(.top, 4)
        }
        .padding(Theme.Spacing.xl)
    }

    // MARK: - Actions

    private func loadCatalog() {
        allSigns = dependencies.signCatalogService.allSigns()
        allCategories = dependencies.signCatalogService.allCategories()
    }

    private func handleDestination(_ destination: DeepLinkDestination?) {
        guard let destination else { return }

        switch destination {
        case .signsSearch(let query):
            searchQuery = query
            deepLinkRouter.activeDestination = nil

        case .signDetail(let signId):
            if let match = dependencies.signCatalogService.sign(byId: signId) {
                navigatedSign = match
            }
            deepLinkRouter.activeDestination = nil

        default:
            break
        }
    }
}

#Preview("Signs Root View") {
    NavigationStack {
        SignsRootView(deepLinkRouter: DeepLinkRouter())
            .environment(\.dependencies, .preview)
    }
}
