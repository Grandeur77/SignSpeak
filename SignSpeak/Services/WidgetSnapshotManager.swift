import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Manager responsible for persisting widget data snapshots to App Group shared storage
/// and notifying WidgetKit to reload Home and Lock screen timelines.
public final class WidgetSnapshotManager: Sendable {
    public static let shared = WidgetSnapshotManager()

    public static let appGroupSuiteName = "group.com.signspeak.app"
    public static let snapshotKey = "signspeak_widget_snapshot"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults? = nil) {
        if let defaults {
            self.defaults = defaults
        } else {
            self.defaults = UserDefaults(suiteName: Self.appGroupSuiteName) ?? .standard
        }
    }

    /// Reads the cached snapshot from shared user defaults.
    public func fetchSnapshot() -> WidgetSnapshot? {
        guard let data = defaults.data(forKey: Self.snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// Updates the widget snapshot and triggers a timeline reload across all widgets.
    public func update(
        profile: UserProfile,
        metrics: LearnHubMetrics? = nil,
        dateProvider: any DateProviding = SystemDateProvider()
    ) {
        let level = profile.level
        let tierTitle = ExplorerLevel.tierTitle(forXP: profile.xp)

        let snapshot = WidgetSnapshot(
            currentStreak: profile.currentStreak,
            longestStreak: profile.longestStreak,
            xp: profile.xp,
            level: level,
            levelTitle: tierTitle,
            streakFreezes: profile.streakFreezes,
            dailyGoalMinutes: profile.dailyGoalMinutes,
            dailyGoalVerified: metrics?.dailyGoalVerified ?? 0,
            dailyGoalTarget: metrics?.dailyGoalTarget ?? 3,
            lastPracticeDay: profile.lastPracticeDay,
            lastUpdated: dateProvider.now
        )

        saveSnapshot(snapshot)
    }

    /// Explicitly saves a snapshot and invalidates widget timelines.
    public func saveSnapshot(_ snapshot: WidgetSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: Self.snapshotKey)
        }

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
