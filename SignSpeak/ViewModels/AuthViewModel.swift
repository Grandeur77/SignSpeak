import SwiftUI

/// View model orchestrating validation, error handling, session creation, and routing for all authentication screens.
@Observable
@MainActor
public final class AuthViewModel {

    // MARK: - Navigation Destinations

    public enum NavigationDestination: Hashable, Sendable {
        case signIn
        case signUp
        case forgotPassword
        case checkYourEmail(email: String, mode: EmailCheckMode)
    }

    public enum EmailCheckMode: Hashable, Sendable {
        case activation
        case passwordReset
    }

    public enum PasswordStrength: String, Sendable {
        case weak = "Weak"
        case fair = "Fair"
        case good = "Good"
        case strong = "Strong"
    }

    // MARK: - Dependencies

    private let authService: any AuthServicing
    private let biometricAuthService: any BiometricAuthServicing
    private let userDefaults: UserDefaults

    // MARK: - Form Inputs

    public var name: String = "" {
        didSet { clearErrors() }
    }
    public var email: String = "" {
        didSet {
            clearErrors()
            evaluateAccountFound()
        }
    }
    public var password: String = "" {
        didSet { clearErrors() }
    }
    public var isPasswordVisible: Bool = false
    public var agreesToTerms: Bool = false {
        didSet { clearErrors() }
    }

    // MARK: - State & Feedback

    public var isLoading: Bool = false
    public var inlinePasswordError: String? = nil
    public var generalErrorMessage: String? = nil
    public var isAccountFound: Bool = false

    // MARK: - Navigation & Sheets

    public var navigationPath: [NavigationDestination] = []
    public var showTermsSheet: Bool = false
    public var showPrivacySheet: Bool = false

    // MARK: - Resend Countdown Timer

    public var resendCountdown: Int = 30
    public var isResendTimerActive: Bool = false
    private nonisolated(unsafe) var countdownTask: Task<Void, Never>?

    // MARK: - Biometrics

    public var canUseFaceID: Bool {
        biometricAuthService.isBiometricAvailable
    }

    public var savedFaceIDEmail: String? {
        userDefaults.string(forKey: "savedFaceIDEmail")
    }

    // MARK: - Initializer

    public init(
        authService: any AuthServicing,
        biometricAuthService: any BiometricAuthServicing,
        userDefaults: UserDefaults = .standard
    ) {
        self.authService = authService
        self.biometricAuthService = biometricAuthService
        self.userDefaults = userDefaults
    }

    deinit {
        countdownTask?.cancel()
    }

    // MARK: - Validation Rules

    public var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    public var isNameValid: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    public var isMinLengthMet: Bool {
        password.count >= 8
    }

    public var hasNumber: Bool {
        password.rangeOfCharacter(from: .decimalDigits) != nil
    }

    public var hasSpecialCharacter: Bool {
        let specialSet = CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;':\",./<>?`~")
        return password.rangeOfCharacter(from: specialSet) != nil
    }

    public var rulesMetCount: Int {
        var count = 0
        if isMinLengthMet { count += 1 }
        if hasNumber { count += 1 }
        if hasSpecialCharacter { count += 1 }
        return count
    }

    public var passwordStrength: PasswordStrength {
        switch rulesMetCount {
        case 0, 1:
            return .weak
        case 2:
            return .fair
        case 3:
            if password.count >= 12 && password.rangeOfCharacter(from: .uppercaseLetters) != nil {
                return .strong
            }
            return .good
        default:
            return .weak
        }
    }

    public var isSignUpValid: Bool {
        isNameValid && isEmailValid && rulesMetCount >= 3 && agreesToTerms && !isLoading
    }

    public var isSignInValid: Bool {
        isEmailValid && !password.isEmpty && !isLoading
    }

    public var isForgotPasswordValid: Bool {
        isEmailValid && !isLoading
    }

    // MARK: - Actions

    public func clearErrors() {
        inlinePasswordError = nil
        generalErrorMessage = nil
    }

    private func evaluateAccountFound() {
        // Subtle hint when a valid email format is entered
        if isEmailValid {
            isAccountFound = true
        } else {
            isAccountFound = false
        }
    }

    /// Signs in with existing email and password.
    public func signIn() async {
        guard isSignInValid else { return }
        isLoading = true
        clearErrors()

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            _ = try await authService.signIn(email: trimmedEmail, password: password)
            // Persist for Face ID shortcut next time
            userDefaults.set(trimmedEmail, forKey: "savedFaceIDEmail")
            isLoading = false
        } catch {
            isLoading = false
            let mapped = AuthError.from(error)
            if mapped == .wrongPassword || mapped == .userNotFound {
                inlinePasswordError = "Incorrect email or password. Try again"
            } else {
                generalErrorMessage = mapped.localizedDescription
            }
        }
    }

    /// Creates a new permanent user account.
    public func signUp() async {
        guard isSignUpValid else { return }
        isLoading = true
        clearErrors()

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            _ = try await authService.signUp(name: trimmedName, email: trimmedEmail, password: password)
            userDefaults.set(trimmedEmail, forKey: "savedFaceIDEmail")
            isLoading = false
            startResendCountdown()
            navigationPath.append(.checkYourEmail(email: trimmedEmail, mode: .activation))
        } catch {
            isLoading = false
            generalErrorMessage = AuthError.from(error).localizedDescription
        }
    }

    /// Sends a password reset email.
    public func sendPasswordReset() async {
        guard isForgotPasswordValid else { return }
        isLoading = true
        clearErrors()

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await authService.sendPasswordReset(email: trimmedEmail)
            isLoading = false
            startResendCountdown()
            navigationPath.append(.checkYourEmail(email: trimmedEmail, mode: .passwordReset))
        } catch {
            isLoading = false
            generalErrorMessage = AuthError.from(error).localizedDescription
        }
    }

    /// Resends the verification or reset email.
    public func resendEmail(email: String, mode: EmailCheckMode) async {
        guard !isResendTimerActive else { return }
        isLoading = true
        clearErrors()

        do {
            switch mode {
            case .activation:
                try await authService.sendEmailVerification()
            case .passwordReset:
                try await authService.sendPasswordReset(email: email)
            }
            isLoading = false
            startResendCountdown()
        } catch {
            isLoading = false
            generalErrorMessage = AuthError.from(error).localizedDescription
        }
    }

    /// Authenticates with Google.
    public func signInWithGoogle() async {
        isLoading = true
        clearErrors()
        do {
            _ = try await authService.signInWithGoogle()
            isLoading = false
        } catch {
            isLoading = false
            generalErrorMessage = AuthError.from(error).localizedDescription
        }
    }

    /// Authenticates anonymously as a guest signer.
    public func continueAsGuest() async {
        isLoading = true
        clearErrors()
        do {
            _ = try await authService.signInAnonymously()
            isLoading = false
        } catch {
            isLoading = false
            generalErrorMessage = AuthError.from(error).localizedDescription
        }
    }

    /// Triggers Face ID biometric sign-in shortcut.
    public func signInWithFaceID() async {
        guard canUseFaceID else { return }
        isLoading = true
        clearErrors()

        do {
            let success = try await biometricAuthService.authenticate(reason: "Sign in to your SignSpeak account")
            if success {
                if let savedEmail = savedFaceIDEmail, !savedEmail.isEmpty {
                    email = savedEmail
                }
                // Auto sign-in or session restoration handled by CredentialVault in Step 3.7
                isLoading = false
            } else {
                isLoading = false
                inlinePasswordError = "Face ID not recognized. Please sign in with your password."
            }
        } catch {
            isLoading = false
            inlinePasswordError = "Face ID authentication failed. Please sign in with your password."
        }
    }

    /// Starts a 30-second countdown before the user can tap "Resend email".
    public func startResendCountdown(seconds: Int = 30) {
        countdownTask?.cancel()
        resendCountdown = seconds
        isResendTimerActive = true

        countdownTask = Task { [weak self] in
            while true {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, !Task.isCancelled else { break }
                if self.resendCountdown > 1 {
                    self.resendCountdown -= 1
                } else {
                    self.resendCountdown = 0
                    self.isResendTimerActive = false
                    break
                }
            }
        }
    }

    /// Opens the iOS Mail app or web mail fallback.
    public func openMailApp() {
        if let mailURL = URL(string: "message://"), UIApplication.shared.canOpenURL(mailURL) {
            UIApplication.shared.open(mailURL)
        } else if let fallbackURL = URL(string: "mailto:") {
            UIApplication.shared.open(fallbackURL)
        }
    }
}
