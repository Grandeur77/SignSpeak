import SwiftUI

/// Accessible celebration confetti overlay.
/// In adherence with Apple HIG and requirement `confetti only without Reduce Motion`,
/// confetti particles are completely suppressed when the user has enabled Reduce Motion.
public struct ConfettiView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating: Bool = false

    private let particleCount: Int = 45
    private let colors: [Color] = [
        Color.brandTurquoise,
        Color.brandYellow,
        Color.danger,
        Color.brandNavy,
        Color(red: 0.98, green: 0.58, blue: 0.24), // Orange
        Color(red: 0.56, green: 0.35, blue: 0.96)  // Purple
    ]

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            if !reduceMotion {
                ZStack {
                    ForEach(0..<particleCount, id: \.self) { index in
                        ConfettiParticle(
                            index: index,
                            total: particleCount,
                            containerSize: geometry.size,
                            color: colors[index % colors.count],
                            isAnimating: isAnimating
                        )
                    }
                }
                .allowsHitTesting(false)
                .onAppear {
                    withAnimation(.easeOut(duration: 3.5)) {
                        isAnimating = true
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// An individual falling, rotating confetti particle.
private struct ConfettiParticle: View {
    let index: Int
    let total: Int
    let containerSize: CGSize
    let color: Color
    let isAnimating: Bool

    // Deterministic random pseudo-seed values based on index
    private var startX: CGFloat {
        let fraction = CGFloat(index) / CGFloat(total)
        return fraction * containerSize.width
    }

    private var endX: CGFloat {
        let drift = CGFloat((index % 7) - 3) * 35
        return startX + drift
    }

    private var size: CGSize {
        let width = CGFloat(6 + (index % 6) * 2)
        let height = (index % 3 == 0) ? width : width * 1.8
        return CGSize(width: width, height: height)
    }

    private var rotation: Double {
        Double((index * 47) % 360)
    }

    private var endRotation: Double {
        rotation + Double(360 + (index % 4) * 180)
    }

    private var delay: Double {
        Double(index % 10) * 0.08
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: size.width, height: size.height)
            .rotationEffect(.degrees(isAnimating ? endRotation : rotation))
            .rotation3DEffect(
                .degrees(isAnimating ? 360 : 0),
                axis: (x: (index % 2 == 0) ? 1.0 : 0.0, y: 1.0, z: 0.0)
            )
            .position(
                x: isAnimating ? endX : startX,
                y: isAnimating ? containerSize.height + 60 : -30
            )
            .opacity(isAnimating ? 0.0 : 1.0)
            .animation(
                .easeOut(duration: 2.8 + Double(index % 5) * 0.3)
                .delay(delay),
                value: isAnimating
            )
    }
}
