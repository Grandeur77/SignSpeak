import Foundation
import Security
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

/// Specific errors thrown by the biometric credential vault.
public enum CredentialVaultError: Error, LocalizedError, Equatable {
    case accessControlCreationFailed
    case saveFailed(OSStatus)
    case retrievalFailed(OSStatus)
    case notFound
    case userCanceled
    case biometricsChanged
    case encodingFailed

    public var errorDescription: String? {
        switch self {
        case .accessControlCreationFailed:
            return "Failed to configure biometric security attributes for Keychain storage."
        case .saveFailed(let status):
            return "Failed to save credentials in Keychain (status \(status))."
        case .retrievalFailed(let status):
            return "Failed to retrieve credentials from Keychain (status \(status))."
        case .notFound:
            return "No credentials found in the secure vault."
        case .userCanceled:
            return "Biometric authentication was canceled."
        case .biometricsChanged:
            return "Enrolled biometrics have changed. Please re-authenticate with your password."
        case .encodingFailed:
            return "Failed to encode or decode credential data."
        }
    }
}

/// Abstract contract for storing and retrieving user credentials protected by biometric access control.
public protocol CredentialVaultProtocol: Sendable {
    /// True if valid credentials are saved in the vault.
    var hasStoredCredentials: Bool { get }

    /// The email address associated with the currently stored credentials, if any.
    var storedEmail: String? { get }

    /// Saves credentials securely in the Keychain protected by biometric access control (.biometryCurrentSet).
    func saveCredentials(email: String, password: String) throws

    /// Prompts the user with Face ID / biometric authentication and retrieves the stored email and password.
    func retrieveCredentials(promptReason: String) async throws -> (email: String, password: String)?

    /// Removes stored credentials from the Keychain (e.g. on sign-out, password change, or biometric reset).
    func clearCredentials() throws
}

/// Production implementation of `CredentialVaultProtocol` utilizing iOS Keychain Services with `SecAccessControl`.
public final class KeychainCredentialVault: CredentialVaultProtocol, @unchecked Sendable {
    private let serviceName: String
    private let userDefaults: UserDefaults
    private let lock = NSLock()

    public init(
        serviceName: String = "com.grandeur.signspeak.credentials",
        userDefaults: UserDefaults = .standard
    ) {
        self.serviceName = serviceName
        self.userDefaults = userDefaults
    }

    public var hasStoredCredentials: Bool {
        lock.lock()
        defer { lock.unlock() }
        return userDefaults.bool(forKey: "\(serviceName).hasStoredCredentials")
    }

    public var storedEmail: String? {
        lock.lock()
        defer { lock.unlock() }
        return userDefaults.string(forKey: "\(serviceName).storedEmail")
    }

    public func saveCredentials(email: String, password: String) throws {
        lock.lock()
        defer { lock.unlock() }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            throw CredentialVaultError.encodingFailed
        }

        // Delete any existing credential for this service first
        let deleteQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        guard let passwordData = password.data(using: .utf8) else {
            throw CredentialVaultError.encodingFailed
        }

        // Configure SecAccessControl with .biometryCurrentSet
        // This ensures the item is invalidated if biometric enrollment changes
        var cfError: Unmanaged<CFError>?
        var accessControl: SecAccessControl? = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            &cfError
        )

        // Fallback to .userPresence if .biometryCurrentSet is unavailable (e.g. Simulator without biometrics enrolled)
        if accessControl == nil {
            accessControl = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .userPresence,
                nil
            )
        }

        var addQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: trimmedEmail,
            kSecValueData: passwordData
        ]

        if let accessControl {
            addQuery[kSecAttrAccessControl] = accessControl
        }

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CredentialVaultError.saveFailed(status)
        }

        userDefaults.set(trimmedEmail, forKey: "\(serviceName).storedEmail")
        userDefaults.set(true, forKey: "\(serviceName).hasStoredCredentials")
    }

    public func retrieveCredentials(promptReason: String) async throws -> (email: String, password: String)? {
        let context = LAContext()
        context.localizedReason = promptReason
        context.touchIDAuthenticationAllowableReuseDuration = 0

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecReturnData: true,
            kSecReturnAttributes: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecUseAuthenticationContext: context
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let dict = item as? [CFString: Any],
                  let account = dict[kSecAttrAccount] as? String,
                  let passwordData = dict[kSecValueData] as? Data,
                  let password = String(data: passwordData, encoding: .utf8) else {
                throw CredentialVaultError.encodingFailed
            }
            return (email: account, password: password)

        case errSecItemNotFound:
            try? clearCredentials()
            return nil

        case errSecUserCanceled, -128:
            throw CancellationError()

        case errSecAuthFailed:
            // Biometrics changed or invalidated (.biometryCurrentSet triggered)
            try? clearCredentials()
            throw CredentialVaultError.biometricsChanged

        default:
            throw CredentialVaultError.retrievalFailed(status)
        }
    }

    public func clearCredentials() throws {
        lock.lock()
        defer { lock.unlock() }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName
        ]
        SecItemDelete(query as CFDictionary)
        userDefaults.removeObject(forKey: "\(serviceName).storedEmail")
        userDefaults.set(false, forKey: "\(serviceName).hasStoredCredentials")
    }
}

/// In-memory stub implementation of `CredentialVaultProtocol` for SwiftUI previews.
public struct StubCredentialVault: CredentialVaultProtocol {
    public var hasStoredCredentials: Bool
    public var storedEmail: String?

    public init(
        hasStoredCredentials: Bool = true,
        storedEmail: String? = "maya.k@icloud.com"
    ) {
        self.hasStoredCredentials = hasStoredCredentials
        self.storedEmail = storedEmail
    }

    public func saveCredentials(email: String, password: String) throws {}

    public func retrieveCredentials(promptReason: String) async throws -> (email: String, password: String)? {
        guard hasStoredCredentials, let storedEmail else { return nil }
        return (email: storedEmail, password: "SuperSecret123!")
    }

    public func clearCredentials() throws {}
}
