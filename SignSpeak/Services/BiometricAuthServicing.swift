import Foundation

/// Type of biometrics supported by the current hardware.
public enum BiometricType: Sendable, Equatable {
    case none
    case touchID
    case faceID
}

/// Protocol abstracting LocalAuthentication (Face ID / Touch ID) gates.
public protocol BiometricAuthServicing: Sendable {
    /// True if biometric evaluation is enrolled and available on this device.
    var isBiometricAvailable: Bool { get }

    /// The available biometric sensor type.
    var biometricType: BiometricType { get }

    /// Prompts the user for biometric authentication with a localized reason string.
    func authenticate(reason: String) async throws -> Bool
}

/// Fallback biometric authentication service stub.
public struct StubBiometricAuthService: BiometricAuthServicing {
    public var isBiometricAvailable: Bool
    public var biometricType: BiometricType

    public init(isBiometricAvailable: Bool = true, biometricType: BiometricType = .faceID) {
        self.isBiometricAvailable = isBiometricAvailable
        self.biometricType = biometricType
    }

    public func authenticate(reason: String) async throws -> Bool {
        isBiometricAvailable
    }
}

#if canImport(LocalAuthentication)
import LocalAuthentication

/// Production biometric authentication service backed by Apple's `LocalAuthentication` framework.
public final class LocalAuthenticationBiometricService: BiometricAuthServicing, @unchecked Sendable {
    public init() {}

    public var isBiometricAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    public var biometricType: BiometricType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        default:
            return .none
        }
    }

    public func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        } catch let laError as LAError where laError.code == .userCancel || laError.code == .appCancel {
            throw CancellationError()
        }
    }
}
#endif

