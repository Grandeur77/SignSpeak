import SwiftUI

/// Two-way conversation display and interaction modes (design `38-communicator-start`, `39a`, `39b`).
public enum ConversationMode: String, CaseIterable, Identifiable, Sendable {
    /// Opposite sides of table. Partner transcript at top is rotated 180° for them to read easily while user signs.
    case faceToFaceSplit = "faceToFaceSplit"
    /// Large oversized text card to display recognized signs clearly across a counter or in noisy environments.
    case showTextToOthers = "showTextToOthers"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .faceToFaceSplit:
            return "Face-to-Face Split Screen"
        case .showTextToOthers:
            return "Show Text to Others"
        }
    }

    public var subtitle: String {
        switch self {
        case .faceToFaceSplit:
            return "Phone on table between you. Partner transcript rotates 180° so they read comfortably while you sign."
        case .showTextToOthers:
            return "Large high-contrast text card to show hearing people across a counter, register, or noisy room."
        }
    }

    public var badgeText: String {
        switch self {
        case .faceToFaceSplit:
            return "Recommended for 1-on-1"
        case .showTextToOthers:
            return "Counter & Desk Mode"
        }
    }

    public var iconName: String {
        switch self {
        case .faceToFaceSplit:
            return "rectangle.split.2x1.fill"
        case .showTextToOthers:
            return "text.bubble.fill"
        }
    }
}

/// User's dominant signing hand for gesture calibration and coordinate normalization.
public enum DominantHand: String, CaseIterable, Identifiable, Sendable {
    case right = "right"
    case left = "left"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .right: return "Right Hand"
        case .left: return "Left Hand"
        }
    }

    public var shortDescription: String {
        switch self {
        case .right: return "Right hand performs primary motion & finger-spelling"
        case .left: return "Left hand performs primary motion & finger-spelling"
        }
    }

    public var iconName: String {
        switch self {
        case .right: return "hand.raised.right.fill"
        case .left: return "hand.raised.fill"
        }
    }
}

/// Ambient room lighting quality assessment for optical hand tracking.
public enum LightingQuality: String, Sendable, Equatable {
    case optimal
    case good
    case lowLight

    public var title: String {
        switch self {
        case .optimal: return "Optimal Lighting"
        case .good: return "Good Lighting"
        case .lowLight: return "Low Light Warning"
        }
    }

    public var description: String {
        switch self {
        case .optimal:
            return "Excellent contrast. Camera can detect hand keypoints with maximum accuracy."
        case .good:
            return "Lighting is sufficient for sign recognition."
        case .lowLight:
            return "Environment is dim. Move towards a light source or face a window for reliable recognition."
        }
    }

    public var iconName: String {
        switch self {
        case .optimal: return "sun.max.fill"
        case .good: return "sun.min.fill"
        case .lowLight: return "exclamationmark.triangle.fill"
        }
    }

    public var color: Color {
        switch self {
        case .optimal: return .green
        case .good: return .brandTurquoise
        case .lowLight: return .brandYellow
        }
    }
}
