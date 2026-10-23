import SwiftUI

/// Voice & Speech settings screen (design `54-voice-and-speech`).
/// Allows users to select text-to-speech voice, adjust speaking speed (slow / default / fast),
/// preview spoken audio, configure speech recognition language, and toggle on-device noise filtering.
public struct VoiceAndSpeechSettingsView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: VoiceAndSpeechSettingsViewModel?
    @State private var isShowingVoiceSheet: Bool = false

    public init() {}

    public var body: some View {
        ScrollView {
            if let viewModel {
                VStack(spacing: Theme.Spacing.l) {
                    // Header Hero
                    heroHeaderView

                    // Section 1: Spoken Audio (Text-to-Speech)
                    spokenAudioSection(viewModel)

                    // Section 2: Speech Recognition (Microphone Input)
                    speechRecognitionSection(viewModel)

                    // Reset Button
                    resetDefaultsButton(viewModel)
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.xl)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 300)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Voice & Speech")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                viewModel = VoiceAndSpeechSettingsViewModel(
                    speechSynthesisService: dependencies.speechSynthesisService,
                    speechRecognitionService: dependencies.speechRecognitionService
                )
            }
        }
        .sheet(isPresented: $isShowingVoiceSheet) {
            if let viewModel {
                VoiceSelectionSheet(viewModel: viewModel)
            }
        }
    }

    // MARK: - Header Hero

    private var heroHeaderView: some View {
        VStack(spacing: Theme.Spacing.s) {
            ZStack {
                Circle()
                    .fill(Color.brandTurquoise.opacity(0.15))
                    .frame(width: 72, height: 72)

                Image(systemName: "waveform.badge.mic")
                    .font(.system(size: 32, weight: .regular))
                    .foregroundStyle(Color.brandTurquoise)
            }
            .padding(.top, Theme.Spacing.s)

            Text("Voice & Speech")
                .font(.appLargeTitle)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)

            Text("Customize spoken translation voices, speech rate, and on-device microphone noise cancellation.")
                .font(.appBody)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.m)
        }
    }

    // MARK: - Section 1: Spoken Voice & Text-to-Speech

    private func spokenAudioSection(_ viewModel: VoiceAndSpeechSettingsViewModel) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("TEXT-TO-SPEECH VOICE")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, Theme.Spacing.s)

            VStack(spacing: 0) {
                // Voice Selector Row
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.brandTurquoise.opacity(0.15))
                            .frame(width: 40, height: 40)

                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(Color.brandTurquoise)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.selectedVoice?.name ?? "Default Voice")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)

                        HStack(spacing: 6) {
                            Text(viewModel.selectedVoice?.language ?? "en-US")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)

                            if let quality = viewModel.selectedVoice?.qualityDescription, quality != "Default" {
                                Text(quality)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.brandTurquoise)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color.brandTurquoise.opacity(0.15), in: Capsule())
                            }
                        }
                    }

                    Spacer()

                    // Preview Button
                    if let voice = viewModel.selectedVoice {
                        Button {
                            viewModel.previewVoice(voice)
                        } label: {
                            Image(systemName: viewModel.previewingVoiceId == voice.id ? "stop.circle.fill" : "play.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.brandTurquoise)
                        }
                        .buttonStyle(.plain)
                    }

                    // Open Voice Sheet
                    Button {
                        isShowingVoiceSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("Change")
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(Color.brandTurquoise)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.brandTurquoise.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(Theme.Spacing.m)

                Divider().padding(.horizontal, Theme.Spacing.m)

                // Speaking Speed Segmented Row
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Speaking Speed")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)

                        Spacer()

                        Text(viewModel.selectedRate.multiplierText)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.brandTurquoise)
                    }

                    HStack(spacing: 8) {
                        ForEach(SpeakingRate.allCases) { rate in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    viewModel.selectSpeakingRate(rate)
                                }
                            } label: {
                                VStack(spacing: 2) {
                                    Text(rate.title)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(rate.multiplierText)
                                        .font(.system(size: 10))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    viewModel.selectedRate == rate
                                        ? Color.brandTurquoise
                                        : Color.cardBackground.opacity(0.8),
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                                .foregroundStyle(
                                    viewModel.selectedRate == rate
                                        ? Color(red: 11/255, green: 42/255, blue: 74/255)
                                        : Color.textPrimary
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(Theme.Spacing.m)

                Divider().padding(.horizontal, Theme.Spacing.m)

                // Test Spoken Audio Row
                VStack(alignment: .leading, spacing: 10) {
                    Text("Test Spoken Audio")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)

                    TextField("Test phrase", text: Binding(
                        get: { viewModel.testPhrase },
                        set: { viewModel.updateTestPhrase($0) }
                    ), axis: .vertical)
                    .lineLimit(2...3)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textPrimary)
                    .padding(10)
                    .background(Color.appBackground.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))

                    Button {
                        viewModel.playTestAudio()
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.isPlayingTestAudio {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Stop Audio")
                                    .font(.system(size: 13, weight: .bold))
                            } else {
                                Image(systemName: "speaker.wave.3.fill")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Listen to Voice Sample")
                                    .font(.system(size: 13, weight: .bold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            viewModel.isPlayingTestAudio
                                ? Color.danger
                                : Color.brandTurquoise,
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                        .foregroundStyle(
                            viewModel.isPlayingTestAudio
                                ? Color.white
                                : Color(red: 11/255, green: 42/255, blue: 74/255)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(Theme.Spacing.m)
            }
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Section 2: Speech Recognition (Mic Input)

    private func speechRecognitionSection(_ viewModel: VoiceAndSpeechSettingsViewModel) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("SPEECH RECOGNITION (INPUT)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, Theme.Spacing.s)

            VStack(spacing: 0) {
                // Language Selection Menu
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.brandYellow.opacity(0.15))
                            .frame(width: 40, height: 40)

                        Image(systemName: "globe")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.brandYellow)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recognition Language")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)

                        Text(viewModel.selectedRecognitionOption.displayName)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                    }

                    Spacer()

                    Menu {
                        ForEach(VoiceAndSpeechSettingsViewModel.standardRecognitionLanguages) { opt in
                            Button {
                                viewModel.selectRecognitionLanguage(opt.id)
                            } label: {
                                HStack {
                                    Text("\(opt.flag) \(opt.name) (\(opt.region))")
                                    if viewModel.speechRecognitionLanguage == opt.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.selectedRecognitionOption.flag)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.cardBackground.opacity(0.8), in: Capsule())
                        .foregroundStyle(Color.textPrimary)
                    }
                }
                .padding(Theme.Spacing.m)

                Divider().padding(.horizontal, Theme.Spacing.m)

                // Filter Background Noise Toggle
                Toggle(isOn: Binding(
                    get: { viewModel.filterBackgroundNoise },
                    set: { viewModel.setFilterBackgroundNoise($0) }
                )) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.brandTurquoise.opacity(0.15))
                                .frame(width: 40, height: 40)

                            Image(systemName: "waveform.badge.shield.exclamationmark")
                                .font(.system(size: 17))
                                .foregroundStyle(Color.brandTurquoise)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Filter Background Noise")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)

                            Text("Uses hardware voice processing to reduce ambient room noise.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                }
                .tint(Color.brandTurquoise)
                .padding(Theme.Spacing.m)

                Divider().padding(.horizontal, Theme.Spacing.m)

                // Privacy Guarantee Badge
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.brandTurquoise)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("100% On-Device Transcription")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.textPrimary)

                        Text("Speech recognition runs exclusively on your iPhone's Neural Engine. Your voice and conversations are never transmitted to cloud servers.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                            .lineSpacing(2)
                    }
                }
                .padding(Theme.Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.brandTurquoise.opacity(0.06))
            }
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Reset Defaults Button

    private func resetDefaultsButton(_ viewModel: VoiceAndSpeechSettingsViewModel) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.resetToDefaults()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .semibold))
                Text("Reset Voice & Speech Defaults")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Color.textSecondary)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Voice Selection Sheet

/// Sheet letting users browse and test all available on-device text-to-speech voices.
public struct VoiceSelectionSheet: View {
    @Bindable var viewModel: VoiceAndSpeechSettingsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""

    public var filteredVoices: [VoiceOption] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return viewModel.availableVoices
        }
        return viewModel.availableVoices.filter {
            $0.name.lowercased().contains(query) ||
            $0.displayName.lowercased().contains(query) ||
            $0.language.lowercased().contains(query)
        }
    }

    public var body: some View {
        NavigationStack {
            List {
                ForEach(filteredVoices) { voice in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(voice.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)

                                if voice.id == viewModel.selectedVoiceId {
                                    Text("CURRENT")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(Color(red: 11/255, green: 42/255, blue: 74/255))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1)
                                        .background(Color.brandTurquoise, in: Capsule())
                                }

                                if voice.qualityDescription != "Default" {
                                    Text(voice.qualityDescription)
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(Color.brandTurquoise)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1)
                                        .background(Color.brandTurquoise.opacity(0.15), in: Capsule())
                                }
                            }

                            Text(voice.displayName)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                        }

                        Spacer()

                        // Voice preview button
                        Button {
                            viewModel.previewVoice(voice)
                        } label: {
                            Image(systemName: viewModel.previewingVoiceId == voice.id ? "stop.circle.fill" : "play.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.brandTurquoise)
                        }
                        .buttonStyle(.plain)

                        // Selection checkmark
                        if voice.id == viewModel.selectedVoiceId {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.brandTurquoise)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectVoice(id: voice.id)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search voices by name or language")
            .navigationTitle("Select Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
