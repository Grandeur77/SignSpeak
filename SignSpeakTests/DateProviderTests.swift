import Foundation
import Testing
@testable import SignSpeak

struct DateProviderTests {
    @Test func fixedProviderReturnsTheSameMomentEveryTime() {
        let moment = Date(timeIntervalSince1970: 1_790_812_800)
        let provider = FixedDateProvider(now: moment)

        #expect(provider.now == moment)
        #expect(provider.now == provider.now)
    }

    @Test func fixedProviderKeepsTheInjectedCalendar() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Colombo"))
        let provider = FixedDateProvider(now: .now, calendar: calendar)

        #expect(provider.calendar.timeZone.identifier == "Asia/Colombo")
    }

    @Test func systemProviderTracksTheDeviceClock() {
        let before = Date()
        let now = SystemDateProvider().now
        let after = Date()

        #expect(before <= now && now <= after)
    }
}
