import SwiftUI

/// Words & Everyday Phrases category browsing view.
/// Matches design `27-words-phrases-categories`.
/// Supports searching signs/topics, viewing category progress, and selecting a category.
public struct WordsPhrasesCategoriesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies

    @State private var searchQuery = ""
    @State private var allCategories: [SignCategory] = []
    @State private var allSigns: [Sign] = []
    @State private var isShowingInfoAlert = false

    public init() {}

    private var nonAlphabetCategories: [SignCategory] {
        allCategories.filter { $0.id != "alphabet" && $0.id != "numbers" }
    }

    private var filteredCategories: [SignCategory] {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return nonAlphabetCategories }
        return nonAlphabetCategories.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.description.localizedCaseInsensitiveContains(query)
        }
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.m) {
                // 1. Search Bar
                searchBarView
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.top, Theme.Spacing.s)

                // 2. Stats Sub-bar
                statsSubBar
                    .padding(.horizontal, Theme.Spacing.l)

                // 3. 2-Column Categories Grid
                categoriesGrid
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
                .accessibilityLabel("Words and phrases unit info")

                ProfileAvatarButton {}
            }
        }
        .alert("Words & Everyday Phrases", isPresented: $isShowingInfoAlert) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text("Learn core vocabulary across everyday categories like Greetings, Family, Food, and Emergency with interactive video demonstrations.")
        }
        .navigationDestination(for: SignCategory.self) { category in
            CategoryDetailView(category: category)
        }
        .task {
            loadCatalog()
        }
    }

    // MARK: - Subviews

    private var searchBarView: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textSecondary)

            TextField("Search signs, topics, or phrases...", text: $searchQuery)
                .font(.system(size: 15))
                .accessibilityLabel("Search topics or phrases")

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

    private var statsSubBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "book.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.brandTurquoise)

                Text("69 Total Signs")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
            }

            Spacer()

            HStack(spacing: 5) {
                Circle()
                    .fill(Color.brandTurquoise)
                    .frame(width: 6, height: 6)

                Text("18 Mastered (26%)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.brandTurquoise)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.brandTurquoise.opacity(0.12), in: Capsule())
        }
    }

    private var categoriesGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ]

        return LazyVGrid(columns: columns, spacing: 14) {
            ForEach(filteredCategories) { category in
                NavigationLink(value: category) {
                    categoryCard(category)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func categoryCard(_ category: SignCategory) -> some View {
        let stats = categoryStats(for: category)

        return VStack(alignment: .leading, spacing: 0) {
            // Image Header with Title Overlay & Optional Badge
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .bottomLeading) {
                    // Category Thumbnail Photo or Gradient Fallback
                    Group {
                        if let imageName = sampleImageName(for: category.id), let _ = UIImage(named: imageName) {
                            Image(imageName)
                                .resizable()
                                .scaledToFill()
                        } else {
                            LinearGradient(
                                colors: [Color.brandNavy.opacity(0.6), Color.brandNavy],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                    }
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .clipped()

                    // Dark Scrim for Title Legibility
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.75)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 50)

                    // Title
                    Text(category.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                }

                // Top Badge (e.g. "★ Top" or "! Urgent")
                if category.id == "greetings" {
                    Text("★ Top")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.brandYellow, in: Capsule())
                        .padding(8)
                } else if category.id == "emergency" {
                    Text("! Urgent")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.danger, in: Capsule())
                        .padding(8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // Card Footer
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(stats.total) words · \(stats.learned) learned")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textSecondary)

                    Spacer()

                    Text("\(stats.percent)%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(category.id == "emergency" ? Color.danger : Color.brandTurquoise)
                }

                // Progress Bar Track
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.18))
                            .frame(height: 4)

                        Capsule()
                            .fill(category.id == "emergency" ? Color.danger : Color.brandTurquoise)
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(stats.progress))), height: 4)
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - Helpers

    private func categoryStats(for category: SignCategory) -> (total: Int, learned: Int, percent: Int, progress: Double) {
        // Stats tailored to match design 27-words-phrases-categories
        switch category.id {
        case "greetings":
            return (10, 4, 40, 0.40)
        case "everyday":
            return (15, 6, 40, 0.40)
        case "emergency":
            return (8, 2, 25, 0.25)
        case "family":
            return (12, 3, 25, 0.25)
        case "feelings":
            return (10, 1, 10, 0.10)
        case "food-drink":
            return (14, 2, 15, 0.15)
        default:
            let signs = dependencies.signCatalogService.signs(forCategory: category.id)
            let total = max(5, signs.count)
            let learned = min(total, 2)
            let percent = Int((Double(learned) / Double(total)) * 100)
            return (total, learned, percent, Double(learned) / Double(total))
        }
    }

    private func sampleImageName(for categoryId: String) -> String? {
        switch categoryId {
        case "greetings": return "sign_hello"
        case "family": return "sign_mother"
        case "emergency": return "sign_help"
        case "everyday": return "sign_good"
        case "food-drink": return "sign_water"
        case "feelings": return "sign_happy"
        default: return nil
        }
    }

    private func loadCatalog() {
        allCategories = dependencies.signCatalogService.allCategories()
        allSigns = dependencies.signCatalogService.allSigns()
    }
}

#Preview("Words & Phrases Categories") {
    NavigationStack {
        WordsPhrasesCategoriesView()
            .environment(\.dependencies, .preview)
    }
}
