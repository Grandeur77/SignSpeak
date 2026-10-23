import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Protocol managing persistent storage and retrieval of quick phrases (`39c-quick-phrases`, `39b-communicator-full-screen-text`).
public protocol QuickPhraseRepository: Sendable {
    /// Fetches all quick phrases for a given user, including system defaults.
    func fetchPhrases(userId: String) async throws -> [QuickPhrase]

    /// Saves a newly created phrase.
    func addPhrase(_ phrase: QuickPhrase) async throws

    /// Updates an existing phrase.
    func updatePhrase(_ phrase: QuickPhrase) async throws

    /// Deletes a phrase by ID.
    func deletePhrase(id: String, userId: String) async throws

    /// Increments the play count of a phrase and returns the new count.
    @discardableResult
    func incrementPlayCount(id: String, userId: String) async throws -> Int
}

// MARK: - In-Memory / Test Stub Implementation

/// Thread-safe in-memory quick phrase repository for unit tests and offline previews.
public final class StubQuickPhraseRepository: QuickPhraseRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var phrasesByUser: [String: [QuickPhrase]] = [:]

    public init(initialPhrases: [String: [QuickPhrase]] = [:]) {
        self.phrasesByUser = initialPhrases
    }

    private func sortedPhrases(_ list: [QuickPhrase]) -> [QuickPhrase] {
        list.sorted { lhs, rhs in
            if lhs.isEmergency != rhs.isEmergency { return lhs.isEmergency && !rhs.isEmergency }
            if lhs.isKeyCard != rhs.isKeyCard { return lhs.isKeyCard && !rhs.isKeyCard }
            return lhs.playCount > rhs.playCount
        }
    }

    public func fetchPhrases(userId: String) async throws -> [QuickPhrase] {
        lock.lock()
        defer { lock.unlock() }

        if let existing = phrasesByUser[userId], !existing.isEmpty {
            return sortedPhrases(existing)
        }

        // Default seeding
        let defaults = QuickPhrase.defaults.map { phrase in
            var copy = phrase
            copy.userId = userId
            return copy
        }
        phrasesByUser[userId] = defaults
        return sortedPhrases(defaults)
    }

    public func addPhrase(_ phrase: QuickPhrase) async throws {
        lock.lock()
        defer { lock.unlock() }

        var list = phrasesByUser[phrase.userId] ?? QuickPhrase.defaults.map {
            var copy = $0; copy.userId = phrase.userId; return copy
        }
        // If updating key card status, clear existing key cards
        if phrase.isKeyCard {
            for i in 0..<list.count {
                list[i].isKeyCard = false
            }
        }
        list.append(phrase)
        phrasesByUser[phrase.userId] = list
    }

    public func updatePhrase(_ phrase: QuickPhrase) async throws {
        lock.lock()
        defer { lock.unlock() }

        var list = phrasesByUser[phrase.userId] ?? QuickPhrase.defaults.map {
            var copy = $0; copy.userId = phrase.userId; return copy
        }
        if let idx = list.firstIndex(where: { $0.id == phrase.id }) {
            if phrase.isKeyCard {
                for i in 0..<list.count {
                    list[i].isKeyCard = false
                }
            }
            list[idx] = phrase
            phrasesByUser[phrase.userId] = list
        }
    }

    public func deletePhrase(id: String, userId: String) async throws {
        lock.lock()
        defer { lock.unlock() }

        var list = phrasesByUser[userId] ?? QuickPhrase.defaults.map {
            var copy = $0; copy.userId = userId; return copy
        }
        list.removeAll { $0.id == id }
        phrasesByUser[userId] = list
    }

    @discardableResult
    public func incrementPlayCount(id: String, userId: String) async throws -> Int {
        lock.lock()
        defer { lock.unlock() }

        var list = phrasesByUser[userId] ?? QuickPhrase.defaults.map {
            var copy = $0; copy.userId = userId; return copy
        }
        if let idx = list.firstIndex(where: { $0.id == id }) {
            list[idx].playCount += 1
            list[idx].updatedAt = Date()
            let newCount = list[idx].playCount
            phrasesByUser[userId] = list
            return newCount
        }
        return 0
    }
}

// MARK: - Firestore Concrete Implementation

#if canImport(FirebaseFirestore)
/// Firestore-backed quick phrase repository storing user custom phrases and overrides in `users/{uid}/quickPhrases/{phraseId}`.
public final class FirestoreQuickPhraseRepository: QuickPhraseRepository, @unchecked Sendable {
    private let customFirestore: Firestore?
    private let fallbackStub = StubQuickPhraseRepository()

    private var db: Firestore? {
        if let customFirestore { return customFirestore }
        #if canImport(FirebaseCore)
        guard FirebaseApp.app() != nil else { return nil }
        return Firestore.firestore()
        #else
        return nil
        #endif
    }

    public init(firestore: Firestore? = nil) {
        self.customFirestore = firestore
    }

    public func fetchPhrases(userId: String) async throws -> [QuickPhrase] {
        guard let db else {
            return try await fallbackStub.fetchPhrases(userId: userId)
        }

        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("quickPhrases")
                .getDocuments()

            let remotePhrases = snapshot.documents.compactMap { doc -> QuickPhrase? in
                try? doc.data(as: QuickPhrase.self)
            }

            if remotePhrases.isEmpty {
                // First-time seeding into Firestore
                let defaults = QuickPhrase.defaults.map { phrase -> QuickPhrase in
                    var copy = phrase
                    copy.userId = userId
                    return copy
                }
                for phrase in defaults {
                    try? db.collection("users")
                        .document(userId)
                        .collection("quickPhrases")
                        .document(phrase.id)
                        .setData(from: phrase)
                }
                return defaults
            }

            return remotePhrases.sorted { lhs, rhs in
                if lhs.isEmergency != rhs.isEmergency { return lhs.isEmergency && !rhs.isEmergency }
                if lhs.isKeyCard != rhs.isKeyCard { return lhs.isKeyCard && !rhs.isKeyCard }
                return lhs.playCount > rhs.playCount
            }
        } catch {
            return try await fallbackStub.fetchPhrases(userId: userId)
        }
    }

    public func addPhrase(_ phrase: QuickPhrase) async throws {
        guard let db else {
            try await fallbackStub.addPhrase(phrase)
            return
        }

        try db.collection("users")
            .document(phrase.userId)
            .collection("quickPhrases")
            .document(phrase.id)
            .setData(from: phrase)
    }

    public func updatePhrase(_ phrase: QuickPhrase) async throws {
        guard let db else {
            try await fallbackStub.updatePhrase(phrase)
            return
        }

        try db.collection("users")
            .document(phrase.userId)
            .collection("quickPhrases")
            .document(phrase.id)
            .setData(from: phrase, merge: true)
    }

    public func deletePhrase(id: String, userId: String) async throws {
        guard let db else {
            try await fallbackStub.deletePhrase(id: id, userId: userId)
            return
        }

        try await db.collection("users")
            .document(userId)
            .collection("quickPhrases")
            .document(id)
            .delete()
    }

    @discardableResult
    public func incrementPlayCount(id: String, userId: String) async throws -> Int {
        guard let db else {
            return try await fallbackStub.incrementPlayCount(id: id, userId: userId)
        }

        let docRef = db.collection("users")
            .document(userId)
            .collection("quickPhrases")
            .document(id)

        try await docRef.updateData([
            "playCount": FieldValue.increment(Int64(1)),
            "updatedAt": Timestamp(date: Date())
        ])

        let doc = try await docRef.getDocument()
        return (doc.data()?["playCount"] as? Int) ?? 1
    }
}
#else
/// Fallback for targets without FirebaseFirestore
public typealias FirestoreQuickPhraseRepository = StubQuickPhraseRepository
#endif
