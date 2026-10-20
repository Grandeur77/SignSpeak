import Foundation
import FirebaseAuth

/// Clean, human-readable authentication error cases mapping from Firebase Auth and network issues.
public enum AuthError: LocalizedError, Equatable, Sendable {
    case invalidEmail
    case wrongPassword
    case userNotFound
    case emailAlreadyInUse
    case weakPassword
    case networkError
    case userDisabled
    case requiresRecentLogin
    case credentialAlreadyInUse
    case operationNotAllowed
    case tooManyRequests
    case unverifiedEmail
    case noCurrentUser
    case expiredActionCode
    case invalidActionCode
    case missingEmail
    case unknown(String)

    /// User-friendly localized error description adhering to plain-language guidelines.
    public var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address."
        case .wrongPassword:
            return "Incorrect password. Please try again or reset your password."
        case .userNotFound:
            return "No account found with this email address. Please check your spelling or sign up."
        case .emailAlreadyInUse:
            return "An account with this email already exists. Try signing in instead."
        case .weakPassword:
            return "Password is too weak. Please use at least 8 characters with numbers and symbols."
        case .networkError:
            return "Network error. Please check your internet connection and try again."
        case .userDisabled:
            return "This account has been disabled. Please contact support."
        case .requiresRecentLogin:
            return "For security, please sign in again before performing this action."
        case .credentialAlreadyInUse:
            return "This credential is already linked to another account."
        case .operationNotAllowed:
            return "This sign-in method is currently disabled. Please contact support."
        case .tooManyRequests:
            return "Too many attempts. Please wait a moment and try again."
        case .unverifiedEmail:
            return "Please verify your email address to continue."
        case .noCurrentUser:
            return "No active session found. Please sign in."
        case .expiredActionCode:
            return "This verification or reset link has expired. Please request a new one."
        case .invalidActionCode:
            return "This link is invalid or has already been used."
        case .missingEmail:
            return "Please enter your email address."
        case .unknown(let message):
            return message.isEmpty ? "An unexpected error occurred. Please try again." : message
        }
    }

    /// Actionable suggestions for the user to resolve the issue.
    public var recoverySuggestion: String? {
        switch self {
        case .invalidEmail:
            return "Check the email format (e.g. name@domain.com)."
        case .wrongPassword:
            return "Double-check caps lock or tap 'Forgot password?'."
        case .userNotFound:
            return "Make sure you used the email you originally registered with."
        case .emailAlreadyInUse:
            return "Sign in using your existing password or reset it."
        case .weakPassword:
            return "Combine uppercase letters, numbers, and special characters."
        case .networkError:
            return "Verify your Wi-Fi or cellular connection."
        case .userDisabled:
            return "Reach out to support@signspeak.app for assistance."
        case .requiresRecentLogin:
            return "Sign out and sign back in to confirm your identity."
        case .credentialAlreadyInUse:
            return "Sign into your existing account directly."
        case .operationNotAllowed:
            return "Check back later or contact customer support."
        case .tooManyRequests:
            return "Wait 60 seconds before submitting another request."
        case .unverifiedEmail:
            return "Check your spam or junk folder for the verification email."
        case .noCurrentUser:
            return "Tap Sign In to start a new session."
        case .expiredActionCode, .invalidActionCode:
            return "Request a new email verification or password reset link."
        case .missingEmail:
            return "Fill in the email field."
        case .unknown:
            return "Try again in a few moments."
        }
    }

    /// Maps any raw Swift or Firebase `Error` into a typed, user-friendly `AuthError`.
    public static func from(_ error: Error) -> AuthError {
        if let authError = error as? AuthError {
            return authError
        }

        let nsError = error as NSError

        // Handle network transport failures (CFNetwork / NSURLErrorDomain)
        if nsError.domain == NSURLErrorDomain {
            return .networkError
        }

        // Firebase Auth domain mappings
        guard nsError.domain == AuthErrorDomain || nsError.domain.contains("FIRAuth") else {
            return .unknown(error.localizedDescription)
        }

        guard let code = AuthErrorCode(rawValue: nsError.code) else {
            return .unknown(error.localizedDescription)
        }

        switch code {
        case .invalidEmail:
            return .invalidEmail
        case .wrongPassword:
            return .wrongPassword
        case .userNotFound:
            return .userNotFound
        case .userDisabled:
            return .userDisabled
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .weakPassword:
            return .weakPassword
        case .operationNotAllowed:
            return .operationNotAllowed
        case .requiresRecentLogin:
            return .requiresRecentLogin
        case .credentialAlreadyInUse, .accountExistsWithDifferentCredential:
            return .credentialAlreadyInUse
        case .tooManyRequests:
            return .tooManyRequests
        case .networkError:
            return .networkError
        case .expiredActionCode:
            return .expiredActionCode
        case .invalidActionCode:
            return .invalidActionCode
        case .missingEmail:
            return .missingEmail
        default:
            return .unknown(error.localizedDescription)
        }
    }
}
