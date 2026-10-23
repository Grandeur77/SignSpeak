import Foundation

/// Pure, testable SM-2 spaced repetition scheduler for ASL sign retention.
/// Implements SuperMemo 2 (SM-2) algorithm calculating review intervals,
/// ease factors, and scheduled due dates based on learner practice performance.
public struct SpacedRepetitionScheduler: Sendable {

    /// Quality grade from 0 (complete blackout) to 5 (flawless, instant recall).
    public enum Quality: Int, Sendable, CaseIterable {
        case blackout = 0      // Complete failure to recall
        case wrongSlow = 1     // Incorrect response, unfamiliar
        case wrongClose = 2    // Incorrect response, but remembered upon seeing
        case correctHard = 3   // Correct response with significant effort or retry
        case correctGood = 4   // Correct response after brief hesitation
        case perfect = 5       // Instant, flawless recall with high confidence

        public var isSuccess: Bool {
            self.rawValue >= 3
        }
    }

    /// Default ease factor for newly added items.
    public static let defaultEaseFactor: Double = 2.5

    /// Minimum ease factor threshold to prevent stagnation (SuperMemo standard).
    public static let minimumEaseFactor: Double = 1.3

    public init() {}

    // MARK: - SM-2 Core Calculation

    /// Evaluates a review attempt and computes the updated `FavouriteRecord`.
    /// - Parameters:
    ///   - current: Current stored favourite record.
    ///   - quality: Quality score from 0 to 5.
    ///   - reviewDate: Timestamp of the review attempt (defaults to now).
    /// - Returns: Updated record with new interval, ease factor, repetition count, and due date.
    public static func evaluate(
        current: FavouriteRecord,
        quality: Int,
        reviewDate: Date = Date()
    ) -> FavouriteRecord {
        let q = max(0, min(5, quality))
        let isSuccess = q >= 3

        var newRepetitions: Int
        var newIntervalDays: Int
        var newEaseFactor: Double = current.easeFactor

        if isSuccess {
            // Update interval based on repetition streak
            switch current.repetitions {
            case 0:
                newIntervalDays = 1
            case 1:
                newIntervalDays = 6
            default:
                let multiplied = Double(current.intervalDays) * current.easeFactor
                newIntervalDays = max(1, Int(round(multiplied)))
            }
            newRepetitions = current.repetitions + 1

            // SM-2 Ease Factor formula: EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
            let delta = 0.1 - Double(5 - q) * (0.08 + Double(5 - q) * 0.02)
            newEaseFactor = max(minimumEaseFactor, current.easeFactor + delta)
        } else {
            // Review failed: reset repetitions back to 0, schedule for next day
            newRepetitions = 0
            newIntervalDays = 1

            // Slightly penalize ease factor on failure, clamped at minimum
            newEaseFactor = max(minimumEaseFactor, current.easeFactor - 0.2)
        }

        // Calculate next review due date
        let calendar = Calendar.current
        let nextDueDate = calendar.date(byAdding: .day, value: newIntervalDays, to: reviewDate)
            ?? reviewDate.addingTimeInterval(Double(newIntervalDays) * 86400)

        return FavouriteRecord(
            signId: current.signId,
            savedAt: current.savedAt,
            intervalDays: newIntervalDays,
            easeFactor: (newEaseFactor * 100).rounded() / 100, // Round to 2 decimals
            repetitions: newRepetitions,
            nextDueDate: nextDueDate,
            lastReviewedAt: reviewDate,
            lastQuality: q
        )
    }

    // MARK: - Due Date Helpers

    /// Checks if a record is due for review as of the specified date.
    public static func isDue(record: FavouriteRecord, asOf date: Date = Date()) -> Bool {
        record.nextDueDate <= date
    }

    /// Returns human-readable relative due status text for display.
    public static func dueStatus(record: FavouriteRecord, asOf date: Date = Date()) -> String {
        let calendar = Calendar.current

        if calendar.isDate(record.nextDueDate, inSameDayAs: date) {
            return "Due today"
        } else if record.nextDueDate < date {
            let daysOverdue = calendar.dateComponents([.day], from: record.nextDueDate, to: date).day ?? 1
            if daysOverdue <= 1 {
                return "Overdue (1 day)"
            } else {
                return "Overdue (\(daysOverdue) days)"
            }
        } else {
            let daysFuture = calendar.dateComponents([.day], from: date, to: record.nextDueDate).day ?? 1
            if daysFuture <= 1 {
                return "Due tomorrow"
            } else {
                return "Due in \(daysFuture) days"
            }
        }
    }

    /// Converts practice recognition metrics (confidence, duration, attempts) into an SM-2 Quality score (0-5).
    public static func qualityScore(
        isCorrect: Bool,
        firstTry: Bool = true,
        confidence: Double = 0.9,
        attempts: Int = 1
    ) -> Int {
        if !isCorrect {
            return attempts > 2 ? 1 : 2
        }

        if firstTry && confidence >= 0.85 {
            return 5
        } else if firstTry && confidence >= 0.70 {
            return 4
        } else if isCorrect {
            return 3
        } else {
            return 2
        }
    }
}
