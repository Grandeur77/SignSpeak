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

    private let sharedStore: SharedStore
    private let defaults: UserDefaults

    public init(defaults: UserDefaults? = nil) {
        if let defaults {
            self.defaults = defaults
            self.sharedStore = SharedStore(defaults: defaults)
        } else {
            self.sharedStore = SharedStore.shared
            self.defaults = UserDefaults(suiteName: SharedStore.primaryAppGroupSuiteName)
                ?? UserDefaults(suiteName: SharedStore.legacyAppGroupSuiteName)
                ?? .standard
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
        sharedStore.update(profile: profile, metrics: metrics, dateProvider: dateProvider)
    }

    /// Explicitly saves a snapshot and invalidates widget timelines.
    public func saveSnapshot(_ snapshot: WidgetSnapshot) {
        sharedStore.saveSnapshot(snapshot)
    }
}
