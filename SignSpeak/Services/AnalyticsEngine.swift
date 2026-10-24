import Foundation

/// Practice duration data point for bar charts.
public struct DailyPracticeMetric: Identifiable, Sendable, Equatable {
    public var id: String { dayLabel }
    public let dayLabel: String // "Mon", "Tue", etc.
    public let minutes: Double
    public let date: Date
    public let goalMinutes: Double

    public init(dayLabel: String, minutes: Double, date: Date, goalMinutes: Double = 10.0) {
        self.dayLabel = dayLabel
        self.minutes = minutes
        self.date = date
        self.goalMinutes = goalMinutes
    }
}

/// Accuracy trend data point for line charts.
public struct AccuracyTrendMetric: Identifiable, Sendable, Equatable {
    public var id: String { dayLabel }
    public let dayLabel: String
    public let accuracyPercentage: Double // 0 - 100
    public let date: Date

    public init(dayLabel: String, accuracyPercentage: Double, date: Date) {
        self.dayLabel = dayLabel
        self.accuracyPercentage = accuracyPercentage
        self.date = date
    }
}

/// Summary comparison of practice progress between this week and last week.
public struct WeekOverWeekComparison: Sendable, Equatable {
    public let thisWeekMinutes: Int
    public let lastWeekMinutes: Int
    public let percentageChange: Double // e.g. +15.0 or -5.0
    public let averageAccuracyThisWeek: Int // 0 - 100
    public let totalSignsLearned: Int

    public var isPositive: Bool {
        percentageChange >= 0
    }

    public var formattedChange: String {
        let sign = percentageChange >= 0 ? "+" : ""
        return "\(sign)\(Int(percentageChange))%"
    }

    public init(
        thisWeekMinutes: Int = 54,
        lastWeekMinutes: Int = 46,
        percentageChange: Double = 17.4,
        averageAccuracyThisWeek: Int = 92,
        totalSignsLearned: Int = 14
    ) {
        self.thisWeekMinutes = thisWeekMinutes
        self.lastWeekMinutes = lastWeekMinutes
        self.percentageChange = percentageChange
        self.averageAccuracyThisWeek = averageAccuracyThisWeek
        self.totalSignsLearned = totalSignsLearned
    }
}

/// Aggregates learning sessions and sign attempts for Step 9.3 progress analytics.
public struct AnalyticsEngine: Sendable {

    /// Calculates week-over-week comparison metrics.
    public static func calculateWeekOverWeek(
        thisWeekMinutes: Int,
        lastWeekMinutes: Int,
        accuracyThisWeek: Int,
        signsLearned: Int
    ) -> WeekOverWeekComparison {
        let change: Double
        if lastWeekMinutes == 0 {
            change = thisWeekMinutes > 0 ? 100.0 : 0.0
        } else {
            change = ((Double(thisWeekMinutes) - Double(lastWeekMinutes)) / Double(lastWeekMinutes)) * 100.0
        }

        return WeekOverWeekComparison(
            thisWeekMinutes: thisWeekMinutes,
            lastWeekMinutes: lastWeekMinutes,
            percentageChange: change,
            averageAccuracyThisWeek: accuracyThisWeek,
            totalSignsLearned: signsLearned
        )
    }

    /// Generates 7-day daily practice duration data for bar charts.
    public static func generateDailyPracticeMetrics(
        referenceDate: Date = Date(),
        goalMinutes: Double = 10.0
    ) -> [DailyPracticeMetric] {
        let calendar = Calendar.current
        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let sampleMinutes: [Double] = [12.0, 15.0, 8.0, 14.0, 20.0, 10.0, 6.0]

        var metrics: [DailyPracticeMetric] = []
        for i in 0..<7 {
            let offset = i - 6
            let date = calendar.date(byAdding: .day, value: offset, to: referenceDate) ?? referenceDate
            let label = dayNames[i]
            metrics.append(DailyPracticeMetric(
                dayLabel: label,
                minutes: sampleMinutes[i],
                date: date,
                goalMinutes: goalMinutes
            ))
        }
        return metrics
    }

    /// Generates 7-day accuracy trend metrics for line charts.
    public static func generateAccuracyTrendMetrics(
        referenceDate: Date = Date()
    ) -> [AccuracyTrendMetric] {
        let calendar = Calendar.current
        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let sampleAcc: [Double] = [84.0, 88.0, 86.0, 91.0, 95.0, 92.0, 94.0]

        var metrics: [AccuracyTrendMetric] = []
        for i in 0..<7 {
            let offset = i - 6
            let date = calendar.date(byAdding: .day, value: offset, to: referenceDate) ?? referenceDate
            metrics.append(AccuracyTrendMetric(
                dayLabel: dayNames[i],
                accuracyPercentage: sampleAcc[i],
                date: date
            ))
        }
        return metrics
    }
}
