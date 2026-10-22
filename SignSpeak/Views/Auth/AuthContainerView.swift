import SwiftUI

/// Top-level authentication navigation host connecting Welcome, Sign-In, Sign-Up,
/// Forgot Password, and Email Verification screens with unified state.
public struct AuthContainerView: View {
    @Bindable var viewModel: AuthViewModel

    public init(viewModel: AuthViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            WelcomeView(
                onCreateAccount: {
                    viewModel.navigationPath.append(.signUp)
                },
                onSignIn: {
                    viewModel.navigationPath.append(.signIn)
                },
                onGoogleSignIn: {
                    await viewModel.signInWithGoogle()
                },
                onGuestSignIn: {
                    await viewModel.continueAsGuest()
                }
            )
            .navigationDestination(for: AuthViewModel.NavigationDestination.self) { destination in
                switch destination {
                case .signIn:
                    SignInView(viewModel: viewModel)
                case .signUp:
                    SignUpView(viewModel: viewModel)
                case .forgotPassword:
                    ForgotPasswordView(viewModel: viewModel)
                case .checkYourEmail(let email, let mode):
                    CheckYourEmailView(viewModel: viewModel, email: email, mode: mode)
                }
            }
        }
    }
}
