import SwiftUI
import AVFoundation
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Steps in the complete Step 3.9 onboarding experience.
public enum OnboardingStep: Int, CaseIterable, Comparable, Sendable {
    case carousel1 = 0       // 10-onboarding-1-learn
    case carousel2 = 1       // 12-onboarding-2-talk
    case carousel3 = 2       // 15-onboarding-3-community
    case role = 3            // 17-onboarding-role
    case dailyGoal = 4       // 18-onboarding-daily-goal
    case camera = 5          // 11-permission-camera
    case microphone = 6      // 13-permission-microphone
    case notifications = 7   // 14-permission-notifications-stay-on-track
    case soundAlerts = 8     // 62-sound-alerts-setup (shown only for .deaf role)

    public static func < (lhs: OnboardingStep, rhs: OnboardingStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// User's primary intent and role choice (17-onboarding-role).
public enum OnboardingRole: String, CaseIterable, Identifiable, Sendable {
    case deaf = "deaf"
    case family = "family"
    case work = "work"
    case learner = "learner"
    case curious = "curious"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .deaf: return "I'm deaf or hard of hearing"
        case .family: return "I'm learning for family or friends"
        case .work: return "I'm learning for work"
        case .learner: return "Learning ASL"
        case .curious: return "Just curious"
        }
    }

    public var subtitle: String {
        switch self {
        case .deaf: return "Real-time two-way translation, visual alerts, & quick phrases"
        case .family: return "Everyday conversational signs and bridge tools"
        case .work: return "Professional vocabulary, customer service & workplace signs"
        case .learner: return "Build everyday conversational signs and natural flow"
        case .curious: return "Explore the alphabet, basic greetings, and Deaf culture"
        }
    }

    public var iconName: String {
        switch self {
        case .deaf: return "ear.and.waveform"
        case .family: return "person.2.fill"
        case .work: return "briefcase.fill"
        case .learner: return "hand.raised.fill"
        case .curious: return "sparkles"
        }
    }
}

/// Pacing and daily commitment goal (18-onboarding-daily-goal).
public enum DailyGoalOption: Int, CaseIterable, Identifiable, Sendable {
    case casual = 5
    case regular = 10
    case serious = 15
    case intense = 20

    public var id: Int { rawValue }
    public var minutes: Int { rawValue }

    public var name: String {
        switch self {
        case .casual: return "Casual"
        case .regular: return "Regular"
        case .serious: return "Serious"
        case .intense: return "Intense"
        }
    }

    public var subtitle: String {
        switch self {
        case .casual: return "Just dipping your toes in. 1-2 new gestures or a rapid morning review."
        case .regular: return "Steady progress. Build everyday conversational signs and natural flow."
        case .serious: return "Accelerated learning. Master phrases, facial expressions, and fast fingerspelling."
        case .intense: return "Immersive commitment. Fast-track expressive fluency for work or community."
        }
    }

    public var isRecommended: Bool {
        self == .regular
    }
}


/// View model driving the Step 3.9 multi-step onboarding journey.
@Observable
@MainActor
public final class OnboardingViewModel {
    public var currentStep: OnboardingStep = .carousel1
    public var selectedRole: OnboardingRole = .learner
    public var selectedDailyGoal: DailyGoalOption = .regular
    public var practiceTime: Date = Calendar.current.date(from: DateComponents(hour: 19, minute: 0)) ?? Date()
    public var activeDays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
    public var soundAlertsEnabled: Bool = true
    public var enabledSoundAlerts: Set<SoundAlertType> = Set(SoundAlertType.allCases)

    public var isCameraAuthorized: Bool = false
    public var isMicrophoneAuthorized: Bool = false
    public var isNotificationsAuthorized: Bool = false
    public var isCameraDenied: Bool = false
    public var isMicrophoneDenied: Bool = false
    public var isSaving: Bool = false

    private let authService: any AuthServicing
    private let userProfileRepository: any UserProfileRepository
    private let publicProfileRepository: any PublicProfileRepository
    private let cameraService: any CameraServicing
    private let notificationService: any NotificationServicing
    private let router: AppRouter

    public init(
        authService: any AuthServicing,
        userProfileRepository: any UserProfileRepository,
        publicProfileRepository: any PublicProfileRepository,
        cameraService: any CameraServicing,
        notificationService: any NotificationServicing,
        router: AppRouter,
        initialStep: OnboardingStep = .carousel1
    ) {
        self.authService = authService
        self.userProfileRepository = userProfileRepository
        self.publicProfileRepository = publicProfileRepository
        self.cameraService = cameraService
        self.notificationService = notificationService
        self.router = router
        self.currentStep = initialStep
    }

    // MARK: - Navigation

    /// Advances to the next logical screen, taking conditional branching into account.
    public func advance() {
        switch currentStep {
        case .carousel1:
            currentStep = .carousel2
        case .carousel2:
            currentStep = .carousel3
        case .carousel3:
            currentStep = .role
        case .role:
            currentStep = .dailyGoal
        case .dailyGoal:
            currentStep = .camera
        case .camera:
            currentStep = .microphone
        case .microphone:
            currentStep = .notifications
        case .notifications:
            if selectedRole == .deaf {
                currentStep = .soundAlerts
            } else {
                Task { await complete() }
            }
        case .soundAlerts:
            Task { await complete() }
        }
    }

    /// Navigates to previous screen if possible.
    public func goBack() {
        switch currentStep {
        case .carousel1:
            break
        case .carousel2:
            currentStep = .carousel1
        case .carousel3:
            currentStep = .carousel2
        case .role:
            currentStep = .carousel3
        case .dailyGoal:
            currentStep = .role
        case .camera:
            currentStep = .dailyGoal
        case .microphone:
            currentStep = .camera
        case .notifications:
            currentStep = .microphone
        case .soundAlerts:
            currentStep = .notifications
        }
    }

    /// Skips the remainder of the flow and applies default or currently selected values.
    public func skip() {
        Task {
            await complete()
        }
    }

    // MARK: - Permission Primers

    /// Requests camera authorization from AVFoundation.
    public func requestCameraAccess() async {
        let granted = await cameraService.requestAuthorization()
        isCameraAuthorized = granted
        isCameraDenied = !granted
        advance()
    }

    /// Requests microphone recording permission via AVFoundation.
    public func requestMicrophoneAccess() async {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            let granted = await AVAudioApplication.requestRecordPermission()
            isMicrophoneAuthorized = granted
            isMicrophoneDenied = !granted
        } else {
            let granted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            isMicrophoneAuthorized = granted
            isMicrophoneDenied = !granted
        }
        #else
        isMicrophoneAuthorized = true
        #endif
        advance()
    }

    /// Requests local notifications permission and schedules daily practice reminder.
    public func requestNotificationAccess() async {
        do {
            let granted = try await notificationService.requestAuthorization()
            isNotificationsAuthorized = granted
            if granted {
                let hour = Calendar.current.component(.hour, from: practiceTime)
                let minute = Calendar.current.component(.minute, from: practiceTime)
                try? await notificationService.scheduleDailyReminder(hour: hour, minute: minute)
            }
        } catch {
            isNotificationsAuthorized = false
        }
        advance()
    }

    // MARK: - Final Completion & Persistence

    /// Persists onboarding choices into the user's private and public profiles, then transitions the router.
    public func complete() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        guard let userId = authService.currentUserId else {
            await router.completeOnboarding()
            return
        }

        let hour = Calendar.current.component(.hour, from: practiceTime)
        let minute = Calendar.current.component(.minute, from: practiceTime)
        let timeString = String(format: "%02d:%02d", hour, minute)

        let reminderSettings = ReminderSettings(
            enabled: isNotificationsAuthorized,
            practiceTime: timeString,
            activeDays: Array(activeDays).sorted()
        )

        var profile = (try? await userProfileRepository.fetchProfile(userId: userId))
            ?? UserProfile(id: userId, displayName: authService.currentUser?.displayName ?? "Learner")

        profile.role = selectedRole.rawValue
        profile.dailyGoalMinutes = selectedDailyGoal.minutes
        profile.reminderSettings = reminderSettings
        profile.soundAlertsEnabled = (selectedRole == .deaf) ? soundAlertsEnabled : false
        profile.onboardingComplete = true

        try? await userProfileRepository.saveProfile(profile)
        try? await publicProfileRepository.syncFromPrivateProfile(profile)

        await router.completeOnboarding()
    }
}
