import Foundation
import Testing
@testable import SignSpeak

@Suite("AppShell & Deep-Link Routing")
@MainActor
struct AppShellTests {

    @Test("AppTab contains all 5 required navigation destinations with icons")
    func appTabIntegrity() {
        let tabs = AppTab.allCases
        #expect(tabs.count == 5)
        #expect(tabs == [.home, .learn, .talk, .signs, .settings])

        for tab in tabs {
            #expect(!tab.title.isEmpty)
            #expect(!tab.iconName.isEmpty)
            #expect(tab.id == tab.rawValue)
        }
    }

    @Test("DeepLinkRouter navigates directly to primary tabs")
    func directTabDeepLinks() {
        let router = DeepLinkRouter()

        let testCases: [(String, AppTab)] = [
            ("signspeak://home", .home),
            ("signspeak://learn", .learn),
            ("signspeak://talk", .talk),
            ("signspeak://signs", .signs),
            ("signspeak://settings", .settings)
        ]

        for (urlStr, expectedTab) in testCases {
            let url = URL(string: urlStr)!
            let handled = router.handle(url: url)
            #expect(handled)
            #expect(router.selectedTab == expectedTab)
        }
    }

    @Test("DeepLinkRouter presents profile modal via signspeak://profile")
    func profileDeepLink() {
        let router = DeepLinkRouter()
        #expect(!router.isPresentingProfile)

        let handled = router.handle(url: URL(string: "signspeak://profile")!)
        #expect(handled)
        #expect(router.isPresentingProfile)
        #expect(router.activeDestination == .profile)

        router.closeProfile()
        #expect(!router.isPresentingProfile)

        router.openProfile()
        #expect(router.isPresentingProfile)
    }

    @Test("DeepLinkRouter opens practice with specified sign query item")
    func practiceDeepLink() {
        let router = DeepLinkRouter()

        let handled = router.handle(url: URL(string: "signspeak://practice?sign=ThankYou")!)
        #expect(handled)
        #expect(router.selectedTab == .learn)
        #expect(router.activeDestination == .practice(signId: "ThankYou"))
    }

    @Test("DeepLinkRouter opens communicator via signspeak://communicator")
    func communicatorDeepLink() {
        let router = DeepLinkRouter()

        let handled = router.handle(url: URL(string: "signspeak://communicator")!)
        #expect(handled)
        #expect(router.selectedTab == .talk)
        #expect(router.activeDestination == .communicator)
    }

    @Test("DeepLinkRouter filters signs directory with query item")
    func signsSearchDeepLink() {
        let router = DeepLinkRouter()

        let handled = router.handle(url: URL(string: "signspeak://signs?query=Greetings")!)
        #expect(handled)
        #expect(router.selectedTab == .signs)
        #expect(router.activeDestination == .signsSearch(query: "Greetings"))
    }

    @Test("DeepLinkRouter routes to sign detail from path component")
    func signDetailDeepLink() {
        let router = DeepLinkRouter()

        let handled = router.handle(url: URL(string: "signspeak://sign/Hello")!)
        #expect(handled)
        #expect(router.selectedTab == .signs)
        #expect(router.activeDestination == .signDetail(signId: "Hello"))
    }

    @Test("DeepLinkRouter ignores invalid schemes and unknown paths gracefully")
    func invalidDeepLinksIgnored() {
        let router = DeepLinkRouter()
        router.selectedTab = .home

        let invalidScheme = URL(string: "https://signspeak.com/home")!
        #expect(!router.handle(url: invalidScheme))
        #expect(router.selectedTab == .home)

        let unknownPath = URL(string: "signspeak://non-existent-action")!
        #expect(!router.handle(url: unknownPath))
        #expect(router.selectedTab == .home)
    }
}
