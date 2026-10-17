import Foundation

/// User account profile information stored in Firestore.
public struct UserProfile: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var displayName: String
    public var email: String?
    public var role: String
    public var dailyGoalMinutes: Int
    public var currentStreak: Int
    public var xp: Int
    public var level: Int

    public init(
        id: String,
        displayName: String,
        email: String? = nil,
        role: String = "learner",
        dailyGoalMinutes: Int = 10,
        currentStreak: Int = 0,
        xp: Int = 0,
        level: Int = 1
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.role = role
        self.dailyGoalMinutes = dailyGoalMinutes
        self.currentStreak = currentStreak
        self.xp = xp
        self.level = level
    }
}

/// Protocol abstracting user profile persistence.
public protocol UserProfileRepository: Sendable {
    func fetchProfile(userId: String) async throws -> UserProfile?
    func saveProfile(_ profile: UserProfile) async throws
    func updateStreak(userId: String, streak: Int) async throws
}

/// In-memory repository stub for previews and unit tests.
public final class StubUserProfileRepository: UserProfileRepository, @unchecked Sendable {
    private var profiles: [String: UserProfile] = [:]

    public init(initialProfiles: [UserProfile] = []) {
        for profile in initialProfiles {
            profiles[profile.id] = profile
        }
    }

    public func fetchProfile(userId: String) async throws -> UserProfile? {
        profiles[userId] ?? UserProfile(id: userId, displayName: "Guest Learner")
    }

    public func saveProfile(_ profile: UserProfile) async throws {
        profiles[profile.id] = profile
    }

    public func updateStreak(userId: String, streak: Int) async throws {
        profiles[userId]?.currentStreak = streak
    }
}
