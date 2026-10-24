import Foundation

/// Protocol for persisting and retrieving sound alert detection logs (`64-sound-alert-history`).
public protocol SoundAlertHistoryRepository: AnyObject, Sendable {
    func getHistory() -> [SoundAlertRecord]
    func addAlert(_ alert: SoundAlertRecord)
    func clearHistory()
}

/// UserDefaults-backed implementation of `SoundAlertHistoryRepository`.
public final class LocalSoundAlertHistoryRepository: SoundAlertHistoryRepository, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "signspeak.soundalert.history"
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func getHistory() -> [SoundAlertRecord] {
        lock.lock()
        defer { lock.unlock() }

        guard let data = defaults.data(forKey: key) else { return [] }
        do {
            let records = try JSONDecoder().decode([SoundAlertRecord].self, from: data)
            return records.sorted(by: { $0.timestamp > $1.timestamp })
        } catch {
            return []
        }
    }

    public func addAlert(_ alert: SoundAlertRecord) {
        lock.lock()
        defer { lock.unlock() }

        var current = (try? defaults.data(forKey: key)).flatMap {
            try? JSONDecoder().decode([SoundAlertRecord].self, from: $0)
        } ?? []

        // Insert at beginning, cap at 100 entries
        current.insert(alert, at: 0)
        if current.count > 100 {
            current = Array(current.prefix(100))
        }

        if let encoded = try? JSONEncoder().encode(current) {
            defaults.set(encoded, forKey: key)
        }
    }

    public func clearHistory() {
        lock.lock()
        defer { lock.unlock() }
        defaults.removeObject(forKey: key)
    }
}

/// In-memory implementation of `SoundAlertHistoryRepository` for previews and unit tests.
public final class StubSoundAlertHistoryRepository: SoundAlertHistoryRepository, @unchecked Sendable {
    private var records: [SoundAlertRecord]
    private let lock = NSLock()

    public init(initialRecords: [SoundAlertRecord] = []) {
        self.records = initialRecords
    }

    public func getHistory() -> [SoundAlertRecord] {
        lock.lock()
        defer { lock.unlock() }
        return records.sorted(by: { $0.timestamp > $1.timestamp })
    }

    public func addAlert(_ alert: SoundAlertRecord) {
        lock.lock()
        defer { lock.unlock() }
        records.insert(alert, at: 0)
    }

    public func clearHistory() {
        lock.lock()
        defer { lock.unlock() }
        records.removeAll()
    }
}
