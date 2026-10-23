import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Protocol abstracting user-submitted sign requests persistence.
public protocol SignRequestRepository: Sendable {
    func submitRequest(_ request: SignRequest) async throws
    func fetchMyRequests(userId: String) async throws -> [SignRequest]
}

/// In-memory sign requests stub for tests and previews.
public final class StubSignRequestRepository: SignRequestRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [SignRequest] = []

    public init(initialRequests: [SignRequest] = []) {
        self.requests = initialRequests
    }

    public func submitRequest(_ request: SignRequest) async throws {
        lock.lock()
        defer { lock.unlock() }
        requests.append(request)
    }

    public func fetchMyRequests(userId: String) async throws -> [SignRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests.filter { $0.requesterId == userId }
    }
}

#if canImport(FirebaseFirestore)
/// Concrete implementation of `SignRequestRepository` backed by Cloud Firestore `signRequests/{id}`.
public final class FirestoreSignRequestRepository: SignRequestRepository, @unchecked Sendable {
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
    private var localCache: [SignRequest] = []

    public init(firestore: Firestore? = nil) {
        self.customFirestore = firestore
    }

    public func submitRequest(_ request: SignRequest) async throws {
        lock.lock()
        localCache.append(request)
        lock.unlock()

        if let db {
            try db.collection("signRequests").document(request.id).setData(from: request)
        }
    }

    public func fetchMyRequests(userId: String) async throws -> [SignRequest] {
        if let db {
            do {
                let snapshot = try await db.collection("signRequests")
                    .whereField("requesterId", isEqualTo: userId)
                    .getDocuments()
                let fetched = snapshot.documents.compactMap { try? $0.data(as: SignRequest.self) }
                lock.lock()
                localCache = fetched
                lock.unlock()
                return fetched
            } catch {
                // Offline fallback to local cache
            }
        }

        lock.lock()
        defer { lock.unlock() }
        return localCache.filter { $0.requesterId == userId }
    }
}
#endif
