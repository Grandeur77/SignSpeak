import SwiftUI

/// Counter Mode / Communicator Full Screen Text (`39b-communicator-full-screen-text`).
/// Designed for high-contrast across-the-counter communication at service desks, cash registers, or noisy areas.
/// Features oversized high-visibility typography, speak aloud action, quick-switch phrase chips,
/// 180° orientation flipping, keep-screen-awake lock, and two-way reply dictation.
public struct CounterModeView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: CounterModeViewModel?
    public let initialPhrase: String?

    public init(initialPhrase: String? = nil) {
        self.initialPhrase = initialPhrase
    }

    public var body: some View {
        GeometryReader { geometry in
            if let vm = viewModel {
                ZStack {
                    // Deep high contrast canvas
                    Color.appBackground.ignoresSafeArea()

                    VStack(spacing: 0) {
                        // Main Counter Mode Card
                        counterModeCard(vm, size: geometry.size)

                        // Bottom Two-Way Reply Bar (when not in full immersion mode)
                        if !vm.isFullscreen {
                            replyBar(vm)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
                .sheet(isPresented: Binding(
                    get: { vm.isShowingEditSheet },
                    set: { vm.isShowingEditSheet = $0 }
                )) {
                    editPhraseSheet(vm)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .statusBarHidden(viewModel?.isFullscreen ?? false)
        .navigationBarBackButtonHidden(true)
        .task {
            if viewModel == nil {
                let vm = CounterModeViewModel(
                    repository: dependencies.quickPhraseRepository,
                    speechSynthesisService: dependencies.speechSynthesisService,
                    speechRecognitionService: dependencies.speechRecognitionService,
                    userId: dependencies.authService.currentUserId ?? "guest",
                    initialPhrase: initialPhrase ?? "Please speak slowly, I am deaf"
                )
                viewModel = vm
                vm.onAppear()
            }
        }
        .onDisappear {
            viewModel?.onDisappear()
        }
    }

    // MARK: - Main High-Contrast Card

    private func counterModeCard(_ vm: CounterModeViewModel, size: CGSize) -> some View {
        VStack(spacing: 0) {
            // Header: Close, Mode Pill, 180° Flip, Fullscreen
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(red: 11/255, green: 42/255, blue: 74/255))
                        .frame(width: 44, height: 44)
                        .background(Color(red: 11/255, green: 42/255, blue: 74/255).opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                // Counter Mode Pill
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(red: 11/255, green: 42/255, blue: 74/255))
                        .frame(width: 8, height: 8)

                    Text("COUNTER MODE")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(Color(red: 11/255, green: 42/255, blue: 74/255))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(red: 11/255, green: 42/255, blue: 74/255).opacity(0.12), in: Capsule())

                Spacer()

                HStack(spacing: 8) {
                    // 180° Flip Toggle
                    Button {
                        vm.toggleFlip180()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(red: 11/255, green: 42/255, blue: 74/255))
                            .frame(width: 44, height: 44)
                            .background(
                                vm.isFlipped180
                                    ? Color(red: 11/255, green: 42/255, blue: 74/255).opacity(0.25)
                                    : Color(red: 11/255, green: 42/255, blue: 74/255).opacity(0.12),
                                in: Circle()
                            )
                    }
                    .buttonStyle(.plain)

                    // Fullscreen Toggle
                    Button {
                        vm.toggleFullscreen()
                    } label: {
                        Image(systemName: vm.isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color(red: 11/255, green: 42/255, blue: 74/255))
                            .frame(width: 44, height: 44)
                            .background(Color(red: 11/255, green: 42/255, blue: 74/255).opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.m)

            Spacer(minLength: 8)

            // Center Large Phrase Display (Rotatable 180°)
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 11/255, green: 42/255, blue: 74/255).opacity(0.12))
                        .frame(width: 56, height: 56)

                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Color(red: 11/255, green: 42/255, blue: 74/255))
                }

                Text(vm.currentPhrase)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 11/255, green: 42/255, blue: 74/255))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, Theme.Spacing.l)
                    .minimumScaleFactor(0.6)

                Text("You can reply by speaking or typing into this phone.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 11/255, green: 42/255, blue: 74/255).opacity(0.85))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(red: 11/255, green: 42/255, blue: 74/255).opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

                // Speaking Waveform Feedback
                HStack(spacing: 4) {
                    ForEach(0..<4) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(red: 11/255, green: 42/255, blue: 74/255))
                            .frame(width: 4, height: vm.isSpeaking ? CGFloat([14, 22, 18, 10][index]) : 6)
                            .animation(vm.isSpeaking ? .easeInOut(duration: 0.3).repeatForever().delay(Double(index) * 0.1) : .default, value: vm.isSpeaking)
                    }

                    if vm.isSpeaking {
                        Text("Speaking aloud…")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(red: 11/255, green: 42/255, blue: 74/255))
                            .padding(.leading, 4)
                    }
                }
                .frame(height: 24)
                .opacity(vm.isSpeaking ? 1 : 0)
            }
            .rotationEffect(vm.isFlipped180 ? .degrees(180) : .zero)
            .padding(.vertical, Theme.Spacing.m)

            Spacer(minLength: 8)

            // Action Buttons: Speak Aloud & Edit Phrase
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        vm.speakAloud()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.system(size: 17, weight: .bold))
                            Text("Speak aloud")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(red: 11/255, green: 42/255, blue: 74/255), in: RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)

                    Button {
                        vm.openEditSheet()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "pencil")
                                .font(.system(size: 16, weight: .bold))
                            Text("Edit phrase")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(Color(red: 11/255, green: 42/255, blue: 74/255))
                        .frame(width: 140, height: 52)
                        .background(Color(red: 11/255, green: 42/255, blue: 74/255).opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }

                // Quick Switch Chips Bar
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("QUICK SWITCH")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1)
                            .foregroundStyle(Color(red: 11/255, green: 42/255, blue: 74/255).opacity(0.7))

                        Spacer()

                        Text("Tap to display")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(red: 11/255, green: 42/255, blue: 74/255).opacity(0.7))
                    }
                    .padding(.horizontal, 4)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            quickChip(text: "I need a doctor", icon: "cross.case.fill", vm: vm)
                            quickChip(text: "Where is the train?", icon: "tram.fill", vm: vm)
                            quickChip(text: "How much is this?", icon: "banknote.fill", vm: vm)
                            quickChip(text: "Where is the bathroom?", icon: "figure.walk", vm: vm)
                            quickChip(text: "Please speak slowly, I am deaf", icon: "arrow.counterclockwise", vm: vm)

                            ForEach(vm.quickSwitchPhrases) { phrase in
                                if phrase.text != "Please speak slowly, I am deaf" {
                                    quickChip(text: phrase.text, icon: phrase.isEmergency ? "sos" : "bubble.left.fill", vm: vm)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.l)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.brandYellow, in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: Color.black.opacity(0.12), radius: 14, y: 6)
        .padding(Theme.Spacing.m)
    }

    private func quickChip(text: String, icon: String, vm: CounterModeViewModel) -> some View {
        Button {
            vm.selectChipPhrase(text)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(text.contains("doctor") ? Color.danger : Color(red: 11/255, green: 42/255, blue: 74/255))

                Text(text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 11/255, green: 42/255, blue: 74/255))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color.white, in: Capsule())
            .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Reply Bar

    private func replyBar(_ vm: CounterModeViewModel) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                // Speech Dictation Button
                Button {
                    vm.toggleReplyDictation()
                } label: {
                    ZStack {
                        if vm.isListeningReply {
                            Circle()
                                .fill(Color.danger.opacity(0.2))
                                .frame(width: 44, height: 44)
                                .scaleEffect(1.2)
                        }

                        Image(systemName: vm.isListeningReply ? "mic.fill" : "mic")
                            .font(.system(size: 18))
                            .foregroundStyle(vm.isListeningReply ? Color.danger : Color.brandTurquoise)
                            .frame(width: 44, height: 44)
                            .background(Color.cardBackground, in: Circle())
                    }
                }
                .buttonStyle(.plain)

                // Text Input
                TextField("Type or speak to reply…", text: Binding(
                    get: { vm.replyText },
                    set: { vm.replyText = $0 }
                ))
                .font(.system(size: 15))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 14))

                // Speak Reply Button
                if !vm.replyText.isEmpty {
                    Button {
                        vm.speakReply()
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.white)
                            .frame(width: 44, height: 44)
                            .background(Color.brandTurquoise, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.m)
        }
    }

    // MARK: - Edit Phrase Modal Sheet

    private func editPhraseSheet(_ vm: CounterModeViewModel) -> some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Type a phrase to show across the counter:")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextEditor(text: Binding(
                    get: { vm.editInputText },
                    set: { vm.editInputText = $0 }
                ))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .padding(12)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
                .frame(height: 120)

                Button {
                    vm.applyEditedPhrase()
                } label: {
                    Text("Update Screen")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(red: 11/255, green: 42/255, blue: 74/255), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(vm.editInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }
            .padding(Theme.Spacing.l)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Edit Display Phrase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        vm.isShowingEditSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
