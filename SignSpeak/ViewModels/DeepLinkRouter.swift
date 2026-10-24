import SwiftUI

/// Structured destination parsed from a deep-link URL.
public enum DeepLinkDestination: Equatable, Sendable {
    case tab(AppTab)
    case profile
    case practice(signId: String?)
    case communicator
    case signDetail(signId: String)
    case signsSearch(query: String)
    case soundAlerts
    case inbox
    case community
}

/// Central deep-link coordinator handling `signspeak://` custom scheme URLs
/// and widget / notification shortcuts across the entire app hierarchy.
@Observable
@MainActor
public final class DeepLinkRouter {
    public var selectedTab: AppTab = .home
    public var isPresentingProfile: Bool = false
    public var activeDestination: DeepLinkDestination?

    public init(initialTab: AppTab = .home) {
        self.selectedTab = initialTab
    }

    /// Parses an incoming URL and updates router state accordingly.
    /// Returns `true` if the URL was recognized and handled.
    @discardableResult
    public func handle(url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "signspeak" else {
            return false
        }

        let host = url.host?.lowercased() ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        // 1. Direct Tab Routes: signspeak://home, signspeak://learn, etc.
        if let tab = AppTab(rawValue: host) {
            selectedTab = tab

            // Check query items on tab route
            if tab == .signs, let query = queryItems.first(where: { $0.name == "query" })?.value, !query.isEmpty {
                activeDestination = .signsSearch(query: query)
            } else if tab == .learn, let sign = queryItems.first(where: { $0.name == "sign" })?.value, !sign.isEmpty {
                activeDestination = .practice(signId: sign)
            } else {
                activeDestination = .tab(tab)
            }
            return true
        }

        // 2. Specific Feature Routes
        switch host {
        case "profile":
            isPresentingProfile = true
            activeDestination = .profile
            return true

        case "practice":
            selectedTab = .learn
            let signId = queryItems.first(where: { $0.name == "sign" })?.value
            activeDestination = .practice(signId: signId)
            return true

        case "communicator", "talk-live":
            selectedTab = .talk
            activeDestination = .communicator
            return true

        case "sign":
            selectedTab = .signs
            if let signId = pathComponents.first {
                activeDestination = .signDetail(signId: signId)
            } else if let signId = queryItems.first(where: { $0.name == "id" })?.value {
                activeDestination = .signDetail(signId: signId)
            }
            return true

        case "alerts", "sound-alerts":
            selectedTab = .home
            activeDestination = .soundAlerts
            return true

        case "inbox", "notifications":
            selectedTab = .home
            activeDestination = .inbox
            return true

        case "community":
            selectedTab = .home
            activeDestination = .community
            return true

        default:
            return false
        }
    }

    /// Programmatically opens the user Profile sheet.
    public func openProfile() {
        isPresentingProfile = true
    }

    /// Programmatically closes the user Profile sheet.
    public func closeProfile() {
        isPresentingProfile = false
    }
}
