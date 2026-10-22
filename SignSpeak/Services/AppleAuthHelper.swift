import Foundation
import CryptoKit
import AuthenticationServices

/// Utility generating cryptographically secure nonces and SHA256 digests for Sign in with Apple.
public enum AppleAuthHelper {

    /// Generates a cryptographically secure random string of specified length.
    public static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            // Fallback pseudo-random string if SecRandomCopyBytes fails
            let letters = "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
            return String((0..<length).map { _ in letters.randomElement()! })
        }

        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    /// Computes the SHA256 hex digest of the raw string to embed into the Apple ID request.
    public static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
