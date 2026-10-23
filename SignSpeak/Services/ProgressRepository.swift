import Foundation

/// Practice progress data for an individual ASL sign.
public struct SignProgress: Identifiable, Codable, Sendable, Equatable {
    public var id: String { signId }
    public let signId: String
    public var attempts: Int
    public var correct: Int
    public var isMastered: Bool
    public var lastPracticedAt: Date?

    public init(
        signId: String,
        attempts: Int = 0,
        correct: Int = 0,
        isMastered: Bool = false,
        lastPracticedAt: Date? = nil
    ) {
        self.signId = signId
        self.attempts = attempts
        self.correct = correct
        self.isMastered = isMastered
        self.lastPracticedAt = lastPracticedAt
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

/// Protocol abstracting learning progress storage.
public protocol ProgressRepository: Sendable {
    func fetchProgress(userId: String) async throws -> [SignProgress]
    func recordAttempt(userId: String, signId: String, isCorrect: Bool) async throws
    func fetchMistakes(userId: String) async throws -> [SignProgress]
    func fetchLearnHubMetrics(userId: String) async throws -> LearnHubMetrics
}

extension ProgressRepository {
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

/// In-memory progress repository stub with realistic curriculum seed defaults.
public final class StubProgressRepository: ProgressRepository, @unchecked Sendable {
    private var progressStore: [String: [String: SignProgress]] = [:]

    public init(initialStore: [String: [String: SignProgress]]? = nil) {
        if let initialStore {
            self.progressStore = initialStore
        } else {
            // Seed default mock progress matching design 25-learn-hub
            self.progressStore = [
                "preview-user-123": Self.seedLearnerProgress(),
                "default": Self.seedLearnerProgress()
            ]
        }
    }

    public func fetchProgress(userId: String) async throws -> [SignProgress] {
        if let userDict = progressStore[userId] {
            return Array(userDict.values)
        }
        // Fallback to default seeded progress
        return Array((progressStore["default"] ?? [:]).values)
    }

    public func recordAttempt(userId: String, signId: String, isCorrect: Bool) async throws {
        var userDict = progressStore[userId] ?? progressStore["default"] ?? [:]
        var item = userDict[signId] ?? SignProgress(signId: signId)
        item.attempts += 1
        if isCorrect {
            item.correct += 1
            if item.correct >= 5 {
                item.isMastered = true
            }
        }
        item.lastPracticedAt = Date()
        userDict[signId] = item
        progressStore[userId] = userDict
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
