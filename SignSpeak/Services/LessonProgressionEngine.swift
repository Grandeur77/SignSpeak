import Foundation

/// State of completion and availability for a curriculum lesson.
public enum LessonStatus: String, Sendable, Codable, Equatable {
    case completed
    case inProgress
    case locked
}

/// Consolidated progress summary for an evaluated curriculum lesson.
public struct LessonProgressSummary: Identifiable, Sendable, Equatable {
    public var id: String { lessonId }
    public let lessonId: String
    public let status: LessonStatus
    public let masteredCount: Int
    public let totalSignsCount: Int

    public init(
        lessonId: String,
        status: LessonStatus,
        masteredCount: Int,
        totalSignsCount: Int
    ) {
        self.lessonId = lessonId
        self.status = status
        self.masteredCount = masteredCount
        self.totalSignsCount = totalSignsCount
    }

    /// True if the lesson is either actively in progress or completed.
    public var isUnlocked: Bool {
        status != .locked
    }

    /// Progression ratio from 0.0 to 1.0.
    public var progressFraction: Double {
        guard totalSignsCount > 0 else { return 0.0 }
        return min(1.0, Double(masteredCount) / Double(totalSignsCount))
    }
}

/// Pure deterministic engine evaluating sequential lesson unlocking and progress.
/// Adheres to requirement: "lesson unlocking (sequential prerequisites, completed / in-progress / locked states)".
public struct LessonProgressionEngine: Sendable {

    /// Evaluates sequential lesson status for an ordered list of lessons.
    /// Rules:
    /// - The first lesson (index 0) is always unlocked (`.inProgress` if unmastered, `.completed` if all signs mastered).
    /// - A lesson is `.completed` if all signs in that lesson are marked mastered (`isMastered == true`) in `progress`.
    /// - Subsequent lessons are unlocked (`.inProgress` or `.completed`) ONLY IF every preceding lesson in the sequence is `.completed`.
    /// - If any preceding lesson is not yet `.completed`, the lesson is `.locked`.
    public static func evaluate(
        lessons: [Lesson],
        progress: [String: SignProgress]
    ) -> [LessonProgressSummary] {
        var results: [LessonProgressSummary] = []
        var precedingAllCompleted = true

        for (index, lesson) in lessons.enumerated() {
            let total = lesson.signIds.count
            let mastered = lesson.signIds.filter { signId in
                progress[signId]?.isMastered == true
            }.count

            let isFullyMastered = total > 0 && mastered >= total

            let status: LessonStatus
            if isFullyMastered && precedingAllCompleted {
                status = .completed
            } else if index == 0 || precedingAllCompleted {
                status = .inProgress
                precedingAllCompleted = false
            } else {
                status = .locked
                precedingAllCompleted = false
            }

            results.append(
                LessonProgressSummary(
                    lessonId: lesson.id,
                    status: status,
                    masteredCount: mastered,
                    totalSignsCount: total
                )
            )
        }

        return results
    }

    /// Convenience lookup for a specific lesson's summary.
    public static func summary(
        forLesson lessonId: String,
        in lessons: [Lesson],
        progress: [String: SignProgress]
    ) -> LessonProgressSummary? {
        evaluate(lessons: lessons, progress: progress).first { $0.lessonId == lessonId }
    }
}
