import Foundation
import Testing
@testable import SignSpeak

/// Smoke tests
struct AppDependenciesTests {
    @Test func liveContainerUsesTheSystemClock() {
        #expect(AppDependencies.live.dateProvider is SystemDateProvider)
    }

    @Test func previewContainerUsesAFixedDate() {
        let provider = AppDependencies.preview.dateProvider
        #expect(provider is FixedDateProvider)
        #expect(provider.now == Date(timeIntervalSince1970: 1_790_812_800))
    }
}
