import SwiftUI

/// Preset quick phrase item.
public struct QuickPhraseItem: Identifiable, Sendable {
    public let id: String
    public let text: String
    public let category: String
    public let isEmergency: Bool

    public init(id: String = UUID().uuidString, text: String, category: String, isEmergency: Bool = false) {
        self.id = id
        self.text = text
        self.category = category
        self.isEmergency = isEmergency
    }
}

/// Quick Phrases shortcut sheet (`38-communicator-start`, `39c-quick-phrases`).
/// Allows users to quickly browse and speak frequently used phrases by category.
public struct QuickPhrasesSheet: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: String = "All"
    @State private var spokenPhraseId: String? = nil

    public let categories = ["All", "Essentials", "Emergency", "Greetings", "Questions", "Shopping"]

    public let phrases: [QuickPhraseItem] = [
        QuickPhraseItem(text: "Hello! Nice to meet you.", category: "Greetings"),
        QuickPhraseItem(text: "I am deaf / hard of hearing.", category: "Essentials"),
        QuickPhraseItem(text: "Could you please speak slowly into the phone?", category: "Essentials"),
        QuickPhraseItem(text: "Where is the nearest restroom?", category: "Questions"),
        QuickPhraseItem(text: "How much does this cost?", category: "Shopping"),
        QuickPhraseItem(text: "Thank you for your help!", category: "Greetings"),
        QuickPhraseItem(text: "I need medical assistance immediately.", category: "Emergency", isEmergency: true),
        QuickPhraseItem(text: "Please call emergency services for me.", category: "Emergency", isEmergency: true),
        QuickPhraseItem(text: "Can you write that down, please?", category: "Questions")
    ]

    public var filteredPhrases: [QuickPhraseItem] {
        if selectedCategory == "All" {
            return phrases
        }
        return phrases.filter { $0.category == selectedCategory }
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { cat in
                            let isSelected = selectedCategory == cat
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedCategory = cat
                                }
                            } label: {
                                Text(cat)
                                    .font(.system(size: 13, weight: .semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        isSelected
                                            ? (cat == "Emergency" ? Color.danger : Color.brandTurquoise)
                                            : Color.cardBackground,
                                        in: Capsule()
                                    )
                                    .foregroundStyle(
                                        isSelected
                                            ? (cat == "Emergency" ? Color.white : Color(red: 11/255, green: 42/255, blue: 74/255))
                                            : Color.textPrimary
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.vertical, Theme.Spacing.m)
                }
                .background(Color.cardBackground.opacity(0.5))

                // Phrases List
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredPhrases) { phrase in
                            Button {
                                speakPhrase(phrase)
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(phrase.text)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(phrase.isEmergency ? Color.danger : Color.textPrimary)
                                            .multilineTextAlignment(.leading)

                                        HStack(spacing: 6) {
                                            Text(phrase.category)
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(phrase.isEmergency ? Color.danger : Color.brandTurquoise)

                                            if phrase.isEmergency {
                                                Text("SOS")
                                                    .font(.system(size: 9, weight: .heavy))
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 1)
                                                    .background(Color.danger, in: Capsule())
                                            }
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: spokenPhraseId == phrase.id ? "speaker.wave.3.fill" : "speaker.wave.2")
                                        .font(.system(size: 16))
                                        .foregroundStyle(phrase.isEmergency ? Color.danger : Color.brandTurquoise)
                                }
                                .padding(Theme.Spacing.m)
                                .background(
                                    phrase.isEmergency
                                        ? Color.danger.opacity(0.08)
                                        : Color.cardBackground,
                                    in: RoundedRectangle(cornerRadius: 14)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(
                                            phrase.isEmergency ? Color.danger.opacity(0.3) : Color.clear,
                                            lineWidth: 1.5
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(Theme.Spacing.l)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Quick Phrases")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brandTurquoise)
                }
            }
        }
    }

    private func speakPhrase(_ phrase: QuickPhraseItem) {
        spokenPhraseId = phrase.id
        Task {
            try? await dependencies.speechSynthesisService.speak(text: phrase.text, voiceLanguage: "en-US")
            try? await Task.sleep(nanoseconds: 500_000_000)
            if spokenPhraseId == phrase.id {
                spokenPhraseId = nil
            }
        }
    }
}
