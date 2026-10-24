import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

public struct SignOfTheDayEntry: TimelineEntry {
    public let date: Date
    public let sign: SignOfTheDaySnapshot

    public init(date: Date, sign: SignOfTheDaySnapshot) {
        self.date = date
        self.sign = sign
    }
}

// MARK: - Timeline Provider

public struct SignOfTheDayTimelineProvider: TimelineProvider {
    public init() {}

    public func placeholder(in context: Context) -> SignOfTheDayEntry {
        SignOfTheDayEntry(date: Date(), sign: SignOfTheDaySnapshot.fallback)
    }

    public func getSnapshot(in context: Context, completion: @escaping (SignOfTheDayEntry) -> Void) {
        let sign = SignOfTheDayProvider.signOfTheDay(for: Date())
        completion(SignOfTheDayEntry(date: Date(), sign: sign))
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<SignOfTheDayEntry>) -> Void) {
        let currentDate = Date()
        let sign = SignOfTheDayProvider.signOfTheDay(for: currentDate)
        let entry = SignOfTheDayEntry(date: currentDate, sign: sign)

        // Advance to next sign automatically at midnight
        let nextMidnight = SignOfTheDayProvider.nextMidnight(after: currentDate)
        let timeline = Timeline(entries: [entry], policy: .after(nextMidnight))
        completion(timeline)
    }
}

// MARK: - Widget View

public struct SignOfTheDayWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: SignOfTheDayEntry

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

    // MARK: - System Medium
    private var mediumView: some View {
        HStack(spacing: 12) {
            // Left Hero Sign Badge
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.08))

                VStack(spacing: 4) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(deafYellow)

                    Text(entry.sign.name)
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white)

                    Text(entry.sign.category.uppercased())
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(deafTurquoise)
                        .tracking(0.8)
                }
                .padding(10)
            }
            .frame(width: 105)

            // Right Detail & Action
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("SIGN OF THE DAY")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(deafYellow)
                        .tracking(1.0)
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundStyle(deafYellow)
                }

                Text(entry.sign.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)

                Text(entry.sign.description)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .lineLimit(2)
                    .lineSpacing(1.5)

                Spacer()

                Link(destination: URL(string: "signspeak://practice?sign=\(entry.sign.id)")!) {
                    HStack(spacing: 6) {
                        Text("Practice Sign")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(deafNavy)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(deafNavy)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(deafYellow)
                    .clipShape(Capsule())
                }
            }
            .padding(.vertical, 4)
        }
        .padding(10)
    }

    // MARK: - System Large
    private var largeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SIGN OF THE DAY")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(deafYellow)
                        .tracking(1.2)
                    Text(DateFormatter.localizedString(from: entry.date, dateStyle: .medium, timeStyle: .none))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.6))
                }

                Spacer()

                Text(entry.sign.category)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(deafTurquoise)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(deafTurquoise.opacity(0.18))
                    .clipShape(Capsule())
            }

            // Visual Presentation Card
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.06))

                VStack(spacing: 8) {
                    Image(systemName: "hand.wave.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(deafYellow)

                    Text(entry.sign.name)
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white)

                    Text(entry.sign.category.uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(deafYellow.opacity(0.9))
                        .tracking(1.5)
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)

            // Description / Anatomical Hint
            VStack(alignment: .leading, spacing: 4) {
                Text("How to perform")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.9))

                Text(entry.sign.description)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .lineSpacing(2)
            }

            Spacer()

            // Action Buttons
            HStack(spacing: 10) {
                Link(destination: URL(string: "signspeak://practice?sign=\(entry.sign.id)")!) {
                    HStack {
                        Spacer()
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 12, weight: .bold))
                        Text("Practice Sign")
                            .font(.system(size: 12, weight: .bold))
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .foregroundStyle(deafNavy)
                    .background(deafYellow)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Link(destination: URL(string: "signspeak://signs")!) {
                    HStack {
                        Spacer()
                        Text("Directory")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .foregroundStyle(Color.white)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(14)
    }
}

// MARK: - Widget Declaration

public struct SignOfTheDayWidget: Widget {
    public let kind: String = "com.signspeak.widget.signOfTheDay"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SignOfTheDayTimelineProvider()) { entry in
            SignOfTheDayWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Sign of the Day")
        .description("Discover and practice a new American Sign Language sign every day.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
