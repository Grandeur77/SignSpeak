import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Timeline Entry

public struct QuickCommunicatorEntry: TimelineEntry {
    public let date: Date
    public let phrases: [QuickPhraseSnapshot]

    public init(date: Date, phrases: [QuickPhraseSnapshot]) {
        self.date = date
        self.phrases = phrases
    }
}

// MARK: - Timeline Provider

public struct QuickCommunicatorTimelineProvider: TimelineProvider {
    public init() {}

    public func placeholder(in context: Context) -> QuickCommunicatorEntry {
        QuickCommunicatorEntry(date: Date(), phrases: QuickPhraseSnapshot.defaultPhrases)
    }

    public func getSnapshot(in context: Context, completion: @escaping (QuickCommunicatorEntry) -> Void) {
        let snapshot = SharedStore.shared.fetchSnapshot()
        completion(QuickCommunicatorEntry(date: Date(), phrases: snapshot.quickPhrases))
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<QuickCommunicatorEntry>) -> Void) {
        let snapshot = SharedStore.shared.fetchSnapshot()
        let entry = QuickCommunicatorEntry(date: Date(), phrases: snapshot.quickPhrases)
        let nextMidnight = SignOfTheDayProvider.nextMidnight(after: Date())
        let timeline = Timeline(entries: [entry], policy: .after(nextMidnight))
        completion(timeline)
    }
}

// MARK: - Widget View

public struct QuickCommunicatorWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: QuickCommunicatorEntry

    private let deafNavy = Color(red: 0.0, green: 0.176, blue: 0.384)
    private let deafYellow = Color(red: 0.992, green: 0.725, blue: 0.075)
    private let deafTurquoise = Color(red: 0.078, green: 0.749, blue: 0.749)

    public var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumView
            case .systemLarge:
                largeView
            default:
                mediumView
            }
        }
        .containerBackground(for: .widget) {
            deafNavy
        }
    }

    // MARK: - System Medium (Interactive 2x2 Grid)
    private var mediumView: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(deafYellow)
                    Text("COMMUNICATOR")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(deafYellow)
                        .tracking(1.0)
                }

                Spacer()

                Button(intent: OpenCommunicatorIntent()) {
                    HStack(spacing: 3) {
                        Text("Open")
                            .font(.system(size: 10, weight: .bold))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // 2x2 Phrase Grid
            let items = Array(entry.phrases.prefix(4))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(items) { phrase in
                    Button(intent: SpeakPhraseIntent(phrase: phrase.text)) {
                        HStack(spacing: 6) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(phrase.isEmergency ? Color.orange : deafTurquoise)

                            Text(phrase.text)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            phrase.isEmergency
                                ? Color.orange.opacity(0.18)
                                : Color.white.opacity(0.08)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
    }

    // MARK: - System Large (Rich List with Categories & Speak Buttons)
    private var largeView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform.badge.magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundStyle(deafYellow)
                        Text("QUICK COMMUNICATOR")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(deafYellow)
                            .tracking(1.2)
                    }
                    Text("Tap to speak aloud instantly")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.6))
                }

                Spacer()

                Button(intent: OpenCommunicatorIntent()) {
                    HStack(spacing: 4) {
                        Text("Live Talk")
                            .font(.system(size: 11, weight: .bold))
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 10))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .foregroundStyle(deafNavy)
                    .background(deafYellow)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Phrase Cards
            let items = Array(entry.phrases.prefix(4))
            VStack(spacing: 8) {
                ForEach(items) { phrase in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(phrase.category.uppercased())
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundStyle(phrase.isEmergency ? Color.orange : deafTurquoise)
                                .tracking(0.8)

                            Text(phrase.text)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button(intent: SpeakPhraseIntent(phrase: phrase.text)) {
                            HStack(spacing: 4) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 10))
                                Text("Speak")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .foregroundStyle(Color.white)
                            .background(deafTurquoise.opacity(0.25))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        phrase.isEmergency
                            ? Color.orange.opacity(0.15)
                            : Color.white.opacity(0.06)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            Spacer()

            // Emergency Bottom Bar
            Link(destination: URL(string: "signspeak://communicator")!) {
                HStack {
                    Spacer()
                    Image(systemName: "keyboard")
                        .font(.system(size: 11))
                    Text("Type to Speak in Fullscreen")
                        .font(.system(size: 11, weight: .bold))
                    Spacer()
                }
                .padding(.vertical, 9)
                .foregroundStyle(Color.white.opacity(0.85))
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(14)
    }
}

// MARK: - Widget Declaration

public struct QuickCommunicatorWidget: Widget {
    public let kind: String = "com.signspeak.widget.quickCommunicator"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickCommunicatorTimelineProvider()) { entry in
            QuickCommunicatorWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Quick Communicator")
        .description("Instantly speak essential phrases and open two-way live communication.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
