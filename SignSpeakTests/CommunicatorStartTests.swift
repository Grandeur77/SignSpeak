import Testing
import Foundation
@testable import SignSpeak

/// Comprehensive unit test suite for Communicator start dashboard (design `38-communicator-start`),
/// conversation modes, dominant hand settings, and biometric-protected conversation history.
@Suite("Communicator Start & Modes")
@MainActor
struct CommunicatorStartTests {

    // MARK: - 1. ConversationMode Enum Tests

    @Test("ConversationMode enum provides titles, badges, and icon names")
    func conversationModeProperties() {
        let split = ConversationMode.faceToFaceSplit
        #expect(split.title == "Face-to-Face Split Screen")
        #expect(split.badgeText.contains("1-on-1"))
        #expect(!split.iconName.isEmpty)
        #expect(split.subtitle.contains("180°"))

        let counter = ConversationMode.showTextToOthers
        #expect(counter.title == "Show Text to Others")
        #expect(counter.badgeText.contains("Counter"))
        #expect(!counter.iconName.isEmpty)

        #expect(ConversationMode.allCases.count == 2)
    }

    // MARK: - 2. DominantHand Enum Tests

    @Test("DominantHand enum provides titles and icon names")
    func dominantHandProperties() {
        let right = DominantHand.right
        let left = DominantHand.left

        #expect(right.title == "Right Hand")
        #expect(right.iconName == "hand.raised.right.fill")

        #expect(left.title == "Left Hand")
        #expect(left.iconName == "hand.raised.fill")

        #expect(DominantHand.allCases.count == 2)
    }

    // MARK: - 3. LightingQuality Tests

    @Test("LightingQuality provides descriptions and warning indicators")
    func lightingQualityProperties() {
        let optimal = LightingQuality.optimal
        #expect(optimal.title == "Optimal Lighting")
        #expect(!optimal.iconName.isEmpty)

        let low = LightingQuality.lowLight
        #expect(low.title.contains("Warning"))
        #expect(low.description.contains("Move towards a light source"))
    }

    // MARK: - 4. CommunicatorStartViewModel Defaults & Persistence

    @Test("CommunicatorStartViewModel loads defaults when UserDefaults is empty")
    func viewModelDefaults() {
        let testDefaults = UserDefaults(suiteName: "TestCommDefaults_\(UUID().uuidString)")!
        let vm = CommunicatorStartViewModel(userDefaults: testDefaults)

        #expect(vm.selectedMode == .faceToFaceSplit)
        #expect(vm.dominantHand == .right)
        #expect(!vm.isShowingLiveSession)
        #expect(!vm.isShowingQuickPhrases)
        #expect(!vm.isShowingHistory)
        #expect(!vm.isShowingCalibration)
        #expect(!vm.isHistoryUnlocked)
    }

    @Test("CommunicatorStartViewModel persists selected mode and dominant hand")
    func viewModelPersistence() {
        let testDefaults = UserDefaults(suiteName: "TestCommPersist_\(UUID().uuidString)")!
        let vm = CommunicatorStartViewModel(userDefaults: testDefaults)

        vm.selectMode(.showTextToOthers)
        #expect(vm.selectedMode == .showTextToOthers)
        #expect(testDefaults.string(forKey: CommunicatorStartViewModel.keySelectedMode) == "showTextToOthers")

        vm.selectDominantHand(.left)
        #expect(vm.dominantHand == .left)
        #expect(testDefaults.string(forKey: CommunicatorStartViewModel.keyDominantHand) == "left")

        // Reload to verify persistence
        let reloaded = CommunicatorStartViewModel(userDefaults: testDefaults)
        #expect(reloaded.selectedMode == .showTextToOthers)
        #expect(reloaded.dominantHand == .left)
    }

    @Test("CommunicatorStartViewModel startConversation launches session with active mode")
    func viewModelStartConversation() {
        let testDefaults = UserDefaults(suiteName: "TestCommStart_\(UUID().uuidString)")!
        let vm = CommunicatorStartViewModel(userDefaults: testDefaults)

        vm.startConversation(mode: .showTextToOthers)
        #expect(vm.isShowingLiveSession)
        #expect(vm.selectedMode == .showTextToOthers)
    }

    // MARK: - 5. Biometric Lock for Conversation History

    @Test("History protection evaluation respects biometric lock and conversation protection settings")
    func historyProtectionEvaluation() {
        let vm = CommunicatorStartViewModel()

        #expect(vm.isHistoryProtected(isBiometricLockEnabled: true, protectConversations: true))
        #expect(!vm.isHistoryProtected(isBiometricLockEnabled: false, protectConversations: true))
        #expect(!vm.isHistoryProtected(isBiometricLockEnabled: true, protectConversations: false))
        #expect(!vm.isHistoryProtected(isBiometricLockEnabled: false, protectConversations: false))
    }

    @Test("Unprotected history opens immediately without prompting biometric auth")
    func openHistoryUnprotected() async {
        let vm = CommunicatorStartViewModel()
        let mockBiometric = MockBiometricAuthService()

        await vm.requestOpenHistory(
            isBiometricLockEnabled: false,
            protectConversations: false,
            biometricService: mockBiometric
        )

        #expect(vm.isShowingHistory)
        #expect(mockBiometric.authenticateCallCount == 0)
    }

    @Test("Protected history prompts biometric authentication and unlocks on success")
    func openHistoryProtectedSuccess() async {
        let vm = CommunicatorStartViewModel()
        let mockBiometric = MockBiometricAuthService(
            isBiometricAvailable: true,
            authenticationResult: true
        )

        await vm.requestOpenHistory(
            isBiometricLockEnabled: true,
            protectConversations: true,
            biometricService: mockBiometric
        )

        #expect(mockBiometric.authenticateCallCount == 1)
        #expect(vm.isHistoryUnlocked)
        #expect(vm.isShowingHistory)
        #expect(vm.authenticationError == nil)
    }

    @Test("Protected history denies access when biometric authentication fails")
    func openHistoryProtectedFailure() async {
        let vm = CommunicatorStartViewModel()
        let mockBiometric = MockBiometricAuthService(
            isBiometricAvailable: true,
            authenticationResult: false
        )

        await vm.requestOpenHistory(
            isBiometricLockEnabled: true,
            protectConversations: true,
            biometricService: mockBiometric
        )

        #expect(mockBiometric.authenticateCallCount == 1)
        #expect(!vm.isHistoryUnlocked)
        #expect(!vm.isShowingHistory)
        #expect(vm.authenticationError != nil)
    }

    // MARK: - 6. Quick Phrases Model

    @Test("QuickPhraseItem captures emergency flag and categories")
    func quickPhraseItemModel() {
        let normal = QuickPhraseItem(text: "Hello", category: "Greetings")
        #expect(!normal.isEmergency)

        let emergency = QuickPhraseItem(text: "Need doctor", category: "Emergency", isEmergency: true)
        #expect(emergency.isEmergency)
    }
}
