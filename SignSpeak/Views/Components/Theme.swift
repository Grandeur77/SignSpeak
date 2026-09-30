import SwiftUI

/// Colours live in `Assets.xcassets/Colors` (each with a dark-mode variant) and are
/// used through Xcode's generated symbols, e.g. `.foregroundStyle(.textPrimary)`.
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

/// App text styles. 
extension Font {
    static let appLargeTitle = Font.largeTitle.weight(.bold)
    static let appTitle = Font.title2.weight(.bold)
    static let appSectionTitle = Font.title3.weight(.semibold)
    static let appButton = Font.headline
}
