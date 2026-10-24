#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Practice reminder configuration for daily and smart notifications.
public struct ReminderSettings: Codable, Sendable, Equatable {
    public var enabled: Bool
    public var practiceTime: String // "19:00"
    public var activeDays: [Int] // 1...7 (1 = Sunday, 2 = Monday, ..., 7 = Saturday)
    public var eveningEnabled: Bool
    public var eveningTime: String // "20:30"
    public var streakAlertsEnabled: Bool
    public var communityReactionsEnabled: Bool
    public var newLessonsEnabled: Bool
    public var weeklyReportEnabled: Bool

    public init(
        enabled: Bool = true,
        practiceTime: String = "19:00",
        activeDays: [Int] = [1, 2, 3, 4, 5, 6, 7],
        eveningEnabled: Bool = true,
        eveningTime: String = "20:30",
        streakAlertsEnabled: Bool = true,
        communityReactionsEnabled: Bool = true,
        newLessonsEnabled: Bool = true,
        weeklyReportEnabled: Bool = true
    ) {
        self.enabled = enabled
        self.practiceTime = practiceTime
        self.activeDays = activeDays
        self.eveningEnabled = eveningEnabled
        self.eveningTime = eveningTime
        self.streakAlertsEnabled = streakAlertsEnabled
        self.communityReactionsEnabled = communityReactionsEnabled
        self.newLessonsEnabled = newLessonsEnabled
        self.weeklyReportEnabled = weeklyReportEnabled
    }

    enum CodingKeys: String, CodingKey {
        case enabled, practiceTime, activeDays, eveningEnabled, eveningTime
        case streakAlertsEnabled, communityReactionsEnabled, newLessonsEnabled, weeklyReportEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        self.practiceTime = try container.decodeIfPresent(String.self, forKey: .practiceTime) ?? "19:00"
        self.activeDays = try container.decodeIfPresent([Int].self, forKey: .activeDays) ?? [1, 2, 3, 4, 5, 6, 7]
        self.eveningEnabled = try container.decodeIfPresent(Bool.self, forKey: .eveningEnabled) ?? true
        self.eveningTime = try container.decodeIfPresent(String.self, forKey: .eveningTime) ?? "20:30"
        self.streakAlertsEnabled = try container.decodeIfPresent(Bool.self, forKey: .streakAlertsEnabled) ?? true
        self.communityReactionsEnabled = try container.decodeIfPresent(Bool.self, forKey: .communityReactionsEnabled) ?? true
        self.newLessonsEnabled = try container.decodeIfPresent(Bool.self, forKey: .newLessonsEnabled) ?? true
        self.weeklyReportEnabled = try container.decodeIfPresent(Bool.self, forKey: .weeklyReportEnabled) ?? true
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
    func deleteProfile(userId: String) async throws
}

public extension UserProfileRepository {
    func deleteProfile(userId: String) async throws {}
}

#if canImport(FirebaseFirestore)
/// Concrete implementation of `UserProfileRepository` backed by Cloud Firestore.
public final class FirestoreProfileRepository: UserProfileRepository, @unchecked Sendable {
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
    private let collectionName = "users"

    public init(firestore: Firestore? = nil) {
        self.customFirestore = firestore
    }

    public func fetchProfile(userId: String) async throws -> UserProfile? {
        guard let db else { return nil }
        let doc = try await db.collection(collectionName).document(userId).getDocument()
        guard doc.exists else { return nil }
        return try doc.data(as: UserProfile.self)
    }

    public func saveProfile(_ profile: UserProfile) async throws {
        guard let db else { return }
        try db.collection(collectionName).document(profile.id).setData(from: profile, merge: true)
    }

    public func updateStreak(userId: String, streak: Int) async throws {
        guard let db else { return }
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

    public func deleteProfile(userId: String) async throws {
        lock.lock()
        defer { lock.unlock() }
        profiles.removeValue(forKey: userId)
    }
}
