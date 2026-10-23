import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Stored user favourite / bookmark record in `users/{uid}/favourites/{signId}`.
public struct FavouriteRecord: Identifiable, Codable, Sendable, Equatable {
    public var id: String { signId }
    public let signId: String
    public let savedAt: Date
    public var intervalDays: Int // Spaced repetition interval
    public var easeFactor: Double
    public var repetitions: Int
    public var nextDueDate: Date

    public init(
        signId: String,
        savedAt: Date = Date(),
        intervalDays: Int = 1,
        easeFactor: Double = 2.5,
        repetitions: Int = 0,
        nextDueDate: Date = Date()
    ) {
        self.signId = signId
        self.savedAt = savedAt
        self.intervalDays = intervalDays
        self.easeFactor = easeFactor
        self.repetitions = repetitions
        self.nextDueDate = nextDueDate
    }
}

/// Protocol abstracting user bookmark and favourite sign management.
public protocol FavouritesRepository: Sendable {
    func fetchFavourites(userId: String) async throws -> [FavouriteRecord]
    func isFavourite(userId: String, signId: String) async throws -> Bool
    @discardableResult
    func toggleFavourite(userId: String, signId: String) async throws -> Bool
    func addFavourite(userId: String, signId: String) async throws
    func removeFavourite(userId: String, signId: String) async throws
    func updateSpacedRepetition(userId: String, record: FavouriteRecord) async throws
}

/// In-memory stub for favourites management in tests and previews.
public final class StubFavouritesRepository: FavouritesRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var store: [String: [String: FavouriteRecord]] = [:]

    public init(initialStore: [String: [String: FavouriteRecord]]? = nil) {
        if let initialStore {
            self.store = initialStore
        } else {
            // Seed sample bookmarks for preview user
            self.store = [
                "preview-user-123": [
                    "sign-word-hello": FavouriteRecord(signId: "sign-word-hello"),
                    "sign-letter-a": FavouriteRecord(signId: "sign-letter-a")
                ],
                "default": [
                    "sign-word-hello": FavouriteRecord(signId: "sign-word-hello")
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
                // Offline fallback
            }
        }

        lock.lock()
        defer { lock.unlock() }
        return Array((localCache[userId] ?? [:]).values)
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
}
#endif
