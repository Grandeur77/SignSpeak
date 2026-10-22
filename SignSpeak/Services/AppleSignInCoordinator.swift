import Foundation
import AuthenticationServices
import UIKit

/// Coordinates native Sign in with Apple modal presentation, nonce creation, and credential extraction.
@MainActor
public final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    private var currentNonce: String?
    private var continuation: CheckedContinuation<(idToken: String, rawNonce: String, fullName: PersonNameComponents?), Error>?

    public override init() {
        super.init()
    }

    /// Triggers the native Apple ID authorization sheet and awaits validated identity tokens.
    public func requestAppleAuthorization() async throws -> (idToken: String, rawNonce: String, fullName: PersonNameComponents?) {
        let nonce = AppleAuthHelper.randomNonceString()
        self.currentNonce = nonce

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = AppleAuthHelper.sha256(nonce)

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            authorizationController.performRequests()
        }
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding

    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return ASPresentationAnchor()
        }
        return window
    }

    // MARK: - ASAuthorizationControllerDelegate

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            continuation?.resume(throwing: AuthError.unknown("Unable to serialize Apple authentication token."))
            continuation = nil
            return
        }

        continuation?.resume(returning: (idToken: idTokenString, rawNonce: nonce, fullName: appleIDCredential.fullName))
        continuation = nil
    }

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            continuation?.resume(throwing: CancellationError())
        } else {
            continuation?.resume(throwing: AuthError.from(error))
        }
        continuation = nil
    }
}
