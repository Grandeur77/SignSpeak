import SwiftUI

@main
struct SignSpeakApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let dependencies = AppDependencies.live

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(\.dependencies, dependencies)
        }
    }
}
