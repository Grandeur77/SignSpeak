import SwiftUI

/// Features real-time password strength rules, terms checkbox, loading states,
/// inline validation, and direct Google authentication.
public struct SignUpView: View {
    @Bindable var viewModel: AuthViewModel
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name
        case email
        case password
    }

    public init(viewModel: AuthViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                // MARK: - Top Badge
                HStack(spacing: 6) {
                    Image(systemName: "pencil.line")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.brandTurquoise)

                    Text("Start signing in 2 minutes")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.brandTurquoise)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.brandTurquoise.opacity(0.12), in: Capsule())
                .padding(.top, Theme.Spacing.s)

                // MARK: - Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Create your account")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Text("Join our signing community today")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color.textSecondary)
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
                    // Name Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.textPrimary)

                        HStack(spacing: 12) {
                            Image(systemName: "person")
                                .font(.system(size: 17))
                                .foregroundStyle(Color.textSecondary)

                            TextField("Maya Kowalski", text: $viewModel.name)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .name)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .email }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
                    }

                    // Email Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.textPrimary)

                        HStack(spacing: 12) {
                            Image(systemName: "envelope")
                                .font(.system(size: 17))
                                .foregroundStyle(Color.textSecondary)

                            TextField("maya@example.com", text: $viewModel.email)
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
                        Text("Password")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.textPrimary)

                        HStack(spacing: 12) {
                            Image(systemName: "lock")
                                .font(.system(size: 17))
                                .foregroundStyle(Color.textSecondary)

                            if viewModel.isPasswordVisible {
                                TextField("Create a strong password", text: $viewModel.password)
                                    .focused($focusedField, equals: .password)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        if viewModel.isSignUpValid {
                                            Task { await viewModel.signUp() }
                                        }
                                    }
                            } else {
                                SecureField("Create a strong password", text: $viewModel.password)
                                    .focused($focusedField, equals: .password)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        if viewModel.isSignUpValid {
                                            Task { await viewModel.signUp() }
                                        }
                                    }
                            }

                            Button {
                                viewModel.isPasswordVisible.toggle()
                            } label: {
                                Image(systemName: viewModel.isPasswordVisible ? "eye" : "eye.slash")
                                    .font(.system(size: 17))
                                    .foregroundStyle(Color.textSecondary)
                            }
                            .accessibilityLabel(viewModel.isPasswordVisible ? "Hide password" : "Show password")
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
                    }

                    // MARK: - Password Strength Meter (3 Rules)
                    VStack(alignment: .leading, spacing: 8) {
                        // Segmented bar
                        HStack(spacing: 6) {
                            strengthBarSegment(active: viewModel.rulesMetCount >= 1, color: Color.danger)
                            strengthBarSegment(active: viewModel.rulesMetCount >= 2, color: Color.brandYellow)
                            strengthBarSegment(active: viewModel.rulesMetCount >= 3, color: Color.brandTurquoise)
                        }

                        HStack {
                            Text("Strength: ")
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
                            +
                            Text(viewModel.passwordStrength.rawValue)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(strengthColor)

                            Spacer()

                            Text("\(viewModel.rulesMetCount) of 3 rules met")
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
                        }

                        // Checklist chips
                        HStack(spacing: 14) {
                            ruleItem(title: "8+ characters", isMet: viewModel.isMinLengthMet)
                            ruleItem(title: "1 number", isMet: viewModel.hasNumber)
                            ruleItem(title: "1 special character", isMet: viewModel.hasSpecialCharacter)
                        }
                        .padding(.top, 2)
                    }
                    .padding(.top, 4)

                    // MARK: - Terms & Privacy Agreement
                    HStack(alignment: .top, spacing: 12) {
                        Button {
                            viewModel.agreesToTerms.toggle()
                        } label: {
                            Image(systemName: viewModel.agreesToTerms ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(viewModel.agreesToTerms ? Color.brandTurquoise : Color(.systemGray4))
                        }
                        .accessibilityLabel(viewModel.agreesToTerms ? "Agreed to terms" : "Agree to terms")

                        Text("I agree to the ")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                        +
                        Text("Terms")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.brandTurquoise)
                        +
                        Text(" and ")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                        +
                        Text("Privacy Policy")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.brandTurquoise)
                    }
                    .onTapGesture {
                        // Open Terms on tap or toggle
                        viewModel.agreesToTerms.toggle()
                    }
                    .padding(.top, 6)
                }

                // MARK: - Create Account Primary Button
                Button {
                    focusedField = nil
                    Task { await viewModel.signUp() }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Create account")
                                .font(.body.weight(.semibold))
                            Image(systemName: "arrow.right")
                                .font(.body.weight(.bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(Color.onPrimary)
                    .background(viewModel.isSignUpValid ? Color.primaryFill : Color.primaryFill.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!viewModel.isSignUpValid || viewModel.isLoading)
                .accessibilityLabel("Create account")

                // MARK: - Divider
                HStack(spacing: 12) {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color(.systemGray4))
                    Text("or continue with")
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
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

                // MARK: - Bottom Link to Sign In
                HStack {
                    Spacer()
                    Text("Already have an account?")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                    Button("Sign in") {
                        if viewModel.navigationPath.contains(.signIn) {
                            viewModel.navigationPath.removeAll(where: { $0 == .signUp })
                        } else {
                            viewModel.navigationPath.append(.signIn)
                        }
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
                    .foregroundStyle(Color.textPrimary)
                }
            }
        }
        .sheet(isPresented: $viewModel.showTermsSheet) {
            TermsOfServiceSheet()
        }
        .sheet(isPresented: $viewModel.showPrivacySheet) {
            PrivacyPolicySheet()
        }
    }

    // MARK: - Helper Views

    private func strengthBarSegment(active: Bool, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(active ? color : Color(.systemGray5))
            .frame(height: 5)
    }

    private var strengthColor: Color {
        switch viewModel.passwordStrength {
        case .weak: return Color.danger
        case .fair: return Color.brandYellow
        case .good, .strong: return Color.brandTurquoise
        }
    }

    private func ruleItem(title: String, isMet: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 13))
                .foregroundStyle(isMet ? Color.brandTurquoise : Color.textSecondary)

            Text(title)
                .font(.caption)
                .foregroundStyle(isMet ? Color.textPrimary : Color.textSecondary)
        }
    }
}
