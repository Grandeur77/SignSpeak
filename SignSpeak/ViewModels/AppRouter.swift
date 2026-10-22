import SwiftUI

/// Top-level application destinations decided dynamically by `AppRouter`.
public enum AppRoute: Sendable, Equatable {
    /// Initial launch splash screen while credentials and local preferences load.
    case splash
    /// Signed-out Welcome screen (`03-welcome`).
    case welcome
    /// Signed-in new user onboarding flow (`10-onboarding`).
    case onboarding
    /// Biometric Face ID security lock (`59-face-id-lock`) when enabled in settings.
    case faceIDLock
    /// Main authenticated app experience with tab navigation shell (`19-dashboard`).
    case mainApp
}

/// Central routing view model evaluating auth state, onboarding progress, and biometric security locks.
@Observable
@MainActor
public final class AppRouter {
    private let authService: any AuthServicing
    private let userProfileRepository: any UserProfileRepository
    private let biometricAuthService: any BiometricAuthServicing
    public let credentialVault: any CredentialVaultProtocol
    private let dateProvider: any DateProviding
    private let userDefaults: UserDefaults

    public var currentRoute: AppRoute = .splash
    public var isBiometricAuthenticated: Bool = false
    public var isBiometricLockEnabled: Bool {
        get { userDefaults.bool(forKey: "isFaceIDLockEnabled") }
        set { userDefaults.set(newValue, forKey: "isFaceIDLockEnabled") }
    }

    private nonisolated(unsafe) var authTask: Task<Void, Never>?

    public init(
        authService: any AuthServicing,
        userProfileRepository: any UserProfileRepository,
        biometricAuthService: any BiometricAuthServicing,
        credentialVault: (any CredentialVaultProtocol)? = nil,
        dateProvider: (any DateProviding)? = nil,
        userDefaults: UserDefaults = .standard,
        initialRoute: AppRoute = .splash
    ) {
        self.authService = authService
        self.userProfileRepository = userProfileRepository
        self.biometricAuthService = biometricAuthService
        self.credentialVault = credentialVault ?? KeychainCredentialVault(userDefaults: userDefaults)
        self.dateProvider = dateProvider ?? SystemDateProvider()
        self.userDefaults = userDefaults
        self.currentRoute = initialRoute
    }

    deinit {
        authTask?.cancel()
    }

    /// Evaluates initial state while guaranteeing a brief minimum splash presentation for smooth UX.
    public func resolveInitialRoute(minimumSplashDuration: TimeInterval = 1.0) async {
        let startTime = dateProvider.now

        // Allow splash animation to play smoothly
        let elapsed = dateProvider.now.timeIntervalSince(startTime)
        let remaining = max(0, minimumSplashDuration - elapsed)
        if remaining > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }

        await evaluateDestination()
        startObservingAuthState()
    }

    /// Determines the active screen based on user credentials, biometric preferences, and onboarding progress.
    public func evaluateDestination() async {
        guard let userId = authService.currentUserId else {
            currentRoute = .welcome
            return
        }

        // 1. Biometric security lock if user has enabled it in Settings
        if isBiometricLockEnabled && !isBiometricAuthenticated && biometricAuthService.isBiometricAvailable {
            currentRoute = .faceIDLock
            return
        }

        // 2. Onboarding check
        do {
            let profile = try await userProfileRepository.fetchProfile(userId: userId)
            if let profile, profile.onboardingComplete {
                currentRoute = .mainApp
            } else {
                currentRoute = .onboarding
            }
        } catch {
            // Graceful fallback to main app
            currentRoute = .mainApp
        }
    }

    /// Attempts Face ID / Touch ID unlock when on .faceIDLock route.
    @discardableResult
    public func unlockWithBiometrics() async -> Bool {
        do {
            let success = try await biometricAuthService.authenticate(reason: "Unlock SignSpeak")
            if success {
                isBiometricAuthenticated = true
                await evaluateDestination()
                return true
            }
            return false
        } catch {
            return false
        }
    }

    /// Advances user past onboarding and records completion in profile.
    public func completeOnboarding() async {
        if let userId = authService.currentUserId {
            var profile = (try? await userProfileRepository.fetchProfile(userId: userId)) ?? UserProfile(id: userId, displayName: "Learner")
            profile.onboardingComplete = true
            try? await userProfileRepository.saveProfile(profile)
        }
        currentRoute = .mainApp
    }

    /// Signs out the current user session and returns to Welcome screen.
    public func signOut() {
        try? authService.signOut()
        try? credentialVault.clearCredentials()
        isBiometricAuthenticated = false
        currentRoute = .welcome
    }

    /// Enters guest learning session anonymously.
    public func continueAsGuest() async {
        _ = try? await authService.signInAnonymously()
        await evaluateDestination()
    }

    private func startObservingAuthState() {
        authTask?.cancel()
        authTask = Task { [weak self] in
            guard let self else { return }
            for await userId in self.authService.authStateStream {
                if Task.isCancelled { break }
                if userId == nil {
                    self.isBiometricAuthenticated = false
                    try? self.credentialVault.clearCredentials()
                    self.currentRoute = .welcome
                } else if self.currentRoute == .welcome {
                    await self.evaluateDestination()
                }
            }
        }
    }
}
