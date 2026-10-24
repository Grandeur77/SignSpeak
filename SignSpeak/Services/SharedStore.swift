import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Central App Group persistence coordinator (Step 13.1)
/// Reads and writes Codable snapshots for Home and Lock Screen widgets.
public final class SharedStore: Sendable {
    public static let shared = SharedStore()

    /// Preferred App Group suite name as configured in Xcode signing.
    public static let primaryAppGroupSuiteName = "group.com.mileesha.SignSpeak"
    /// Fallback App Group suite name.
    public static let legacyAppGroupSuiteName = "group.com.signspeak.app"
    /// Key for storing encoded WidgetSnapshot in shared UserDefaults.
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

    /// Convenience initializer using a specific suite name (useful for isolated unit tests).
    public convenience init(suiteName: String) {
        let customDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        self.init(defaults: customDefaults)
    }

    /// Fetches the latest decoded snapshot from shared storage.
    /// Falls back to a deterministic default snapshot when none is saved yet.
    public func fetchSnapshot() -> WidgetSnapshot {
        guard let data = defaults.data(forKey: Self.snapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return makeDefaultSnapshot()
        }
        return snapshot
    }

    /// Explicitly writes a snapshot to shared storage and triggers a WidgetCenter timeline reload.
    public func saveSnapshot(_ snapshot: WidgetSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: Self.snapshotKey)
        }
        reloadTimelines()
    }

    /// Synchronizes progress and profile state into the snapshot.
    public func update(
        profile: UserProfile,
        metrics: LearnHubMetrics? = nil,
        signOfTheDay: SignOfTheDaySnapshot? = nil,
        quickPhrases: [QuickPhraseSnapshot]? = nil,
        dateProvider: any DateProviding = SystemDateProvider()
    ) {
        let level = profile.level
        let tierTitle = ExplorerLevel.tierTitle(forXP: profile.xp)
        let verified = metrics?.dailyGoalVerified ?? 0
        let target = metrics?.dailyGoalTarget ?? 3
        let remaining = max(0, target - verified)
        let isCompleted = verified >= target && target > 0

        let chosenSign = signOfTheDay ?? SignOfTheDayProvider.signOfTheDay(for: dateProvider.now)
        let chosenPhrases = quickPhrases ?? QuickPhraseSnapshot.defaultPhrases

        let snapshot = WidgetSnapshot(
            currentStreak: profile.currentStreak,
            longestStreak: profile.longestStreak,
            xp: profile.xp,
            level: level,
            levelTitle: tierTitle,
            streakFreezes: profile.streakFreezes,
            dailyGoalMinutes: profile.dailyGoalMinutes,
            dailyGoalVerified: verified,
            dailyGoalTarget: target,
            lastPracticeDay: profile.lastPracticeDay,
            lastUpdated: dateProvider.now,
            remainingMinutes: remaining,
            isGoalCompleted: isCompleted,
            signOfTheDay: chosenSign,
            quickPhrases: chosenPhrases
        )

        saveSnapshot(snapshot)
    }

    /// Informs WidgetKit to reload all active Home and Lock screen widget timelines.
    public func reloadTimelines() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    /// Generates a fallback default snapshot with deterministic Sign of the Day.
    public func makeDefaultSnapshot(date: Date = Date()) -> WidgetSnapshot {
        let sign = SignOfTheDayProvider.signOfTheDay(for: date)
        return WidgetSnapshot(
            currentStreak: 0,
            longestStreak: 0,
            xp: 0,
            level: 1,
            levelTitle: "Explorer I",
            streakFreezes: 0,
            dailyGoalMinutes: 10,
            dailyGoalVerified: 0,
            dailyGoalTarget: 3,
            lastPracticeDay: nil,
            lastUpdated: date,
            remainingMinutes: 3,
            isGoalCompleted: false,
            signOfTheDay: sign,
            quickPhrases: QuickPhraseSnapshot.defaultPhrases
        )
    }
}
