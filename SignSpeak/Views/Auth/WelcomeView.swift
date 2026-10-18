import SwiftUI

/// Features a hero photo of deaf and hearing friends communicating, the Deaf Flag unity badge,
/// and primary authentication pathways (Email/Password, Google, Guest).
public struct WelcomeView: View {
    @Environment(\.dependencies) private var dependencies
    
    public var onSignIn: (() -> Void)?
    public var onGoogleSignIn: (() async -> Void)?
    public var onGuestSignIn: (() async -> Void)?

    @State private var isSigningInGoogle = false
    @State private var isSigningInGuest = false
    @State private var errorMessage: String?

    public init(
        onSignIn: (() -> Void)? = nil,
        onGoogleSignIn: (() async -> Void)? = nil,
        onGuestSignIn: (() async -> Void)? = nil
    ) {
        self.onSignIn = onSignIn
        self.onGoogleSignIn = onGoogleSignIn
        self.onGuestSignIn = onGuestSignIn
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Top Hero Section
                heroBanner
                    .accessibilityHidden(true)

                // Overlapping App Logo
                AppLogoArtwork()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
                    .offset(y: -32)
                    .padding(.bottom, -20)
                    .accessibilityLabel("SignSpeak Logo")

                // Core Brand & Value Proposition
                VStack(spacing: Theme.Spacing.m) {
                    // "DEAF & HEARING UNITY" Pill Badge
                    HStack(spacing: 6) {
                        Image(systemName: "hand.wave.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.brandTurquoise)

                        Text("DEAF & HEARING UNITY")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.brandTurquoise)
                            .tracking(1.0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.brandTurquoise.opacity(0.12), in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.brandTurquoise.opacity(0.25), lineWidth: 1)
                    )

                    // Title
                    Text("Communicate without\nbarriers")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.brandNavy)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    // Subtitle
                    Text("Real-time sign language translation and learning for everyone.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.l)
                }
                .padding(.top, Theme.Spacing.s)

                // Error message if authentication fails
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Color.danger)
                        .padding(.horizontal, Theme.Spacing.m)
                        .padding(.top, Theme.Spacing.s)
                }

                // Action Buttons Section
                VStack(spacing: Theme.Spacing.m) {
                    // Primary Sign In Button
                    Button {
                        onSignIn?()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign in")
                                .font(.system(size: 17, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                        }
                        .foregroundStyle(Color.onPrimary)
                        .frame(height: 52)
                        .background(Color.primaryFill, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Sign in with email and password")

                    // "OR CONTINUE WITH" Divider
                    HStack(spacing: Theme.Spacing.m) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.25))
                            .frame(height: 1)

                        Text("OR CONTINUE WITH")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.gray)
                            .tracking(0.8)

                        Rectangle()
                            .fill(Color.gray.opacity(0.25))
                            .frame(height: 1)
                    }
                    .padding(.vertical, Theme.Spacing.xs)

                    // Continue with Google Button
                    Button {
                        handleGoogleSignIn()
                    } label: {
                        HStack(spacing: 12) {
                            Spacer()
                            if isSigningInGoogle {
                                ProgressView()
                                    .tint(.primary)
                            } else {
                                GoogleGlyph()
                                    .frame(width: 20, height: 20)

                                Text("Continue with Google")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.textPrimary)
                            }
                            Spacer()
                        }
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.button)
                                .fill(Color.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.button)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSigningInGoogle || isSigningInGuest)
                    .accessibilityLabel("Continue with Google")

                    // Explore as Guest Link
                    Button {
                        handleGuestSignIn()
                    } label: {
                        HStack(spacing: 6) {
                            if isSigningInGuest {
                                ProgressView()
                                    .tint(Color.brandNavy)
                            } else {
                                Text("Explore as Guest")
                                    .font(.system(size: 15, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                        }
                        .foregroundStyle(Color.brandNavy)
                        .frame(minHeight: Theme.minTapTarget)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSigningInGoogle || isSigningInGuest)
                    .padding(.top, Theme.Spacing.xs)

                    // Terms and Privacy Legal Note
                    HStack(spacing: 4) {
                        Text("By continuing, you agree to SignSpeak's")
                            .foregroundStyle(Color.textSecondary)

                        Text("Terms of Service")
                            .foregroundStyle(Color.brandTurquoise)
                            .underline()

                        Text("and")
                            .foregroundStyle(Color.textSecondary)

                        Text("Privacy Policy.")
                            .foregroundStyle(Color.brandTurquoise)
                            .underline()
                    }
                    .font(.system(size: 11))
                    .multilineTextAlignment(.center)
                    .padding(.top, Theme.Spacing.s)
                    .padding(.horizontal, Theme.Spacing.m)
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.m)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Hero Banner
    private var heroBanner: some View {
        ZStack(alignment: .bottom) {
            Image("WelcomeHero")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 330)
                .clipped()

            // Sinuous Deaf Flag waves overlapping bottom edge
            ZStack(alignment: .bottom) {
                // Wave 1: Soft Yellow
                WaveShape(phase: 1.0, amplitude: 14, frequency: 1.1)
                    .fill(Color.brandYellow.opacity(0.85))
                    .frame(height: 38)

                // Wave 2: Deaf Flag Turquoise
                WaveShape(phase: 2.2, amplitude: 16, frequency: 1.0)
                    .fill(Color.brandTurquoise.opacity(0.9))
                    .frame(height: 28)

                // Bottom fade to content background
                LinearGradient(
                    colors: [Color.clear, Color.appBackground],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 30)
            }
        }
    }

    // MARK: - Actions
    private func handleGoogleSignIn() {
        if let onGoogleSignIn {
            Task {
                isSigningInGoogle = true
                errorMessage = nil
                await onGoogleSignIn()
                isSigningInGoogle = false
            }
        } else {
            Task {
                isSigningInGoogle = true
                errorMessage = nil
                do {
                    _ = try await dependencies.authService.signInWithGoogle()
                } catch {
                    errorMessage = error.localizedDescription
                }
                isSigningInGoogle = false
            }
        }
    }

    private func handleGuestSignIn() {
        if let onGuestSignIn {
            Task {
                isSigningInGuest = true
                errorMessage = nil
                await onGuestSignIn()
                isSigningInGuest = false
            }
        } else {
            Task {
                isSigningInGuest = true
                errorMessage = nil
                do {
                    _ = try await dependencies.authService.signInAnonymously()
                } catch {
                    errorMessage = error.localizedDescription
                }
                isSigningInGuest = false
            }
        }
    }
}

/// Standalone multi-color Google "G" brand glyph.
public struct GoogleGlyph: View {
    public init() {}

    public var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let center = CGPoint(x: w / 2, y: h / 2)
            let radius = min(w, h) / 2
            let innerRadius = radius * 0.55

            // Blue sector (Right/Top)
            var bluePath = Path()
            bluePath.addArc(center: center, radius: radius, startAngle: .degrees(-45), endAngle: .degrees(45), clockwise: false)
            bluePath.addLine(to: center)
            bluePath.closeSubpath()
            context.fill(bluePath, with: .color(Color(red: 66/255, green: 133/255, blue: 244/255)))

            // Green sector (Bottom Right)
            var greenPath = Path()
            greenPath.addArc(center: center, radius: radius, startAngle: .degrees(45), endAngle: .degrees(135), clockwise: false)
            greenPath.addLine(to: center)
            greenPath.closeSubpath()
            context.fill(greenPath, with: .color(Color(red: 52/255, green: 168/255, blue: 83/255)))

            // Yellow sector (Bottom Left)
            var yellowPath = Path()
            yellowPath.addArc(center: center, radius: radius, startAngle: .degrees(135), endAngle: .degrees(225), clockwise: false)
            yellowPath.addLine(to: center)
            yellowPath.closeSubpath()
            context.fill(yellowPath, with: .color(Color(red: 251/255, green: 188/255, blue: 5/255)))

            // Red sector (Top Left)
            var redPath = Path()
            redPath.addArc(center: center, radius: radius, startAngle: .degrees(225), endAngle: .degrees(315), clockwise: false)
            redPath.addLine(to: center)
            redPath.closeSubpath()
            context.fill(redPath, with: .color(Color(red: 234/255, green: 67/255, blue: 53/255)))

            // Inner circle knockout
            var centerHole = Path()
            centerHole.addEllipse(in: CGRect(x: center.x - innerRadius, y: center.y - innerRadius, width: innerRadius * 2, height: innerRadius * 2))
            context.fill(centerHole, with: .color(.white))

            // Blue horizontal bar
            let barRect = CGRect(x: center.x, y: center.y - (radius - innerRadius) / 2, width: radius, height: radius - innerRadius)
            context.fill(Path(barRect), with: .color(Color(red: 66/255, green: 133/255, blue: 244/255)))
        }
    }
}

#Preview("Welcome Screen - 03-welcome") {
    WelcomeView()
        .environment(\.dependencies, .preview)
}
