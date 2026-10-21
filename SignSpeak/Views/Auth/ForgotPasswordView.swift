import SwiftUI

/// Features secure icon illustration, clear input requirements, and email dispatch to CheckYourEmail.
public struct ForgotPasswordView: View {
    @Bindable var viewModel: AuthViewModel
    @FocusState private var isEmailFocused: Bool

    public init(viewModel: AuthViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                // MARK: - Center Graphic: Secure Lock Emblem
                ZStack {
                    Circle()
                        .fill(Color.brandTurquoise.opacity(0.08))
                        .frame(width: 120, height: 120)

                    Circle()
                        .strokeBorder(Color.brandTurquoise.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .frame(width: 90, height: 90)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 68, height: 68)
                        .shadow(color: Color.brandTurquoise.opacity(0.18), radius: 10, y: 4)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.brandNavy)

                    // "Secure" Floating Badge
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.brandNavy)
                        Text("Secure")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.brandNavy)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.brandTurquoise.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
                    .offset(y: 45)
                }
                .padding(.top, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.s)

                // MARK: - Header
                VStack(spacing: 8) {
                    Text("Reset your password")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.brandNavy)
                        .accessibilityAddTraits(.isHeader)

                    Text("Enter your email and we'll send you a reset link.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.l)
                }

                // MARK: - General Error Banner
                if let generalError = viewModel.generalErrorMessage {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.danger)

                        Text(generalError)
                            .font(.subheadline)
                            .foregroundStyle(Color.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Theme.Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, Theme.Spacing.l)
                }

                // MARK: - Form Card
                VStack(spacing: Theme.Spacing.m) {
                    // Email Input
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Email")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.textPrimary)

                            Spacer()

                            Text("REQUIRED")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.brandTurquoise)
                                .tracking(0.8)
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "envelope")
                                .font(.system(size: 17))
                                .foregroundStyle(Color.textSecondary)

                            TextField("Enter your registered email", text: $viewModel.email)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .focused($isEmailFocused)
                                .submitLabel(.send)
                                .onSubmit {
                                    if viewModel.isForgotPasswordValid {
                                        Task { await viewModel.sendPasswordReset() }
                                    }
                                }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
                    }

                    // Send Reset Link Primary Button
                    Button {
                        isEmailFocused = false
                        Task { await viewModel.sendPasswordReset() }
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Send reset link")
                                    .font(.body.weight(.semibold))
                                Image(systemName: "arrow.right")
                                    .font(.body.weight(.bold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(.white)
                        .background(viewModel.isForgotPasswordValid ? Color.brandNavy : Color.brandNavy.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(!viewModel.isForgotPasswordValid || viewModel.isLoading)
                    .accessibilityLabel("Send reset link")

                    // Info Callout Card
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.textSecondary)
                            .padding(.top, 2)

                        Text("Make sure to check your spam or junk folder if you don't receive an email within a few minutes.")
                            .font(.footnote)
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Theme.Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6).opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, Theme.Spacing.l)

                Spacer(minLength: 24)

                // MARK: - Sign Assistance Pill
                HStack(spacing: 6) {
                    Image(systemName: "hand.wave")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.brandNavy)

                    Text("Sign assistance available in-app")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.brandNavy)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color(.systemGray6), in: Capsule())

                // MARK: - Bottom Link to Sign In
                HStack {
                    Spacer()
                    Text("Remember password?")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                    Button("Sign in") {
                        if viewModel.navigationPath.contains(.signIn) {
                            viewModel.navigationPath.removeAll(where: { $0 == .forgotPassword })
                        } else {
                            viewModel.navigationPath.append(.signIn)
                        }
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.brandTurquoise)
                    Spacer()
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
                    .foregroundStyle(Color.brandNavy)
                }
            }
        }
    }
}
