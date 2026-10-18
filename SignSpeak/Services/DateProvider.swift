import Foundation

/// Date logic
public protocol DateProviding: Sendable {
    var now: Date { get }
    var calendar: Calendar { get }
}

/// using the device clock and the user's calendar.
public struct SystemDateProvider: DateProviding {
    public var now: Date { Date() }
    public var calendar: Calendar { .current }

    public init() {}
}

