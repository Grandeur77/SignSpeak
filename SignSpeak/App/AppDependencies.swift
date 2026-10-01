import SwiftUI

/// .live` at the root; previews and tests use `.preview` or their own mocks.
nonisolated struct AppDependencies: Sendable {
    var dateProvider: any DateProviding

    static let live = AppDependencies(
        dateProvider: SystemDateProvider()
    )

    static let preview = AppDependencies(
        dateProvider: FixedDateProvider(now: Date(timeIntervalSince1970: 1_790_812_800)) // 1 Oct 2026
    )
}

extension EnvironmentValues {
    @Entry var dependencies: AppDependencies = .live
}
