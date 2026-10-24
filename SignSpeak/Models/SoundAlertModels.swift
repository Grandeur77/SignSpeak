import Foundation

/// Sound detection category options for deaf / hard of hearing users (62-sound-alerts-setup).
public enum SoundAlertType: String, CaseIterable, Identifiable, Codable, Sendable {
    case doorbell
    case knocking
    case fireAlarm
    case sirens
    case babyCrying
    case nameCalling

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .doorbell: return "Doorbell"
        case .knocking: return "Knocking"
        case .fireAlarm: return "Fire alarm"
        case .sirens: return "Emergency sirens"
        case .babyCrying: return "Baby crying"
        case .nameCalling: return "Someone calling your name"
        }
    }

    public var subtitle: String {
        switch self {
        case .doorbell: return "Chimes & digital rings"
        case .knocking: return "Solid door thumps & raps"
        case .fireAlarm: return "Smoke detectors & continuous horn"
        case .sirens: return "Ambulance, police & public alarms"
        case .babyCrying: return "Distress sounds & sudden shrieks"
        case .nameCalling: return "Directional voice spikes & shouts"
        }
    }

    public var icon: String {
        switch self {
        case .doorbell: return "bell.fill"
        case .knocking: return "hand.tap.fill"
        case .fireAlarm: return "flame.fill"
        case .sirens: return "light.beacon.max.fill"
        case .babyCrying: return "figure.and.child.holdinghands"
        case .nameCalling: return "waveform.badge.magnifyingglass"
        }
    }

    public var isUrgent: Bool {
        self == .fireAlarm || self == .sirens
    }

    public var defaultHapticPattern: HapticPattern {
        switch self {
        case .doorbell, .knocking: return .pulse
        case .babyCrying, .nameCalling: return .long
        case .fireAlarm, .sirens: return .sos
        }
    }
}

/// Vibration pattern played through CoreHaptics (`CHHapticEngine`).
public enum HapticPattern: String, CaseIterable, Identifiable, Codable, Sendable {
    case pulse = "Pulse"
    case long = "Long"
    case sos = "SOS"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .pulse: return "3 rhythmic tap bursts"
        case .long: return "1 continuous vibration"
        case .sos: return "Morse code ... --- ... urgency pattern"
        }
    }
}

/// Sensitivity threshold for sound recognition.
public enum SoundAlertSensitivity: String, CaseIterable, Identifiable, Codable, Sendable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    public var id: String { rawValue }

    public var minimumConfidence: Double {
        switch self {
        case .low: return 0.50
        case .medium: return 0.70
        case .high: return 0.85
        }
    }
}

/// Historical record of a sound alert event (`64-sound-alert-history`).
public struct SoundAlertRecord: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let type: SoundAlertType
    public let timestamp: Date
    public let confidence: Double
    public let isEmergency: Bool

    public init(
        id: UUID = UUID(),
        type: SoundAlertType,
        timestamp: Date = Date(),
        confidence: Double,
        isEmergency: Bool? = nil
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.confidence = confidence
        self.isEmergency = isEmergency ?? type.isUrgent
    }
}

/// User customization and preferences for Sound Alerts (`66-sound-alerts-customise`).
public struct SoundAlertSettings: Codable, Sendable, Equatable {
    public var isListening: Bool
    public var enabledSounds: Set<SoundAlertType>
    public var hapticPatterns: [SoundAlertType: HapticPattern]
    public var sensitivities: [SoundAlertType: SoundAlertSensitivity]
    public var flashScreen: Bool
    public var flashTorch: Bool
    public var emergencyContactName: String?
    public var emergencyContactPhone: String?
    public var mutedUntil: Date?

    public init(
        isListening: Bool = true,
        enabledSounds: Set<SoundAlertType> = Set(SoundAlertType.allCases),
        hapticPatterns: [SoundAlertType: HapticPattern] = Dictionary(uniqueKeysWithValues: SoundAlertType.allCases.map { ($0, $0.defaultHapticPattern) }),
        sensitivities: [SoundAlertType: SoundAlertSensitivity] = Dictionary(uniqueKeysWithValues: SoundAlertType.allCases.map { ($0, .medium) }),
        flashScreen: Bool = true,
        flashTorch: Bool = true,
        emergencyContactName: String? = nil,
        emergencyContactPhone: String? = nil,
        mutedUntil: Date? = nil
    ) {
        self.isListening = isListening
        self.enabledSounds = enabledSounds
        self.hapticPatterns = hapticPatterns
        self.sensitivities = sensitivities
        self.flashScreen = flashScreen
        self.flashTorch = flashTorch
        self.emergencyContactName = emergencyContactName
        self.emergencyContactPhone = emergencyContactPhone
        self.mutedUntil = mutedUntil
    }

    public var isMuted: Bool {
        guard let mutedUntil else { return false }
        return Date() < mutedUntil
    }

    public func hapticPattern(for type: SoundAlertType) -> HapticPattern {
        hapticPatterns[type] ?? type.defaultHapticPattern
    }

    public func sensitivity(for type: SoundAlertType) -> SoundAlertSensitivity {
        sensitivities[type] ?? .medium
    }
}
