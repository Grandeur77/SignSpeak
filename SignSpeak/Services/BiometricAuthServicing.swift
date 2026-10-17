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
