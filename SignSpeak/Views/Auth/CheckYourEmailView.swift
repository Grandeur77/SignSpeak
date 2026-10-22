import SwiftUI

/// Features animated envelope illustration, direct "Open Mail app" action,
/// active 30s resend countdown timer, live sign support info, and return navigation.
public struct CheckYourEmailView: View {
    @Bindable var viewModel: AuthViewModel
    public let email: String
    public let mode: AuthViewModel.EmailCheckMode

    public init(viewModel: AuthViewModel, email: String, mode: AuthViewModel.EmailCheckMode) {
        self.viewModel = viewModel
        self.email = email
        self.mode = mode
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                // MARK: - Center Graphic: Animated Envelope Emblem
                ZStack {
                    Circle()
                        .fill(Color.brandTurquoise.opacity(0.12))
                        .frame(width: 140, height: 140)

                    Circle()
                        .fill(Color.brandTurquoise.opacity(0.06))
                        .frame(width: 170, height: 170)

                    // Card with envelope
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color.white)
                        .frame(width: 104, height: 104)
                        .shadow(color: Color.brandNavy.opacity(0.08), radius: 14, y: 6)
                        .overlay(
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(Color.brandTurquoise)
                        )

                    // Yellow exclamation badge (top right)
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.brandYellow)
                        .background(Color.white, in: Circle())
                        .offset(x: 52, y: -48)

                    // Turquoise signing hand badge (bottom left)
                    ZStack {
                        Circle()
                            .fill(Color.brandTurquoise)
                            .frame(width: 32, height: 32)
                        Image(systemName: "hand.wave.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.white)
                    }
                    .offset(x: -48, y: 46)
                }
                .padding(.top, Theme.Spacing.l)

                // MARK: - Header
                VStack(spacing: 8) {
                    Text("Check your email")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    HStack(spacing: 4) {
                        Text("We sent a link to")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.textSecondary)
                        Text(email)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.brandTurquoise)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.l)
                }

                // MARK: - Instruction Card
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.brandTurquoise.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "hand.point.up.left.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.brandTurquoise)
                    }

                    Text("Tap the link in your email to reset your password or activate your SignSpeak account.")
                        .font(.subheadline)
                        .foregroundStyle(Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Theme.Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6).opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, Theme.Spacing.l)

                // MARK: - Primary Action: Open Mail App
                VStack(spacing: Theme.Spacing.m) {
                    Button {
                        viewModel.openMailApp()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.badge")
                                .font(.body.weight(.semibold))
                            Text("Open Mail app")
                                .font(.body.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(Color.onPrimary)
                        .background(Color.primaryFill, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .accessibilityLabel("Open Mail app")

                    // MARK: - Resend Countdown / Button
                    Button {
                        Task { await viewModel.resendEmail(email: email, mode: mode) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .semibold))

                            if viewModel.isResendTimerActive {
                                Text("Resend email (\(formattedCountdown))")
                                    .font(.subheadline.weight(.medium))
                            } else {
                                Text("Resend email")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                        .foregroundStyle(viewModel.isResendTimerActive ? Color.textSecondary : Color.brandTurquoise)
                        .frame(height: 38)
                    }
                    .disabled(viewModel.isResendTimerActive || viewModel.isLoading)
                }
                .padding(.horizontal, Theme.Spacing.l)

                // MARK: - Deaf & Hard of Hearing Live Support Card
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.cardBackground)
                            .frame(width: 44, height: 44)
                            .shadow(color: Color.black.opacity(0.06), radius: 6, y: 2)
                        Image(systemName: "video.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.brandTurquoise)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Deaf & Hard of Hearing")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.textPrimary)

                        Text("Live video sign support ready")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }

                    Spacer()

                    Button("Help") {
                        // Open support FAQ
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.cardBackground, in: Capsule())
                    .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
                }
                .padding(Theme.Spacing.m)
                .background(Color(.systemGray6).opacity(0.8), in: RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, Theme.Spacing.l)

                Spacer(minLength: 24)

                // MARK: - Bottom Link: Back to Sign In
                Button {
                    viewModel.navigationPath.removeAll()
                    viewModel.navigationPath.append(.signIn)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back to sign in")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Color.textPrimary)
                }
                .padding(.bottom, Theme.Spacing.l)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if !viewModel.navigationPath.isEmpty {
                        viewModel.navigationPath.removeLast()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundStyle(Color.textPrimary)
                }
            }
        }
    }

    private var formattedCountdown: String {
        let minutes = viewModel.resendCountdown / 60
        let seconds = viewModel.resendCountdown % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
