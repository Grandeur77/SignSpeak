import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Stored user favourite / bookmark record in `users/{uid}/favourites/{signId}`.
/// Tracks SM-2 spaced repetition interval, ease factor, repetition streak, and review due date.
public struct FavouriteRecord: Identifiable, Codable, Sendable, Equatable {
    public var id: String { signId }
    public let signId: String
    public let savedAt: Date
    public var intervalDays: Int // Spaced repetition interval in days (srsInterval)
    public var easeFactor: Double // SM-2 ease factor (srsEase)
    public var repetitions: Int // Number of consecutive successful recall reviews
    public var nextDueDate: Date // Review scheduled date (dueAt)
    public var lastReviewedAt: Date?
    public var lastQuality: Int?

    public init(
        signId: String,
        savedAt: Date = Date(),
        intervalDays: Int = 1,
        easeFactor: Double = 2.5,
        repetitions: Int = 0,
        nextDueDate: Date = Date(),
        lastReviewedAt: Date? = nil,
        lastQuality: Int? = nil
    ) {
        self.signId = signId
        self.savedAt = savedAt
        self.intervalDays = intervalDays
        self.easeFactor = easeFactor
        self.repetitions = repetitions
        self.nextDueDate = nextDueDate
        self.lastReviewedAt = lastReviewedAt
        self.lastQuality = lastQuality
    }

    enum CodingKeys: String, CodingKey {
        case signId
        case savedAt, addedAt
        case intervalDays, srsInterval
        case easeFactor, srsEase
        case repetitions
        case nextDueDate, dueAt
        case lastReviewedAt
        case lastQuality
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.signId = try container.decode(String.self, forKey: .signId)

        if let d = try? container.decode(Date.self, forKey: .savedAt) {
            self.savedAt = d
        } else if let d = try? container.decode(Date.self, forKey: .addedAt) {
            self.savedAt = d
        } else {
            self.savedAt = Date()
        }

        if let i = try? container.decode(Int.self, forKey: .intervalDays) {
            self.intervalDays = i
        } else if let i = try? container.decode(Int.self, forKey: .srsInterval) {
            self.intervalDays = i
        } else {
            self.intervalDays = 1
        }

        if let e = try? container.decode(Double.self, forKey: .easeFactor) {
            self.easeFactor = e
        } else if let e = try? container.decode(Double.self, forKey: .srsEase) {
            self.easeFactor = e
        } else {
            self.easeFactor = 2.5
        }

        self.repetitions = (try? container.decode(Int.self, forKey: .repetitions)) ?? 0

        if let d = try? container.decode(Date.self, forKey: .nextDueDate) {
            self.nextDueDate = d
        } else if let d = try? container.decode(Date.self, forKey: .dueAt) {
            self.nextDueDate = d
        } else {
            self.nextDueDate = Date()
        }

        self.lastReviewedAt = try? container.decodeIfPresent(Date.self, forKey: .lastReviewedAt)
        self.lastQuality = try? container.decodeIfPresent(Int.self, forKey: .lastQuality)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(signId, forKey: .signId)
        try container.encode(savedAt, forKey: .savedAt)
        try container.encode(savedAt, forKey: .addedAt)
        try container.encode(intervalDays, forKey: .intervalDays)
        try container.encode(intervalDays, forKey: .srsInterval)
        try container.encode(easeFactor, forKey: .easeFactor)
        try container.encode(easeFactor, forKey: .srsEase)
        try container.encode(repetitions, forKey: .repetitions)
        try container.encode(nextDueDate, forKey: .nextDueDate)
        try container.encode(nextDueDate, forKey: .dueAt)
        try container.encodeIfPresent(lastReviewedAt, forKey: .lastReviewedAt)
        try container.encodeIfPresent(lastQuality, forKey: .lastQuality)
    }
}

/// Protocol abstracting user bookmark and favourite sign management with SM-2 spaced repetition.
public protocol FavouritesRepository: Sendable {
    func fetchFavourites(userId: String) async throws -> [FavouriteRecord]
    func fetchDueFavourites(userId: String, asOf: Date) async throws -> [FavouriteRecord]
    func isFavourite(userId: String, signId: String) async throws -> Bool
    @discardableResult
    func toggleFavourite(userId: String, signId: String) async throws -> Bool
    func addFavourite(userId: String, signId: String) async throws
    func removeFavourite(userId: String, signId: String) async throws
    func updateSpacedRepetition(userId: String, record: FavouriteRecord) async throws
    @discardableResult
    func recordPracticeResult(userId: String, signId: String, quality: Int, reviewDate: Date) async throws -> FavouriteRecord
}

/// In-memory stub for favourites management in tests and previews.
public final class StubFavouritesRepository: FavouritesRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var store: [String: [String: FavouriteRecord]] = [:]

    public init(initialStore: [String: [String: FavouriteRecord]]? = nil) {
        if let initialStore {
            self.store = initialStore
        } else {
            // Seed sample bookmarks with spaced repetition schedule for preview user
            let now = Date()
            self.store = [
                "preview-user-123": [
                    "sign-word-hello": FavouriteRecord(
                        signId: "sign-word-hello",
                        savedAt: now.addingTimeInterval(-86400 * 5),
                        intervalDays: 1,
                        easeFactor: 2.5,
                        repetitions: 1,
                        nextDueDate: now // Due today
                    ),
                    "sign-letter-a": FavouriteRecord(
                        signId: "sign-letter-a",
                        savedAt: now.addingTimeInterval(-86400 * 10),
                        intervalDays: 6,
                        easeFactor: 2.6,
                        repetitions: 2,
                        nextDueDate: now.addingTimeInterval(86400 * 3) // Due in 3 days
                    ),
                    "sign-letter-m": FavouriteRecord(
                        signId: "sign-letter-m",
                        savedAt: now.addingTimeInterval(-86400 * 2),
                        intervalDays: 1,
                        easeFactor: 2.4,
                        repetitions: 0,
                        nextDueDate: now.addingTimeInterval(-86400) // Overdue by 1 day
                    )
                ],
                "default": [
                    "sign-word-hello": FavouriteRecord(
                        signId: "sign-word-hello",
                        savedAt: now,
                        nextDueDate: now
                    )
                ]
            ]
        }
    }

    public func fetchFavourites(userId: String) async throws -> [FavouriteRecord] {
        lock.lock()
        defer { lock.unlock() }
        let userDict = store[userId] ?? (userId == "default" || userId == "preview-user-123" ? store["default"] : nil) ?? [:]
        return Array(userDict.values)
    }

    public func fetchDueFavourites(userId: String, asOf: Date = Date()) async throws -> [FavouriteRecord] {
        let all = try await fetchFavourites(userId: userId)
        return all.filter { SpacedRepetitionScheduler.isDue(record: $0, asOf: asOf) }
    }

    public func isFavourite(userId: String, signId: String) async throws -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let userDict = store[userId] ?? (userId == "default" || userId == "preview-user-123" ? store["default"] : nil) ?? [:]
        return userDict[signId] != nil
    }

    @discardableResult
    public func toggleFavourite(userId: String, signId: String) async throws -> Bool {
        lock.lock()
        defer { lock.unlock() }
        var userDict = store[userId] ?? [:]
        if userDict[signId] != nil {
            userDict.removeValue(forKey: signId)
            store[userId] = userDict
            return false
        } else {
            userDict[signId] = FavouriteRecord(signId: signId)
            store[userId] = userDict
            return true
        }
    }

    public func addFavourite(userId: String, signId: String) async throws {
        lock.lock()
        defer { lock.unlock() }
        var userDict = store[userId] ?? [:]
        userDict[signId] = FavouriteRecord(signId: signId)
        store[userId] = userDict
    }

    public func removeFavourite(userId: String, signId: String) async throws {
        lock.lock()
        defer { lock.unlock() }
        var userDict = store[userId] ?? [:]
        userDict.removeValue(forKey: signId)
        store[userId] = userDict
    }

    public func updateSpacedRepetition(userId: String, record: FavouriteRecord) async throws {
        lock.lock()
        defer { lock.unlock() }
        var userDict = store[userId] ?? [:]
        userDict[record.signId] = record
        store[userId] = userDict
    }

    @discardableResult
    public func recordPracticeResult(
        userId: String,
        signId: String,
        quality: Int,
        reviewDate: Date = Date()
    ) async throws -> FavouriteRecord {
        lock.lock()
        defer { lock.unlock() }
        var userDict = store[userId] ?? [:]
        let current = userDict[signId] ?? FavouriteRecord(signId: signId, savedAt: reviewDate)
        let updated = SpacedRepetitionScheduler.evaluate(current: current, quality: quality, reviewDate: reviewDate)
        userDict[signId] = updated
        store[userId] = userDict
        return updated
    }
}

#if canImport(FirebaseFirestore)
/// Concrete implementation of `FavouritesRepository` backed by `users/{uid}/favourites/{signId}`.
public final class FirestoreFavouritesRepository: FavouritesRepository, @unchecked Sendable {
    private let customFirestore: Firestore?
    private var db: Firestore? {
        if let customFirestore { return customFirestore }
        #if canImport(FirebaseCore)
        guard FirebaseApp.app() != nil else { return nil }
        return Firestore.firestore()
        #else
        return nil
        #endif
    }

    private let lock = NSLock()
    private var localCache: [String: [String: FavouriteRecord]] = [:]

    public init(firestore: Firestore? = nil) {
        self.customFirestore = firestore
    }

    public func fetchFavourites(userId: String) async throws -> [FavouriteRecord] {
        if let db {
            do {
                let snapshot = try await db.collection("users")
                    .document(userId)
                    .collection("favourites")
                    .getDocuments()
                let items = snapshot.documents.compactMap { try? $0.data(as: FavouriteRecord.self) }
                lock.lock()
                var dict: [String: FavouriteRecord] = [:]
                for item in items { dict[item.signId] = item }
                localCache[userId] = dict
                lock.unlock()
                return items
            } catch {
                // Offline fallback to local cache
            }
        }

        lock.lock()
        defer { lock.unlock() }
        return Array((localCache[userId] ?? [:]).values)
    }

    public func fetchDueFavourites(userId: String, asOf: Date = Date()) async throws -> [FavouriteRecord] {
        let all = try await fetchFavourites(userId: userId)
        return all.filter { SpacedRepetitionScheduler.isDue(record: $0, asOf: asOf) }
    }

    public func isFavourite(userId: String, signId: String) async throws -> Bool {
        let all = try await fetchFavourites(userId: userId)
        return all.contains { $0.signId == signId }
    }

    @discardableResult
    public func toggleFavourite(userId: String, signId: String) async throws -> Bool {
        let current = try await isFavourite(userId: userId, signId: signId)
        if current {
            try await removeFavourite(userId: userId, signId: signId)
            return false
        } else {
            try await addFavourite(userId: userId, signId: signId)
            return true
        }
    }

    public func addFavourite(userId: String, signId: String) async throws {
        let record = FavouriteRecord(signId: signId)
        lock.lock()
        var dict = localCache[userId] ?? [:]
        dict[signId] = record
        localCache[userId] = dict
        lock.unlock()

        if let db {
            try db.collection("users")
                .document(userId)
                .collection("favourites")
                .document(signId)
                .setData(from: record)
        }
    }

    public func removeFavourite(userId: String, signId: String) async throws {
        lock.lock()
        var dict = localCache[userId] ?? [:]
        dict.removeValue(forKey: signId)
        localCache[userId] = dict
        lock.unlock()

        if let db {
            try await db.collection("users")
                .document(userId)
                .collection("favourites")
                .document(signId)
                .delete()
        }
    }

    public func updateSpacedRepetition(userId: String, record: FavouriteRecord) async throws {
        lock.lock()
        var dict = localCache[userId] ?? [:]
        dict[record.signId] = record
        localCache[userId] = dict
        lock.unlock()

        if let db {
            try db.collection("users")
                .document(userId)
                .collection("favourites")
                .document(record.signId)
                .setData(from: record, merge: true)
        }
    }

    @discardableResult
    public func recordPracticeResult(
        userId: String,
        signId: String,
        quality: Int,
        reviewDate: Date = Date()
    ) async throws -> FavouriteRecord {
        let all = try await fetchFavourites(userId: userId)
        let current = all.first(where: { $0.signId == signId }) ?? FavouriteRecord(signId: signId, savedAt: reviewDate)
        let updated = SpacedRepetitionScheduler.evaluate(current: current, quality: quality, reviewDate: reviewDate)
        try await updateSpacedRepetition(userId: userId, record: updated)
        return updated
    }
}
#endif
