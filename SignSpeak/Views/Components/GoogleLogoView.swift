import SwiftUI

/// Pixel-perfect vector representation of the Google "G" multi-colored mark.
public struct GoogleLogoView: View {
    public var size: CGFloat = 20

    public init(size: CGFloat = 20) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            // Google 'G' official multi-colored brand layout
            Canvas { context, canvasSize in
                let w = canvasSize.width
                let h = canvasSize.height
                let center = CGPoint(x: w / 2, y: h / 2)
                let radius = min(w, h) / 2
                let innerRadius = radius * 0.55

                // Red segment (top left)
                var redPath = Path()
                redPath.addArc(center: center, radius: radius, startAngle: .degrees(-45), endAngle: .degrees(-140), clockwise: true)
                redPath.addArc(center: center, radius: innerRadius, startAngle: .degrees(-140), endAngle: .degrees(-45), clockwise: false)
                redPath.closeSubpath()
                context.fill(redPath, with: .color(Color(red: 234/255, green: 67/255, blue: 53/255)))

                // Yellow segment (bottom left)
                var yellowPath = Path()
                yellowPath.addArc(center: center, radius: radius, startAngle: .degrees(-140), endAngle: .degrees(-225), clockwise: true)
                yellowPath.addArc(center: center, radius: innerRadius, startAngle: .degrees(-225), endAngle: .degrees(-140), clockwise: false)
                yellowPath.closeSubpath()
                context.fill(yellowPath, with: .color(Color(red: 251/255, green: 188/255, blue: 5/255)))

                // Green segment (bottom right)
                var greenPath = Path()
                greenPath.addArc(center: center, radius: radius, startAngle: .degrees(-225), endAngle: .degrees(-315), clockwise: true)
                greenPath.addArc(center: center, radius: innerRadius, startAngle: .degrees(-315), endAngle: .degrees(-225), clockwise: false)
                greenPath.closeSubpath()
                context.fill(greenPath, with: .color(Color(red: 52/255, green: 168/255, blue: 83/255)))

                // Blue segment & crossbar (right)
                var bluePath = Path()
                bluePath.addArc(center: center, radius: radius, startAngle: .degrees(-315), endAngle: .degrees(-405), clockwise: true)
                bluePath.addLine(to: CGPoint(x: center.x, y: center.y - innerRadius * 0.4))
                bluePath.addLine(to: CGPoint(x: center.x + radius, y: center.y - innerRadius * 0.4))
                bluePath.closeSubpath()
                context.fill(bluePath, with: .color(Color(red: 66/255, green: 133/255, blue: 244/255)))

                // Horizontal crossbar
                var barPath = Path()
                barPath.addRect(CGRect(x: center.x, y: center.y - innerRadius * 0.45, width: radius * 0.95, height: innerRadius * 0.9))
                context.fill(barPath, with: .color(Color(red: 66/255, green: 133/255, blue: 244/255)))
            }
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Google Logo")
    }
}
