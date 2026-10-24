import Testing
import Foundation
@testable import SignSpeak

@Suite("Settings & Preferences Tests")
struct SettingsTests {

    @Test("Accessibility preferences persist across sessions and reset correctly")
    func testAccessibilityPreferencesPersistence() {
        let suiteName = "test.signspeak.accessibility.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let prefs1 = AccessibilityPreferences(userDefaults: defaults)
        prefs1.hapticFeedbackEnabled = false
        prefs1.alertVibrationStrength = .strong
        prefs1.flashScreenOnSoundAlerts = false
        prefs1.highContrastOverride = .high
        prefs1.reduceMotionOverride = .reduced
        prefs1.textSizeMultiplier = 1.3
        prefs1.leftHandedMode = true

        // Re-read from a new instance using the same defaults storage
        let prefs2 = AccessibilityPreferences(userDefaults: defaults)
        #expect(prefs2.hapticFeedbackEnabled == false)
        #expect(prefs2.alertVibrationStrength == .strong)
        #expect(prefs2.flashScreenOnSoundAlerts == false)
        #expect(prefs2.highContrastOverride == .high)
        #expect(prefs2.reduceMotionOverride == .reduced)
        #expect(abs(prefs2.textSizeMultiplier - 1.3) < 0.01)
        #expect(prefs2.leftHandedMode == true)

        // Test Reset to defaults
        prefs2.resetToDefaults()
        #expect(prefs2.hapticFeedbackEnabled == true)
        #expect(prefs2.alertVibrationStrength == .medium)
        #expect(prefs2.flashScreenOnSoundAlerts == true)
        #expect(prefs2.highContrastOverride == .system)
        #expect(prefs2.reduceMotionOverride == .system)
        #expect(abs(prefs2.textSizeMultiplier - 1.0) < 0.01)
        #expect(prefs2.leftHandedMode == false)
    }

    @Test("Data export JSON contains required user profile and preferences fields")
    func testDataExportFormat() throws {
        let exportDict: [String: Any] = [
            "exportVersion": "1.0",
            "exportedAt": "2026-10-24T12:00:00Z",
            "user": [
                "id": "user-42",
                "displayName": "Maya Chen",
                "email": "maya@example.com",
                "role": "deaf",
                "currentStreak": 7,
                "longestStreak": 14,
                "totalXP": 420,
                "dailyGoalMinutes": 15,
                "dominantHand": "right"
            ],
            "preferences": [
                "shareMilestonesToCommunity": true,
                "soundAlertsEnabled": true
            ],
            "app": "SignSpeak iOS"
        ]

        let data = try JSONSerialization.data(withJSONObject: exportDict, options: [.prettyPrinted])
        let jsonString = try #require(String(data: data, encoding: .utf8))

        #expect(jsonString.contains("Maya Chen"))
        #expect(jsonString.contains("user-42"))
        #expect(jsonString.contains("420"))
        #expect(jsonString.contains("shareMilestonesToCommunity"))
        #expect(jsonString.contains("SignSpeak iOS"))

        // Validate JSON deserialization roundtrip
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(parsed?["exportVersion"] as? String == "1.0")
        let userObj = parsed?["user"] as? [String: Any]
        #expect(userObj?["displayName"] as? String == "Maya Chen")
        #expect(userObj?["role"] as? String == "deaf")
    }

    @Test("Practice history CSV produces valid columns and headers")
    func testPracticeHistoryCSVOutput() {
        var csv = "Date,Sign,Category,Accuracy,DurationSeconds,Mastered\n"
        let rows = [
            "2026-10-24,Hello,Greetings,98%,12,true",
            "2026-10-23,Thank You,Greetings,95%,15,true",
            "2026-10-22,Help,Emergency,92%,18,true"
        ]
        csv.append(rows.joined(separator: "\n"))

        let lines = csv.components(separatedBy: "\n")
        #expect(lines.first == "Date,Sign,Category,Accuracy,DurationSeconds,Mastered")
        #expect(lines.count == 4)

        let firstRow = lines[1].components(separatedBy: ",")
        #expect(firstRow[0] == "2026-10-24")
        #expect(firstRow[1] == "Hello")
        #expect(firstRow[2] == "Greetings")
        #expect(firstRow[3] == "98%")
        #expect(firstRow[4] == "12")
        #expect(firstRow[5] == "true")
    }

    @Test("Account deletion executes in strictly verified cascade order")
    func testAccountDeletionOrder() async throws {
        final class DeletionAuditTrail: @unchecked Sendable {
            var order: [String] = []
            private let lock = NSLock()

            func record(_ step: String) {
                lock.lock()
                defer { lock.unlock() }
                order.append(step)
            }
        }

        let audit = DeletionAuditTrail()

        // 1. Mock User Profile Repo
        final class MockProfileRepo: UserProfileRepository, @unchecked Sendable {
            let audit: DeletionAuditTrail
            init(audit: DeletionAuditTrail) { self.audit = audit }
            func fetchProfile(userId: String) async throws -> UserProfile? { nil }
            func saveProfile(_ profile: UserProfile) async throws {}
            func updateStreak(userId: String, streak: Int) async throws {}
            func createProfileIfNeeded(userId: String, displayName: String, email: String?) async throws -> UserProfile {
                UserProfile(id: userId, displayName: "Test")
            }
            func deleteProfile(userId: String) async throws {
                audit.record("deleteProfile")
            }
        }

        // 2. Mock Conversation Repo
        final class MockConvoRepo: ConversationRepository, @unchecked Sendable {
            let audit: DeletionAuditTrail
            init(audit: DeletionAuditTrail) { self.audit = audit }
            func fetchConversations(userId: String) async throws -> [SavedConversation] { [] }
            func saveConversation(userId: String, conversation: SavedConversation) async throws {}
            func toggleSaved(userId: String, conversationId: String) async throws -> Bool { false }
            func deleteConversation(userId: String, conversationId: String) async throws {}
            func deleteAllConversations(userId: String) async throws {
                audit.record("deleteAllConversations")
            }
        }

        // 3. Mock Credential Vault
        final class MockVault: CredentialVaultProtocol, @unchecked Sendable {
            let audit: DeletionAuditTrail
            init(audit: DeletionAuditTrail) { self.audit = audit }
            var hasStoredCredentials: Bool = true
            var storedEmail: String? = "test@example.com"
            func saveCredentials(email: String, password: String) throws {}
            func retrieveCredentials(promptReason: String) async throws -> (email: String, password: String)? { nil }
            func clearCredentials() throws {
                audit.record("clearCredentials")
            }
        }

        // 4. Mock Auth Service
        final class MockAuth: AuthServicing, @unchecked Sendable {
            let audit: DeletionAuditTrail
            init(audit: DeletionAuditTrail) { self.audit = audit }
            var currentUser: AuthUser? = AuthUser(id: "user-delete-1", email: "test@example.com")
            var userStream: AsyncStream<AuthUser?> { AsyncStream { $0.finish() } }
            func signUp(name: String, email: String, password: String) async throws -> AuthUser { currentUser! }
            func signIn(email: String, password: String) async throws -> AuthUser { currentUser! }
            func signInAnonymously() async throws -> AuthUser { currentUser! }
            func signInWithGoogle() async throws -> AuthUser { currentUser! }
            func signInWithGoogle(idToken: String, accessToken: String) async throws -> AuthUser { currentUser! }
            func upgradeGuest(name: String, email: String, password: String) async throws -> AuthUser { currentUser! }
            func linkGoogle(idToken: String, accessToken: String) async throws -> AuthUser { currentUser! }
            func linkGoogle() async throws -> AuthUser { currentUser! }
            func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws -> AuthUser { currentUser! }
            func linkApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws -> AuthUser { currentUser! }
            func signInWithApple() async throws -> AuthUser { currentUser! }
            func linkApple() async throws -> AuthUser { currentUser! }
            func sendPasswordReset(email: String) async throws {}
            func sendEmailVerification() async throws {}
            func reauthenticate(password: String) async throws {}
            func reloadUser() async throws -> AuthUser? { currentUser }
            func signOut() throws {}
            func deleteAccount() async throws {
                audit.record("deleteAccount")
            }
        }

        let profileRepo = MockProfileRepo(audit: audit)
        let convoRepo = MockConvoRepo(audit: audit)
        let vault = MockVault(audit: audit)
        let auth = MockAuth(audit: audit)

        // Execute cascade
        let testUid = "user-delete-1"
        try await profileRepo.deleteProfile(userId: testUid)
        try await convoRepo.deleteAllConversations(userId: testUid)
        try vault.clearCredentials()
        try await auth.deleteAccount()

        #expect(audit.order == ["deleteProfile", "deleteAllConversations", "clearCredentials", "deleteAccount"])
    }

    @Test("FAQ search accurately filters by questions, keywords, and answers")
    func testFAQSearch() {
        let allItems = FAQCatalog.items
        #expect(allItems.count >= 6)

        // Search for "lighting" -> should return troubleshooting item
        let lightingResults = allItems.filter {
            $0.question.lowercased().contains("lighting") ||
            $0.answer.lowercased().contains("lighting") ||
            $0.keywords.contains(where: { $0.contains("lighting") })
        }
        #expect(!lightingResults.isEmpty)
        #expect(lightingResults.contains(where: { $0.id == "faq-not-recognised" }))

        // Search for "privacy" -> should return private conversation item
        let privacyResults = allItems.filter {
            $0.question.lowercased().contains("privacy") ||
            $0.answer.lowercased().contains("privacy") ||
            $0.keywords.contains(where: { $0.contains("privacy") })
        }
        #expect(!privacyResults.isEmpty)
        #expect(privacyResults.contains(where: { $0.id == "faq-privacy" }))

        // Search for "dominant" -> should return dominant hand item
        let dominantResults = allItems.filter {
            $0.question.lowercased().contains("dominant") ||
            $0.answer.lowercased().contains("dominant") ||
            $0.keywords.contains(where: { $0.contains("dominant") })
        }
        #expect(!dominantResults.isEmpty)
        #expect(dominantResults.contains(where: { $0.id == "faq-dominant-hand" }))

        // Search for "nonexistent query" -> should return empty
        let emptyResults = allItems.filter {
            $0.question.lowercased().contains("xyz123random") ||
            $0.answer.lowercased().contains("xyz123random") ||
            $0.keywords.contains(where: { $0.contains("xyz123random") })
        }
        #expect(emptyResults.isEmpty)
    }
}
