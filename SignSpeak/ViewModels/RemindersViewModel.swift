import SwiftUI
import Foundation

/// Notification preview types selectable for testing in the preview card.
public enum ReminderPreviewType: String, CaseIterable, Identifiable, Sendable {
    case dailyPractice = "Daily Practice"
    case eveningStreak = "Streak at Risk"
    case community = "Community"
    case weeklyReport = "Weekly Report"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dailyPractice: return "Time for Daily Sign ✋"
        case .eveningStreak: return "Streak at Risk! 🔥"
        case .community: return "New reaction on your sign 💬"
        case .weeklyReport: return "Your Weekly Progress 📊"
        }
    }

    public var sampleBody: String {
        switch self {
        case .dailyPractice:
            return "Keep your 4-day streak alive! Spend 5 minutes practicing today's signs."
        case .eveningStreak:
            return "Your streak expires at midnight. Complete 1 quick practice to keep it safe!"
        case .community:
            return "Alex reacted with 👏 to your 'Coffee' sign request."
        case .weeklyReport:
            return "You learned 14 signs this week with 92% average accuracy. Fantastic work!"
        }
    }
}

/// View model driving the Step 8.1 Reminders and Notifications screen (`51-reminders-notifications`).
@Observable
@MainActor
public final class RemindersViewModel {
    public var settings: ReminderSettings
    public var authorizationStatus: NotificationAuthorizationStatus = .notDetermined
    public var isPermissionDenied: Bool = false
    public var isSaving: Bool = false
    public var showTestAlertBanner: Bool = false
    public var selectedPreviewType: ReminderPreviewType = .dailyPractice

    private let notificationService: any NotificationServicing
    private let userProfileRepository: any UserProfileRepository
    private let userId: String

    public init(
        notificationService: any NotificationServicing,
        userProfileRepository: any UserProfileRepository,
        userId: String,
        initialSettings: ReminderSettings = ReminderSettings()
    ) {
        self.notificationService = notificationService
        self.userProfileRepository = userProfileRepository
        self.userId = userId
        self.settings = initialSettings
    }

    // MARK: - Lifecycle

    public func onAppear() async {
        await checkPermissionStatus()
        await loadSettings()
    }

    public func checkPermissionStatus() async {
        let status = await notificationService.getAuthorizationStatus()
        self.authorizationStatus = status
        self.isPermissionDenied = (status == .denied)
    }

    public func loadSettings() async {
        do {
            if let profile = try await userProfileRepository.fetchProfile(userId: userId),
               let saved = profile.reminderSettings {
                self.settings = saved
            }
        } catch {
            // Use defaults if fetch fails
        }
    }

    // MARK: - Actions & Rescheduling

    public func requestPermission() async {
        do {
            let granted = try await notificationService.requestAuthorization()
            await checkPermissionStatus()
            if granted {
                await rescheduleNotifications()
            }
        } catch {
            await checkPermissionStatus()
        }
    }

    public func setDailyReminderEnabled(_ enabled: Bool) {
        settings.enabled = enabled
        saveAndReschedule()
    }

    public func setPracticeTime(hour: Int, minute: Int) {
        settings.practiceTime = String(format: "%02d:%02d", hour, minute)
        saveAndReschedule()
    }

    public func setEveningEnabled(_ enabled: Bool) {
        settings.eveningEnabled = enabled
        saveAndReschedule()
    }

    public func setEveningTime(hour: Int, minute: Int) {
        settings.eveningTime = String(format: "%02d:%02d", hour, minute)
        saveAndReschedule()
    }

    public func toggleDay(_ day: Int) {
        if settings.activeDays.contains(day) {
            if settings.activeDays.count > 1 {
                settings.activeDays.removeAll { $0 == day }
            }
        } else {
            settings.activeDays.append(day)
            settings.activeDays.sort()
        }
        saveAndReschedule()
    }

    public func toggleStreakAlerts(_ enabled: Bool) {
        settings.streakAlertsEnabled = enabled
        saveAndReschedule()
    }

    public func toggleCommunityReactions(_ enabled: Bool) {
        settings.communityReactionsEnabled = enabled
        saveAndReschedule()
    }

    public func toggleNewLessons(_ enabled: Bool) {
        settings.newLessonsEnabled = enabled
        saveAndReschedule()
    }

    public func toggleWeeklyReport(_ enabled: Bool) {
        settings.weeklyReportEnabled = enabled
        saveAndReschedule()
    }

    public func sendTestNotification() async {
        do {
            let title = selectedPreviewType.title
            let body = selectedPreviewType.sampleBody
            try await notificationService.scheduleTestPreview(title: title, body: body)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                self.showTestAlertBanner = true
            }
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                withAnimation {
                    self.showTestAlertBanner = false
                }
            }
        } catch {
            // Notification failed (permission or mock)
        }
    }

    // MARK: - Internal Persistence

    private func saveAndReschedule() {
        Task {
            await rescheduleNotifications()
            await persistProfileSettings()
        }
    }

    public func rescheduleNotifications() async {
        guard authorizationStatus != .denied else { return }
        try? await notificationService.scheduleReminders(settings: settings)
    }

    private func persistProfileSettings() async {
        isSaving = true
        defer { isSaving = false }
        do {
            guard var profile = try await userProfileRepository.fetchProfile(userId: userId) else { return }
            profile.reminderSettings = settings
            try await userProfileRepository.saveProfile(profile)
        } catch {
            // Profile save failed
        }
    }

    // MARK: - Date Helpers

    public var practiceTimeDate: Date {
        let parts = settings.practiceTime.split(separator: ":").compactMap { Int($0) }
        let hour = parts.count > 0 ? parts[0] : 19
        let minute = parts.count > 1 ? parts[1] : 0
        return Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
    }

    public var eveningTimeDate: Date {
        let parts = settings.eveningTime.split(separator: ":").compactMap { Int($0) }
        let hour = parts.count > 0 ? parts[0] : 20
        let minute = parts.count > 1 ? parts[1] : 30
        return Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
    }
}
