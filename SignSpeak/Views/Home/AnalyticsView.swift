import SwiftUI
import Charts

/// Screen 24: Progress Analytics view per Step 9.3 specifications.
/// Displays Swift Charts for daily practice duration and accuracy trends,
/// week-over-week comparisons, strongest signs, and needs-practice list with direct practice CTAs.
public struct AnalyticsView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AnalyticsViewModel

    public init(viewModel: AnalyticsViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? AnalyticsViewModel())
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                // MARK: - Range Picker
                rangePicker

                // MARK: - Week-over-Week Hero Card
                weekOverWeekCard

                // MARK: - Daily Practice Duration Bar Chart
                practiceDurationChartCard

                // MARK: - Accuracy Trend Line Chart
                accuracyTrendChartCard

                // MARK: - Strongest Signs List
                strongestSignsSection

                // MARK: - Needs Practice Section
                needsPracticeSection

                // MARK: - Recommended Practice CTA
                NavigationLink {
                    CameraTestView()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("Start Recommended Practice")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(Color.brandNavy)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.brandYellow, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, Theme.Spacing.s)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.m)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Progress Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let uid = dependencies.authService.currentUserId ?? "guest"
            viewModel.update(
                progressRepository: dependencies.progressRepository,
                userProfileRepository: dependencies.userProfileRepository,
                userId: uid,
                dateProvider: dependencies.dateProvider
            )
            await viewModel.loadAnalytics()
        }
    }

    // MARK: - Range Picker
    private var rangePicker: some View {
        Picker("Time Range", selection: $viewModel.selectedRange) {
            ForEach(AnalyticsTimeRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Week-over-Week Card
    private var weekOverWeekCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 16/255, green: 40/255, blue: 74/255),
                            Color(red: 10/255, green: 26/255, blue: 50/255)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: Theme.Spacing.m) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WEEKLY REPORT")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.brandTurquoise)
                            .tracking(0.8)

                        Text("\(viewModel.comparison.thisWeekMinutes) mins practiced")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    // Week over week pill
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.comparison.isPositive ? "arrow.up.right" : "arrow.down.right")
                        Text(viewModel.comparison.formattedChange)
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(viewModel.comparison.isPositive ? Color.brandTurquoise : Color.brandYellow)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.12), in: Capsule())
                }

                Divider()
                    .overlay(Color.white.opacity(0.12))

                HStack {
                    metricPill(label: "AVG ACCURACY", value: "\(viewModel.comparison.averageAccuracyThisWeek)%")
                    Spacer()
                    metricPill(label: "SIGNS LEARNED", value: "\(viewModel.comparison.totalSignsLearned)")
                    Spacer()
                    metricPill(label: "LAST WEEK", value: "\(viewModel.comparison.lastWeekMinutes)m")
                }
            }
            .padding(Theme.Spacing.l)
        }
    }

    private func metricPill(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Daily Practice Duration Bar Chart
    private var practiceDurationChartCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Practice Time")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                    Text("Minutes per day vs 10 min daily goal")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
            }

            Chart {
                ForEach(viewModel.dailyMetrics) { item in
                    BarMark(
                        x: .value("Day", item.dayLabel),
                        y: .value("Minutes", item.minutes)
                    )
                    .foregroundStyle(
                        item.minutes >= item.goalMinutes ? Color.brandTurquoise : Color.brandYellow
                    )
                    .cornerRadius(4)
                }

                RuleMark(y: .value("Goal", 10.0))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .foregroundStyle(Color.textSecondary.opacity(0.6))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("10m Goal")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.textSecondary)
                    }
            }
            .frame(height: 160)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Daily practice duration chart")
            .accessibilityValue("Average 12 minutes daily over past week, exceeding 10 minute goal")
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    // MARK: - Accuracy Trend Line Chart
    private var accuracyTrendChartCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Accuracy Trend")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                    Text("Overall recognition confidence score")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                Text("92% Current")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.brandTurquoise)
            }

            Chart {
                ForEach(viewModel.accuracyMetrics) { item in
                    AreaMark(
                        x: .value("Day", item.dayLabel),
                        y: .value("Accuracy", item.accuracyPercentage)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.brandTurquoise.opacity(0.28), Color.brandTurquoise.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Day", item.dayLabel),
                        y: .value("Accuracy", item.accuracyPercentage)
                    )
                    .foregroundStyle(Color.brandTurquoise)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    PointMark(
                        x: .value("Day", item.dayLabel),
                        y: .value("Accuracy", item.accuracyPercentage)
                    )
                    .foregroundStyle(Color.brandYellow)
                }
            }
            .chartYScale(domain: 70...100)
            .frame(height: 160)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Recognition accuracy trend chart")
            .accessibilityValue("Ranging from 84 percent to 95 percent accuracy across the week")
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    // MARK: - Strongest Signs Section
    private var strongestSignsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundStyle(Color.brandYellow)
                Text("Strongest Signs")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
            }

            ForEach(viewModel.strongestSigns) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.signName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Text("\(item.category) • \(item.attempts) attempts")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                    }

                    Spacer()

                    Text("\(item.accuracyPercentage)%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.brandTurquoise)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.brandTurquoise.opacity(0.12), in: Capsule())
                }
                .padding(Theme.Spacing.m)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Needs Practice Section
    private var needsPracticeSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .foregroundStyle(Color.brandYellow)
                Text("Needs Practice")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
            }

            ForEach(viewModel.needsPracticeSigns) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.signName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Text("\(item.category) • \(item.accuracyPercentage)% accuracy")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                    }

                    Spacer()

                    NavigationLink {
                        CameraTestView()
                    } label: {
                        Text("Practice")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.brandNavy)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.brandYellow, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(Theme.Spacing.m)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}
