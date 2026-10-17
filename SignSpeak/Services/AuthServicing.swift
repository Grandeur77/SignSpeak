import Foundation

/// Protocol abstracting Firebase Authentication and session lifecycle.
public protocol AuthServicing: Sendable {
    /// Identifier of the currently signed-in user, if any.
    var currentUserId: String? { get }

    /// Stream of user ID changes (nil on sign out).
    var authStateStream: AsyncStream<String?> { get }

    /// Signs in an existing user with email and password.
    func signIn(email: String, password: String) async throws -> String

    /// Creates a new user with email and password.
    func signUp(email: String, password: String) async throws -> String

    /// Authenticates anonymously as a guest.
    func signInAnonymously() async throws -> String

    /// Authenticates via Google Sign-In.
    func signInWithGoogle() async throws -> String

    /// Signs out the current user session.
    func signOut() throws

    /// Deletes the current user's authentication account.
    func deleteAccount() async throws
}

/// Fallback in-memory authentication service stub for previews and early tests.
public final class StubAuthService: AuthServicing, @unchecked Sendable {
    public var currentUserId: String?

    public var authStateStream: AsyncStream<String?> {
        AsyncStream { continuation in
            continuation.yield(self.currentUserId)
            continuation.finish()
        }
    }

    public init(initialUserId: String? = nil) {
        self.currentUserId = initialUserId
    }

    public func signIn(email: String, password: String) async throws -> String {
        let uid = "stub-user-\(email)"
        currentUserId = uid
        return uid
    }

    public func signUp(email: String, password: String) async throws -> String {
        let uid = "stub-user-\(email)"
        currentUserId = uid
        return uid
    }

    public func signInAnonymously() async throws -> String {
        let uid = "stub-anonymous-user"
        currentUserId = uid
        return uid
    }

    public func signInWithGoogle() async throws -> String {
        let uid = "stub-google-user"
        currentUserId = uid
        return uid
    }

    public func signOut() throws {
        currentUserId = nil
    }

    public func deleteAccount() async throws {
        currentUserId = nil
    }
}
