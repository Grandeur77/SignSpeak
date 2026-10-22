import Foundation

/// Represents an authenticated user in the SignSpeak system.
public struct AuthUser: Identifiable, Equatable, Hashable, Sendable {
    /// Unique authentication user identifier (Firebase UID).
    public let id: String

    /// User's email address, if registered.
    public let email: String?

    /// User's preferred display name.
    public let displayName: String?

    /// Whether the user has completed email verification.
    public let isEmailVerified: Bool

    /// Whether the session is currently an anonymous guest account.
    public let isAnonymous: Bool

    public init(
        id: String,
        email: String? = nil,
        displayName: String? = nil,
        isEmailVerified: Bool = false,
        isAnonymous: Bool = false
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.isEmailVerified = isEmailVerified
        self.isAnonymous = isAnonymous
    }
}
