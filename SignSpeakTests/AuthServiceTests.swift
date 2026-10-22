import Foundation
import Testing
import FirebaseAuth
@testable import SignSpeak

@Suite("AuthService & Error Mapping")
struct AuthServiceTests {

    // MARK: - AuthUser Tests

    @Test("AuthUser initializes with all properties and maintains equality")
    func authUserProperties() {
        let user1 = AuthUser(
            id: "uid-123",
            email: "signer@signspeak.app",
            displayName: "Jordan Lee",
            isEmailVerified: true,
            isAnonymous: false
        )

        #expect(user1.id == "uid-123")
        #expect(user1.email == "signer@signspeak.app")
        #expect(user1.displayName == "Jordan Lee")
        #expect(user1.isEmailVerified == true)
        #expect(user1.isAnonymous == false)

        let user2 = AuthUser(
            id: "uid-123",
            email: "signer@signspeak.app",
            displayName: "Jordan Lee",
            isEmailVerified: true,
            isAnonymous: false
        )
        #expect(user1 == user2)

        let guestUser = AuthUser(id: "guest-456", isAnonymous: true)
        #expect(guestUser.isAnonymous == true)
        #expect(guestUser.email == nil)
        #expect(guestUser.displayName == nil)
        #expect(guestUser != user1)
    }

    // MARK: - AuthError Mapping Tests

    @Test("AuthError maps standard FirebaseAuth error codes to friendly messages")
    func authErrorMappingFromFirebaseCodes() {
        let codeMappings: [(AuthErrorCode, AuthError)] = [
            (.invalidEmail, .invalidEmail),
            (.wrongPassword, .wrongPassword),
            (.userNotFound, .userNotFound),
            (.userDisabled, .userDisabled),
            (.emailAlreadyInUse, .emailAlreadyInUse),
            (.weakPassword, .weakPassword),
            (.operationNotAllowed, .operationNotAllowed),
            (.requiresRecentLogin, .requiresRecentLogin),
            (.credentialAlreadyInUse, .credentialAlreadyInUse),
            (.accountExistsWithDifferentCredential, .credentialAlreadyInUse),
            (.tooManyRequests, .tooManyRequests),
            (.networkError, .networkError),
            (.expiredActionCode, .expiredActionCode),
            (.invalidActionCode, .invalidActionCode),
            (.missingEmail, .missingEmail)
        ]

        for (code, expectedError) in codeMappings {
            let nsError = NSError(domain: AuthErrorDomain, code: code.rawValue, userInfo: nil)
            let mapped = AuthError.from(nsError)
            #expect(mapped == expectedError)
            #expect(mapped.errorDescription != nil && !mapped.errorDescription!.isEmpty)
            #expect(mapped.recoverySuggestion != nil && !mapped.recoverySuggestion!.isEmpty)
        }
    }

    @Test("AuthError maps URL and network transport errors to .networkError")
    func authErrorMappingFromNetworkDomain() {
        let urlError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)
        let mapped = AuthError.from(urlError)
        #expect(mapped == .networkError)
    }

    @Test("AuthError maps unknown or foreign errors to .unknown with original message")
    func authErrorMappingFromUnknownError() {
        struct CustomError: Error, LocalizedError {
            var errorDescription: String? { "Custom test failure" }
        }

        let mapped = AuthError.from(CustomError())
        #expect(mapped == .unknown("Custom test failure"))
    }

    // MARK: - MockAuthService Flow Tests

    @Test("MockAuthService sign-up lifecycle captures name/email and notifies stream")
    func mockAuthServiceSignUp() async throws {
        let auth = MockAuthService(currentUserId: nil)
        #expect(auth.currentUser == nil)
        #expect(auth.currentUserId == nil)

        let user = try await auth.signUp(name: "Taylor", email: "taylor@example.com", password: "Password123!")

        #expect(auth.signUpCallCount == 1)
        #expect(auth.lastSignUpName == "Taylor")
        #expect(auth.lastSignUpEmail == "taylor@example.com")
        #expect(user.displayName == "Taylor")
        #expect(user.email == "taylor@example.com")
        #expect(auth.currentUser == user)
        #expect(auth.currentUserId == user.id)
    }

    @Test("MockAuthService sign-in captures credentials and updates current user")
    func mockAuthServiceSignIn() async throws {
        let auth = MockAuthService()

        let user = try await auth.signIn(email: "alex@example.com", password: "SecurePassword!")

        #expect(auth.signInCallCount == 1)
        #expect(auth.lastSignInEmail == "alex@example.com")
        #expect(user.email == "alex@example.com")
        #expect(auth.currentUser?.email == "alex@example.com")
    }

    @Test("MockAuthService anonymous guest and guest upgrading flow")
    func mockAuthServiceGuestAndUpgrade() async throws {
        let auth = MockAuthService()

        // 1. Sign in anonymously
        let guest = try await auth.signInAnonymously()
        #expect(auth.signInAnonymouslyCallCount == 1)
        #expect(guest.isAnonymous == true)
        #expect(auth.currentUser?.isAnonymous == true)

        // 2. Upgrade guest to permanent account
        let upgraded = try await auth.upgradeGuest(
            name: "Morgan",
            email: "morgan@example.com",
            password: "NewPassword123!"
        )

        #expect(auth.upgradeGuestCallCount == 1)
        #expect(upgraded.isAnonymous == false)
        #expect(upgraded.email == "morgan@example.com")
        #expect(upgraded.displayName == "Morgan")
        #expect(auth.currentUser?.isAnonymous == false)
    }

    @Test("MockAuthService password reset, email verification, and reauthentication")
    func mockAuthServiceSecurityOperations() async throws {
        let auth = MockAuthService(currentUserId: "user-abc")

        try await auth.sendPasswordReset(email: "reset@example.com")
        #expect(auth.sendPasswordResetCallCount == 1)
        #expect(auth.lastResetEmail == "reset@example.com")

        try await auth.sendEmailVerification()
        #expect(auth.sendEmailVerificationCallCount == 1)

        try await auth.reauthenticate(password: "Secret123")
        #expect(auth.reauthenticateCallCount == 1)
        #expect(auth.lastReauthenticatedPassword == "Secret123")

        let reloaded = try await auth.reloadUser()
        #expect(auth.reloadUserCallCount == 1)
        #expect(reloaded?.isEmailVerified == true)
    }

    @Test("MockAuthService sign-out and account deletion clear user session")
    func mockAuthServiceSignOutAndDelete() async throws {
        let auth = MockAuthService(currentUserId: "active-session")
        #expect(auth.currentUser != nil)

        try auth.signOut()
        #expect(auth.signOutCallCount == 1)
        #expect(auth.currentUser == nil)
        #expect(auth.currentUserId == nil)

        auth.currentUserId = "new-session"
        #expect(auth.currentUser != nil)

        try await auth.deleteAccount()
        #expect(auth.deleteAccountCallCount == 1)
        #expect(auth.currentUser == nil)
        #expect(auth.currentUserId == nil)
    }

    @Test("MockAuthService throws configured error deterministically")
    func mockAuthServiceErrorPropagation() async {
        let auth = MockAuthService()
        auth.shouldThrowError = AuthError.wrongPassword

        await #expect(throws: AuthError.wrongPassword) {
            _ = try await auth.signIn(email: "test@example.com", password: "wrong")
        }

        await #expect(throws: AuthError.wrongPassword) {
            _ = try await auth.signUp(name: "Test", email: "test@example.com", password: "wrong")
        }

        await #expect(throws: AuthError.wrongPassword) {
            _ = try await auth.upgradeGuest(name: "Test", email: "test@example.com", password: "wrong")
        }
    }

    // MARK: - StubAuthService Flow Tests

    @Test("StubAuthService simulates in-memory session changes")
    func stubAuthServiceLifecycle() async throws {
        let stub = StubAuthService()
        #expect(stub.currentUser == nil)

        let guest = try await stub.signInAnonymously()
        #expect(guest.isAnonymous == true)

        let upgraded = try await stub.upgradeGuest(name: "Sam", email: "sam@example.com", password: "pass")
        #expect(upgraded.email == "sam@example.com")
        #expect(upgraded.isAnonymous == false)

        try await stub.sendEmailVerification()
        try await stub.sendPasswordReset(email: "sam@example.com")

        let reloaded = try await stub.reloadUser()
        #expect(reloaded?.isEmailVerified == true)

        try stub.signOut()
        #expect(stub.currentUser == nil)
    }

    // MARK: - Google Sign-In & Linking Tests

    @Test("MockAuthService executes Google sign-in and captures OAuth tokens")
    func mockAuthServiceGoogleSignIn() async throws {
        let auth = MockAuthService()

        let user = try await auth.signInWithGoogle(idToken: "sample-id-token", accessToken: "sample-access-token")

        #expect(auth.signInWithGoogleCallCount == 1)
        #expect(auth.lastGoogleIdToken == "sample-id-token")
        #expect(auth.lastGoogleAccessToken == "sample-access-token")
        #expect(user.isAnonymous == false)
        #expect(auth.currentUser == user)
    }

    @Test("MockAuthService links Google credential to anonymous guest account")
    func mockAuthServiceGoogleGuestLinking() async throws {
        let auth = MockAuthService()

        // 1. Enter as guest
        let guest = try await auth.signInAnonymously()
        #expect(guest.isAnonymous == true)
        let guestId = guest.id

        // 2. Link Google account
        let linkedUser = try await auth.linkGoogle(idToken: "google-id-token", accessToken: "google-access-token")

        #expect(auth.linkGoogleCallCount == 1)
        #expect(linkedUser.id == guestId)
        #expect(linkedUser.isAnonymous == false)
        #expect(linkedUser.email == "google.linked@example.com")
        #expect(auth.currentUser?.isAnonymous == false)
    }

    @Test("StubAuthService performs Google sign-in and guest linking")
    func stubAuthServiceGoogleFlows() async throws {
        let stub = StubAuthService()

        let user = try await stub.signInWithGoogle()
        #expect(user.email == "google.user@example.com")
        #expect(user.isAnonymous == false)

        _ = try await stub.signInAnonymously()
        #expect(stub.currentUser?.isAnonymous == true)

        let linked = try await stub.linkGoogle()
        #expect(linked.isAnonymous == false)
        #expect(stub.currentUser?.isAnonymous == false)
    }

    // MARK: - Sign in with Apple Tests

    @Test("AppleAuthHelper generates nonces and deterministic SHA256 digests")
    func appleAuthHelperCrypto() {
        let nonce1 = AppleAuthHelper.randomNonceString(length: 32)
        let nonce2 = AppleAuthHelper.randomNonceString(length: 32)

        #expect(nonce1.count == 32)
        #expect(nonce2.count == 32)
        #expect(nonce1 != nonce2)

        let hash1 = AppleAuthHelper.sha256(nonce1)
        let hash2 = AppleAuthHelper.sha256(nonce1)
        #expect(hash1.count == 64) // SHA256 produces 64 hex characters (32 bytes)
        #expect(hash1 == hash2)
    }

    @Test("MockAuthService executes Apple sign-in and stores identity parameters")
    func mockAuthServiceAppleSignIn() async throws {
        let auth = MockAuthService()

        var nameComponents = PersonNameComponents()
        nameComponents.givenName = "Alex"
        nameComponents.familyName = "Rivera"

        let user = try await auth.signInWithApple(
            idToken: "mock-apple-id-token",
            rawNonce: "mock-apple-nonce",
            fullName: nameComponents
        )

        #expect(auth.signInWithAppleCallCount == 1)
        #expect(auth.lastAppleIdToken == "mock-apple-id-token")
        #expect(auth.lastAppleRawNonce == "mock-apple-nonce")
        #expect(auth.lastAppleFullName?.givenName == "Alex")
        #expect(user.displayName == "Alex Rivera")
        #expect(user.isAnonymous == false)
        #expect(auth.currentUser == user)
    }

    @Test("MockAuthService links Apple credential to active guest account")
    func mockAuthServiceAppleGuestLinking() async throws {
        let auth = MockAuthService()

        // 1. Authenticate as guest
        let guest = try await auth.signInAnonymously()
        #expect(guest.isAnonymous == true)
        let guestId = guest.id

        // 2. Link Apple account
        let linked = try await auth.linkApple(
            idToken: "apple-token",
            rawNonce: "apple-nonce",
            fullName: nil
        )

        #expect(auth.linkAppleCallCount == 1)
        #expect(linked.id == guestId)
        #expect(linked.isAnonymous == false)
        #expect(linked.email == "apple.linked@example.com")
        #expect(auth.currentUser?.isAnonymous == false)
    }

    @Test("StubAuthService performs Apple sign-in and guest linking")
    func stubAuthServiceAppleFlows() async throws {
        let stub = StubAuthService()

        let user = try await stub.signInWithApple()
        #expect(user.email == "apple.user@example.com")
        #expect(user.isAnonymous == false)

        _ = try await stub.signInAnonymously()
        #expect(stub.currentUser?.isAnonymous == true)

        let linked = try await stub.linkApple()
        #expect(linked.isAnonymous == false)
        #expect(stub.currentUser?.isAnonymous == false)
    }
}
