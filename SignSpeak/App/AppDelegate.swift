import UIKit
import FirebaseCore
#if canImport(UserNotifications)
import UserNotifications
#endif

/// AppDelegate configuring Firebase, Google Sign-In, and UNUserNotificationCenter foreground delegate.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        setupNotificationCategories(center: center)
        #endif

        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        #if canImport(GoogleSignIn)
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }
        #endif
        return false
    }

    #if canImport(UserNotifications)
    // MARK: - UNUserNotificationCenterDelegate

    /// Allows notifications to present banners and play sounds while the app is actively in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    /// Handles user interaction with notification actions (e.g., "Practise Now", "Remind Me in 1 Hour").
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier

        if actionIdentifier == NotificationActionIdentifier.remind1Hour {
            // Re-schedule reminder in 1 hour
            let originalContent = response.notification.request.content
            let newContent = UNMutableNotificationContent()
            newContent.title = originalContent.title
            newContent.body = originalContent.body
            newContent.sound = originalContent.sound
            newContent.categoryIdentifier = originalContent.categoryIdentifier

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
            let req = UNNotificationRequest(
                identifier: "remind_1_hour_\(UUID().uuidString)",
                content: newContent,
                trigger: trigger
            )
            Task {
                try? await center.add(req)
                completionHandler()
            }
            return
        }

        completionHandler()
    }

    private func setupNotificationCategories(center: UNUserNotificationCenter) {
        let practiseAction = UNNotificationAction(
            identifier: NotificationActionIdentifier.practiseNow,
            title: "Practise Now",
            options: [.foreground]
        )

        let remindLaterAction = UNNotificationAction(
            identifier: NotificationActionIdentifier.remind1Hour,
            title: "Remind Me in 1 Hour",
            options: []
        )

        let replyAction = UNNotificationAction(
            identifier: NotificationActionIdentifier.reply,
            title: "Reply",
            options: [.foreground]
        )

        let practiceCategory = UNNotificationCategory(
            identifier: NotificationCategoryIdentifier.practiceReminder,
            actions: [practiseAction, remindLaterAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let streakCategory = UNNotificationCategory(
            identifier: NotificationCategoryIdentifier.streakAlert,
            actions: [practiseAction, remindLaterAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let communityCategory = UNNotificationCategory(
            identifier: NotificationCategoryIdentifier.communityReaction,
            actions: [replyAction],
            intentIdentifiers: [],
            options: []
        )

        let newLessonCategory = UNNotificationCategory(
            identifier: NotificationCategoryIdentifier.newLesson,
            actions: [practiseAction],
            intentIdentifiers: [],
            options: []
        )

        let weeklyReportCategory = UNNotificationCategory(
            identifier: NotificationCategoryIdentifier.weeklyReport,
            actions: [practiseAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([
            practiceCategory,
            streakCategory,
            communityCategory,
            newLessonCategory,
            weeklyReportCategory
        ])
    }
    #endif
}
