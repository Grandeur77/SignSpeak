import SwiftUI

/// Accessible modal sheet explaining SignSpeak's terms of service and acceptable use policies.
public struct TermsOfServiceSheet: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    Text("Terms of Service")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.textPrimary)

                    Text("Last updated: October 2026")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)

                    Group {
                        Text("1. Purpose & Learning Scope")
                            .font(.headline)
                            .foregroundStyle(Color.textPrimary)

                        Text("SignSpeak is designed to empower communication and education in American Sign Language (ASL). While our on-device machine learning models aim for high accuracy, automated recognition should not be relied upon as a substitute for certified human interpreters in critical legal, medical, or emergency contexts.")
                            .font(.subheadline)
                            .foregroundStyle(Color.textPrimary)

                        Text("2. User Accounts & Fair Use")
                            .font(.headline)
                            .foregroundStyle(Color.textPrimary)

                        Text("You agree to use SignSpeak respectfully and preserve the integrity of our signing community. You are responsible for safeguarding your login credentials and ensuring any contributions align with community standards.")
                            .font(.subheadline)
                            .foregroundStyle(Color.textPrimary)

                        Text("3. On-Device Processing Guarantee")
                            .font(.headline)
                            .foregroundStyle(Color.textPrimary)

                        Text("All camera vision frames, hand pose landmarks, audio streams, and acoustic classification run exclusively on your physical Apple device. No raw video or audio streams are transmitted to remote servers.")
                            .font(.subheadline)
                            .foregroundStyle(Color.textPrimary)
                    }

                    Spacer(minLength: 40)
                }
                .padding(Theme.Spacing.l)
            }
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.brandTurquoise)
                }
            }
        }
    }
}

/// Accessible modal sheet highlighting on-device privacy, zero raw media ingestion, and data governance.
public struct PrivacyPolicySheet: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    Text("Privacy & Deaf Data Ethics")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.textPrimary)

                    Text("Last updated: October 2026")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)

                    Group {
                        Text("1. What We Store")
                            .font(.headline)
                            .foregroundStyle(Color.textPrimary)

                        Text("We only store your account identifier, name, email address, practice streaks, and learning statistics in secure cloud storage. This enables synchronization across your devices.")
                            .font(.subheadline)
                            .foregroundStyle(Color.textPrimary)

                        Text("2. What Never Leaves Your iPhone")
                            .font(.headline)
                            .foregroundStyle(Color.textPrimary)

                        Text("Your live camera feed, hand landmarks, microphone input, sound emergency alerts, and biometric face prints are processed strictly on-device using Apple Core ML, Vision, and LocalAuthentication. Raw sensor data is discarded immediately after analysis.")
                            .font(.subheadline)
                            .foregroundStyle(Color.textPrimary)

                        Text("3. Your Rights & Deletion")
                            .font(.headline)
                            .foregroundStyle(Color.textPrimary)

                        Text("You maintain full control of your information. You can export your progress records or permanently delete your account and all associated cloud data at any time directly within Settings.")
                            .font(.subheadline)
                            .foregroundStyle(Color.textPrimary)
                    }

                    Spacer(minLength: 40)
                }
                .padding(Theme.Spacing.l)
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.brandTurquoise)
                }
            }
        }
    }
}
