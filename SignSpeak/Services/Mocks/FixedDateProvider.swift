import Foundation

/// returns the same moment for previews and tests
public struct FixedDateProvider: DateProviding {
    public var now: Date
    public var calendar: Calendar

    public init(now: Date, calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar
    }
}

