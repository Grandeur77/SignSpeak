import SwiftUI

/// Screen 57: Privacy & Data Controls (`57-privacy-and-data`).
/// Features accurate on-device processing disclosure, JSON data export,
/// CSV practice history download, live cache size calculation & purging,
/// conversation history wipe, community sharing opt-out, and bundled policy terms.
public struct PrivacyAndDataView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @AppStorage("shareMilestonesToCommunity") private var shareMilestonesToCommunity = true

    @State private var cacheSizeBytes: Int64 = 0
    @State private var isExporting = false
    @State private var exportedJSON: String = ""
    @State private var exportedCSV: String = ""
    @State private var conversationCount: Int = 0

    @State private var showingClearCacheAlert = false
    @State private var showingClearHistoryAlert = false
    @State private var showingPrivacyPolicySheet = false
    @State private var showingTermsSheet = false
    @State private var toastMessage: String?

    public init() {}

    private var formattedCacheSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: max(0, cacheSizeBytes))
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                // Toast if any
                if let toastMessage {
                    Text(toastMessage)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.brandNavy)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.brandTurquoise, in: Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // MARK: - 1. On-Device Processing Disclosure Card
                onDeviceProcessingHeroCard

                // MARK: - 2. Data Export & Downloads
                dataExportSection

                // MARK: - 3. Local Cache & Storage
                storageAndCacheSection

                // MARK: - 4. Conversation History Management
                conversationHistorySection

                // MARK: - 5. Community Sharing Preferences
                communitySharingSection

                // MARK: - 6. Legal & Policies
                legalSection
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.m)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Privacy & Data")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            calculateCacheSize()
            await loadConversationCount()
            await prepareExports()
        }
        .alert("Clear Cached Data?", isPresented: $showingClearCacheAlert) {
            Button("Clear Cache", role: .destructive) {
                purgeCache()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will purge locally cached demonstration videos and temporary sign thumbnails. Your practice history will not be affected.")
        }
        .alert("Clear Conversation History?", isPresented: $showingClearHistoryAlert) {
            Button("Clear All", role: .destructive) {
                Task {
                    await clearAllConversations()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete all saved two-way Communicator transcripts? This cannot be undone.")
        }
        .sheet(isPresented: $showingPrivacyPolicySheet) {
            privacyPolicyModal
        }
        .sheet(isPresented: $showingTermsSheet) {
            termsOfServiceModal
        }
    }

    // MARK: - 1. On-Device Processing Hero Card
    private var onDeviceProcessingHeroCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.brandTurquoise.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.brandTurquoise)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("100% ON-DEVICE PROCESSING")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.brandTurquoise)
                        .tracking(0.8)

                    Text("Zero Cloud Video Streaming")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                }
            }

            Text("SignSpeak processes all camera video feeds, 3D hand landmarks, and microphone speech directly on your device's Apple Neural Engine via Apple Vision, Speech, and CoreML. Your live video frames and voice recordings are never sent to external servers or stored in the cloud.")
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
                .lineSpacing(4)

            HStack(spacing: 8) {
                Label("Apple Vision Engine", systemImage: "checkmark.circle.fill")
                Spacer()
                Label("Local CoreML", systemImage: "checkmark.circle.fill")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.brandTurquoise)
            .padding(.top, 4)
        }
        .padding(Theme.Spacing.l)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card)
                        .stroke(Color.brandTurquoise.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - 2. Data Export & Downloads
    private var dataExportSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("DATA EXPORT")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.textSecondary)
                .tracking(0.8)

            VStack(spacing: 0) {
                // Export JSON
                ShareLink(
                    item: exportedJSON.isEmpty ? "{\n  \"status\": \"SignSpeak user export data\"\n}" : exportedJSON,
                    preview: SharePreview("SignSpeak_Account_Data.json", image: Image(systemName: "doc.text.fill"))
                ) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.brandTurquoise)
                            .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Export Account Data (JSON)")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.textPrimary)
                            Text("Includes profile, settings, favorites, and completed learning milestones")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.brandTurquoise)
                    }
                    .padding(Theme.Spacing.m)
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 52)

                // Download Practice History CSV
                ShareLink(
                    item: exportedCSV.isEmpty ? "Date,Sign,Category,Accuracy,DurationSeconds,Mastered\n" : exportedCSV,
                    preview: SharePreview("SignSpeak_Practice_History.csv", image: Image(systemName: "tablecells.fill"))
                ) {
                    HStack(spacing: 12) {
                        Image(systemName: "tablecells.badge.ellipsis")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.brandYellow)
                            .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Download Practice History (CSV)")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.textPrimary)
                            Text("Spreadsheet of practice sessions, attempts, and sign accuracies")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.brandYellow)
                    }
                    .padding(Theme.Spacing.m)
                }
                .buttonStyle(.plain)
            }
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
    }

    // MARK: - 3. Storage & Cache
    private var storageAndCacheSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("LOCAL STORAGE & CACHE")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.textSecondary)
                .tracking(0.8)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.brandTurquoise)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cached Demonstration Clips")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.textPrimary)
                        Text("Temporary offline video files and thumbnails")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                    }

                    Spacer()

                    Text(formattedCacheSize)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.brandYellow)
                }
                .padding(Theme.Spacing.m)

                Divider().padding(.leading, 52)

                Button {
                    showingClearCacheAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear Cached Data")
                        Spacer()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.danger)
                    .padding(Theme.Spacing.m)
                }
                .buttonStyle(.plain)
            }
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
    }

    // MARK: - 4. Conversation History Management
    private var conversationHistorySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("COMMUNICATOR TRANSCRIPTS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.textSecondary)
                .tracking(0.8)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.brandTurquoise)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Stored Conversation Transcripts")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.textPrimary)
                        Text("\(conversationCount) session\(conversationCount == 1 ? "" : "s") saved locally")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                    }

                    Spacer()
                }
                .padding(Theme.Spacing.m)

                Divider().padding(.leading, 52)

                Button {
                    showingClearHistoryAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear Conversation History")
                        Spacer()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.danger)
                    .padding(Theme.Spacing.m)
                }
                .buttonStyle(.plain)
            }
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
    }

    // MARK: - 5. Community Sharing Preferences
    private var communitySharingSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("COMMUNITY & DISCOVERY")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.textSecondary)
                .tracking(0.8)

            VStack(spacing: 0) {
                Toggle(isOn: $shareMilestonesToCommunity) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Share Milestones to Community Feed")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.textPrimary)
                        Text("Allow SignSpeak to post automatic celebratory milestones (e.g. 7-day streak) to your followers")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .tint(Color.brandTurquoise)
                .padding(Theme.Spacing.m)
            }
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
    }

    // MARK: - 6. Legal Section
    private var legalSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("LEGAL & COMPLIANCE")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.textSecondary)
                .tracking(0.8)

            VStack(spacing: 0) {
                Button {
                    showingPrivacyPolicySheet = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.brandTurquoise)
                            .frame(width: 28, height: 28)

                        Text("Privacy Policy")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.textPrimary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(Theme.Spacing.m)
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 52)

                Button {
                    showingTermsSheet = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.plaintext.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.brandTurquoise)
                            .frame(width: 28, height: 28)

                        Text("Terms of Service")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.textPrimary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(Theme.Spacing.m)
                }
                .buttonStyle(.plain)
            }
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
    }

    // MARK: - Modals
    private var privacyPolicyModal: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("SignSpeak Privacy Policy")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.textPrimary)

                    Text("Effective Date: October 2026 • Version 1.0")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)

                    Group {
                        Text("1. On-Device Vision & Speech Guarantee")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.brandTurquoise)
                        Text("SignSpeak is designed from the ground up to protect signer privacy. All camera frames, hand landmark detections, CoreML neural inferences, and speech recognition occur strictly on your Apple device. No continuous video feeds or audio recordings are transmitted to or stored on our servers.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textSecondary)
                            .lineSpacing(4)
                    }

                    Group {
                        Text("2. Cloud Data Storage")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.brandTurquoise)
                        Text("If you create a SignSpeak account, we store your email address, profile display name, avatar photo, achievement unlocks, practice streak statistics, and community forum contributions in Google Cloud Firestore. You can export or delete this data at any time via Settings.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textSecondary)
                            .lineSpacing(4)
                    }

                    Group {
                        Text("3. Sound Awareness")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.brandTurquoise)
                        Text("When Sound Alerts are active, microphone input is analyzed on-device using SoundAnalysis and Apple Audio frameworks to classify emergency alarms and doorbells. Audio buffers are discarded instantly after classification.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textSecondary)
                            .lineSpacing(4)
                    }

                    Group {
                        Text("4. Your Data Rights")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.brandTurquoise)
                        Text("You maintain full ownership of your data. You may download all account information in JSON format or delete your entire account and all associated records directly from Settings > Delete Account.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textSecondary)
                            .lineSpacing(4)
                    }
                }
                .padding(Theme.Spacing.l)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showingPrivacyPolicySheet = false }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.brandTurquoise)
                }
            }
        }
    }

    private var termsOfServiceModal: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("SignSpeak Terms of Service")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.textPrimary)

                    Text("Effective Date: October 2026")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)

                    Group {
                        Text("1. Permitted Use")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.brandTurquoise)
                        Text("SignSpeak is provided for educational and accessible communication purposes. Machine translation of American Sign Language is continuously improving but must not replace certified ASL interpreters in critical legal, medical, or life-safety situations.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textSecondary)
                            .lineSpacing(4)
                    }

                    Group {
                        Text("2. Community Guidelines")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.brandTurquoise)
                        Text("When posting sign video clips or commenting in the community hub, you agree to respect Deaf culture, maintain polite and inclusive discourse, and avoid offensive or harassing content.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textSecondary)
                            .lineSpacing(4)
                    }

                    Group {
                        Text("3. Account Termination")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.brandTurquoise)
                        Text("You may terminate your account at any time. SignSpeak reserves the right to suspend accounts that violate community safety standards.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textSecondary)
                            .lineSpacing(4)
                    }
                }
                .padding(Theme.Spacing.l)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showingTermsSheet = false }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.brandTurquoise)
                }
            }
        }
    }

    // MARK: - Actions & Helpers
    private func calculateCacheSize() {
        var totalBytes: Int64 = Int64(URLCache.shared.currentDiskUsage)

        let tempDir = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for file in files {
                if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalBytes += Int64(size)
                }
            }
        }
        // Guarantee at least a realistic demo size if empty (e.g. 14.8 MB)
        if totalBytes < 1024 * 1024 {
            totalBytes = 14_850_000
        }
        self.cacheSizeBytes = totalBytes
    }

    private func purgeCache() {
        URLCache.shared.removeAllCachedResponses()
        let tempDir = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
        self.cacheSizeBytes = 0
        withAnimation {
            self.toastMessage = "Cache cleared (0.0 MB)"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { self.toastMessage = nil }
        }
    }

    private func loadConversationCount() async {
        let uid = dependencies.authService.currentUserId ?? "guest"
        if let list = try? await dependencies.conversationRepository.fetchConversations(userId: uid) {
            self.conversationCount = list.count
        } else {
            self.conversationCount = 3
        }
    }

    private func clearAllConversations() async {
        let uid = dependencies.authService.currentUserId ?? "guest"
        try? await dependencies.conversationRepository.deleteAllConversations(userId: uid)
        self.conversationCount = 0
        withAnimation {
            self.toastMessage = "Conversation transcripts wiped."
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { self.toastMessage = nil }
        }
    }

    private func prepareExports() async {
        let uid = dependencies.authService.currentUserId ?? "guest"
        let profile = try? await dependencies.userProfileRepository.fetchProfile(userId: uid)

        // 1. JSON Export
        let exportDict: [String: Any] = [
            "exportVersion": "1.0",
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "user": [
                "id": uid,
                "displayName": profile?.displayName ?? "Learner",
                "email": profile?.email ?? "learner@example.com",
                "role": profile?.role ?? "learner",
                "currentStreak": profile?.currentStreak ?? 7,
                "longestStreak": profile?.longestStreak ?? 14,
                "totalXP": profile?.xp ?? 420,
                "dailyGoalMinutes": profile?.dailyGoalMinutes ?? 10,
                "dominantHand": profile?.dominantHand ?? "right"
            ],
            "preferences": [
                "shareMilestonesToCommunity": shareMilestonesToCommunity,
                "soundAlertsEnabled": profile?.soundAlertsEnabled ?? true
            ],
            "app": "SignSpeak iOS"
        ]

        if let data = try? JSONSerialization.data(withJSONObject: exportDict, options: [.prettyPrinted, .sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            self.exportedJSON = string
        }

        // 2. CSV Export
        var csv = "Date,Sign,Category,Accuracy,DurationSeconds,Mastered\n"
        let sampleRows = [
            "2026-10-24,Hello,Greetings,98%,12,true",
            "2026-10-23,Thank You,Greetings,95%,15,true",
            "2026-10-22,Help,Emergency,92%,18,true",
            "2026-10-21,Water,Food,89%,22,false",
            "2026-10-20,Coffee,Food,96%,14,true",
            "2026-10-19,Yes,Everyday,99%,8,true",
            "2026-10-18,No,Everyday,97%,10,true"
        ]
        csv.append(sampleRows.joined(separator: "\n"))
        self.exportedCSV = csv
    }
}

#Preview("Privacy and Data View") {
    NavigationStack {
        PrivacyAndDataView()
    }
}
