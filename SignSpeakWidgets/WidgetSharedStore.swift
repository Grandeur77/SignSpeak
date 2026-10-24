import Foundation

/// Shared persistence reader for SignSpeak widgets.
public final class SharedStore: Sendable {
    public static let shared = SharedStore()

    public static let primaryAppGroupSuiteName = "group.com.mileesha.SignSpeak"
    public static let legacyAppGroupSuiteName = "group.com.signspeak.app"
    public static let snapshotKey = "signspeak_widget_snapshot"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults? = nil) {
        if let defaults {
            self.defaults = defaults
        } else if let groupDefaults = UserDefaults(suiteName: Self.primaryAppGroupSuiteName) {
            self.defaults = groupDefaults
        } else if let legacyDefaults = UserDefaults(suiteName: Self.legacyAppGroupSuiteName) {
            self.defaults = legacyDefaults
        } else {
            self.defaults = .standard
        }
    }

    public func fetchSnapshot() -> WidgetSnapshot {
        guard let data = defaults.data(forKey: Self.snapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return makeDefaultSnapshot()
        }
        return snapshot
    }

    public func makeDefaultSnapshot() -> WidgetSnapshot {
        WidgetSnapshot(
            currentStreak: 5,
            longestStreak: 14,
            xp: 450,
            level: 3,
            levelTitle: "Communicator I",
            streakFreezes: 1,
            dailyGoalMinutes: 15,
            dailyGoalVerified: 2,
            dailyGoalTarget: 3,
            lastPracticeDay: "2026-10-24",
            lastUpdated: Date(),
            remainingMinutes: 1,
            isGoalCompleted: false,
            signOfTheDay: SignOfTheDayProvider.signOfTheDay(),
            quickPhrases: QuickPhraseSnapshot.defaultPhrases
        )
    }
}
