import Foundation

/// Protocol abstracting Firebase Authentication and session lifecycle.
public protocol AuthServicing: Sendable {
    /// The currently signed-in user, if any.
    var currentUser: AuthUser? { get }

    /// Stream of current user updates (yields nil when signed out).
    var userStream: AsyncStream<AuthUser?> { get }

    /// Identifier of the currently signed-in user (derived from `currentUser`).
    var currentUserId: String? { get }

    /// Stream of user ID changes (nil on sign out).
    var authStateStream: AsyncStream<String?> { get }

    /// Creates a new user with name, email, and password, setting their display name and sending a verification email.
    func signUp(name: String, email: String, password: String) async throws -> AuthUser

    /// Signs in an existing user with email and password.
    func signIn(email: String, password: String) async throws -> AuthUser

    /// Authenticates anonymously as a guest.
    func signInAnonymously() async throws -> AuthUser

    /// Authenticates via Google Sign-In (linked to Step 3.4).
    func signInWithGoogle() async throws -> AuthUser

    /// Upgrades an anonymous guest account into a permanent email/password account.
    func upgradeGuest(name: String, email: String, password: String) async throws -> AuthUser

    /// Sends a password reset email to the specified address.
    func sendPasswordReset(email: String) async throws

    /// Resends an email verification link to the currently signed-in user.
    func sendEmailVerification() async throws

    /// Re-authenticates the current user using their password before sensitive security operations.
    func reauthenticate(password: String) async throws

    /// Reloads the current user profile from the server to refresh claims and email verification status.
    func reloadUser() async throws -> AuthUser?

    /// Signs out the current user session.
    func signOut() throws

    /// Deletes the current user's authentication account.
    func deleteAccount() async throws
}

public extension AuthServicing {
    var currentUserId: String? {
        currentUser?.id
    }

    var authStateStream: AsyncStream<String?> {
        AsyncStream { continuation in
            let task = Task {
                for await user in userStream {
                    continuation.yield(user?.id)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

/// In-memory authentication service stub for SwiftUI previews and early UI testing.
public final class StubAuthService: AuthServicing, @unchecked Sendable {
    private let lock = NSLock()
    private var _currentUser: AuthUser?
    private var continuations: [UUID: AsyncStream<AuthUser?>.Continuation] = [:]

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

    public init(initialUserId: String? = nil, initialUser: AuthUser? = nil) {
        if let initialUser {
            self._currentUser = initialUser
        } else if let initialUserId {
            self._currentUser = AuthUser(
                id: initialUserId,
                email: "\(initialUserId)@example.com",
                displayName: "SignSpeak User",
                isEmailVerified: true,
                isAnonymous: false
            )
        } else {
            self._currentUser = nil
        }
    }

    private func notify(with user: AuthUser?) {
        lock.lock()
        _currentUser = user
        let currentContinuations = Array(continuations.values)
        lock.unlock()

        for continuation in currentContinuations {
            continuation.yield(user)
        }
    }

    public func signUp(name: String, email: String, password: String) async throws -> AuthUser {
        let user = AuthUser(
            id: "stub-user-\(email)",
            email: email,
            displayName: name.isEmpty ? "New User" : name,
            isEmailVerified: false,
            isAnonymous: false
        )
        notify(with: user)
        return user
    }

    public func signIn(email: String, password: String) async throws -> AuthUser {
        let user = AuthUser(
            id: "stub-user-\(email)",
            email: email,
            displayName: "Alex Rivera",
            isEmailVerified: true,
            isAnonymous: false
        )
        notify(with: user)
        return user
    }

    public func signInAnonymously() async throws -> AuthUser {
        let user = AuthUser(
            id: "stub-anonymous-user",
            email: nil,
            displayName: "Guest",
            isEmailVerified: false,
            isAnonymous: true
        )
        notify(with: user)
        return user
    }

    public func signInWithGoogle() async throws -> AuthUser {
        let user = AuthUser(
            id: "stub-google-user",
            email: "google.user@example.com",
            displayName: "Google User",
            isEmailVerified: true,
            isAnonymous: false
        )
        notify(with: user)
        return user
    }

    public func upgradeGuest(name: String, email: String, password: String) async throws -> AuthUser {
        let user = AuthUser(
            id: currentUser?.id ?? "stub-user-\(email)",
            email: email,
            displayName: name.isEmpty ? "Upgraded User" : name,
            isEmailVerified: false,
            isAnonymous: false
        )
        notify(with: user)
        return user
    }

    public func sendPasswordReset(email: String) async throws {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AuthError.missingEmail
        }
        // Simulated network transmission
    }

    public func sendEmailVerification() async throws {
        guard currentUser != nil else {
            throw AuthError.noCurrentUser
        }
        // Simulated verification email transmission
    }

    public func reauthenticate(password: String) async throws {
        guard currentUser != nil else {
            throw AuthError.noCurrentUser
        }
        if password == "wrong-password" {
            throw AuthError.wrongPassword
        }
    }

    public func reloadUser() async throws -> AuthUser? {
        guard let current = currentUser else { return nil }
        // Simulated verified reload
        let updated = AuthUser(
            id: current.id,
            email: current.email,
            displayName: current.displayName,
            isEmailVerified: true,
            isAnonymous: current.isAnonymous
        )
        notify(with: updated)
        return updated
    }

    public func signOut() throws {
        notify(with: nil)
    }

    public func deleteAccount() async throws {
        notify(with: nil)
    }
}
