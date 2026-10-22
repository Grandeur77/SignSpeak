import Foundation
import Testing
@testable import SignSpeak

@Suite("AuthViewModel Form Validation & Session Flows")
@MainActor
struct AuthViewModelTests {

    private func makeIsolatedDefaults() -> UserDefaults {
        let suite = "test-auth-vm-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    // MARK: - Validation Tests

    @Test("Email format validation correctly discriminates standard and invalid emails")
    func emailValidation() {
        let auth = MockAuthService()
        let biometric = MockBiometricAuthService()
        let vm = AuthViewModel(authService: auth, biometricAuthService: biometric)

        vm.email = ""
        #expect(vm.isEmailValid == false)

        vm.email = "invalid-email"
        #expect(vm.isEmailValid == false)

        vm.email = "missing@domain"
        #expect(vm.isEmailValid == false)

        vm.email = "user@domain.com"
        #expect(vm.isEmailValid == true)

        vm.email = " maya.k@icloud.com "
        #expect(vm.isEmailValid == true)
    }

    @Test("Name validation requires at least 2 non-whitespace characters")
    func nameValidation() {
        let auth = MockAuthService()
        let biometric = MockBiometricAuthService()
        let vm = AuthViewModel(authService: auth, biometricAuthService: biometric)

        vm.name = ""
        #expect(vm.isNameValid == false)

        vm.name = "A"
        #expect(vm.isNameValid == false)

        vm.name = "  "
        #expect(vm.isNameValid == false)

        vm.name = "Al"
        #expect(vm.isNameValid == true)

        vm.name = "Maya Kowalski"
        #expect(vm.isNameValid == true)
    }

    @Test("Password strength meter accurately evaluates the 3 required rules")
    func passwordStrengthEvaluation() {
        let auth = MockAuthService()
        let biometric = MockBiometricAuthService()
        let vm = AuthViewModel(authService: auth, biometricAuthService: biometric)

        // 0 rules met
        vm.password = "short"
        #expect(vm.isMinLengthMet == false)
        #expect(vm.hasNumber == false)
        #expect(vm.hasSpecialCharacter == false)
        #expect(vm.rulesMetCount == 0)
        #expect(vm.passwordStrength == .weak)

        // 1 rule met (length)
        vm.password = "longpasswordonly"
        #expect(vm.isMinLengthMet == true)
        #expect(vm.hasNumber == false)
        #expect(vm.hasSpecialCharacter == false)
        #expect(vm.rulesMetCount == 1)
        #expect(vm.passwordStrength == .weak)

        // 2 rules met (length + number)
        vm.password = "longpassword123"
        #expect(vm.isMinLengthMet == true)
        #expect(vm.hasNumber == true)
        #expect(vm.hasSpecialCharacter == false)
        #expect(vm.rulesMetCount == 2)
        #expect(vm.passwordStrength == .fair)

        // 3 rules met (length + number + special char)
        vm.password = "SignLanguage2025!"
        #expect(vm.isMinLengthMet == true)
        #expect(vm.hasNumber == true)
        #expect(vm.hasSpecialCharacter == true)
        #expect(vm.rulesMetCount == 3)
        #expect(vm.passwordStrength == .strong)
    }

    @Test("Sign-up validity requires valid name, email, all 3 password rules, and terms agreement")
    func signUpFormValidity() {
        let auth = MockAuthService()
        let biometric = MockBiometricAuthService()
        let vm = AuthViewModel(authService: auth, biometricAuthService: biometric)

        vm.name = "Maya Kowalski"
        vm.email = "maya@example.com"
        vm.password = "SignLanguage2025!"
        vm.agreesToTerms = false

        #expect(vm.isSignUpValid == false)

        vm.agreesToTerms = true
        #expect(vm.isSignUpValid == true)

        // Breaking password invalidates form
        vm.password = "weak"
        #expect(vm.isSignUpValid == false)
    }

    // MARK: - Sign-In Tests

    @Test("Successful email sign-in persists savedFaceIDEmail and clears loading state")
    func successfulSignIn() async {
        let auth = MockAuthService()
        let biometric = MockBiometricAuthService()
        let defaults = makeIsolatedDefaults()
        let vm = AuthViewModel(authService: auth, biometricAuthService: biometric, userDefaults: defaults)

        vm.email = "maya.k@icloud.com"
        vm.password = "SuperSecret123!"

        await vm.signIn()

        #expect(auth.signInCallCount == 1)
        #expect(auth.lastSignInEmail == "maya.k@icloud.com")
        #expect(vm.isLoading == false)
        #expect(vm.inlinePasswordError == nil)
        #expect(defaults.string(forKey: "savedFaceIDEmail") == "maya.k@icloud.com")
    }

    @Test("Wrong password produces exact inline error state matching design 08-sign-in-error")
    func wrongPasswordInlineError() async {
        let auth = MockAuthService()
        auth.shouldThrowError = AuthError.wrongPassword
        let biometric = MockBiometricAuthService()
        let vm = AuthViewModel(authService: auth, biometricAuthService: biometric)

        vm.email = "maya.k@icloud.com"
        vm.password = "WrongPassword123"

        await vm.signIn()

        #expect(vm.isLoading == false)
        #expect(vm.inlinePasswordError == "Incorrect email or password. Try again")
        #expect(vm.generalErrorMessage == nil)
    }

    @Test("Network failure maps to friendly general error banner")
    func networkFailureBanner() async {
        let auth = MockAuthService()
        auth.shouldThrowError = AuthError.networkError
        let biometric = MockBiometricAuthService()
        let vm = AuthViewModel(authService: auth, biometricAuthService: biometric)

        vm.email = "maya.k@icloud.com"
        vm.password = "SuperSecret123!"

        await vm.signIn()

        #expect(vm.isLoading == false)
        #expect(vm.inlinePasswordError == nil)
        #expect(vm.generalErrorMessage != nil)
    }

    // MARK: - Sign-Up & Email Verification Tests

    @Test("Sign-up flow dispatches verification and navigates to check your email")
    func signUpNavigationToCheckYourEmail() async {
        let auth = MockAuthService()
        let biometric = MockBiometricAuthService()
        let vm = AuthViewModel(authService: auth, biometricAuthService: biometric)

        vm.name = "Maya Kowalski"
        vm.email = "maya@example.com"
        vm.password = "SignLanguage2025!"
        vm.agreesToTerms = true

        await vm.signUp()

        #expect(auth.signUpCallCount == 1)
        #expect(vm.isLoading == false)
        #expect(vm.navigationPath.count == 1)
        #expect(vm.navigationPath.first == .checkYourEmail(email: "maya@example.com", mode: .activation))
        #expect(vm.isResendTimerActive == true)
    }

    // MARK: - Forgot Password Tests

    @Test("Forgot password sends reset link and transitions to check your email")
    func forgotPasswordFlow() async {
        let auth = MockAuthService()
        let biometric = MockBiometricAuthService()
        let vm = AuthViewModel(authService: auth, biometricAuthService: biometric)

        vm.email = "maya@example.com"

        await vm.sendPasswordReset()

        #expect(auth.sendPasswordResetCallCount == 1)
        #expect(auth.lastResetEmail == "maya@example.com")
        #expect(vm.isLoading == false)
        #expect(vm.navigationPath.count == 1)
        #expect(vm.navigationPath.first == .checkYourEmail(email: "maya@example.com", mode: .passwordReset))
    }

    // MARK: - Guest & Google Sign-In Tests

    @Test("Continue as guest triggers anonymous sign-in")
    func guestExploration() async {
        let auth = MockAuthService()
        let biometric = MockBiometricAuthService()
        let vm = AuthViewModel(authService: auth, biometricAuthService: biometric)

        await vm.continueAsGuest()

        #expect(auth.signInAnonymouslyCallCount == 1)
        #expect(vm.isLoading == false)
    }

    @Test("Google sign-in invokes auth service Google provider")
    func googleSignInTrigger() async {
        let auth = MockAuthService()
        let biometric = MockBiometricAuthService()
        let vm = AuthViewModel(authService: auth, biometricAuthService: biometric)

        await vm.signInWithGoogle()

        #expect(auth.signInWithGoogleCallCount == 1)
        #expect(vm.isLoading == false)
    }

    @Test("Apple sign-in invokes auth service Apple provider")
    func appleSignInTrigger() async {
        let auth = MockAuthService()
        let biometric = MockBiometricAuthService()
        let vm = AuthViewModel(authService: auth, biometricAuthService: biometric)

        await vm.signInWithApple()

        #expect(auth.signInWithAppleCallCount == 1)
        #expect(vm.isLoading == false)
        #expect(vm.generalErrorMessage == nil)
    }

    @Test("Apple sign-in user cancellation does not set general error message")
    func appleSignInCancellation() async {
        let auth = MockAuthService()
        auth.shouldThrowError = CancellationError()
        let biometric = MockBiometricAuthService()
        let vm = AuthViewModel(authService: auth, biometricAuthService: biometric)

        await vm.signInWithApple()

        #expect(auth.signInWithAppleCallCount == 1)
        #expect(vm.isLoading == false)
        #expect(vm.generalErrorMessage == nil)
    }

    @Test("Apple sign-in failure sets general error message")
    func appleSignInFailure() async {
        let auth = MockAuthService()
        auth.shouldThrowError = AuthError.networkError
        let biometric = MockBiometricAuthService()
        let vm = AuthViewModel(authService: auth, biometricAuthService: biometric)

        await vm.signInWithApple()

        #expect(auth.signInWithAppleCallCount == 1)
        #expect(vm.isLoading == false)
        #expect(vm.generalErrorMessage != nil)
    }
}

