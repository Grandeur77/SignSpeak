import Foundation

/// Date logic
protocol DateProviding: Sendable {
    var now: Date { get }
    var calendar: Calendar { get }
}

/// using the device clock and the user's calendar.
nonisolated struct SystemDateProvider: DateProviding {
    var now: Date { Date() }
    var calendar: Calendar { .current }
}
