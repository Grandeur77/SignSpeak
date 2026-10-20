import SwiftUI

/// Supports direct search, category browsing, and opens sign demonstration details.
public struct SignsRootView: View {
    @Bindable var deepLinkRouter: DeepLinkRouter

    @State private var searchQuery = ""
    @State private var selectedCategory = "All"

    private let categories = ["All", "Alphabet", "Greetings", "Family", "Food", "Emergency"]

    public init(deepLinkRouter: DeepLinkRouter) {
        self.deepLinkRouter = deepLinkRouter
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.m) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Signs Directory")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.brandNavy)

                        Text("Explore ASL vocabulary and fingerspelling")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textSecondary)
                    }

                    Spacer()

                    ProfileAvatarButton {
                        deepLinkRouter.openProfile()
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.s)

                // Search Bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.textSecondary)

                    TextField("Search signs (e.g. Hello, Thank You, A–Z)", text: $searchQuery)
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
                .padding(.horizontal, Theme.Spacing.l)

                // Category Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                Text(category)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(selectedCategory == category ? Color.onPrimary : Color.textPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        selectedCategory == category ? Color.brandNavy : Color.cardBackground,
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                }

                // Sign List
                VStack(spacing: 10) {
                    signItemRow(sign: "Hello", category: "Greetings", level: "Beginner")
                    signItemRow(sign: "Thank You", category: "Polite Expressions", level: "Beginner")
                    signItemRow(sign: "Please", category: "Polite Expressions", level: "Beginner")
                    signItemRow(sign: "Yes", category: "Responses", level: "Beginner")
                    signItemRow(sign: "No", category: "Responses", level: "Beginner")
                    signItemRow(sign: "Help", category: "Emergency", level: "Crucial")
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.s)
            }
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .onChange(of: deepLinkRouter.activeDestination) { _, newDest in
            if case let .signsSearch(query) = newDest {
                searchQuery = query
                deepLinkRouter.activeDestination = nil
            }
        }
    }

    private func signItemRow(sign: String, category: String, level: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.brandTurquoise.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.brandTurquoise)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(sign)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                Text(category)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            Text(level)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.brandTurquoise)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.brandTurquoise.opacity(0.1), in: Capsule())

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}

#Preview("Signs Root View") {
    NavigationStack {
        SignsRootView(deepLinkRouter: DeepLinkRouter())
    }
}
