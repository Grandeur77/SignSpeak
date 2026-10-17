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

/// Protocol abstracting learning progress storage.
public protocol ProgressRepository: Sendable {
    func fetchProgress(userId: String) async throws -> [SignProgress]
    func recordAttempt(userId: String, signId: String, isCorrect: Bool) async throws
}

/// In-memory progress repository stub.
public final class StubProgressRepository: ProgressRepository, @unchecked Sendable {
    private var progressStore: [String: [String: SignProgress]] = [:]

    public init() {}

    public func fetchProgress(userId: String) async throws -> [SignProgress] {
        Array((progressStore[userId] ?? [:]).values)
    }

    public func recordAttempt(userId: String, signId: String, isCorrect: Bool) async throws {
        var userDict = progressStore[userId] ?? [:]
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
}
