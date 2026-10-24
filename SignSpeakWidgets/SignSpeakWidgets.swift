import SwiftUI
import WidgetKit
import AppIntents

@main
struct SignSpeakWidgets: WidgetBundle {
    var body: some Widget {
        StreakWidget()
        SignOfTheDayWidget()
        QuickCommunicatorWidget()
    }
}
