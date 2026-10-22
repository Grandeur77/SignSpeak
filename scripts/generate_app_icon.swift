import Foundation
import CoreGraphics
import ImageIO

func renderIcon(pixelSize: Int, isAppIcon: Bool) -> CGImage? {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: pixelSize * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return nil
    }

    let size = CGFloat(pixelSize)

    // Background: Deaf Flag Turquoise (#00A3A6)
    let turquoise = CGColor(srgbRed: 0.0, green: 163.0/255.0, blue: 166.0/255.0, alpha: 1.0)
    ctx.setFillColor(turquoise)
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

    // Bottom Wave: Deaf Flag Warm Yellow (#FFC72C)
    let yellow = CGColor(srgbRed: 255.0/255.0, green: 199.0/255.0, blue: 44.0/255.0, alpha: 1.0)
    ctx.setFillColor(yellow)

    let wavePath = CGMutablePath()
    let waveHeight: CGFloat = size * 0.28
    wavePath.move(to: CGPoint(x: 0, y: 0))
    wavePath.addLine(to: CGPoint(x: 0, y: waveHeight * 0.8))

    let steps = 100
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps)
        let x = t * size
        let y = waveHeight * 0.8 + sin(t * .pi * 2.2 + 0.3) * (size * 0.06)
        wavePath.addLine(to: CGPoint(x: x, y: y))
    }
    wavePath.addLine(to: CGPoint(x: size, y: 0))
    wavePath.closeSubpath()

    ctx.addPath(wavePath)
    ctx.fillPath()

    // Stylized ILY Hand Gesture
    let white = CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    ctx.setFillColor(white)
    ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.015), blur: size * 0.03, color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.25))

    let handPath = CGMutablePath()
    let cx = size * 0.5
    let cy = size * 0.44
    let s = size * 0.48

    let wristLeft = CGPoint(x: cx - s * 0.22, y: cy - s * 0.45)
    let wristRight = CGPoint(x: cx + s * 0.22, y: cy - s * 0.45)
    let thumbTip = CGPoint(x: cx - s * 0.52, y: cy - s * 0.05)
    let thumbCrotch = CGPoint(x: cx - s * 0.24, y: cy + s * 0.1)
    let indexTip = CGPoint(x: cx - s * 0.16, y: cy + s * 0.58)
    let indexBaseRight = CGPoint(x: cx - s * 0.06, y: cy + s * 0.18)
    let middleBump = CGPoint(x: cx + s * 0.06, y: cy + s * 0.18)
    let ringBump = CGPoint(x: cx + s * 0.18, y: cy + s * 0.16)
    let pinkyTip = CGPoint(x: cx + s * 0.32, y: cy + s * 0.50)
    let pinkyOuter = CGPoint(x: cx + s * 0.38, y: cy + s * 0.12)

    handPath.move(to: wristLeft)
    handPath.addCurve(to: thumbTip,
                      control1: CGPoint(x: cx - s * 0.32, y: cy - s * 0.35),
                      control2: CGPoint(x: cx - s * 0.56, y: cy - s * 0.22))
    handPath.addCurve(to: thumbCrotch,
                      control1: CGPoint(x: cx - s * 0.50, y: cy + s * 0.05),
                      control2: CGPoint(x: cx - s * 0.35, y: cy + s * 0.06))
    handPath.addCurve(to: indexTip,
                      control1: CGPoint(x: cx - s * 0.25, y: cy + s * 0.25),
                      control2: CGPoint(x: cx - s * 0.22, y: cy + s * 0.45))
    handPath.addCurve(to: indexBaseRight,
                      control1: CGPoint(x: cx - s * 0.10, y: cy + s * 0.60),
                      control2: CGPoint(x: cx - s * 0.06, y: cy + s * 0.35))
    handPath.addCurve(to: middleBump,
                      control1: CGPoint(x: cx - s * 0.03, y: cy + s * 0.22),
                      control2: CGPoint(x: cx + s * 0.03, y: cy + s * 0.24))
    handPath.addCurve(to: ringBump,
                      control1: CGPoint(x: cx + s * 0.09, y: cy + s * 0.22),
                      control2: CGPoint(x: cx + s * 0.14, y: cy + s * 0.22))
    handPath.addCurve(to: pinkyTip,
                      control1: CGPoint(x: cx + s * 0.20, y: cy + s * 0.28),
                      control2: CGPoint(x: cx + s * 0.26, y: cy + s * 0.45))
    handPath.addCurve(to: pinkyOuter,
                      control1: CGPoint(x: cx + s * 0.38, y: cy + s * 0.50),
                      control2: CGPoint(x: cx + s * 0.40, y: cy + s * 0.30))
    handPath.addCurve(to: wristRight,
                      control1: CGPoint(x: cx + s * 0.36, y: cy - s * 0.15),
                      control2: CGPoint(x: cx + s * 0.30, y: cy - s * 0.35))
    handPath.addLine(to: wristLeft)
    handPath.closeSubpath()

    ctx.addPath(handPath)
    ctx.fillPath()

    // Signal Arcs
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    ctx.setStrokeColor(yellow)
    ctx.setLineWidth(size * 0.024)
    ctx.setLineCap(.round)

    let arc1 = CGMutablePath()
    arc1.addArc(center: CGPoint(x: indexTip.x + s * 0.08, y: indexTip.y + s * 0.02),
                radius: size * 0.065,
                startAngle: 0.2,
                endAngle: 1.4,
                clockwise: false)
    ctx.addPath(arc1)
    ctx.strokePath()

    let arc2 = CGMutablePath()
    arc2.addArc(center: CGPoint(x: indexTip.x + s * 0.08, y: indexTip.y + s * 0.02),
                radius: size * 0.11,
                startAngle: 0.3,
                endAngle: 1.3,
                clockwise: false)
    ctx.addPath(arc2)
    ctx.strokePath()

    return ctx.makeImage()
}

func writePNG(image: CGImage, path: String) {
    let url = URL(fileURLWithPath: path) as CFURL
    guard let destination = CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil) else {
        fatalError("Cannot create image destination at \(path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("Cannot finalize PNG at \(path)")
    }
    print("Saved \(path) with dimensions \(image.width)x\(image.height)")
}

if let appIcon = renderIcon(pixelSize: 1024, isAppIcon: true) {
    writePNG(image: appIcon, path: "/Users/mileeshafernando/IOS/SignSpeak/SignSpeak/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
}

let launchDir = "/Users/mileeshafernando/IOS/SignSpeak/SignSpeak/Assets.xcassets/LaunchLogo.imageset"
try? FileManager.default.createDirectory(atPath: launchDir, withIntermediateDirectories: true)
if let launchLogo = renderIcon(pixelSize: 512, isAppIcon: false) {
    writePNG(image: launchLogo, path: "\(launchDir)/LaunchLogo.png")
}
