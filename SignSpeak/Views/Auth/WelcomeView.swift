import SwiftUI

/// Features a hero photo with subtle Deaf Flag sinuous waves, the Deaf & Hearing Unity badge,
/// fully rounded pill/capsule buttons for "Create account" and "Sign in", "Continue as guest",
/// and the transparent privacy assurance ("We only collect your name and email.").
public struct WelcomeView: View {
    @Environment(\.dependencies) private var dependencies
    
    public var onCreateAccount: (() -> Void)?
    public var onSignIn: (() -> Void)?
    public var onGoogleSignIn: (() async -> Void)?
    public var onGuestSignIn: (() async -> Void)?

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
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .shadow(color: Color.brandTurquoise.opacity(0.18), radius: 14, y: 6)
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
                        .foregroundStyle(Color.textPrimary)
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
                    // 1. Primary Action: Compact Rounded "Create account ->" Capsule
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
                        .frame(maxWidth: 300)
                        .frame(height: 52)
                        .background(
                            Color.primaryFill,
                            in: Capsule()
                        )
                        .shadow(color: Color.primaryFill.opacity(0.25), radius: 10, y: 5)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Create an account")

                    // 2. Secondary Action: Compact Rounded "Sign in" Capsule
                    Button {
                        onSignIn?()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign in")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                        }
                        .frame(maxWidth: 300)
                        .frame(height: 52)
                        .background(
                            Color.cardBackground,
                            in: Capsule()
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.brandTurquoise.opacity(0.35), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Sign in to existing account")

                    // 3. Tertiary Link: "Continue as guest"
                    Button {
                        handleGuestSignIn()
                    } label: {
                        HStack(spacing: 6) {
                            if isSigningInGuest {
                                ProgressView()
                                    .tint(Color.brandTurquoise)
                            } else {
                                Text("Continue as guest")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color(red: 0/255, green: 105/255, blue: 114/255))
                            }
                        }
                        .frame(minHeight: Theme.minTapTarget)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSigningInGuest)

                    // 4. Privacy Trust Note
                    HStack(spacing: 6) {
                        Image(systemName: "lock")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.textSecondary)

                        Text("We only collect your name and email.")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.top, 2)

                    // 5. Terms and Privacy Legal Note
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
                .padding(.top, Theme.Spacing.m)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .background(Color(red: 247/255, green: 250/255, blue: 251/255).ignoresSafeArea())
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

                // Wave 3: Surface blend (#f7fafb)
                WaveShape(phase: 3.4, amplitude: 10, frequency: 1.3)
                    .fill(Color(red: 247/255, green: 250/255, blue: 251/255))
                    .frame(height: 22)

                // Subtle gradient transition
                LinearGradient(
                    colors: [Color.clear, Color(red: 247/255, green: 250/255, blue: 251/255)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 28)
            }
        }
    }

    // MARK: - Actions
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

#Preview("Welcome Screen - Stitch cd04a4753a4b4cde9a1700c7542a3b5d") {
    WelcomeView()
        .environment(\.dependencies, .preview)
}
