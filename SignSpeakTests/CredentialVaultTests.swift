import Foundation
import Testing
@testable import SignSpeak

@Suite("CredentialVault Keychain & Biometric Storage")
struct CredentialVaultTests {

    private func makeIsolatedDefaults() -> UserDefaults {
        let suite = "test-vault-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test("MockCredentialVault records save and retrieval lifecycle")
    func mockVaultLifecycle() async throws {
        let vault = MockCredentialVault()
        #expect(vault.hasStoredCredentials == false)
        #expect(vault.storedEmail == nil)

        try vault.saveCredentials(email: "maya.k@icloud.com", password: "SuperSecret123!")
        #expect(vault.saveCallCount == 1)
        #expect(vault.hasStoredCredentials == true)
        #expect(vault.storedEmail == "maya.k@icloud.com")

        let retrieved = try await vault.retrieveCredentials(promptReason: "Sign in")
        #expect(vault.retrieveCallCount == 1)
        #expect(retrieved?.email == "maya.k@icloud.com")
        #expect(retrieved?.password == "SuperSecret123!")

        try vault.clearCredentials()
        #expect(vault.clearCallCount == 1)
        #expect(vault.hasStoredCredentials == false)
        #expect(vault.storedEmail == nil)

        let emptyResult = try await vault.retrieveCredentials(promptReason: "Sign in")
        #expect(emptyResult == nil)
    }

    @Test("MockCredentialVault throws CancellationError when user cancels prompt")
    func mockVaultCancellation() async {
        let vault = MockCredentialVault(storedEmail: "maya.k@icloud.com", storedPassword: "password123")
        vault.shouldCancel = true

        await #expect(throws: CancellationError.self) {
            _ = try await vault.retrieveCredentials(promptReason: "Sign in")
        }
    }

    @Test("MockCredentialVault propagates biometricsChanged error")
    func mockVaultBiometricsChanged() async {
        let vault = MockCredentialVault(storedEmail: "maya.k@icloud.com", storedPassword: "password123")
        vault.shouldThrowError = CredentialVaultError.biometricsChanged

        await #expect(throws: CredentialVaultError.biometricsChanged) {
            _ = try await vault.retrieveCredentials(promptReason: "Sign in")
        }
    }

    @Test("KeychainCredentialVault validates empty input and encodes safely")
    func keychainVaultInputValidation() throws {
        let defaults = makeIsolatedDefaults()
        let vault = KeychainCredentialVault(serviceName: "test.service.\(UUID().uuidString)", userDefaults: defaults)

        #expect(vault.hasStoredCredentials == false)
        #expect(vault.storedEmail == nil)

        #expect(throws: CredentialVaultError.encodingFailed) {
            try vault.saveCredentials(email: "", password: "password")
        }

        #expect(throws: CredentialVaultError.encodingFailed) {
            try vault.saveCredentials(email: "test@example.com", password: "")
        }
    }

    @Test("StubCredentialVault provides realistic preview data")
    func stubVaultData() async throws {
        let stub = StubCredentialVault(hasStoredCredentials: true, storedEmail: "maya.k@icloud.com")
        #expect(stub.hasStoredCredentials == true)
        #expect(stub.storedEmail == "maya.k@icloud.com")

        let credentials = try await stub.retrieveCredentials(promptReason: "Test")
        #expect(credentials?.email == "maya.k@icloud.com")
        #expect(credentials?.password == "SuperSecret123!")
    }
}
