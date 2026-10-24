import SwiftUI
import WidgetKit

/// Central WidgetBundle combining all SignSpeak Home and Lock Screen widgets.
public struct SignSpeakWidgetsBundle: WidgetBundle {
    public init() {}

    public var body: some Widget {
        StreakWidget()
        SignOfTheDayWidget()
        QuickCommunicatorWidget()
    }
}
