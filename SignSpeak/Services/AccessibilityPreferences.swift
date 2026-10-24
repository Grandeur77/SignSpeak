import SwiftUI
import Combine

/// Alert vibration strength setting.
public enum AlertVibrationStrength: String, CaseIterable, Identifiable, Codable, Sendable {
    case light = "Light"
    case medium = "Medium"
    case strong = "Strong"

    public var id: String { rawValue }
}

/// High contrast preference setting.
public enum ContrastPreference: String, CaseIterable, Identifiable, Codable, Sendable {
    case system = "Follow System"
    case high = "High Contrast"
    case standard = "Standard"

    public var id: String { rawValue }
}

/// Reduce motion preference setting.
public enum MotionPreference: String, CaseIterable, Identifiable, Codable, Sendable {
    case system = "Follow System"
    case reduced = "Reduced Motion"
    case standard = "Standard"

    public var id: String { rawValue }
}

/// Service managing accessibility settings app-wide (`55-accessibility`).
/// Controls haptic recognition feedback, alert vibrations, flashing screen,
/// contrast & motion overrides, dynamic text size preview, and left-handed signing mode.
@Observable
public final class AccessibilityPreferences: @unchecked Sendable {
    private let lock = NSRecursiveLock()
    private let userDefaults: UserDefaults

    public var hapticFeedbackEnabled: Bool {
        didSet { save() }
    }
    public var alertVibrationStrength: AlertVibrationStrength {
        didSet { save() }
    }
    public var flashScreenOnSoundAlerts: Bool {
        didSet { save() }
    }
    public var highContrastOverride: ContrastPreference {
        didSet { save() }
    }
    public var reduceMotionOverride: MotionPreference {
        didSet { save() }
    }
    public var textSizeMultiplier: Double {
        didSet { save() }
    }
    public var leftHandedMode: Bool {
        didSet { save() }
    }

    public static let shared = AccessibilityPreferences()

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        // Load persisted values or use accessibility defaults
        let haptic = userDefaults.object(forKey: "signspeak.pref.hapticFeedbackEnabled") as? Bool ?? true
        let rawVibration = userDefaults.string(forKey: "signspeak.pref.alertVibrationStrength") ?? AlertVibrationStrength.medium.rawValue
        let vibration = AlertVibrationStrength(rawValue: rawVibration) ?? .medium
        let flash = userDefaults.object(forKey: "signspeak.pref.flashScreenOnSoundAlerts") as? Bool ?? true
        let rawContrast = userDefaults.string(forKey: "signspeak.pref.highContrastOverride") ?? ContrastPreference.system.rawValue
        let contrast = ContrastPreference(rawValue: rawContrast) ?? .system
        let rawMotion = userDefaults.string(forKey: "signspeak.pref.reduceMotionOverride") ?? MotionPreference.system.rawValue
        let motion = MotionPreference(rawValue: rawMotion) ?? .system
        let textScale = userDefaults.object(forKey: "signspeak.pref.textSizeMultiplier") as? Double ?? 1.0
        let leftHanded = userDefaults.object(forKey: "signspeak.pref.leftHandedMode") as? Bool ?? false

        self.hapticFeedbackEnabled = haptic
        self.alertVibrationStrength = vibration
        self.flashScreenOnSoundAlerts = flash
        self.highContrastOverride = contrast
        self.reduceMotionOverride = motion
        self.textSizeMultiplier = textScale
        self.leftHandedMode = leftHanded
    }

    public func save() {
        lock.lock()
        defer { lock.unlock() }

        userDefaults.set(hapticFeedbackEnabled, forKey: "signspeak.pref.hapticFeedbackEnabled")
        userDefaults.set(alertVibrationStrength.rawValue, forKey: "signspeak.pref.alertVibrationStrength")
        userDefaults.set(flashScreenOnSoundAlerts, forKey: "signspeak.pref.flashScreenOnSoundAlerts")
        userDefaults.set(highContrastOverride.rawValue, forKey: "signspeak.pref.highContrastOverride")
        userDefaults.set(reduceMotionOverride.rawValue, forKey: "signspeak.pref.reduceMotionOverride")
        userDefaults.set(textSizeMultiplier, forKey: "signspeak.pref.textSizeMultiplier")
        userDefaults.set(leftHandedMode, forKey: "signspeak.pref.leftHandedMode")
    }

    public func resetToDefaults() {
        lock.lock()
        defer { lock.unlock() }

        hapticFeedbackEnabled = true
        alertVibrationStrength = .medium
        flashScreenOnSoundAlerts = true
        highContrastOverride = .system
        reduceMotionOverride = .system
        textSizeMultiplier = 1.0
        leftHandedMode = false
    }

    /// Triggers a test haptic according to current vibration setting.
    @MainActor
    public func triggerTestHaptic() {
        switch alertVibrationStrength {
        case .light:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
        case .medium:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
        case .strong:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
        }
    }
}

// MARK: - SwiftUI Environment Key

public struct AccessibilityPreferencesKey: EnvironmentKey {
    public static let defaultValue: AccessibilityPreferences = .shared
}

public extension EnvironmentValues {
    var accessibilityPreferences: AccessibilityPreferences {
        get { self[AccessibilityPreferencesKey.self] }
        set { self[AccessibilityPreferencesKey.self] = newValue }
    }
}
