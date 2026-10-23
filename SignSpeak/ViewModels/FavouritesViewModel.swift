import SwiftUI
import Observation

/// Filter tabs for sorting and grouping favourites in `44-favourites`.
public enum FavouritesFilterTab: String, Identifiable, CaseIterable, Sendable {
    case all = "All"
    case due = "Due for Review"
    case alphabet = "Alphabet"
    case words = "Words & Phrases"

    public var id: String { rawValue }
}

/// Sort criteria for user's favourited signs.
public enum FavouritesSortOption: String, Identifiable, CaseIterable, Sendable {
    case dueEarliest = "Due Date (Earliest)"
    case recentlyAdded = "Recently Added"
    case alphabetical = "Alphabetical (A–Z)"
    case highestInterval = "Highest Interval"

    public var id: String { rawValue }
}

/// Element uniting a sign and its SM-2 spaced repetition record.
public struct FavouriteSignItem: Identifiable, Sendable, Equatable {
    public var id: String { sign.id }
    public let sign: Sign
    public let record: FavouriteRecord

    public init(sign: Sign, record: FavouriteRecord) {
        self.sign = sign
        self.record = record
    }
}

/// Observable ViewModel coordinating saved signs, SM-2 spaced repetition schedule,
/// practice session initiation, and Firestore synchronization.
/// Matches design `44-favourites`.
@Observable
@MainActor
public final class FavouritesViewModel {
    public private(set) var records: [String: FavouriteRecord] = [:]
    public private(set) var signsById: [String: Sign] = [:]

    public var searchQuery: String = ""
    public var selectedTab: FavouritesFilterTab = .all
    public var selectedSort: FavouritesSortOption = .dueEarliest

    public var isLoading: Bool = false
    public var errorMessage: String? = nil

    public var sessionSigns: [Sign] = []
    public var isPresentingSession: Bool = false

    private let favouritesRepository: any FavouritesRepository
    private let signCatalogService: any SignCatalogServicing
    private let progressRepository: any ProgressRepository
    private let userId: String
    private let nowProvider: () -> Date

    public init(
        favouritesRepository: any FavouritesRepository,
        signCatalogService: any SignCatalogServicing,
        progressRepository: any ProgressRepository = StubProgressRepository(),
        userId: String = "default",
        nowProvider: @escaping () -> Date = { Date() }
    ) {
        self.favouritesRepository = favouritesRepository
        self.signCatalogService = signCatalogService
        self.progressRepository = progressRepository
        self.userId = userId
        self.nowProvider = nowProvider
    }

    // MARK: - Lifecycle

    public func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fetched = try await favouritesRepository.fetchFavourites(userId: userId)
            var recMap: [String: FavouriteRecord] = [:]
            var signMap: [String: Sign] = [:]

            for r in fetched {
                recMap[r.signId] = r
                if let sign = signCatalogService.sign(byId: r.signId) {
                    signMap[r.signId] = sign
                }
            }

            self.records = recMap
            self.signsById = signMap
        } catch {
            self.errorMessage = "Failed to load favourites: \(error.localizedDescription)"
        }
    }

    // MARK: - Computed Properties

    public var totalCount: Int {
        records.count
    }

    public var dueCount: Int {
        let now = nowProvider()
        return records.values.filter { SpacedRepetitionScheduler.isDue(record: $0, asOf: now) }.count
    }

    public var filteredItems: [FavouriteSignItem] {
        let now = nowProvider()
        var items: [FavouriteSignItem] = records.compactMap { (signId, record) in
            guard let sign = signsById[signId] else { return nil }
            return FavouriteSignItem(sign: sign, record: record)
        }

        // 1. Tab Filtering
        switch selectedTab {
        case .all:
            break
        case .due:
            items = items.filter { SpacedRepetitionScheduler.isDue(record: $0.record, asOf: now) }
        case .alphabet:
            items = items.filter { $0.sign.category.lowercased() == "alphabet" }
        case .words:
            items = items.filter { $0.sign.category.lowercased() != "alphabet" }
        }

        // 2. Search Query Filtering
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            items = items.filter { item in
                item.sign.name.lowercased().contains(q) ||
                item.sign.category.lowercased().contains(q) ||
                item.sign.description.lowercased().contains(q)
            }
        }

        // 3. Sorting
        switch selectedSort {
        case .dueEarliest:
            items.sort { $0.record.nextDueDate < $1.record.nextDueDate }
        case .recentlyAdded:
            items.sort { $0.record.savedAt > $1.record.savedAt }
        case .alphabetical:
            items.sort { $0.sign.name.localizedCompare($1.sign.name) == .orderedAscending }
        case .highestInterval:
            items.sort { $0.record.intervalDays > $1.record.intervalDays }
        }

        return items
    }

    // MARK: - Actions

    public func removeFavourite(signId: String) async {
        records.removeValue(forKey: signId)
        signsById.removeValue(forKey: signId)
        try? await favouritesRepository.removeFavourite(userId: userId, signId: signId)
    }

    /// Prepares review session consisting exclusively of signs due today (or all favourites if none due).
    public func prepareDueReviewSession() {
        let now = nowProvider()
        let due = records.values
            .filter { SpacedRepetitionScheduler.isDue(record: $0, asOf: now) }
            .compactMap { signsById[$0.signId] }

        if !due.isEmpty {
            self.sessionSigns = due
        } else {
            // If none due, review all favourites
            self.sessionSigns = Array(signsById.values)
        }
        self.isPresentingSession = true
    }

    /// Prepares practice session for all favourites regardless of due date.
    public func prepareAllFavouritesSession() {
        self.sessionSigns = Array(signsById.values)
        self.isPresentingSession = true
    }

    /// Updates SM-2 spaced repetition schedule after learner finishes practicing a sign.
    public func recordPracticeReview(sign: Sign, quality: Int) async {
        let now = nowProvider()
        do {
            let updated = try await favouritesRepository.recordPracticeResult(
                userId: userId,
                signId: sign.id,
                quality: quality,
                reviewDate: now
            )
            records[sign.id] = updated

            // Also record into user's progress repository
            try? await progressRepository.recordAttempt(
                userId: userId,
                signId: sign.id,
                isCorrect: quality >= 3,
                detectedAs: quality >= 3 ? sign.name : nil
            )
        } catch {
            errorMessage = "Failed to update review record: \(error.localizedDescription)"
        }
    }
}
