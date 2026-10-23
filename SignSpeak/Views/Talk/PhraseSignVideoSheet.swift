import SwiftUI

/// Sign Language visual demonstration modal sheet (`39c-quick-phrases`).
/// Displays looping gesture video guide, sign steps, and a Speak Now button.
public struct PhraseSignVideoSheet: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    public let phrase: QuickPhrase
    public let onSpeak: ((QuickPhrase) -> Void)?

    @State private var matchedSign: Sign? = nil
    @State private var isSpeaking: Bool = false

    public init(phrase: QuickPhrase, onSpeak: ((QuickPhrase) -> Void)? = nil) {
        self.phrase = phrase
        self.onSpeak = onSpeak
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Drag indicator
                Capsule()
                    .fill(Color.textSecondary.opacity(0.3))
                    .frame(width: 44, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                // Header
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(phrase.isEmergency ? Color.danger.opacity(0.15) : Color.brandTurquoise.opacity(0.15))
                            .frame(width: 40, height: 40)

                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(phrase.isEmergency ? Color.danger : Color.brandTurquoise)
                    }

                    VStack(alignment: .leading, spacing: 3) {
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

                        Text(phrase.text)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                            .padding(8)
                            .background(Color.cardBackground, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.m)

                ScrollView {
                    VStack(spacing: Theme.Spacing.m) {
                        // Media container
                        ZStack(alignment: .bottomLeading) {
                            if let matchedSign {
                                SignMediaPlayer(sign: matchedSign)
                                    .frame(height: 220)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                            } else {
                                // Stylized animated sign gesture card
                                ZStack {
                                    Color(red: 11/255, green: 42/255, blue: 74/255)

                                    VStack(spacing: 14) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.brandTurquoise.opacity(0.15))
                                                .frame(width: 80, height: 80)

                                            Image(systemName: "hands.sparkles.fill")
                                                .font(.system(size: 40))
                                                .foregroundStyle(Color.brandTurquoise)
                                        }

                                        Text("Gesture Demonstration")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(Color.white)

                                        Text(phrase.note ?? "Clear, expressive ASL phrasing for immediate recognition")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.white.opacity(0.8))
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 24)
                                    }
                                }
                                .frame(height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                            }

                            // Looping Gesture Guide Badge
                            HStack(spacing: 5) {
                                Image(systemName: "repeat")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Looping Gesture Guide")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(Color.brandTurquoise)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.75), in: Capsule())
                            .padding(12)
                        }

                        // Instructional guidance if available
                        if let matchedSign, !matchedSign.howToSteps.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("HOW TO SIGN")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.textSecondary)

                                ForEach(Array(matchedSign.howToSteps.enumerated()), id: \.offset) { idx, step in
                                    HStack(alignment: .top, spacing: 10) {
                                        Text("\(idx + 1)")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(Color.brandTurquoise)
                                            .frame(width: 20, height: 20)
                                            .background(Color.brandTurquoise.opacity(0.15), in: Circle())

                                        Text(step)
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.textPrimary)
                                    }
                                }
                            }
                            .padding(Theme.Spacing.m)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                }

                // Action Bar
                HStack(spacing: 12) {
                    Button {
                        speakAloud()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                                .font(.system(size: 16, weight: .bold))
                            Text(isSpeaking ? "Speaking…" : "Speak Now")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(red: 11/255, green: 42/255, blue: 74/255), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 100, height: 50)
                    .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 14))
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.m)
                .padding(.bottom, Theme.Spacing.l)
                .background(Color.cardBackground.opacity(0.5))
            }
            .background(Color.appBackground.ignoresSafeArea())
            .task {
                lookupSign()
            }
        }
    }

    private func lookupSign() {
        if let signId = phrase.signId, let sign = dependencies.signCatalogService.sign(byId: signId) {
            matchedSign = sign
            return
        }
        if let sign = dependencies.signCatalogService.sign(named: phrase.text) {
            matchedSign = sign
            return
        }
    }

    private func speakAloud() {
        isSpeaking = true
        onSpeak?(phrase)

        Task {
            try? await dependencies.speechSynthesisService.speak(text: phrase.text, voiceLanguage: "en-US")
            try? await Task.sleep(nanoseconds: 800_000_000)
            isSpeaking = false
        }
    }
}
