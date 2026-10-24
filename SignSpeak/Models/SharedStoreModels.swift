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

/// Helper providing deterministic daily sign rotation and midnight timeline schedules.
public enum SignOfTheDayProvider {
    /// Deterministically selects a sign for a given calendar date.
    public static func signOfTheDay(for date: Date = Date(), signs: [Sign]? = nil) -> SignOfTheDaySnapshot {
        let availableSigns = signs ?? SignCatalogService().allSigns()
        guard !availableSigns.isEmpty else {
            return SignOfTheDaySnapshot.fallback
        }

        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let year = calendar.component(.year, from: date)

        // Seeded rotation formula guaranteeing deterministic daily change
        let seed = abs(year * 365 + dayOfYear)
        let index = seed % availableSigns.count
        let sign = availableSigns[index]

        return SignOfTheDaySnapshot(
            id: sign.id,
            name: sign.name,
            category: sign.category.capitalized,
            description: sign.description.isEmpty ? "Learn and practice this everyday American Sign Language sign." : sign.description,
            imageName: sign.imageName ?? "hand.raised.fill"
        )
    }

    /// Calculates the start of the next calendar day (midnight) after the provided date.
    public static func nextMidnight(after date: Date = Date(), calendar: Calendar = .current) -> Date {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) else {
            return date.addingTimeInterval(86400)
        }
        return calendar.startOfDay(for: tomorrow)
    }
}
