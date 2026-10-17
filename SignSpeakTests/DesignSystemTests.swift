import SwiftUI
import UIKit
import Testing
@testable import SignSpeak

@Suite("Design System & Color Assets")
struct DesignSystemTests {
    @Test("Tap target meets Apple HIG minimum requirement of 44pt")
    func minimumTapTargetRequirement() {
        #expect(Theme.minTapTarget >= 44)
    }

    @Test("All Deaf Flag and semantic color assets exist in asset catalog")
    func assetCatalogColorsExist() {
        let expectedColors = [
            "BrandNavy",
            "BrandTurquoise",
            "BrandYellow",
            "AppBackground",
            "CardBackground",
            "PrimaryFill",
            "OnPrimary",
            "AccentText",
            "TextPrimary",
            "TextSecondary",
            "Success",
            "Danger"
        ]

        for colorName in expectedColors {
            let uiColor = UIColor(named: colorName, in: Bundle(for: AppDelegate.self), compatibleWith: nil)
            #expect(uiColor != nil, "Asset catalog color '\(colorName)' is missing")
        }
    }

    @Test("AppTextStyle maps to valid fonts")
    func typographyStyles() {
        #expect(AppTextStyle.largeTitle.font == .appLargeTitle)
        #expect(AppTextStyle.title.font == .appTitle)
        #expect(AppTextStyle.headline.font == .appHeadline)
        #expect(AppTextStyle.body.font == .appBody)
        #expect(AppTextStyle.caption.font == .appCaption)
    }
}
