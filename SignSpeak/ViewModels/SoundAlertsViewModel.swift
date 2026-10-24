import SwiftUI
import Observation
import UIKit

/// ViewModel managing state, live audio detection, customization, and emergency actions for Sound Alerts.
/// Maps to screens `61-sound-alerts-home`, `62-sound-alerts-setup`, `63-sound-alert-doorbell`,
/// `64-sound-alert-history`, `65-sound-alert-fire-emergency`, and `66-sound-alerts-customise`.
@Observable
@MainActor
public final class SoundAlertsViewModel {
    public let service: any SoundAlerting
    public let historyRepository: any SoundAlertHistoryRepository
    public let hapticService: HapticFeedbackService
    public let torchService: TorchService

    private let settingsKey = "signspeak.soundalert.settings"
    public var settings: SoundAlertSettings {
        didSet {
            saveSettings()
            service.updateSettings(settings)
        }
    }

    public var history: [SoundAlertRecord] = []
    public var activeAlert: SoundAlertRecord?
    public var remainingMuteSeconds: Int = 0

    public var isShowingCustomise: Bool = false
    public var isShowingHistory: Bool = false
    public var isShowingSetup: Bool = false

    private var alertStreamTask: Task<Void, Never>?
    private var muteTimerTask: Task<Void, Never>?

    public var isListening: Bool {
        service.isListening && settings.isListening && !settings.isMuted
    }

    public var isMuted: Bool {
        settings.isMuted
    }

    public init(
        service: any SoundAlerting,
        historyRepository: any SoundAlertHistoryRepository,
        hapticService: HapticFeedbackService? = nil,
        torchService: TorchService? = nil
    ) {
        self.service = service
        self.historyRepository = historyRepository
        self.hapticService = hapticService ?? .shared
        self.torchService = torchService ?? .shared

        // Load saved settings or fall back to defaults
        if let data = UserDefaults.standard.data(forKey: "signspeak.soundalert.settings"),
           let decoded = try? JSONDecoder().decode(SoundAlertSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = SoundAlertSettings()
        }

        self.history = historyRepository.getHistory()
        updateMuteCountdown()
        startObservingAlertStream()
    }

    // MARK: - Lifecycle & Observation

    public func start() {
        if settings.isListening {
            Task {
                try? await service.startListening()
            }
        }
        history = historyRepository.getHistory()
    }

    private func startObservingAlertStream() {
        alertStreamTask?.cancel()
        alertStreamTask = Task { [weak self] in
            guard let stream = self?.service.alertStream else { return }
            for await alert in stream {
                guard let self else { return }
                self.handleIncomingAlert(alert)
            }
        }
    }

    private func handleIncomingAlert(_ alert: SoundAlertRecord) {
        // Record in history
        historyRepository.addAlert(alert)
        history = historyRepository.getHistory()

        // Set active alert for modal display
        activeAlert = alert

        // Fire haptic pattern
        let pattern = settings.hapticPattern(for: alert.type)
        hapticService.play(pattern)

        // Flash torch if enabled
        if settings.flashTorch {
            torchService.flash(times: alert.isEmergency ? 5 : 3)
        }

        // VoiceOver accessibility announcement
        let announcement = alert.isEmergency
            ? "EMERGENCY ALERT: \(alert.type.title) detected. Take immediate action."
            : "Sound Alert: \(alert.type.title) detected with \(Int(alert.confidence * 100)) percent confidence."
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }

    // MARK: - Actions

    public func toggleListening() {
        settings.isListening.toggle()
        if settings.isListening {
            Task { try? await service.startListening() }
        } else {
            service.stopListening()
        }
    }

    public func toggleSound(_ type: SoundAlertType) {
        if settings.enabledSounds.contains(type) {
            settings.enabledSounds.remove(type)
        } else {
            settings.enabledSounds.insert(type)
        }
    }

    public func setSensitivity(_ sensitivity: SoundAlertSensitivity, for type: SoundAlertType) {
        settings.sensitivities[type] = sensitivity
    }

    public func setHapticPattern(_ pattern: HapticPattern, for type: SoundAlertType) {
        settings.hapticPatterns[type] = pattern
    }

    public func testHapticPattern(_ pattern: HapticPattern) {
        hapticService.play(pattern)
    }

    public func muteFor5Minutes() {
        let muteEnd = Date().addingTimeInterval(300)
        settings.mutedUntil = muteEnd
        updateMuteCountdown()
    }

    public func unmute() {
        settings.mutedUntil = nil
        remainingMuteSeconds = 0
        muteTimerTask?.cancel()
    }

    public func dismissAlert() {
        activeAlert = nil
    }

    public func simulateAlert(_ type: SoundAlertType) {
        let record = SoundAlertRecord(
            type: type,
            timestamp: Date(),
            confidence: 0.94,
            isEmergency: type.isUrgent
        )
        service.simulateAlert(record)
    }

    public func clearHistory() {
        historyRepository.clearHistory()
        history = []
    }

    // MARK: - Emergency Communications

    public func callEmergencyServices() {
        // Universal emergency dispatch
        if let url = URL(string: "tel://911"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    public func notifyEmergencyContact() {
        guard let phone = settings.emergencyContactPhone?.filter({ $0.isNumber || $0 == "+" }), !phone.isEmpty else {
            return
        }

        let alertName = activeAlert?.type.title ?? "Alarm"
        let body = "SignSpeak Emergency Alert: \(alertName) has been detected at my location. Please contact or check on me."
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "sms:\(phone)&body=\(encodedBody)"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Persistence & Timers

    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }

    private func updateMuteCountdown() {
        muteTimerTask?.cancel()
        guard let until = settings.mutedUntil, until > Date() else {
            remainingMuteSeconds = 0
            return
        }

        remainingMuteSeconds = Int(ceil(until.timeIntervalSince(Date())))

        muteTimerTask = Task { [weak self] in
            while true {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self else { break }
                if let until = self.settings.mutedUntil, until > Date() {
                    self.remainingMuteSeconds = Int(ceil(until.timeIntervalSince(Date())))
                } else {
                    self.remainingMuteSeconds = 0
                    self.settings.mutedUntil = nil
                    break
                }
            }
        }
    }
}
