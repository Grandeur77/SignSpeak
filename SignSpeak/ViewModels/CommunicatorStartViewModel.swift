import SwiftUI

/// View model driving the Communicator Start dashboard (`38-communicator-start`).
/// Manages conversation mode selection, dominant hand preferences, shortcuts, and biometric lock verification.
@Observable
@MainActor
public final class CommunicatorStartViewModel {
    // MARK: - UserDefaults Keys

    public static let keySelectedMode = "communicator_selectedMode"
    public static let keyDominantHand = "communicator_dominantHand"

    // MARK: - Dependencies

    private let userDefaults: UserDefaults

    // MARK: - State

    public var selectedMode: ConversationMode = .faceToFaceSplit
    public var dominantHand: DominantHand = .right

    public var isShowingLiveSession: Bool = false
    public var isShowingQuickPhrases: Bool = false
    public var isShowingHistory: Bool = false
    public var isShowingCalibration: Bool = false

    public var isHistoryUnlocked: Bool = false
    public var isAuthenticating: Bool = false
    public var authenticationError: String? = nil

    // MARK: - Initialization

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadPreferences()
    }

    // MARK: - Preferences

    public func loadPreferences() {
        if let modeRaw = userDefaults.string(forKey: Self.keySelectedMode),
           let mode = ConversationMode(rawValue: modeRaw) {
            self.selectedMode = mode
        } else {
            self.selectedMode = .faceToFaceSplit
        }

        if let handRaw = userDefaults.string(forKey: Self.keyDominantHand),
           let hand = DominantHand(rawValue: handRaw) {
            self.dominantHand = hand
        } else {
            self.dominantHand = .right
        }
    }

    public func selectMode(_ mode: ConversationMode) {
        selectedMode = mode
        userDefaults.set(mode.rawValue, forKey: Self.keySelectedMode)
    }

    public func selectDominantHand(_ hand: DominantHand) {
        dominantHand = hand
        userDefaults.set(hand.rawValue, forKey: Self.keyDominantHand)
    }

    public func startConversation(mode: ConversationMode? = nil) {
        if let mode {
            selectMode(mode)
        }
        isShowingLiveSession = true
    }

    // MARK: - Protected History Verification

    public func isHistoryProtected(isBiometricLockEnabled: Bool, protectConversations: Bool) -> Bool {
        isBiometricLockEnabled && protectConversations
    }

    public func requestOpenHistory(
        isBiometricLockEnabled: Bool,
        protectConversations: Bool,
        biometricService: any BiometricAuthServicing
    ) async {
        let isProtected = isHistoryProtected(
            isBiometricLockEnabled: isBiometricLockEnabled,
            protectConversations: protectConversations
        )

        // If not protected or already unlocked in current session, open directly
        if !isProtected || isHistoryUnlocked {
            isShowingHistory = true
            return
        }

        // Prompt biometric authentication
        isAuthenticating = true
        authenticationError = nil

        do {
            let success = try await biometricService.authenticate(reason: "Unlock conversation history and past transcripts")
            isAuthenticating = false
            if success {
                isHistoryUnlocked = true
                isShowingHistory = true
            } else {
                authenticationError = "Biometric authentication was cancelled or failed."
            }
        } catch {
            isAuthenticating = false
            authenticationError = error.localizedDescription
        }
    }
}
