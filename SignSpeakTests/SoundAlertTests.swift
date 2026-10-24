import Testing
import Foundation
@testable import SignSpeak

/// Test suite for Phase 12 Sound Alerts (sound classification, mapping, sensitivity thresholds,
/// cool-down deduplication, mute timer, history persistence, and view model workflows).
@Suite("Sound Alerts Test Suite")
struct SoundAlertTests {

    // MARK: - 1. Classification Identifier Mapping

    @Test("Sound identifier mapping resolves Apple SoundAnalysis classes to SoundAlertType correctly")
    func testIdentifierMapping() {
        // Doorbell
        #expect(SoundAlertService.mapIdentifierToSoundType("doorbell") == .doorbell)
        #expect(SoundAlertService.mapIdentifierToSoundType("ding_dong") == .doorbell)
        #expect(SoundAlertService.mapIdentifierToSoundType("bell") == .doorbell)
        #expect(SoundAlertService.mapIdentifierToSoundType("chime") == .doorbell)

        // Knocking
        #expect(SoundAlertService.mapIdentifierToSoundType("knock") == .knocking)
        #expect(SoundAlertService.mapIdentifierToSoundType("door_knock") == .knocking)
        #expect(SoundAlertService.mapIdentifierToSoundType("tapping") == .knocking)
        #expect(SoundAlertService.mapIdentifierToSoundType("thump") == .knocking)

        // Fire Alarm
        #expect(SoundAlertService.mapIdentifierToSoundType("smoke_detector") == .fireAlarm)
        #expect(SoundAlertService.mapIdentifierToSoundType("fire_alarm") == .fireAlarm)
        #expect(SoundAlertService.mapIdentifierToSoundType("smoke_alarm") == .fireAlarm)
        #expect(SoundAlertService.mapIdentifierToSoundType("buzzer") == .fireAlarm)

        // Sirens
        #expect(SoundAlertService.mapIdentifierToSoundType("siren") == .sirens)
        #expect(SoundAlertService.mapIdentifierToSoundType("ambulance_siren") == .sirens)
        #expect(SoundAlertService.mapIdentifierToSoundType("police_siren") == .sirens)
        #expect(SoundAlertService.mapIdentifierToSoundType("emergency_vehicle") == .sirens)

        // Baby Crying
        #expect(SoundAlertService.mapIdentifierToSoundType("baby_crying") == .babyCrying)
        #expect(SoundAlertService.mapIdentifierToSoundType("infant_cry") == .babyCrying)

        // Shouting / Calling
        #expect(SoundAlertService.mapIdentifierToSoundType("shouting") == .nameCalling)
        #expect(SoundAlertService.mapIdentifierToSoundType("screaming") == .nameCalling)
        #expect(SoundAlertService.mapIdentifierToSoundType("yell") == .nameCalling)

        // Unrelated sound
        #expect(SoundAlertService.mapIdentifierToSoundType("piano_sonata") == nil)
        #expect(SoundAlertService.mapIdentifierToSoundType("dog_barking") == nil)
    }

    // MARK: - 2. Sensitivity Thresholds

    @Test("Sensitivity thresholds provide correct minimum confidence numbers")
    func testSensitivityThresholds() {
        #expect(SoundAlertSensitivity.low.minimumConfidence == 0.50)
        #expect(SoundAlertSensitivity.medium.minimumConfidence == 0.70)
        #expect(SoundAlertSensitivity.high.minimumConfidence == 0.85)
    }

    // MARK: - 3. Urgency and Default Haptics

    @Test("Emergency categories are correctly marked and assigned SOS vibration")
    func testEmergencyCategories() {
        #expect(SoundAlertType.fireAlarm.isUrgent == true)
        #expect(SoundAlertType.sirens.isUrgent == true)
        #expect(SoundAlertType.doorbell.isUrgent == false)
        #expect(SoundAlertType.knocking.isUrgent == false)
        #expect(SoundAlertType.babyCrying.isUrgent == false)
        #expect(SoundAlertType.nameCalling.isUrgent == false)

        #expect(SoundAlertType.fireAlarm.defaultHapticPattern == .sos)
        #expect(SoundAlertType.sirens.defaultHapticPattern == .sos)
        #expect(SoundAlertType.doorbell.defaultHapticPattern == .pulse)
        #expect(SoundAlertType.knocking.defaultHapticPattern == .pulse)
        #expect(SoundAlertType.babyCrying.defaultHapticPattern == .long)
        #expect(SoundAlertType.nameCalling.defaultHapticPattern == .long)
    }

    // MARK: - 4. Settings Defaults & Mute Logic

    @Test("SoundAlertSettings initializes with all sounds enabled and handles mute window")
    func testSettingsAndMute() {
        var settings = SoundAlertSettings()
        #expect(settings.enabledSounds.count == SoundAlertType.allCases.count)
        #expect(settings.isListening == true)
        #expect(settings.isMuted == false)

        // Enable mute for 5 minutes
        settings.mutedUntil = Date().addingTimeInterval(300)
        #expect(settings.isMuted == true)

        // Past mute expires
        settings.mutedUntil = Date().addingTimeInterval(-10)
        #expect(settings.isMuted == false)
    }

    // MARK: - 5. History Repository

    @Test("SoundAlertHistoryRepository stores alerts, returns sorted by date, and supports clear")
    func testHistoryRepository() {
        let repo = StubSoundAlertHistoryRepository()
        #expect(repo.getHistory().isEmpty)

        let t1 = Date().addingTimeInterval(-200)
        let t2 = Date().addingTimeInterval(-100)
        let alert1 = SoundAlertRecord(type: .doorbell, timestamp: t1, confidence: 0.92)
        let alert2 = SoundAlertRecord(type: .fireAlarm, timestamp: t2, confidence: 0.98, isEmergency: true)

        repo.addAlert(alert1)
        repo.addAlert(alert2)

        let history = repo.getHistory()
        #expect(history.count == 2)
        #expect(history.first?.type == .fireAlarm) // Most recent first
        #expect(history.last?.type == .doorbell)
        #expect(history.first?.isEmergency == true)

        repo.clearHistory()
        #expect(repo.getHistory().isEmpty)
    }

    // MARK: - 6. Mock Service and ViewModel Observation

    @Test("SoundAlertsViewModel handles simulated alerts, updates history, and sets activeAlert")
    @MainActor
    func testViewModelFlow() async throws {
        let mockService = MockSoundAlertService()
        let repo = StubSoundAlertHistoryRepository()
        let viewModel = SoundAlertsViewModel(
            service: mockService,
            historyRepository: repo
        )

        #expect(viewModel.history.isEmpty)
        #expect(viewModel.activeAlert == nil)

        // Trigger alert simulation
        viewModel.simulateAlert(.doorbell)

        // Allow task loop to yield
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(viewModel.activeAlert?.type == .doorbell)
        #expect(viewModel.history.count == 1)
        #expect(viewModel.history.first?.type == .doorbell)

        // Dismiss alert
        viewModel.dismissAlert()
        #expect(viewModel.activeAlert == nil)

        // Mute 5 min
        viewModel.muteFor5Minutes()
        #expect(viewModel.isMuted == true)
        #expect(viewModel.remainingMuteSeconds > 280)

        // Unmute
        viewModel.unmute()
        #expect(viewModel.isMuted == false)
        #expect(viewModel.remainingMuteSeconds == 0)
    }

    // MARK: - 7. Customization Settings

    @Test("Customization updates per-sound sensitivity and haptic patterns")
    @MainActor
    func testCustomizationSettings() {
        let mockService = MockSoundAlertService()
        let repo = StubSoundAlertHistoryRepository()
        let viewModel = SoundAlertsViewModel(
            service: mockService,
            historyRepository: repo
        )

        // Toggle sound
        #expect(viewModel.settings.enabledSounds.contains(.babyCrying))
        viewModel.toggleSound(.babyCrying)
        #expect(!viewModel.settings.enabledSounds.contains(.babyCrying))
        viewModel.toggleSound(.babyCrying)
        #expect(viewModel.settings.enabledSounds.contains(.babyCrying))

        // Set sensitivity
        viewModel.setSensitivity(.high, for: .doorbell)
        #expect(viewModel.settings.sensitivity(for: .doorbell) == .high)

        // Set haptic pattern
        viewModel.setHapticPattern(.sos, for: .doorbell)
        #expect(viewModel.settings.hapticPattern(for: .doorbell) == .sos)
    }
}
