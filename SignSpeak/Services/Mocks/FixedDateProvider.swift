import Foundation

/// returns the same moment for previews and tests
nonisolated struct FixedDateProvider: DateProviding {
    var now: Date
    var calendar: Calendar

    init(now: Date, calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar
    }
}
