import Foundation
import SwiftUI

/// Active tab in the Signs Directory.
public enum DirectoryTab: String, CaseIterable, Sendable, Identifiable {
    case all = "All"
    case dictionary = "ASL Dictionary"
    case phrases = "Phrases"

    public var id: String { rawValue }
}

/// Sorting criteria for the signs directory.
public enum DirectorySort: String, CaseIterable, Sendable, Identifiable {
    case alphabeticalAsc = "A to Z"
    case alphabeticalDesc = "Z to A"
    case level = "Difficulty Level"
    case status = "Learning Status"

    public var id: String { rawValue }
}

/// Learning status filter and badge representation.
public enum SignStatusFilter: String, CaseIterable, Sendable, Identifiable {
    case all = "All"
    case mastered = "Mastered"
    case learning = "Learning"
    case newSign = "New"

    public var id: String { rawValue }
}

/// View model driving the Signs Directory screen (Step 6.1).
/// Matches designs `43-signs-directory` and `42-search-results-empty`.
@MainActor
@Observable
public final class SignsDirectoryViewModel {
    public var searchQuery: String = ""
    public var selectedTab: DirectoryTab = .all
    public var selectedCategory: String? = nil
    public var selectedLevel: SignLevel? = nil
    public var selectedRecognition: SignRecognitionType? = nil
    public var selectedStatus: SignStatusFilter = .all
    public var selectedSort: DirectorySort = .alphabeticalAsc
    public var onlyBookmarked: Bool = false

    // State presentation
    public var isFilterSheetPresented: Bool = false
    public var isRequestSheetPresented: Bool = false
    public var isSubmittingRequest: Bool = false
    public var requestSuccessBanner: String? = nil

    // Data stores
    public private(set) var allSigns: [Sign] = []
    public private(set) var categories: [SignCategory] = []
    public private(set) var userProgress: [String: SignProgress] = [:]
    public private(set) var favouriteIds: Set<String> = []

    private let signCatalogService: any SignCatalogServicing
    private let progressRepository: any ProgressRepository
    private let favouritesRepository: any FavouritesRepository
    private let signRequestRepository: any SignRequestRepository
    private let authService: any AuthServicing

    public init(
        signCatalogService: any SignCatalogServicing,
        progressRepository: any ProgressRepository,
        favouritesRepository: any FavouritesRepository,
        signRequestRepository: any SignRequestRepository,
        authService: any AuthServicing
    ) {
        self.signCatalogService = signCatalogService
        self.progressRepository = progressRepository
        self.favouritesRepository = favouritesRepository
        self.signRequestRepository = signRequestRepository
        self.authService = authService
    }

    public func load() async {
        allSigns = signCatalogService.allSigns()
        categories = signCatalogService.allCategories()

        let userId = authService.currentUserId ?? "default"

        // Load learning progress
        if let progressItems = try? await progressRepository.fetchProgress(userId: userId) {
            var dict: [String: SignProgress] = [:]
            for item in progressItems { dict[item.signId] = item }
            userProgress = dict
        }

        // Load favourites / bookmarks
        if let favs = try? await favouritesRepository.fetchFavourites(userId: userId) {
            favouriteIds = Set(favs.map(\.signId))
        }
    }

    // MARK: - Computed Filtered Signs

    public var filteredSigns: [Sign] {
        var signs = allSigns

        // 1. Search Query Filter & Ranking
        let cleanQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !cleanQuery.isEmpty {
            signs = signs.filter { sign in
                if sign.name.lowercased().contains(cleanQuery) { return true }
                if sign.category.lowercased().contains(cleanQuery) { return true }
                if sign.description.lowercased().contains(cleanQuery) { return true }
                if let hint = sign.pronunciationHint?.lowercased(), hint.contains(cleanQuery) { return true }
                return false
            }
        }

        // 2. Tab Filter
        switch selectedTab {
        case .all:
            break
        case .dictionary:
            // Single-word dictionary vocabulary or alphabet letters
            signs = signs.filter { sign in
                !sign.name.contains(" ") || sign.category == "alphabet" || sign.category == "numbers"
            }
        case .phrases:
            // Multi-word phrases, greetings, or courtesy expressions
            signs = signs.filter { sign in
                sign.name.contains(" ") || sign.category == "courtesy" || sign.category == "greetings"
            }
        }

        // 3. Category Filter
        if let selectedCategory, !selectedCategory.isEmpty, selectedCategory != "All" {
            signs = signs.filter { $0.category.localizedCaseInsensitiveCompare(selectedCategory) == .orderedSame }
        }

        // 4. Level Filter
        if let selectedLevel {
            signs = signs.filter { $0.level == selectedLevel }
        }

        // 5. Recognition Filter
        if let selectedRecognition {
            signs = signs.filter { $0.recognition == selectedRecognition }
        }

        // 6. Learning Status Filter
        switch selectedStatus {
        case .all:
            break
        case .mastered:
            signs = signs.filter { status(for: $0) == .mastered }
        case .learning:
            signs = signs.filter { status(for: $0) == .learning }
        case .newSign:
            signs = signs.filter { status(for: $0) == .newSign }
        }

        // 7. Bookmarked Filter
        if onlyBookmarked {
            signs = signs.filter { favouriteIds.contains($0.id) }
        }

        // 8. Sorting
        switch selectedSort {
        case .alphabeticalAsc:
            signs.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .alphabeticalDesc:
            signs.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .level:
            signs.sort { $0.level < $1.level }
        case .status:
            signs.sort { statusRank(for: $0) < statusRank(for: $1) }
        }

        return signs
    }

    // MARK: - Metrics and Counts

    public var totalCount: Int { allSigns.count }

    public var masteredCount: Int {
        allSigns.filter { status(for: $0) == .mastered }.count
    }

    public var learningCount: Int {
        allSigns.filter { status(for: $0) == .learning }.count
    }

    public var newCount: Int {
        allSigns.filter { status(for: $0) == .newSign }.count
    }

    public var activeFilterCount: Int {
        var count = 0
        if selectedCategory != nil && selectedCategory != "All" { count += 1 }
        if selectedLevel != nil { count += 1 }
        if selectedRecognition != nil { count += 1 }
        if selectedStatus != .all { count += 1 }
        if onlyBookmarked { count += 1 }
        return count
    }

    // MARK: - Status and Bookmarks

    public func status(for sign: Sign) -> SignStatusFilter {
        guard let progress = userProgress[sign.id] else { return .newSign }
        if progress.isMastered {
            return .mastered
        } else if progress.attempts > 0 || progress.correct > 0 {
            return .learning
        } else {
            return .newSign
        }
    }

    private func statusRank(for sign: Sign) -> Int {
        switch status(for: sign) {
        case .mastered: return 0
        case .learning: return 1
        case .newSign: return 2
        case .all: return 3
        }
    }

    public func isBookmarked(sign: Sign) -> Bool {
        favouriteIds.contains(sign.id)
    }

    public func toggleBookmark(sign: Sign) async {
        let userId = authService.currentUserId ?? "default"
        if favouriteIds.contains(sign.id) {
            favouriteIds.remove(sign.id)
            try? await favouritesRepository.removeFavourite(userId: userId, signId: sign.id)
        } else {
            favouriteIds.insert(sign.id)
            try? await favouritesRepository.addFavourite(userId: userId, signId: sign.id)
        }
    }

    // MARK: - Filter Reset and Alphabet Jump

    public func resetFilters() {
        searchQuery = ""
        selectedTab = .all
        selectedCategory = nil
        selectedLevel = nil
        selectedRecognition = nil
        selectedStatus = .all
        selectedSort = .alphabeticalAsc
        onlyBookmarked = false
    }

    public func browseAlphabet() {
        searchQuery = ""
        selectedTab = .all
        selectedCategory = "alphabet"
        selectedLevel = nil
        selectedRecognition = nil
        selectedStatus = .all
        onlyBookmarked = false
    }

    // MARK: - Sign Request Submission

    public func submitSignRequest(term: String, category: String, notes: String?) async throws {
        let cleanTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTerm.isEmpty else { return }

        isSubmittingRequest = true
        defer { isSubmittingRequest = false }

        let userId = authService.currentUserId ?? "anonymous-learner"
        let request = SignRequest(
            requesterId: userId,
            term: cleanTerm,
            category: category.isEmpty ? "General" : category,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        try await signRequestRepository.submitRequest(request)
        requestSuccessBanner = "Sign request submitted for '\(cleanTerm)'!"
        isRequestSheetPresented = false
    }
}
