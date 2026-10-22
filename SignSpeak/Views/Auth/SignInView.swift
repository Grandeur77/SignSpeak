import SwiftUI

/// Features Face ID quick sign-in, account recognition hint, inline password error state,
/// show/hide password toggle, and Google authentication.
public struct SignInView: View {
    @Bindable var viewModel: AuthViewModel
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email
        case password
    }

    public init(viewModel: AuthViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                // MARK: - Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Welcome back")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.brandNavy)
                        .accessibilityAddTraits(.isHeader)

                    Text("Sign in to continue your practice")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.top, Theme.Spacing.m)

                // MARK: - Face ID Quick Sign-In Card (if biometrics enabled/available)
                if viewModel.canUseFaceID {
                    faceIDShortcutCard
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
                }

                // MARK: - Form Inputs
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    // Email Field
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Email")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.textPrimary)

                            Spacer()

                            if viewModel.isAccountFound {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle")
                                    Text("Account found")
                                }
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.brandTurquoise)
                                .transition(.opacity)
                            }
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "envelope")
                                .font(.system(size: 17))
                                .foregroundStyle(Color.textSecondary)

                            TextField("Enter your email", text: $viewModel.email)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .focused($focusedField, equals: .email)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .password }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
                    }

                    // Password Field
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Password")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.textPrimary)

                            Spacer()

                            Button("Forgot password?") {
                                viewModel.navigationPath.append(.forgotPassword)
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.brandTurquoise)
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "lock")
                                .font(.system(size: 17))
                                .foregroundStyle(Color.textSecondary)

                            if viewModel.isPasswordVisible {
                                TextField("Enter your password", text: $viewModel.password)
                                    .focused($focusedField, equals: .password)
                                    .submitLabel(.go)
                                    .onSubmit { Task { await viewModel.signIn() } }
                            } else {
                                SecureField("Enter your password", text: $viewModel.password)
                                    .focused($focusedField, equals: .password)
                                    .submitLabel(.go)
                                    .onSubmit { Task { await viewModel.signIn() } }
                            }

                            Button {
                                viewModel.isPasswordVisible.toggle()
                            } label: {
                                Image(systemName: viewModel.isPasswordVisible ? "eye" : "eye.slash")
                                    .font(.system(size: 17))
                                    .foregroundStyle(Color.textSecondary)
                            }
                            .accessibilityLabel(viewModel.isPasswordVisible ? "Hide password" : "Show password")

                            if viewModel.inlinePasswordError != nil {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 17))
                                    .foregroundStyle(Color.danger)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(
                            Color(.systemGray6),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(viewModel.inlinePasswordError != nil ? Color.danger : Color.clear, lineWidth: 1.5)
                        )

                        // Inline Password Error Notice (matching 08-sign-in-error.png)
                        if let inlineError = viewModel.inlinePasswordError {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.danger)

                                Text(inlineError)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color.danger)
                            }
                            .padding(.top, 2)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }

                // MARK: - Sign In Primary Button
                Button {
                    focusedField = nil
                    Task { await viewModel.signIn() }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Sign in")
                                .font(.body.weight(.semibold))
                            Image(systemName: "arrow.right")
                                .font(.body.weight(.bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(.white)
                    .background(viewModel.isSignInValid ? Color.brandNavy : Color.brandNavy.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!viewModel.isSignInValid || viewModel.isLoading)
                .accessibilityLabel("Sign in")

                // MARK: - Divider
                HStack(spacing: 12) {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color(.systemGray4))
                    Text("OR CONTINUE WITH")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.textSecondary)
                        .tracking(0.8)
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color(.systemGray4))
                }
                .padding(.vertical, Theme.Spacing.xs)

                // MARK: - Apple Sign In Button
                Button {
                    Task { await viewModel.signInWithApple() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 20))
                        Text("Continue with Apple")
                            .font(.body.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(.white)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 16))
                }
                .accessibilityLabel("Continue with Apple")

                // MARK: - Google Sign In Button
                Button {
                    Task { await viewModel.signInWithGoogle() }
                } label: {
                    HStack(spacing: 10) {
                        GoogleLogoView(size: 20)
                        Text("Continue with Google")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                }
                .accessibilityLabel("Continue with Google")

                // MARK: - Guest Sign-In Shortcut
                Button {
                    Task { await viewModel.continueAsGuest() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 17))
                        Text("Explore as Guest")
                            .font(.body.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .foregroundStyle(Color.brandTurquoise)
                }
                .accessibilityLabel("Explore as Guest")

                // MARK: - Bottom Link to Sign Up
                HStack {
                    Spacer()
                    Text("Don't have an account?")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                    Button("Create one") {
                        viewModel.navigationPath.append(.signUp)
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.brandTurquoise)
                    Spacer()
                }
                .padding(.top, Theme.Spacing.s)
                .padding(.bottom, Theme.Spacing.l)
            }
            .padding(.horizontal, Theme.Spacing.l)
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

    // MARK: - Face ID Shortcut Card
    private var faceIDShortcutCard: some View {
        Button {
            Task { await viewModel.signInWithFaceID() }
        } label: {
            HStack(spacing: 14) {
                // Teal rounded badge with Face ID smiley
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white)
                        .frame(width: 44, height: 44)
                        .shadow(color: Color.brandTurquoise.opacity(0.12), radius: 6, y: 2)

                    Image(systemName: "faceid")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Color.brandTurquoise)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sign in with Face ID")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.brandNavy)

                    Text(viewModel.savedFaceIDEmail ?? "Instant gesture & biometric key")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(Color.white, in: Circle())
            }
            .padding(14)
            .background(Color.brandTurquoise.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.brandTurquoise.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sign in with Face ID")
    }
}
