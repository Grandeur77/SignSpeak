import SwiftUI

/// Screen 56: Delete Account view (`56-delete-account`).
/// Requires typing "DELETE" to confirm irreversible erasure of the user's
/// profile, progress, conversations, Keychain credentials, and authentication account.
public struct DeleteAccountView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var confirmationText: String = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?

    public init() {}

    private var isConfirmationValid: Bool {
        confirmationText.trimmingCharacters(in: .whitespaces) == "DELETE"
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                // Warning Header
                VStack(spacing: Theme.Spacing.m) {
                    ZStack {
                        Circle()
                            .fill(Color.danger.opacity(0.12))
                            .frame(width: 64, height: 64)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(Color.danger)
                    }

                    VStack(spacing: 4) {
                        Text("Delete Your Account")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.textPrimary)

                        Text("This action is permanent and cannot be undone.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.danger)
                    }
                }
                .padding(.top, Theme.Spacing.s)

                // Detailed Impact List
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    Text("WHAT WILL BE PERMANENTLY ERASED:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.textSecondary)
                        .tracking(0.8)

                    VStack(alignment: .leading, spacing: 12) {
                        impactRow(icon: "person.crop.circle.badge.xmark", text: "Your personal profile, display name, and avatar image")
                        impactRow(icon: "flame.fill", text: "All practice streaks, daily milestones, and 16 achievement badges")
                        impactRow(icon: "chart.line.uptrend.xyaxis", text: "Sign accuracy statistics, total XP, and progress history")
                        impactRow(icon: "bubble.left.and.bubble.right.fill", text: "All saved two-way Communicator transcripts and message logs")
                        impactRow(icon: "key.fill", text: "Saved biometric credentials and Face ID Keychain tokens")
                        impactRow(icon: "person.3.fill", text: "Community forum comments, reactions, and demonstration clips")
                    }
                }
                .padding(Theme.Spacing.l)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))

                // Error Message if any
                if let errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(Color.danger)
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.danger)
                    }
                    .padding(Theme.Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                }

                // Confirmation Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("To confirm, type DELETE in all capital letters:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.textPrimary)

                    TextField("Type DELETE", text: $confirmationText)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .padding(Theme.Spacing.m)
                        .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isConfirmationValid ? Color.danger : Color.clear, lineWidth: 1.5)
                        )
                }
                .padding(Theme.Spacing.l)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))

                // Action Buttons
                VStack(spacing: 12) {
                    // Delete Button
                    Button {
                        Task {
                            await performAccountDeletion()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isDeleting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "trash.fill")
                                Text("Permanently Delete Account")
                                    .font(.system(size: 16, weight: .bold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            isConfirmationValid && !isDeleting ? Color.danger : Color.danger.opacity(0.3),
                            in: RoundedRectangle(cornerRadius: Theme.Radius.button)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!isConfirmationValid || isDeleting)

                    // Keep My Account Button
                    Button {
                        dismiss()
                    } label: {
                        Text("Keep My Account")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, Theme.Spacing.s)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.m)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func impactRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.danger)
                .frame(width: 20, height: 20)

            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
                .lineSpacing(2)
        }
    }

    private func performAccountDeletion() async {
        isDeleting = true
        errorMessage = nil

        let uid = dependencies.authService.currentUserId ?? "guest"

        do {
            // Step 1: Delete User Firestore Profile and subcollections
            try await dependencies.userProfileRepository.deleteProfile(userId: uid)

            // Step 2: Clear all saved conversation transcripts
            try await dependencies.conversationRepository.deleteAllConversations(userId: uid)

            // Step 3: Clear secure Keychain items
            try? dependencies.credentialVault.clearCredentials()

            // Step 4: Delete Firebase Auth Account
            try await dependencies.authService.deleteAccount()

            // Step 5: Sign out router
            router.signOut()
        } catch {
            isDeleting = false
            errorMessage = "Failed to complete account deletion: \(error.localizedDescription)"
        }
    }
}

#Preview("Delete Account View") {
    NavigationStack {
        DeleteAccountView()
            .environment(
                AppRouter(
                    authService: StubAuthService(initialUserId: "user-1"),
                    userProfileRepository: StubUserProfileRepository(),
                    biometricAuthService: StubBiometricAuthService()
                )
            )
    }
}
