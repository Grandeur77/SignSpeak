import SwiftUI

/// Apple Human Interface Guidelines and Deaf Flag design system tokens.
enum Theme {
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let button: CGFloat = 16
        static let card: CGFloat = 20
        static let sheet: CGFloat = 24
    }

    /// Apple HIG minimum size for anything tappable.
    static let minTapTarget: CGFloat = 44
}

/// App typography roles mapped directly to Dynamic Type styles so they scale
/// with the user's preferred text size while preserving bold hierarchy.
extension Font {
    static let appLargeTitle = Font.largeTitle.weight(.bold)
    static let appTitle = Font.title.weight(.bold)
    static let appTitle2 = Font.title2.weight(.bold)
    static let appSectionTitle = Font.title3.weight(.semibold)
    static let appHeadline = Font.headline
    static let appBody = Font.body
    static let appCaption = Font.caption
    static let appButton = Font.headline
}

/// Role-based typography tokens for consistent screen hierarchies.
enum AppTextStyle {
    case largeTitle
    case title
    case headline
    case body
    case caption

    var font: Font {
        switch self {
        case .largeTitle:
            return .appLargeTitle
        case .title:
            return .appTitle
        case .headline:
            return .appHeadline
        case .body:
            return .appBody
        case .caption:
            return .appCaption
        }
    }
}

extension View {
    /// Applies a standard SignSpeak typography role to the view.
    func appTextStyle(_ style: AppTextStyle) -> some View {
        self.font(style.font)
    }
}

/// Colours live in `Assets.xcassets/Colors` (each with a dark-mode variant) and are
/// automatically exposed on `Color` and `ShapeStyle` by Xcode's symbol generator:
/// `.brandNavy`, `.brandTurquoise`, `.brandYellow`, `.appBackground`, `.cardBackground`,
/// `.primaryFill`, `.onPrimary`, `.accentText`, `.textPrimary`, `.textSecondary`, `.success`, `.danger`.

