import SwiftUI

/// Screen 46: Report Sheet view (`46-report-sheet`).
/// Allows reporting posts or comments for spam, offensive content, harassment, or misleading signs,
/// with an immediate option to block the author locally.
public struct ReportSheetView: View {
    public let post: CommunityPost
    public let onReport: (CommunityReportReason, String?, Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedReason: CommunityReportReason = .offensive
    @State private var additionalDetails: String = ""
    @State private var alsoBlockUser: Bool = false

    public init(post: CommunityPost, onReport: @escaping (CommunityReportReason, String?, Bool) -> Void) {
        self.post = post
        self.onReport = onReport
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reporting content by @\(post.authorName)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)

                        Text("Reports are reviewed by SignSpeak community safety within 24 hours.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Reason for Reporting") {
                    Picker("Select Reason", selection: $selectedReason) {
                        ForEach(CommunityReportReason.allCases) { reason in
                            Text(reason.rawValue).tag(reason)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section("Additional Details (Optional)") {
                    TextField("Provide any helpful context…", text: $additionalDetails, axis: .vertical)
                        .lineLimit(3...5)
                }

                Section {
                    Toggle(isOn: $alsoBlockUser) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Also Block @\(post.authorName)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                            Text("Hide all future posts and comments from this signer")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                    .tint(Color.brandTurquoise)
                }
            }
            .navigationTitle("Report Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Submit Report") {
                        let details = additionalDetails.trimmingCharacters(in: .whitespaces)
                        onReport(selectedReason, details.isEmpty ? nil : details, alsoBlockUser)
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.danger)
                }
            }
        }
    }
}
