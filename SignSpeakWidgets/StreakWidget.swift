import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

public struct StreakEntry: TimelineEntry {
    public let date: Date
    public let snapshot: WidgetSnapshot

    public init(date: Date, snapshot: WidgetSnapshot) {
        self.date = date
        self.snapshot = snapshot
    }
}

// MARK: - Timeline Provider

public struct StreakTimelineProvider: TimelineProvider {
    private let sharedStore: SharedStore

    public init(sharedStore: SharedStore = .shared) {
        self.sharedStore = sharedStore
    }

    public func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: Date(), snapshot: sharedStore.makeDefaultSnapshot())
    }

    public func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        let entry = StreakEntry(date: Date(), snapshot: sharedStore.fetchSnapshot())
        completion(entry)
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let currentDate = Date()
        let currentSnapshot = sharedStore.fetchSnapshot()
        let entry = StreakEntry(date: currentDate, snapshot: currentSnapshot)

        // Schedule refresh at midnight to advance daily streak state
        let nextMidnight = SignOfTheDayProvider.nextMidnight(after: currentDate)
        let timeline = Timeline(entries: [entry], policy: .after(nextMidnight))
        completion(timeline)
    }
}

// MARK: - Widget View

public struct StreakWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: StreakEntry

    // Deaf Flag Colors
    private let deafNavy = Color(red: 0.0, green: 0.176, blue: 0.384)
    private let deafYellow = Color(red: 0.992, green: 0.725, blue: 0.075)
    private let deafTurquoise = Color(red: 0.078, green: 0.749, blue: 0.749)

    public var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallView
            case .systemMedium:
                mediumView
            case .accessoryCircular:
                accessoryCircularView
            case .accessoryRectangular:
                accessoryRectangularView
            case .accessoryInline:
                accessoryInlineView
            default:
                mediumView
            }
        }
        .containerBackground(for: .widget) {
            deafNavy
        }
    }

    // MARK: - System Small (Home Screen)
    private var smallView: some View {
        Link(destination: URL(string: "signspeak://streak")!) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(deafYellow.opacity(0.2))
                            .frame(width: 32, height: 32)
                        Image(systemName: "flame.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(deafYellow)
                    }

                    Spacer()

                    Text("SignSpeak")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .textCase(.uppercase)
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(entry.snapshot.currentStreak)")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white)

                    Text("DAYS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(deafYellow)
                }

                Text("STREAK")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .tracking(1.2)

                // Today's Goal Ring / Bar
                VStack(alignment: .leading, spacing: 3) {
                    ProgressView(
                        value: Double(entry.snapshot.dailyGoalVerified),
                        total: Double(max(1, entry.snapshot.dailyGoalTarget))
                    )
                    .tint(deafTurquoise)

                    HStack {
                        Text("\(entry.snapshot.dailyGoalVerified)/\(entry.snapshot.dailyGoalTarget) signs")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.7))
                        Spacer()
                        if entry.snapshot.isGoalCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(deafTurquoise)
                        }
                    }
                }
            }
            .padding(12)
        }
    }

    // MARK: - System Medium (Home Screen, 01-widgets-home-screen)
    private var mediumView: some View {
        HStack(spacing: 12) {
            // Left Card: Streak Hero
            Link(destination: URL(string: "signspeak://streak")!) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(deafYellow)
                        Text("\(entry.snapshot.currentStreak) DAY STREAK")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(deafYellow)
                            .tracking(0.5)
                    }

                    Spacer()

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(entry.snapshot.currentStreak)")
                            .font(.system(size: 42, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.white)
                        Text("days")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.7))
                    }

                    HStack(spacing: 6) {
                        Text("+\(entry.snapshot.xp) XP")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(deafTurquoise)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(deafTurquoise.opacity(0.18))
                            .clipShape(Capsule())

                        Text("Best: \(entry.snapshot.longestStreak)d")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            // Right Card: Goal Progress & Start Action
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(entry.snapshot.levelTitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white)
                    Spacer()
                    Text("Lvl \(entry.snapshot.level)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.6))
                }

                // Goal bar
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(
                        value: Double(entry.snapshot.dailyGoalVerified),
                        total: Double(max(1, entry.snapshot.dailyGoalTarget))
                    )
                    .tint(entry.snapshot.isGoalCompleted ? deafTurquoise : deafYellow)

                    Text(
                        entry.snapshot.isGoalCompleted
                            ? "Daily goal reached! 🎉"
                            : "Just \(entry.snapshot.remainingMinutes) min to hit your goal"
                    )
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)
                }

                Spacer()

                Link(destination: URL(string: "signspeak://learn")!) {
                    HStack {
                        Spacer()
                        Text("Start Practice")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(deafNavy)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(deafNavy)
                        Spacer()
                    }
                    .padding(.vertical, 7)
                    .background(deafYellow)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(8)
    }

    // MARK: - Lock Screen Circular
    private var accessoryCircularView: some View {
        Gauge(
            value: Double(entry.snapshot.dailyGoalVerified),
            in: 0...Double(max(1, entry.snapshot.dailyGoalTarget))
        ) {
            Image(systemName: "flame.fill")
        } currentValueLabel: {
            Text("\(entry.snapshot.currentStreak)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircular)
    }

    // MARK: - Lock Screen Rectangular
    private var accessoryRectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                Text("\(entry.snapshot.currentStreak) Day Streak")
                    .font(.headline)
            }
            Text("\(entry.snapshot.dailyGoalVerified)/\(entry.snapshot.dailyGoalTarget) signs completed")
                .font(.caption)
                .foregroundStyle(.secondary)
            ProgressView(
                value: Double(entry.snapshot.dailyGoalVerified),
                total: Double(max(1, entry.snapshot.dailyGoalTarget))
            )
        }
    }

    // MARK: - Lock Screen Inline
    private var accessoryInlineView: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
            Text("\(entry.snapshot.currentStreak)d streak · SignSpeak")
        }
    }
}

// MARK: - Widget Declaration

public struct StreakWidget: Widget {
    public let kind: String = "com.signspeak.widget.streak"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakTimelineProvider()) { entry in
            StreakWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Streak & Daily Goal")
        .description("Track your sign practice streak and today's daily goal progress.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
