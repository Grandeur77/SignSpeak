import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Practice reminder configuration for daily notifications.
public struct ReminderSettings: Codable, Sendable, Equatable {
    public var enabled: Bool
    public var practiceTime: String // "19:00"
    public var activeDays: [Int] // 1...7 (e.g. 1 = Monday / Sunday)

    public init(
        enabled: Bool = true,
        practiceTime: String = "19:00",
        activeDays: [Int] = [1, 2, 3, 4, 5, 6, 7]
    ) {
        self.enabled = enabled
        self.practiceTime = practiceTime
        self.activeDays = activeDays
    }
}

/// Private user profile document stored in `users/{uid}`.
public struct UserProfile: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var displayName: String
    public var email: String?
    public var role: String // "learner", "deaf", "family", "work", "educator", "curious"
    public var dailyGoalMinutes: Int
    public var dominantHand: String // "right" | "left"
    public var xp: Int
    public var level: Int
    public var currentStreak: Int
    public var longestStreak: Int
    public var lastPracticeDay: String? // "yyyy-MM-dd"
    public var streakFreezes: Int
    public var onboardingComplete: Bool
    public var reminderSettings: ReminderSettings?
    public var soundAlertsEnabled: Bool?
    public var createdAt: Date

    public init(
        id: String,
        displayName: String,
        email: String? = nil,
        role: String = "learner",
        dailyGoalMinutes: Int = 10,
        dominantHand: String = "right",
        currentStreak: Int = 0,
        xp: Int = 0,
        level: Int = 1,
        longestStreak: Int = 0,
        lastPracticeDay: String? = nil,
        streakFreezes: Int = 0,
        onboardingComplete: Bool = false,
        reminderSettings: ReminderSettings? = nil,
        soundAlertsEnabled: Bool? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.role = role
        self.dailyGoalMinutes = dailyGoalMinutes
        self.dominantHand = dominantHand
        self.xp = xp
        self.level = level
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastPracticeDay = lastPracticeDay
        self.streakFreezes = streakFreezes
        self.onboardingComplete = onboardingComplete
        self.reminderSettings = reminderSettings
        self.soundAlertsEnabled = soundAlertsEnabled
        self.createdAt = createdAt
    }
}

/// Protocol abstracting private user profile persistence.
public protocol UserProfileRepository: Sendable {
    func fetchProfile(userId: String) async throws -> UserProfile?
    func saveProfile(_ profile: UserProfile) async throws
    func updateStreak(userId: String, streak: Int) async throws
    @discardableResult
    func createProfileIfNeeded(userId: String, displayName: String, email: String?) async throws -> UserProfile
}

#if canImport(FirebaseFirestore)
/// Concrete implementation of `UserProfileRepository` backed by Cloud Firestore.
public final class FirestoreProfileRepository: UserProfileRepository, @unchecked Sendable {
    private let db: Firestore
    private let collectionName = "users"

    public init(firestore: Firestore? = nil) {
        self.db = firestore ?? Firestore.firestore()
    }

    public func fetchProfile(userId: String) async throws -> UserProfile? {
        let doc = try await db.collection(collectionName).document(userId).getDocument()
        guard doc.exists else { return nil }
        return try doc.data(as: UserProfile.self)
    }

    public func saveProfile(_ profile: UserProfile) async throws {
        try db.collection(collectionName).document(profile.id).setData(from: profile, merge: true)
    }

    public func updateStreak(userId: String, streak: Int) async throws {
        try await db.collection(collectionName).document(userId).updateData([
            "currentStreak": streak
        ])
    }

    @discardableResult
    public func createProfileIfNeeded(userId: String, displayName: String, email: String?) async throws -> UserProfile {
        if let existing = try await fetchProfile(userId: userId) {
            return existing
        }
        let cleanName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let newProfile = UserProfile(
            id: userId,
            displayName: cleanName.isEmpty ? "Learner" : cleanName,
            email: email
        )
        try await saveProfile(newProfile)
        return newProfile
    }
}
#endif

/// In-memory repository stub for previews and unit tests.
public final class StubUserProfileRepository: UserProfileRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var profiles: [String: UserProfile] = [:]

    public init(initialProfiles: [UserProfile] = []) {
        for profile in initialProfiles {
            profiles[profile.id] = profile
        }
    }

    public func fetchProfile(userId: String) async throws -> UserProfile? {
        lock.lock()
        defer { lock.unlock() }
        return profiles[userId]
    }

    public func saveProfile(_ profile: UserProfile) async throws {
        lock.lock()
        defer { lock.unlock() }
        profiles[profile.id] = profile
    }

    public func updateStreak(userId: String, streak: Int) async throws {
        lock.lock()
        defer { lock.unlock() }
        profiles[userId]?.currentStreak = streak
    }

    @discardableResult
    public func createProfileIfNeeded(userId: String, displayName: String, email: String?) async throws -> UserProfile {
        lock.lock()
        defer { lock.unlock() }
        if let existing = profiles[userId] {
            return existing
        }
        let cleanName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let newProfile = UserProfile(
            id: userId,
            displayName: cleanName.isEmpty ? "Learner" : cleanName,
            email: email
        )
        profiles[userId] = newProfile
        return newProfile
    }
}
