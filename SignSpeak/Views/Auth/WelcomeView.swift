import SwiftUI

/// Welcome landing screen for unauthenticated users matching Stitch design `cd04a4753a4b4cde9a1700c7542a3b5d`.
/// Features a hero photo with subtle Deaf Flag sinuous waves, the Deaf & Hearing Unity badge,
/// primary "Create account", secondary "Sign in", "Continue with Google", "Continue as guest",
/// and the transparent privacy assurance ("We only collect your name and email.").
public struct WelcomeView: View {
    @Environment(\.dependencies) private var dependencies
    
    public var onCreateAccount: (() -> Void)?
    public var onSignIn: (() -> Void)?
    public var onGoogleSignIn: (() async -> Void)?
    public var onGuestSignIn: (() async -> Void)?

    @State private var isSigningInGoogle = false
    @State private var isSigningInGuest = false
    @State private var errorMessage: String?

    public init(
        onCreateAccount: (() -> Void)? = nil,
        onSignIn: (() -> Void)? = nil,
        onGoogleSignIn: (() async -> Void)? = nil,
        onGuestSignIn: (() async -> Void)? = nil
    ) {
        self.onCreateAccount = onCreateAccount
        self.onSignIn = onSignIn
        self.onGoogleSignIn = onGoogleSignIn
        self.onGuestSignIn = onGuestSignIn
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // MARK: - Top Hero Banner
                heroBanner
                    .accessibilityHidden(true)

                // MARK: - Overlapping App Logo Card
                AppLogoArtwork()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .shadow(color: Color.brandTurquoise.opacity(0.18), radius: 16, y: 8)
                    .offset(y: -32)
                    .padding(.bottom, -20)
                    .accessibilityLabel("SignSpeak Logo")

                // MARK: - Core Headline & Value Proposition
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

                // Error alert message if an action fails
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Color.danger)
                        .padding(.horizontal, Theme.Spacing.m)
                        .padding(.top, Theme.Spacing.s)
                }

                // MARK: - Action Buttons (matching Stitch screen cd04a4753a4b4cde9a1700c7542a3b5d)
                VStack(spacing: 12) {
                    // 1. Primary Action: "Create account ->"
                    Button {
                        if let onCreateAccount {
                            onCreateAccount()
                        } else {
                            onSignIn?()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Spacer()
                            Text("Create account")
                                .font(.system(size: 17, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                        }
                        .foregroundStyle(Color.onPrimary)
                        .frame(height: 52)
                        .background(
                            Color.brandNavy,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.button)
                        )
                        .shadow(color: Color.brandNavy.opacity(0.2), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Create an account")

                    // 2. Secondary Action: "Sign in"
                    Button {
                        onSignIn?()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign in")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.brandNavy)
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
                        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Sign in to existing account")

                    // 3. Social: "Continue with Google"
                    Button {
                        handleGoogleSignIn()
                    } label: {
                        HStack(spacing: 10) {
                            Spacer()
                            if isSigningInGoogle {
                                ProgressView()
                                    .tint(.primary)
                            } else {
                                GoogleGlyph()
                                    .frame(width: 18, height: 18)

                                Text("Continue with Google")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Color.textPrimary)
                            }
                            Spacer()
                        }
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.button)
                                .fill(Color.cardBackground.opacity(0.9))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.button)
                                .stroke(Color.gray.opacity(0.18), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSigningInGoogle || isSigningInGuest)
                    .accessibilityLabel("Continue with Google")

                    // 4. Tertiary Link: "Continue as guest"
                    Button {
                        handleGuestSignIn()
                    } label: {
                        HStack(spacing: 6) {
                            if isSigningInGuest {
                                ProgressView()
                                    .tint(Color.brandTurquoise)
                            } else {
                                Text("Continue as guest")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.brandTurquoise)
                            }
                        }
                        .frame(minHeight: Theme.minTapTarget)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSigningInGoogle || isSigningInGuest)

                    // 5. Privacy Trust Note
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)

                        Text("We only collect your name and email.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.top, 2)

                    // 6. Terms and Privacy Legal Note
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
                    .padding(.top, Theme.Spacing.xs)
                    .padding(.horizontal, Theme.Spacing.m)
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.s)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Hero Banner with Multi-Layer Wave SVG Styling
    private var heroBanner: some View {
        ZStack(alignment: .bottom) {
            Image("WelcomeHero")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 320)
                .clipped()

            // Sinuous Deaf Flag waves overlapping bottom edge
            ZStack(alignment: .bottom) {
                // Wave 1: Soft Yellow (#ffdf99 with 0.45 opacity)
                WaveShape(phase: 1.0, amplitude: 14, frequency: 1.1)
                    .fill(Color(red: 255/255, green: 223/255, blue: 153/255).opacity(0.45))
                    .frame(height: 38)

                // Wave 2: Cyan/Turquoise (#79eefd with 0.35 opacity)
                WaveShape(phase: 2.2, amplitude: 16, frequency: 1.0)
                    .fill(Color(red: 121/255, green: 238/255, blue: 253/255).opacity(0.40))
                    .frame(height: 30)

                // Wave 3: Surface blend
                WaveShape(phase: 3.4, amplitude: 10, frequency: 1.3)
                    .fill(Color.appBackground)
                    .frame(height: 22)

                // Subtle gradient transition
                LinearGradient(
                    colors: [Color.clear, Color.appBackground],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 28)
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

#Preview("Welcome Screen - Stitch cd04a4753a4b4cde9a1700c7542a3b5d") {
    WelcomeView()
        .environment(\.dependencies, .preview)
}
