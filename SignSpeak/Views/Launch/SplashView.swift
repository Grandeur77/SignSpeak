import SwiftUI

/// Displays the SignSpeak Deaf Flag brand logo, on-device intelligence badge, and undulating
/// Deaf Flag sinuous waves (animating continuously, static under Reduce Motion).
struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var wavePhase: Double = 0
    @State private var logoScale: Double = 0.95
    @State private var logoOpacity: Double = 0.0

    var body: some View {
        ZStack {
            // Deep gradient background
            LinearGradient(
                colors: [
                    Color(red: 12/255, green: 22/255, blue: 40/255),
                    Color(red: 7/255, green: 15/255, blue: 30/255)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Main Brand Content
            VStack(spacing: Theme.Spacing.l) {
                Spacer()

                // Centered App Icon Card
                ZStack {
                    // Outer subtle cyan glow
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(Color.brandTurquoise.opacity(0.3), lineWidth: 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(Color(red: 15/255, green: 28/255, blue: 50/255).opacity(0.8))
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: Color.brandTurquoise.opacity(0.2), radius: 20, y: 8)

                    // Inner Icon Artwork (ASL "I Love You" on Deaf Flag colors)
                    AppLogoArtwork()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                // Typography & Taglines
                VStack(spacing: Theme.Spacing.s) {
                    // "SignSpeak"
                    HStack(spacing: 0) {
                        Text("Sign")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Speak")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.brandTurquoise)
                    }
                    .accessibilityAddTraits(.isHeader)

                    // "SIGN • SPEAK • CONNECT"
                    HStack(spacing: 8) {
                        Text("SIGN")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .tracking(1.5)

                        Circle()
                            .fill(Color.brandYellow)
                            .frame(width: 4, height: 4)

                        Text("SPEAK")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .tracking(1.5)

                        Circle()
                            .fill(Color.brandYellow)
                            .frame(width: 4, height: 4)

                        Text("CONNECT")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .tracking(1.5)
                    }

                    // On-Device Intelligence Pill
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.brandTurquoise)
                            .frame(width: 8, height: 8)
                            .shadow(color: Color.brandTurquoise, radius: 4)

                        Text("On-Device Sign Intelligence")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08), in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.top, Theme.Spacing.s)
                }
                .opacity(logoOpacity)

                Spacer()
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.l)

            // Bottom Flowing Deaf Flag Waves
            VStack {
                Spacer()
                ZStack(alignment: .bottom) {
                    // Wave 1: Dark Navy / Blue base
                    WaveShape(phase: wavePhase, amplitude: 18, frequency: 1.2)
                        .fill(Color.brandNavy.opacity(0.7))
                        .frame(height: 140)

                    // Wave 2: Vibrant Turquoise
                    WaveShape(phase: wavePhase + 1.2, amplitude: 22, frequency: 1.0)
                        .fill(Color.brandTurquoise)
                        .frame(height: 110)

                    // Wave 3: Warm Deaf Flag Yellow
                    WaveShape(phase: wavePhase + 2.5, amplitude: 26, frequency: 0.9)
                        .fill(Color.brandYellow)
                        .frame(height: 75)

                    // Base strip
                    WaveShape(phase: wavePhase + 3.8, amplitude: 14, frequency: 1.4)
                        .fill(Color.brandYellow.opacity(0.85))
                        .frame(height: 35)
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .onAppear {
            if reduceMotion {
                logoScale = 1.0
                logoOpacity = 1.0
            } else {
                withAnimation(.easeOut(duration: 0.8)) {
                    logoScale = 1.0
                    logoOpacity = 1.0
                }
                withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                    wavePhase = .pi * 2
                }
            }
        }
    }
}

/// Vector artwork for the SignSpeak App Icon depicting the ASL "I Love You" hand with signal arcs on a turquoise base.
struct AppLogoArtwork: View {
    var body: some View {
        ZStack {
            // Turquoise background
            Color.brandTurquoise

            // Bottom sand wave
            VStack {
                Spacer()
                WaveShape(phase: 0.5, amplitude: 12, frequency: 1.0)
                    .fill(Color.brandYellow)
                    .frame(height: 38)
            }

            // Central "I Love You" hand silhouette & signal arcs
            VStack(spacing: 2) {
                // Signal transmission arcs
                HStack(spacing: 3) {
                    Spacer()
                    Image(systemName: "wave.3.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.brandYellow)
                        .rotationEffect(.degrees(45))
                        .padding(.trailing, 22)
                }

                // Stylized ILY hand gesture
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)
            }
            .padding(.bottom, 6)
        }
    }
}

/// Sinuous sinusoidal wave shape for fluid background graphics.
struct WaveShape: Shape {
    var phase: Double
    var amplitude: CGFloat
    var frequency: CGFloat

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midHeight = rect.height * 0.5

        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: midHeight))

        let width = rect.width
        let step: CGFloat = 4

        for x in stride(from: 0, through: width + step, by: step) {
            let relativeX = x / width
            let sine = sin(relativeX * .pi * 2 * frequency + CGFloat(phase))
            let y = midHeight + sine * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

#Preview("Splash Screen - 02-splash") {
    SplashView()
}
