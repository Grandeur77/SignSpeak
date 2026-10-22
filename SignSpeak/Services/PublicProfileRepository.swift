import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Public profile document stored in `publicProfiles/{uid}`, accessible to all signed-in users.
public struct PublicProfile: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var displayName: String
    public var role: String
    public var level: Int
    public var currentStreak: Int
    public var avatarUpdatedAt: Date?
    public var followerCount: Int
    public var followingCount: Int

    public init(
        id: String,
        displayName: String,
        role: String = "learner",
        level: Int = 1,
        currentStreak: Int = 0,
        avatarUpdatedAt: Date? = nil,
        followerCount: Int = 0,
        followingCount: Int = 0
    ) {
        self.id = id
        self.displayName = displayName
        self.role = role
        self.level = level
        self.currentStreak = currentStreak
        self.avatarUpdatedAt = avatarUpdatedAt
        self.followerCount = followerCount
        self.followingCount = followingCount
    }
}

/// Protocol abstracting public user profile persistence.
public protocol PublicProfileRepository: Sendable {
    func fetchPublicProfile(userId: String) async throws -> PublicProfile?
    func savePublicProfile(_ profile: PublicProfile) async throws
    func syncFromPrivateProfile(_ profile: UserProfile) async throws
}

#if canImport(FirebaseFirestore)
/// Concrete implementation of `PublicProfileRepository` backed by Cloud Firestore.
public final class FirestorePublicProfileRepository: PublicProfileRepository, @unchecked Sendable {
    private let db: Firestore
    private let collectionName = "publicProfiles"

    public init(firestore: Firestore? = nil) {
        self.db = firestore ?? Firestore.firestore()
    }

    public func fetchPublicProfile(userId: String) async throws -> PublicProfile? {
        let doc = try await db.collection(collectionName).document(userId).getDocument()
        guard doc.exists else { return nil }
        return try doc.data(as: PublicProfile.self)
    }

    public func savePublicProfile(_ profile: PublicProfile) async throws {
        try db.collection(collectionName).document(profile.id).setData(from: profile, merge: true)
    }

    public func syncFromPrivateProfile(_ profile: UserProfile) async throws {
        let existing = try? await fetchPublicProfile(userId: profile.id)
        let publicProfile = PublicProfile(
            id: profile.id,
            displayName: profile.displayName,
            role: profile.role,
            level: profile.level,
            currentStreak: profile.currentStreak,
            avatarUpdatedAt: existing?.avatarUpdatedAt,
            followerCount: existing?.followerCount ?? 0,
            followingCount: existing?.followingCount ?? 0
        )
        try await savePublicProfile(publicProfile)
    }
}
#endif

/// In-memory repository stub for previews and unit tests.
public final class StubPublicProfileRepository: PublicProfileRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var profiles: [String: PublicProfile] = [:]

    public init(initialProfiles: [PublicProfile] = []) {
        for profile in initialProfiles {
            profiles[profile.id] = profile
        }
    }

    public func fetchPublicProfile(userId: String) async throws -> PublicProfile? {
        lock.lock()
        defer { lock.unlock() }
        return profiles[userId]
    }

    public func savePublicProfile(_ profile: PublicProfile) async throws {
        lock.lock()
        defer { lock.unlock() }
        profiles[profile.id] = profile
    }

    public func syncFromPrivateProfile(_ profile: UserProfile) async throws {
        lock.lock()
        defer { lock.unlock() }
        let existing = profiles[profile.id]
        let publicProfile = PublicProfile(
            id: profile.id,
            displayName: profile.displayName,
            role: profile.role,
            level: profile.level,
            currentStreak: profile.currentStreak,
            avatarUpdatedAt: existing?.avatarUpdatedAt,
            followerCount: existing?.followerCount ?? 0,
            followingCount: existing?.followingCount ?? 0
        )
        profiles[profile.id] = publicProfile
    }
}
