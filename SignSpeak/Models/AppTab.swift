import Foundation

/// Primary navigation destinations within the SignSpeak application shell.
/// Standardized across iPhone (TabView) and iPad (NavigationSplitView sidebar).
public enum AppTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case home
    case learn
    case talk
    case signs
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .home: return "Home"
        case .learn: return "Learn"
        case .talk: return "Talk"
        case .signs: return "Signs"
        case .settings: return "Settings"
        }
    }

    public var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .learn: return "sparkles"
        case .talk: return "bubble.left.and.bubble.right.fill"
        case .signs: return "book.closed.fill"
        case .settings: return "gearshape.fill"
        }
    }
}
