import SwiftUI

/// Reusable circular progress ring indicator displaying percentage completion.
public struct ProgressRingView: View {
    public let progress: Double
    public let ringSize: CGFloat
    public let strokeWidth: CGFloat
    public let ringColor: Color
    public let trackColor: Color

    public init(
        progress: Double,
        ringSize: CGFloat = 56,
        strokeWidth: CGFloat = 5,
        ringColor: Color? = nil,
        trackColor: Color? = nil
    ) {
        self.progress = max(0.0, min(1.0, progress))
        self.ringSize = ringSize
        self.strokeWidth = strokeWidth
        self.ringColor = ringColor ?? Color.brandTurquoise
        self.trackColor = trackColor ?? Color.gray.opacity(0.2)
    }

    private var percentageText: String {
        "\(Int((progress * 100).rounded()))%"
    }

    public var body: some View {
        ZStack {
            // Track Circle
            Circle()
                .stroke(trackColor, lineWidth: strokeWidth)
                .frame(width: ringSize, height: ringSize)

            // Progress Circle
            Circle()
                .trim(from: 0.0, to: CGFloat(progress))
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: ringSize, height: ringSize)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)

            // Percentage Label
            Text(percentageText)
                .font(.system(size: ringSize * 0.23, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress ring")
        .accessibilityValue(percentageText)
    }
}

#Preview("Progress Ring") {
    HStack(spacing: 20) {
        ProgressRingView(progress: 0.46)
        ProgressRingView(progress: 0.32)
        ProgressRingView(progress: 1.0)
    }
    .padding()
}
