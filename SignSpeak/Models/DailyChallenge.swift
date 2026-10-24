import Foundation

/// Represents a daily practice challenge encouraging regular ASL learning habits.
public struct DailyChallenge: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var title: String
    public var description: String
    public var targetCount: Int
    public var currentCount: Int
    public var xpReward: Int
    public var isCompleted: Bool
    public var dateString: String // "yyyy-MM-dd"

    public var progress: Double {
        guard targetCount > 0 else { return 0 }
        return min(1.0, Double(currentCount) / Double(targetCount))
    }

    public init(
        id: String = "challenge_today",
        title: String = "Sign 3 Everyday Greetings",
        description: String = "Practice 3 greeting signs (Hello, Thank You, Please) with the camera.",
        targetCount: Int = 3,
        currentCount: Int = 2,
        xpReward: Int = 50,
        isCompleted: Bool = false,
        dateString: String = ""
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.targetCount = targetCount
        self.currentCount = currentCount
        self.xpReward = xpReward
        self.isCompleted = isCompleted
        self.dateString = dateString
    }

    /// Generates today's daily challenge based on current date.
    public static func defaultChallenge(for date: Date = Date()) -> DailyChallenge {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)

        let weekday = Calendar.current.component(.weekday, from: date)
        switch weekday {
        case 1, 7: // Weekend
            return DailyChallenge(
                id: "weekend_warrior_\(dateStr)",
                title: "Weekend Quick Review",
                description: "Complete 2 practice rounds to keep your streak fresh over the weekend.",
                targetCount: 2,
                currentCount: 1,
                xpReward: 60,
                isCompleted: false,
                dateString: dateStr
            )
        case 2: // Monday
            return DailyChallenge(
                id: "fresh_start_\(dateStr)",
                title: "Master 3 Alphabet Letters",
                description: "Fingerspell 3 letters in the recognition lab with steady accuracy.",
                targetCount: 3,
                currentCount: 2,
                xpReward: 50,
                isCompleted: false,
                dateString: dateStr
            )
        case 4: // Wednesday
            return DailyChallenge(
                id: "midweek_fluency_\(dateStr)",
                title: "Sign 3 Everyday Greetings",
                description: "Practice Hello, Thank You, and Nice to Meet You in the live camera.",
                targetCount: 3,
                currentCount: 3,
                xpReward: 50,
                isCompleted: true,
                dateString: dateStr
            )
        default:
            return DailyChallenge(
                id: "daily_flow_\(dateStr)",
                title: "Sign 3 Vocabulary Signs",
                description: "Practice any 3 signs with 80%+ accuracy to earn your daily XP bonus.",
                targetCount: 3,
                currentCount: 2,
                xpReward: 50,
                isCompleted: false,
                dateString: dateStr
            )
        }
    }
}
