import Foundation
import FirebaseAuth
import FirebaseCore

/// Production implementation of `AuthServicing` backed by Firebase Authentication.
public final class FirebaseAuthService: AuthServicing, @unchecked Sendable {
    private let auth: Auth
    private let lock = NSLock()
    private var _currentUser: AuthUser?
    private var continuations: [UUID: AsyncStream<AuthUser?>.Continuation] = [:]
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
        // Will be wired to GoogleSignIn SDK in Step 3.4
        throw AuthError.operationNotAllowed
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
