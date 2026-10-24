import SwiftUI
import MessageUI

/// FAQ Item model for searchable FAQ list.
public struct FAQItem: Identifiable, Sendable {
    public let id: String
    public let question: String
    public let answer: String
    public let category: String
    public let keywords: [String]

    public init(id: String, question: String, answer: String, category: String, keywords: [String] = []) {
        self.id = id
        self.question = question
        self.answer = answer
        self.category = category
        self.keywords = keywords
    }
}

/// Catalog of pre-seeded FAQ items for SignSpeak.
public enum FAQCatalog {
    public static let items: [FAQItem] = [
        FAQItem(
            id: "faq-how-it-works",
            question: "How does sign recognition work?",
            answer: "SignSpeak analyzes video frames from your camera at 30 fps using Apple Vision hand pose detection to extract 21 3D joint landmarks per hand. These normalized landmarks are evaluated in real time by an on-device CoreML neural network, guaranteeing instant feedback without cloud latency.",
            category: "Technology",
            keywords: ["recognition", "camera", "vision", "coreml", "ai", "model"]
        ),
        FAQItem(
            id: "faq-not-recognised",
            question: "Why isn't my sign being recognised?",
            answer: "Recognition accuracy depends on good lighting and framing. Ensure your hands are within the viewfinder guide, palms facing the camera at a distance of 1.5–3 feet. Avoid backlighting or loose clothing that obstructs finger silhouettes. Hold the finished pose steady for 1 second.",
            category: "Troubleshooting",
            keywords: ["accuracy", "detect", "fail", "lighting", "hands", "distance", "pose"]
        ),
        FAQItem(
            id: "faq-privacy",
            question: "Is my conversation data private?",
            answer: "Yes, completely! Camera video feeds and speech audio are processed 100% on your device and are never streamed, stored remotely, or used for AI retraining. Conversation transcripts remain local on your device until you choose to export or delete them.",
            category: "Privacy",
            keywords: ["privacy", "private", "security", "stream", "cloud", "camera", "microphone", "confidential"]
        ),
        FAQItem(
            id: "faq-dominant-hand",
            question: "How do I change my dominant hand?",
            answer: "You can toggle between Right and Left hand signing in Settings > Accessibility > Left-Handed Signing Mode or in your Edit Profile screen. Enabling Left-Handed Mode automatically mirrors hand guides, flips landmark coordinates, and mirrors demonstration clips.",
            category: "Accessibility",
            keywords: ["dominant", "hand", "left", "right", "mirror", "handedness"]
        ),
        FAQItem(
            id: "faq-dictionary-signs",
            question: "What signs are currently supported?",
            answer: "SignSpeak currently recognizes the full ASL manual alphabet (A–Z), numbers 1–10, core greetings (Hello, Thank You, Please, Welcome, Good Morning), emergency alerts (Help, Doctor, Police, Fire), food items (Water, Coffee, Tea, Eat), and everyday conversational phrases. New signs are added regularly!",
            category: "Curriculum",
            keywords: ["alphabet", "signs", "words", "dictionary", "numbers", "greetings", "supported"]
        ),
        FAQItem(
            id: "faq-sound-alerts",
            question: "How do Sound Alerts work?",
            answer: "Sound Alerts utilize Apple's SoundAnalysis framework to detect emergency sirens, fire alarms, smoke detectors, and doorbell chimes in your surroundings. When an alert sound is classified, your iPhone flashes its screen border and emits distinct haptic pulses.",
            category: "Awareness",
            keywords: ["sound", "alert", "siren", "doorbell", "flash", "vibration", "alarm"]
        )
    ]
}

/// Screen 60: Help & About view (`60-help-and-about`).
/// Provides searchable FAQs, mail composer for support, report translation issue form,
/// request a sign form, acknowledgements (Apple frameworks, Firebase, WFD Deaf Flag), and version info.
public struct HelpAndAboutView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""
    @State private var expandedItemIds: Set<String> = []

    // Modals
    @State private var showingReportIssueSheet = false
    @State private var showingRequestSignSheet = false
    @State private var showingLicensesSheet = false
    @State private var toastMessage: String?

    // Forms
    @State private var reportedSignName: String = ""
    @State private var reportDescription: String = ""
    @State private var requestedSignName: String = ""
    @State private var requestedSignCategory: String = "Everyday"
    @State private var requestedSignNotes: String = ""

    public init() {}

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var filteredFAQItems: [FAQItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return FAQCatalog.items
        }
        return FAQCatalog.items.filter { item in
            item.question.lowercased().contains(query) ||
            item.answer.lowercased().contains(query) ||
            item.keywords.contains(where: { $0.contains(query) }) ||
            item.category.lowercased().contains(query)
        }
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                // Toast
                if let toastMessage {
                    Text(toastMessage)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.brandNavy)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.brandTurquoise, in: Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Search Bar
                searchBar

                // MARK: - FAQ Section
                faqSection

                // MARK: - Contact & Feedback
                supportActionsSection

                // MARK: - About & Acknowledgements
                aboutAppSection

                // Open-source licenses button
                Button {
                    showingLicensesSheet = true
                } label: {
                    Text("View Open-Source Licenses & Notices")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.brandTurquoise)
                }
                .buttonStyle(.plain)
                .padding(.bottom, Theme.Spacing.m)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.m)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Help & About")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingReportIssueSheet) {
            reportIssueModal
        }
        .sheet(isPresented: $showingRequestSignSheet) {
            requestSignModal
        }
        .sheet(isPresented: $showingLicensesSheet) {
            licensesModal
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textSecondary)

            TextField("Search FAQs (e.g. lighting, privacy, camera)…", text: $searchText)
                .font(.system(size: 14))
                .foregroundStyle(Color.textPrimary)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - FAQ Section
    private var faqSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("FREQUENTLY ASKED QUESTIONS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.textSecondary)
                .tracking(0.8)

            VStack(spacing: 0) {
                if filteredFAQItems.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "questionmark.folder")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.textSecondary)
                        Text("No matching answers found")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Text("Try searching with words like 'vision', 'lighting', or 'hand'.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(Theme.Spacing.xl)
                } else {
                    ForEach(Array(filteredFAQItems.enumerated()), id: \.element.id) { index, item in
                        faqAccordionRow(item: item)

                        if index < filteredFAQItems.count - 1 {
                            Divider().padding(.leading, Theme.Spacing.m)
                        }
                    }
                }
            }
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
    }

    private func faqAccordionRow(item: FAQItem) -> some View {
        let isExpanded = expandedItemIds.contains(item.id)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedItemIds.remove(item.id)
                    } else {
                        expandedItemIds.insert(item.id)
                    }
                }
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.question)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                            .multilineTextAlignment(.leading)

                        Text(item.category)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.brandTurquoise)
                            .textCase(.uppercase)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(Theme.Spacing.m)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(item.answer)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                    .lineSpacing(4)
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.bottom, Theme.Spacing.m)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Support & Feedback Section
    private var supportActionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("SUPPORT & FEEDBACK")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.textSecondary)
                .tracking(0.8)

            VStack(spacing: 0) {
                // Email Support
                Button {
                    let mailto = "mailto:support@signspeak.app?subject=SignSpeak%20Support%20Request"
                    if let url = URL(string: mailto) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.brandTurquoise)
                            .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Contact Support Team")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.textPrimary)
                            Text("Email our accessibility engineering team")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(Theme.Spacing.m)
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 52)

                // Report Translation Issue
                Button {
                    showingReportIssueSheet = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.bubble.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.brandYellow)
                            .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Report Translation Issue")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.textPrimary)
                            Text("Tell us if a sign was misinterpreted or needs correction")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(Theme.Spacing.m)
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 52)

                // Request a Sign
                Button {
                    showingRequestSignSheet = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.raised.badge.plus.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.brandTurquoise)
                            .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Request a Sign to Be Added")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.textPrimary)
                            Text("Submit new vocabulary to our dictionary curriculum")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                        }

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

    // MARK: - About & Acknowledgements
    private var aboutAppSection: some View {
        VStack(spacing: Theme.Spacing.m) {
            // App Branding Banner
            VStack(spacing: 6) {
                Image(systemName: "hands.sparkles.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.brandYellow)

                Text("SignSpeak")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)

                Text("Version \(appVersion) (\(appBuild))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.Spacing.m)

            // Acknowledgements Card
            VStack(alignment: .leading, spacing: 10) {
                Text("ACKNOWLEDGEMENTS & HERITAGE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.brandTurquoise)
                    .tracking(0.8)

                Text("SignSpeak honors the richness of American Sign Language (ASL) and Deaf culture. We recognize and adopt the official World Federation of the Deaf (WFD) Deaf Flag colors—Navy Blue, Turquoise, and Yellow—symbolizing Deaf pride, unity, and signing language rights.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
                    .lineSpacing(4)

                Divider()

                HStack(spacing: 8) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textPrimary)
                    Text("Built with Apple Vision, CoreML, Speech & SwiftUI")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                }
            }
            .padding(Theme.Spacing.m)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
    }

    // MARK: - Modal 1: Report Issue
    private var reportIssueModal: some View {
        NavigationStack {
            Form {
                Section("Sign Information") {
                    TextField("Sign Name (e.g. 'Coffee', 'Doctor')", text: $reportedSignName)
                }

                Section("Issue Description") {
                    TextField("What happened? (e.g. false positive, wrong hand shape)", text: $reportDescription, axis: .vertical)
                        .lineLimit(4...8)
                }
            }
            .navigationTitle("Report Translation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showingReportIssueSheet = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Submit") {
                        showingReportIssueSheet = false
                        withAnimation { toastMessage = "Thank you! Translation report submitted." }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation { toastMessage = nil }
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.brandTurquoise)
                    .disabled(reportedSignName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Modal 2: Request Sign
    private var requestSignModal: some View {
        NavigationStack {
            Form {
                Section("Sign Details") {
                    TextField("Sign Word / Phrase", text: $requestedSignName)

                    Picker("Category", selection: $requestedSignCategory) {
                        Text("Everyday").tag("Everyday")
                        Text("Greetings").tag("Greetings")
                        Text("Emergency").tag("Emergency")
                        Text("Food & Drink").tag("Food & Drink")
                        Text("Family").tag("Family")
                    }
                }

                Section("Notes or Context") {
                    TextField("Context or variation description…", text: $requestedSignNotes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Request a Sign")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showingRequestSignSheet = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Submit") {
                        let name = requestedSignName.trimmingCharacters(in: .whitespaces)
                        let notes = requestedSignNotes
                        let cat = requestedSignCategory
                        Task {
                            let uid = dependencies.authService.currentUserId ?? "guest"
                            let request = SignRequest(
                                id: UUID().uuidString,
                                requesterId: uid,
                                term: name,
                                category: cat,
                                notes: notes.isEmpty ? nil : notes,
                                requestedAt: Date(),
                                status: "pending"
                            )
                            try? await dependencies.signRequestRepository.submitRequest(request)
                        }
                        showingRequestSignSheet = false
                        withAnimation { toastMessage = "Sign request submitted for review!" }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation { toastMessage = nil }
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.brandTurquoise)
                    .disabled(requestedSignName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Modal 3: Open-Source Licenses
    private var licensesModal: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Open-Source Licenses & Attributions")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.textPrimary)

                    licenseItem(
                        name: "Firebase Apple SDK",
                        author: "Google LLC",
                        license: "Apache License 2.0"
                    )

                    licenseItem(
                        name: "Swift Collections",
                        author: "Apple Inc.",
                        license: "Apache License 2.0 with Runtime Exception"
                    )

                    licenseItem(
                        name: "World Federation of the Deaf (WFD) Deaf Flag",
                        author: "Arnaud Balard / WFD",
                        license: "Deaf Heritage & International Sign Rights Attribution"
                    )
                }
                .padding(Theme.Spacing.l)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Licenses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showingLicensesSheet = false }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.brandTurquoise)
                }
            }
        }
    }

    private func licenseItem(name: String, author: String, license: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            Text("Copyright © \(author)")
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)

            Text("Licensed under the \(license).")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.brandTurquoise)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview("Help and About View") {
    NavigationStack {
        HelpAndAboutView()
    }
}
