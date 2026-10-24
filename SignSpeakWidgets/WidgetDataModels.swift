import Foundation

/// Snapshot representation of a curriculum sign for Sign of the Day widgets.
public struct SignOfTheDaySnapshot: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let category: String
    public let description: String
    public let imageName: String

    public init(
        id: String = "sign-letter-a",
        name: String = "A",
        category: String = "Alphabet",
        description: String = "Fist with thumb resting upright beside index finger",
        imageName: String = "hand.raised.fill"
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.imageName = imageName
    }

    public static let fallback = SignOfTheDaySnapshot(
        id: "sign-letter-a",
        name: "A",
        category: "Alphabet",
        description: "Fist with thumb resting upright beside index finger",
        imageName: "hand.raised.fill"
    )
}

/// Snapshot representation of a quick communicator phrase for interactive widgets.
public struct QuickPhraseSnapshot: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let text: String
    public let category: String
    public let isEmergency: Bool

    public init(
        id: String = UUID().uuidString,
        text: String,
        category: String = "Essentials",
        isEmergency: Bool = false
    ) {
        self.id = id
        self.text = text
        self.category = category
        self.isEmergency = isEmergency
    }

    public static let defaultPhrases: [QuickPhraseSnapshot] = [
        QuickPhraseSnapshot(id: "qp-1", text: "I am Deaf, please type", category: "Essentials"),
        QuickPhraseSnapshot(id: "qp-2", text: "Thank you!", category: "Courtesies"),
        QuickPhraseSnapshot(id: "qp-3", text: "Where is the restroom?", category: "Places"),
        QuickPhraseSnapshot(id: "qp-4", text: "I need assistance", category: "Urgent", isEmergency: true)
    ]
}

/// Snapshot representation of user practice progress for widget rendering.
public struct DailyProgressDay: Codable, Sendable, Equatable {
    public let weekday: String
    public let isCompleted: Bool
    public let isToday: Bool

    public init(weekday: String, isCompleted: Bool, isToday: Bool = false) {
        self.weekday = weekday
        self.isCompleted = isCompleted
        self.isToday = isToday
    }
}

/// Deterministic rotation provider for Sign of the Day widgets.
public enum SignOfTheDayProvider {
    public static let catalogSigns: [SignOfTheDaySnapshot] = [
        SignOfTheDaySnapshot(id: "sign-letter-a", name: "A", category: "Alphabet", description: "Fist with thumb resting upright beside index finger", imageName: "hand.raised.fill"),
        SignOfTheDaySnapshot(id: "sign-letter-b", name: "B", category: "Alphabet", description: "Open palm with four upright fingers and thumb crossed over palm", imageName: "hand.raised.fill"),
        SignOfTheDaySnapshot(id: "sign-letter-c", name: "C", category: "Alphabet", description: "Curved hand forming a C shape facing forward", imageName: "hand.raised.fill"),
        SignOfTheDaySnapshot(id: "sign-hello", name: "Hello", category: "Greetings", description: "Open hand saluting from temple outward", imageName: "hand.wave.fill"),
        SignOfTheDaySnapshot(id: "sign-thank-you", name: "Thank You", category: "Greetings", description: "Fingertips touching chin moving forward toward person", imageName: "hand.raised.fingers.spread.fill"),
        SignOfTheDaySnapshot(id: "sign-yes", name: "Yes", category: "Basics", description: "Fist nodding up and down like a head nodding", imageName: "hand.thumbsup.fill"),
        SignOfTheDaySnapshot(id: "sign-no", name: "No", category: "Basics", description: "Index and middle finger tapping thumb shut", imageName: "hand.tap.fill"),
        SignOfTheDaySnapshot(id: "sign-please", name: "Please", category: "Politeness", description: "Flat open palm rubbing clockwise circle over chest", imageName: "hand.raised.fill"),
        SignOfTheDaySnapshot(id: "sign-help", name: "Help", category: "Assistance", description: "Closed thumbs-up fist resting on flat palm lifted upward", imageName: "cross.fill")
    ]

    public static func signOfTheDay(for date: Date = Date()) -> SignOfTheDaySnapshot {
        guard !catalogSigns.isEmpty else { return SignOfTheDaySnapshot.fallback }
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let year = calendar.component(.year, from: date)
        let seed = abs(year * 365 + dayOfYear)
        let index = seed % catalogSigns.count
        return catalogSigns[index]
    }

    public static func nextMidnight(after date: Date = Date(), calendar: Calendar = .current) -> Date {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) else {
            return date.addingTimeInterval(86400)
        }
        return calendar.startOfDay(for: tomorrow)
    }
}

/// App Group container snapshot for Home and Lock Screen widgets.
public struct WidgetSnapshot: Codable, Sendable, Equatable {
    public let currentStreak: Int
    public let longestStreak: Int
    public let xp: Int
    public let level: Int
    public let levelTitle: String
    public let streakFreezes: Int
    public let dailyGoalMinutes: Int
    public let dailyGoalVerified: Int
    public let dailyGoalTarget: Int
    public let lastPracticeDay: String?
    public let lastUpdated: Date
    public let remainingMinutes: Int
    public let isGoalCompleted: Bool
    public let signOfTheDay: SignOfTheDaySnapshot
    public let quickPhrases: [QuickPhraseSnapshot]

    public init(
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        xp: Int = 0,
        level: Int = 1,
        levelTitle: String = "Explorer I",
        streakFreezes: Int = 0,
        dailyGoalMinutes: Int = 10,
        dailyGoalVerified: Int = 0,
        dailyGoalTarget: Int = 3,
        lastPracticeDay: String? = nil,
        lastUpdated: Date = Date(),
        remainingMinutes: Int? = nil,
        isGoalCompleted: Bool? = nil,
        signOfTheDay: SignOfTheDaySnapshot = .fallback,
        quickPhrases: [QuickPhraseSnapshot] = QuickPhraseSnapshot.defaultPhrases
    ) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.xp = xp
        self.level = level
        self.levelTitle = levelTitle
        self.streakFreezes = streakFreezes
        self.dailyGoalMinutes = dailyGoalMinutes
        self.dailyGoalVerified = dailyGoalVerified
        self.dailyGoalTarget = dailyGoalTarget
        self.lastPracticeDay = lastPracticeDay
        self.lastUpdated = lastUpdated
        self.remainingMinutes = remainingMinutes ?? max(0, dailyGoalTarget - dailyGoalVerified)
        self.isGoalCompleted = isGoalCompleted ?? (dailyGoalVerified >= dailyGoalTarget && dailyGoalTarget > 0)
        self.signOfTheDay = signOfTheDay
        self.quickPhrases = quickPhrases
    }

    public var dailyProgressDays: [DailyProgressDay] {
        let calendar = Calendar.current
        let today = Date()
        let weekdays = ["M", "T", "W", "T", "F", "S", "S"]
        let currentWeekday = calendar.component(.weekday, from: today) // Sunday = 1, Mon = 2
        let adjustedWeekdayIndex = (currentWeekday + 5) % 7 // Mon = 0 ... Sun = 6

        return (0..<7).map { index in
            let isPastOrToday = index <= adjustedWeekdayIndex
            let isCompleted = isPastOrToday && (index == adjustedWeekdayIndex ? isGoalCompleted : (currentStreak > (adjustedWeekdayIndex - index)))
            return DailyProgressDay(
                weekday: weekdays[index],
                isCompleted: isCompleted,
                isToday: index == adjustedWeekdayIndex
            )
        }
    }
}
