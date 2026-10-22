import Foundation
import FirebaseAuth
import FirebaseCore
#if canImport(UIKit)
import UIKit
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

/// Production implementation of `AuthServicing` backed by Firebase Authentication.
public final class FirebaseAuthService: AuthServicing, @unchecked Sendable {
    private let auth: Auth
    private let lock = NSLock()
    private var _currentUser: AuthUser?
    nonisolated(unsafe) private var continuations: [UUID: AsyncStream<AuthUser?>.Continuation] = [:]
    private var authListenerHandle: AuthStateDidChangeListenerHandle?

    public var currentUser: AuthUser? {
        lock.lock()
        defer { lock.unlock() }
        return _currentUser
    }

    public var userStream: AsyncStream<AuthUser?> {
        AsyncStream { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }

            let id = UUID()
            self.lock.lock()
            self.continuations[id] = continuation
            continuation.yield(self._currentUser)
            self.lock.unlock()

            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.lock()
                self.continuations.removeValue(forKey: id)
                self.lock.unlock()
            }
        }
    }

    public init(auth: Auth? = nil) {
        Self.ensureFirebaseConfigured()
        let resolvedAuth = auth ?? Auth.auth()
        self.auth = resolvedAuth
        self._currentUser = Self.mapUser(resolvedAuth.currentUser)

        self.authListenerHandle = resolvedAuth.addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            let mapped = Self.mapUser(user)
            self.notify(with: mapped)
        }
    }

    deinit {
        if let handle = authListenerHandle {
            auth.removeStateDidChangeListener(handle)
        }
    }

    private static func ensureFirebaseConfigured() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    private static func mapUser(_ user: User?) -> AuthUser? {
        guard let user else { return nil }
        return AuthUser(
            id: user.uid,
            email: user.email,
            displayName: user.displayName,
            isEmailVerified: user.isEmailVerified,
            isAnonymous: user.isAnonymous
        )
    }

    private func notify(with user: AuthUser?) {
        lock.lock()
        _currentUser = user
        let activeContinuations = Array(continuations.values)
        lock.unlock()

        for continuation in activeContinuations {
            continuation.yield(user)
        }
    }

    public func signUp(name: String, email: String, password: String) async throws -> AuthUser {
        do {
            let result = try await auth.createUser(withEmail: email, password: password)
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedName.isEmpty {
                let changeRequest = result.user.createProfileChangeRequest()
                changeRequest.displayName = trimmedName
                try await changeRequest.commitChanges()
            }
            try await result.user.sendEmailVerification()

            let mapped = Self.mapUser(result.user) ?? AuthUser(
                id: result.user.uid,
                email: result.user.email,
                displayName: trimmedName.isEmpty ? nil : trimmedName,
                isEmailVerified: false,
                isAnonymous: false
            )
            notify(with: mapped)
            return mapped
        } catch {
            throw AuthError.from(error)
        }
    }

    public func signIn(email: String, password: String) async throws -> AuthUser {
        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            let mapped = Self.mapUser(result.user)!
            notify(with: mapped)
            return mapped
        } catch {
            throw AuthError.from(error)
        }
    }

    public func signInAnonymously() async throws -> AuthUser {
        do {
            let result = try await auth.signInAnonymously()
            let mapped = Self.mapUser(result.user)!
            notify(with: mapped)
            return mapped
        } catch {
            throw AuthError.from(error)
        }
    }

    public func signInWithGoogle() async throws -> AuthUser {
        #if canImport(GoogleSignIn)
        let presentingVC = await getTopViewController()
        guard let presentingVC else {
            throw AuthError.unknown("No active view controller available for Google Sign-In.")
        }
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.unknown("Missing Google ID token.")
            }
            let accessToken = result.user.accessToken.tokenString
            return try await signInWithGoogle(idToken: idToken, accessToken: accessToken)
        } catch {
            throw AuthError.from(error)
        }
        #else
        throw AuthError.operationNotAllowed
        #endif
    }

    public func signInWithGoogle(idToken: String, accessToken: String) async throws -> AuthUser {
        do {
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            let result = try await auth.signIn(with: credential)
            let mapped = Self.mapUser(result.user)!
            notify(with: mapped)
            return mapped
        } catch {
            throw AuthError.from(error)
        }
    }

    public func linkGoogle(idToken: String, accessToken: String) async throws -> AuthUser {
        do {
            guard let user = auth.currentUser else {
                throw AuthError.noCurrentUser
            }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            let result = try await user.link(with: credential)
            let mapped = Self.mapUser(result.user)!
            notify(with: mapped)
            return mapped
        } catch {
            throw AuthError.from(error)
        }
    }

    public func linkGoogle() async throws -> AuthUser {
        #if canImport(GoogleSignIn)
        let presentingVC = await getTopViewController()
        guard let presentingVC else {
            throw AuthError.unknown("No active view controller available for Google Sign-In.")
        }
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.unknown("Missing Google ID token.")
            }
            let accessToken = result.user.accessToken.tokenString
            return try await linkGoogle(idToken: idToken, accessToken: accessToken)
        } catch {
            throw AuthError.from(error)
        }
        #else
        throw AuthError.operationNotAllowed
        #endif
    }

    public func signInWithApple() async throws -> AuthUser {
        let coordinator = await MainActor.run { AppleSignInCoordinator() }
        do {
            let authData = try await coordinator.requestAppleAuthorization()
            return try await signInWithApple(idToken: authData.idToken, rawNonce: authData.rawNonce, fullName: authData.fullName)
        } catch is CancellationError {
            throw AuthError.unknown("Sign in was cancelled.")
        } catch {
            throw AuthError.from(error)
        }
    }

    public func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws -> AuthUser {
        do {
            let credential = OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: rawNonce, fullName: fullName)
            let result = try await auth.signIn(with: credential)

            if let fullName {
                let nameString = PersonNameComponentsFormatter().string(from: fullName).trimmingCharacters(in: .whitespacesAndNewlines)
                if !nameString.isEmpty {
                    let changeRequest = result.user.createProfileChangeRequest()
                    changeRequest.displayName = nameString
                    try await changeRequest.commitChanges()
                }
            }

            let mapped = Self.mapUser(result.user)!
            notify(with: mapped)
            return mapped
        } catch {
            throw AuthError.from(error)
        }
    }

    public func linkApple() async throws -> AuthUser {
        let coordinator = await MainActor.run { AppleSignInCoordinator() }
        do {
            let authData = try await coordinator.requestAppleAuthorization()
            return try await linkApple(idToken: authData.idToken, rawNonce: authData.rawNonce, fullName: authData.fullName)
        } catch is CancellationError {
            throw AuthError.unknown("Linking was cancelled.")
        } catch {
            throw AuthError.from(error)
        }
    }

    public func linkApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws -> AuthUser {
        do {
            guard let user = auth.currentUser else {
                throw AuthError.noCurrentUser
            }
            let credential = OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: rawNonce, fullName: fullName)
            let result = try await user.link(with: credential)

            if let fullName {
                let nameString = PersonNameComponentsFormatter().string(from: fullName).trimmingCharacters(in: .whitespacesAndNewlines)
                if !nameString.isEmpty {
                    let changeRequest = result.user.createProfileChangeRequest()
                    changeRequest.displayName = nameString
                    try await changeRequest.commitChanges()
                }
            }

            let mapped = Self.mapUser(result.user)!
            notify(with: mapped)
            return mapped
        } catch {
            throw AuthError.from(error)
        }
    }

    public func upgradeGuest(name: String, email: String, password: String) async throws -> AuthUser {
        do {
            guard let user = auth.currentUser else {
                throw AuthError.noCurrentUser
            }
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            let result = try await user.link(with: credential)
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedName.isEmpty {
                let changeRequest = result.user.createProfileChangeRequest()
                changeRequest.displayName = trimmedName
                try await changeRequest.commitChanges()
            }
            try await result.user.sendEmailVerification()

            let mapped = Self.mapUser(result.user) ?? AuthUser(
                id: result.user.uid,
                email: result.user.email,
                displayName: trimmedName.isEmpty ? nil : trimmedName,
                isEmailVerified: false,
                isAnonymous: false
            )
            notify(with: mapped)
            return mapped
        } catch {
            throw AuthError.from(error)
        }
    }

    public func sendPasswordReset(email: String) async throws {
        do {
            let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedEmail.isEmpty else {
                throw AuthError.missingEmail
            }
            try await auth.sendPasswordReset(withEmail: trimmedEmail)
        } catch {
            throw AuthError.from(error)
        }
    }

    public func sendEmailVerification() async throws {
        do {
            guard let user = auth.currentUser else {
                throw AuthError.noCurrentUser
            }
            try await user.sendEmailVerification()
        } catch {
            throw AuthError.from(error)
        }
    }

    public func reauthenticate(password: String) async throws {
        do {
            guard let user = auth.currentUser, let email = user.email else {
                throw AuthError.noCurrentUser
            }
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            _ = try await user.reauthenticate(with: credential)
        } catch {
            throw AuthError.from(error)
        }
    }

    public func reloadUser() async throws -> AuthUser? {
        do {
            guard let user = auth.currentUser else {
                return nil
            }
            try await user.reload()
            let mapped = Self.mapUser(auth.currentUser)
            notify(with: mapped)
            return mapped
        } catch {
            throw AuthError.from(error)
        }
    }

    public func signOut() throws {
        do {
            try auth.signOut()
            notify(with: nil)
        } catch {
            throw AuthError.from(error)
        }
    }

    public func deleteAccount() async throws {
        do {
            guard let user = auth.currentUser else {
                throw AuthError.noCurrentUser
            }
            try await user.delete()
            notify(with: nil)
        } catch {
            throw AuthError.from(error)
        }
    }
}

#if canImport(UIKit)
@MainActor
private func getTopViewController() -> UIViewController? {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let root = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
        return nil
    }
    var topController = root
    while let presented = topController.presentedViewController {
        topController = presented
    }
    return topController
}
#endif
