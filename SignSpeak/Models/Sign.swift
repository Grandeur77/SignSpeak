import Foundation

/// Recognition engine capability for a sign.
public enum SignRecognitionType: String, Codable, Sendable, CaseIterable {
    case staticSign = "static"
    case motionSign = "motion"
    case none = "none"

    public var title: String {
        switch self {
        case .staticSign: return "Static Pose"
        case .motionSign: return "Motion Gesture"
        case .none: return "Visual Only"
        }
    }
}

/// Handedness requirement for executing the sign.
public enum SignHandedness: String, Codable, Sendable, CaseIterable {
    case oneHanded = "one_handed"
    case twoHanded = "two_handed"
    case dominant = "dominant"

    public var displayName: String {
        switch self {
        case .oneHanded: return "One Hand"
        case .twoHanded: return "Both Hands"
        case .dominant: return "Dominant Hand"
        }
    }
}

/// Learning difficulty level for a sign.
public enum SignLevel: String, Codable, Sendable, CaseIterable, Comparable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"

    public var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }

    private var sortOrder: Int {
        switch self {
        case .beginner: return 1
        case .intermediate: return 2
        case .advanced: return 3
        }
    }

    public static func < (lhs: SignLevel, rhs: SignLevel) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

/// Detailed dictionary and curriculum sign model.
public struct Sign: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let pronunciationHint: String?
    public let category: String
    public let level: SignLevel
    public let frequencyTag: String?
    public let handedness: SignHandedness
    public let recognition: SignRecognitionType
    public let description: String
    public let howToSteps: [String]
    public let commonMistake: String?
    public let mnemonicTip: String?
    public let imageName: String?
    public let frontVideoName: String?
    public let sideVideoName: String?

    public init(
        id: String,
        name: String,
        pronunciationHint: String? = nil,
        category: String,
        level: SignLevel = .beginner,
        frequencyTag: String? = nil,
        handedness: SignHandedness = .oneHanded,
        recognition: SignRecognitionType = .staticSign,
        description: String,
        howToSteps: [String],
        commonMistake: String? = nil,
        mnemonicTip: String? = nil,
        imageName: String? = nil,
        frontVideoName: String? = nil,
        sideVideoName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.pronunciationHint = pronunciationHint
        self.category = category
        self.level = level
        self.frequencyTag = frequencyTag
        self.handedness = handedness
        self.recognition = recognition
        self.description = description
        self.howToSteps = howToSteps
        self.commonMistake = commonMistake
        self.mnemonicTip = mnemonicTip
        self.imageName = imageName
        self.frontVideoName = frontVideoName
        self.sideVideoName = sideVideoName
    }
}
