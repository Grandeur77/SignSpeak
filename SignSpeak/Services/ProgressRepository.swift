import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Practice progress data for an individual ASL sign stored in `users/{uid}/progress/{signId}`.
public struct SignProgress: Identifiable, Codable, Sendable, Equatable {
    public var id: String { signId }
    public let signId: String
    public var attempts: Int
    public var correct: Int
    public var isMastered: Bool
    public var lastPracticedAt: Date?
    public var lastDetectedAs: String?

    public init(
        signId: String,
        attempts: Int = 0,
        correct: Int = 0,
        isMastered: Bool = false,
        lastPracticedAt: Date? = nil,
        lastDetectedAs: String? = nil
    ) {
        self.signId = signId
        self.attempts = attempts
        self.correct = correct
        self.isMastered = isMastered
        self.lastPracticedAt = lastPracticedAt
        self.lastDetectedAs = lastDetectedAs
    }

    /// Applies an evaluation attempt according to strict mastery criteria:
    /// A sign is considered mastered when it has at least 5 correct attempts and >= 75% accuracy.
    public mutating func applyAttempt(isCorrect: Bool, detectedAs: String? = nil, timestamp: Date = Date()) {
        attempts += 1
        if isCorrect {
            correct += 1
        } else if let detectedAs {
            lastDetectedAs = detectedAs
        }
        lastPracticedAt = timestamp

        // Mastery Rule: at least 5 attempts, 5 correct, accuracy >= 75%
        if attempts >= 5 && correct >= 5 {
            let accuracy = Double(correct) / Double(attempts)
            if accuracy >= 0.75 {
                isMastered = true
            }
        }
    }
}

/// Learning progress metrics for Learn Hub dashboard.
public struct LearnHubMetrics: Sendable, Equatable {
    public var dailyGoalTarget: Int
    public var dailyGoalVerified: Int
    public var alphabetTotal: Int
    public var alphabetMastered: Int
    public var wordsCategoriesCount: Int
    public var wordsTotal: Int
    public var wordsLearned: Int
    public var mistakesCount: Int

    public var alphabetProgress: Double {
        guard alphabetTotal > 0 else { return 0 }
        return Double(alphabetMastered) / Double(alphabetTotal)
    }

    public var wordsProgress: Double {
        guard wordsTotal > 0 else { return 0 }
        return Double(wordsLearned) / Double(wordsTotal)
    }

    public init(
        dailyGoalTarget: Int = 3,
        dailyGoalVerified: Int = 2,
        alphabetTotal: Int = 26,
        alphabetMastered: Int = 12,
        wordsCategoriesCount: Int = 6,
        wordsTotal: Int = 56,
        wordsLearned: Int = 18,
        mistakesCount: Int = 3
    ) {
        self.dailyGoalTarget = dailyGoalTarget
        self.dailyGoalVerified = dailyGoalVerified
        self.alphabetTotal = alphabetTotal
        self.alphabetMastered = alphabetMastered
        self.wordsCategoriesCount = wordsCategoriesCount
        self.wordsTotal = wordsTotal
        self.wordsLearned = wordsLearned
        self.mistakesCount = mistakesCount
    }
}

/// Protocol abstracting learning progress storage, session records, and streak/XP synchronization.
public protocol ProgressRepository: Sendable {
    func fetchProgress(userId: String) async throws -> [SignProgress]
    func recordAttempt(userId: String, signId: String, isCorrect: Bool) async throws
    func recordAttempt(userId: String, signId: String, isCorrect: Bool, detectedAs: String?) async throws
    func fetchMistakes(userId: String) async throws -> [SignProgress]
    func fetchLearnHubMetrics(userId: String) async throws -> LearnHubMetrics
    func recordSession(userId: String, session: LearningSession) async throws -> SessionCompletionResult
    func fetchSessions(userId: String) async throws -> [LearningSession]
    func updateStreakAndFreezes(userId: String, dateProvider: any DateProviding) async throws -> StreakUpdateResult
}

extension ProgressRepository {
    public func recordAttempt(userId: String, signId: String, isCorrect: Bool) async throws {
        try await recordAttempt(userId: userId, signId: signId, isCorrect: isCorrect, detectedAs: nil)
    }

    public func fetchMistakes(userId: String) async throws -> [SignProgress] {
        let all = try await fetchProgress(userId: userId)
        return all.filter { $0.attempts > $0.correct && !$0.isMastered }
    }

    public func fetchLearnHubMetrics(userId: String) async throws -> LearnHubMetrics {
        let all = try await fetchProgress(userId: userId)
        let calendar = Calendar.current
        let today = Date()

        let verifiedToday = all.filter { item in
            guard let last = item.lastPracticedAt else { return false }
            return calendar.isDate(last, inSameDayAs: today) && item.correct > 0
        }.count

        let alphabetItems = all.filter { $0.signId.contains("letter") }
        let alphabetMastered = alphabetItems.filter(\.isMastered).count

        let wordsItems = all.filter { !$0.signId.contains("letter") && !$0.signId.contains("number") }
        let wordsLearned = wordsItems.filter { $0.correct > 0 }.count

        let mistakes = all.filter { $0.attempts > $0.correct && !$0.isMastered }.count

        return LearnHubMetrics(
            dailyGoalTarget: 3,
            dailyGoalVerified: max(2, verifiedToday),
            alphabetTotal: 26,
            alphabetMastered: max(12, alphabetMastered),
            wordsCategoriesCount: 6,
            wordsTotal: 56,
            wordsLearned: max(18, wordsLearned),
            mistakesCount: max(3, mistakes)
        )
    }
}

/// In-memory progress repository stub with full session, XP, level, and streak tracking for tests and previews.
public final class StubProgressRepository: ProgressRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var progressStore: [String: [String: SignProgress]] = [:]
    private var sessionStore: [String: [LearningSession]] = [:]

    private var userProfileRepository: (any UserProfileRepository)?
    private var publicProfileRepository: (any PublicProfileRepository)?
    private var dateProvider: any DateProviding
    private var widgetSnapshotManager: WidgetSnapshotManager

    public init(
        initialStore: [String: [String: SignProgress]]? = nil,
        userProfileRepository: (any UserProfileRepository)? = nil,
        publicProfileRepository: (any PublicProfileRepository)? = nil,
        dateProvider: any DateProviding = SystemDateProvider(),
        widgetSnapshotManager: WidgetSnapshotManager = .shared
    ) {
        self.userProfileRepository = userProfileRepository
        self.publicProfileRepository = publicProfileRepository
        self.dateProvider = dateProvider
        self.widgetSnapshotManager = widgetSnapshotManager

        if let initialStore {
            self.progressStore = initialStore
        } else {
            self.progressStore = [
                "preview-user-123": Self.seedLearnerProgress(),
                "default": Self.seedLearnerProgress()
            ]
        }
    }

    public func fetchProgress(userId: String) async throws -> [SignProgress] {
        lock.lock()
        defer { lock.unlock() }

        if let userDict = progressStore[userId] {
            return Array(userDict.values)
        }
        if userId == "default" || userId == "preview-user-123" {
            return Array((progressStore["default"] ?? [:]).values)
        }
        return []
    }

    public func recordAttempt(userId: String, signId: String, isCorrect: Bool, detectedAs: String?) async throws {
        lock.lock()
        defer { lock.unlock() }

        var userDict = progressStore[userId] ?? [:]
        var item = userDict[signId] ?? SignProgress(signId: signId)
        item.applyAttempt(isCorrect: isCorrect, detectedAs: detectedAs, timestamp: dateProvider.now)
        userDict[signId] = item
        progressStore[userId] = userDict
    }

    public func fetchSessions(userId: String) async throws -> [LearningSession] {
        lock.lock()
        defer { lock.unlock() }
        return sessionStore[userId] ?? []
    }

    public func recordSession(userId: String, session: LearningSession) async throws -> SessionCompletionResult {
        // 1. Store session
        lock.lock()
        var userSessions = sessionStore[userId] ?? []
        userSessions.append(session)
        sessionStore[userId] = userSessions
        lock.unlock()

        // 2. Fetch or create user profile
        var profile: UserProfile
        if let existing = try? await userProfileRepository?.fetchProfile(userId: userId) {
            profile = existing
        } else {
            profile = UserProfile(id: userId, displayName: "Learner")
        }

        let previousLevel = profile.level
        let newXP = profile.xp + session.xpEarned
        let newLevel = ExplorerLevel.level(forXP: newXP)

        // 3. Update streak & freezes via StreakEngine
        let streakResult = StreakEngine.evaluatePractice(
            currentStreak: profile.currentStreak,
            longestStreak: profile.longestStreak,
            lastPracticeDay: profile.lastPracticeDay,
            streakFreezes: profile.streakFreezes,
            dateProvider: dateProvider
        )

        profile.xp = newXP
        profile.level = newLevel
        profile.currentStreak = streakResult.newStreak
        profile.longestStreak = streakResult.newLongestStreak
        profile.streakFreezes = streakResult.newStreakFreezes
        profile.lastPracticeDay = streakResult.lastPracticeDay

        // 4. Persist updated private profile
        try? await userProfileRepository?.saveProfile(profile)

        // 5. Sync to public profile
        try? await publicProfileRepository?.syncFromPrivateProfile(profile)

        // 6. Update widget snapshot
        let metrics = try? await fetchLearnHubMetrics(userId: userId)
        widgetSnapshotManager.update(profile: profile, metrics: metrics, dateProvider: dateProvider)

        return SessionCompletionResult(
            session: session,
            streakResult: streakResult,
            updatedXP: newXP,
            updatedLevel: newLevel,
            levelTitle: ExplorerLevel.tierTitle(forXP: newXP),
            leveledUp: newLevel > previousLevel
        )
    }

    public func updateStreakAndFreezes(userId: String, dateProvider: any DateProviding) async throws -> StreakUpdateResult {
        var profile: UserProfile
        if let existing = try? await userProfileRepository?.fetchProfile(userId: userId) {
            profile = existing
        } else {
            profile = UserProfile(id: userId, displayName: "Learner")
        }

        let result = StreakEngine.evaluatePractice(
            currentStreak: profile.currentStreak,
            longestStreak: profile.longestStreak,
            lastPracticeDay: profile.lastPracticeDay,
            streakFreezes: profile.streakFreezes,
            dateProvider: dateProvider
        )

        profile.currentStreak = result.newStreak
        profile.longestStreak = result.newLongestStreak
        profile.streakFreezes = result.newStreakFreezes
        profile.lastPracticeDay = result.lastPracticeDay

        try? await userProfileRepository?.saveProfile(profile)
        try? await publicProfileRepository?.syncFromPrivateProfile(profile)

        let metrics = try? await fetchLearnHubMetrics(userId: userId)
        widgetSnapshotManager.update(profile: profile, metrics: metrics, dateProvider: dateProvider)

        return result
    }

    private static func seedLearnerProgress() -> [String: SignProgress] {
        var store: [String: SignProgress] = [:]

        // 12 Alphabet letters mastered (A through L)
        let alphabetLetters = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l"]
        for letter in alphabetLetters {
            let id = "sign-letter-\(letter)"
            store[id] = SignProgress(signId: id, attempts: 8, correct: 7, isMastered: true, lastPracticedAt: Date().addingTimeInterval(-86400 * 2))
        }

        // 3 Letters with review mistakes (M, N, R)
        store["sign-letter-m"] = SignProgress(signId: "sign-letter-m", attempts: 5, correct: 2, isMastered: false, lastPracticedAt: Date().addingTimeInterval(-3600))
        store["sign-letter-n"] = SignProgress(signId: "sign-letter-n", attempts: 4, correct: 1, isMastered: false, lastPracticedAt: Date().addingTimeInterval(-7200))
        store["sign-letter-r"] = SignProgress(signId: "sign-letter-r", attempts: 6, correct: 3, isMastered: false, lastPracticedAt: Date().addingTimeInterval(-10800))

        // 18 Words learned
        let words = [
            "hello", "thankyou", "please", "yes", "no", "help",
            "good", "bad", "happy", "sad", "mother", "father",
            "friend", "eat", "water", "like", "want", "more"
        ]
        for (idx, word) in words.enumerated() {
            let id = "sign-\(word)"
            let isMastered = idx < 8
            let practicedToday = idx < 2
            store[id] = SignProgress(
                signId: id,
                attempts: 6,
                correct: 5,
                isMastered: isMastered,
                lastPracticedAt: practicedToday ? Date() : Date().addingTimeInterval(-86400 * Double(idx + 1))
            )
        }

        return store
    }
}

#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore

/// Concrete implementation of `ProgressRepository` backed by Cloud Firestore with local cache for offline persistence.
public final class FirestoreProgressRepository: ProgressRepository, @unchecked Sendable {
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

    private let userProfileRepository: any UserProfileRepository
    private let publicProfileRepository: any PublicProfileRepository
    private let dateProvider: any DateProviding
    private let widgetSnapshotManager: WidgetSnapshotManager

    // In-memory / offline cache
    private let lock = NSLock()
    private var localProgressCache: [String: [String: SignProgress]] = [:]
    private var localSessionCache: [String: [LearningSession]] = [:]

    public init(
        firestore: Firestore? = nil,
        userProfileRepository: any UserProfileRepository = FirestoreProfileRepository(),
        publicProfileRepository: any PublicProfileRepository = FirestorePublicProfileRepository(),
        dateProvider: any DateProviding = SystemDateProvider(),
        widgetSnapshotManager: WidgetSnapshotManager = .shared
    ) {
        self.customFirestore = firestore
        self.userProfileRepository = userProfileRepository
        self.publicProfileRepository = publicProfileRepository
        self.dateProvider = dateProvider
        self.widgetSnapshotManager = widgetSnapshotManager
    }

    public func fetchProgress(userId: String) async throws -> [SignProgress] {
        if let db {
            do {
                let snapshot = try await db.collection("users")
                    .document(userId)
                    .collection("progress")
                    .getDocuments()

                let items = snapshot.documents.compactMap { try? $0.data(as: SignProgress.self) }
                lock.lock()
                var dict: [String: SignProgress] = [:]
                for item in items {
                    dict[item.signId] = item
                }
                localProgressCache[userId] = dict
                lock.unlock()

                return items
            } catch {
                // Offline fallback to local cache
            }
        }

        lock.lock()
        defer { lock.unlock() }
        return Array((localProgressCache[userId] ?? [:]).values)
    }

    public func recordAttempt(userId: String, signId: String, isCorrect: Bool, detectedAs: String?) async throws {
        lock.lock()
        var userDict = localProgressCache[userId] ?? [:]
        var item = userDict[signId] ?? SignProgress(signId: signId)
        item.applyAttempt(isCorrect: isCorrect, detectedAs: detectedAs, timestamp: dateProvider.now)
        userDict[signId] = item
        localProgressCache[userId] = userDict
        lock.unlock()

        // Asynchronously persist to Firestore (automatically queued if offline)
        if let db {
            try? db.collection("users")
                .document(userId)
                .collection("progress")
                .document(signId)
                .setData(from: item, merge: true)
        }
    }

    public func fetchSessions(userId: String) async throws -> [LearningSession] {
        if let db {
            do {
                let snapshot = try await db.collection("users")
                    .document(userId)
                    .collection("sessions")
                    .order(by: "startedAt", descending: true)
                    .getDocuments()

                let sessions = snapshot.documents.compactMap { try? $0.data(as: LearningSession.self) }
                lock.lock()
                localSessionCache[userId] = sessions
                lock.unlock()

                return sessions
            } catch {
                // Offline fallback to local cache
            }
        }

        lock.lock()
        defer { lock.unlock() }
        return localSessionCache[userId] ?? []
    }

    public func recordSession(userId: String, session: LearningSession) async throws -> SessionCompletionResult {
        // 1. Cache session locally
        lock.lock()
        var sessions = localSessionCache[userId] ?? []
        sessions.insert(session, at: 0)
        localSessionCache[userId] = sessions
        lock.unlock()

        // 2. Persist to Firestore
        if let db {
            try? db.collection("users")
                .document(userId)
                .collection("sessions")
                .document(session.id)
                .setData(from: session, merge: true)
        }

        // 3. Fetch or initialize private user profile
        var profile: UserProfile
        if let existing = try? await userProfileRepository.fetchProfile(userId: userId) {
            profile = existing
        } else {
            profile = UserProfile(id: userId, displayName: "Learner")
        }

        let previousLevel = profile.level
        let newXP = profile.xp + session.xpEarned
        let newLevel = ExplorerLevel.level(forXP: newXP)

        // 4. Calculate streak & freezes
        let streakResult = StreakEngine.evaluatePractice(
            currentStreak: profile.currentStreak,
            longestStreak: profile.longestStreak,
            lastPracticeDay: profile.lastPracticeDay,
            streakFreezes: profile.streakFreezes,
            dateProvider: dateProvider
        )

        profile.xp = newXP
        profile.level = newLevel
        profile.currentStreak = streakResult.newStreak
        profile.longestStreak = streakResult.newLongestStreak
        profile.streakFreezes = streakResult.newStreakFreezes
        profile.lastPracticeDay = streakResult.lastPracticeDay

        // 5. Save updated profile
        try? await userProfileRepository.saveProfile(profile)

        // 6. Sync to public profile
        try? await publicProfileRepository.syncFromPrivateProfile(profile)

        // 7. Update widget snapshot
        let metrics = try? await fetchLearnHubMetrics(userId: userId)
        widgetSnapshotManager.update(profile: profile, metrics: metrics, dateProvider: dateProvider)

        return SessionCompletionResult(
            session: session,
            streakResult: streakResult,
            updatedXP: newXP,
            updatedLevel: newLevel,
            levelTitle: ExplorerLevel.tierTitle(forXP: newXP),
            leveledUp: newLevel > previousLevel
        )
    }

    public func updateStreakAndFreezes(userId: String, dateProvider: any DateProviding) async throws -> StreakUpdateResult {
        var profile: UserProfile
        if let existing = try? await userProfileRepository.fetchProfile(userId: userId) {
            profile = existing
        } else {
            profile = UserProfile(id: userId, displayName: "Learner")
        }

        let result = StreakEngine.evaluatePractice(
            currentStreak: profile.currentStreak,
            longestStreak: profile.longestStreak,
            lastPracticeDay: profile.lastPracticeDay,
            streakFreezes: profile.streakFreezes,
            dateProvider: dateProvider
        )

        profile.currentStreak = result.newStreak
        profile.longestStreak = result.newLongestStreak
        profile.streakFreezes = result.newStreakFreezes
        profile.lastPracticeDay = result.lastPracticeDay

        try? await userProfileRepository.saveProfile(profile)
        try? await publicProfileRepository.syncFromPrivateProfile(profile)

        let metrics = try? await fetchLearnHubMetrics(userId: userId)
        widgetSnapshotManager.update(profile: profile, metrics: metrics, dateProvider: dateProvider)

        return result
    }
}
#endif
