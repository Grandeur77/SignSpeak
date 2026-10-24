import SwiftUI
import AVFoundation

/// Live two-way Communicator session view (`39a-communicator-live`).
/// Supports:
/// - iPhone & iPad Portrait: Top partner transcript with 180° rotation toggle, live waveform; Bottom camera preview with hand skeleton.
/// - iPad Landscape (Step 14.2): Side-by-side layout (Left: camera preview + hand skeleton overlay; Right: partner speech transcript, type-to-speak input, quick phrases).
/// - Dynamic orientation adaptation for all 4 iPad orientations (`portrait`, `portraitUpsideDown`, `landscapeLeft`, `landscapeRight`).
/// - Multitasking adaptability: fluid transitions across Split View (1/3, 1/2, 2/3), Slide Over, and Stage Manager.
/// - External keyboard type-to-speak: type phrase and press Return to immediately speak aloud and log to transcript.
public struct CommunicatorLiveView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    @State private var viewModel: CommunicatorLiveViewModel?
    @State private var isShowingEndConfirmation: Bool = false
    @State private var typeToSpeakText: String = ""
    @FocusState private var isTypeToSpeakFocused: Bool

    public let mode: ConversationMode
    public let dominantHand: DominantHand

    public init(mode: ConversationMode = .faceToFaceSplit, dominantHand: DominantHand = .right) {
        self.mode = mode
        self.dominantHand = dominantHand
    }

    public var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let isSideBySide = (horizontalSizeClass == .regular && isLandscape)

            Group {
                if let viewModel {
                    if isSideBySide {
                        landscapeSideBySideView(viewModel, geometry: geometry)
                    } else {
                        portraitStackedView(viewModel, geometry: geometry)
                    }
                } else {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        ProgressView("Connecting Communicator…")
                            .tint(Color.brandTurquoise)
                            .foregroundStyle(Color.white)
                    }
                }
            }
            .onAppear {
                updateCameraOrientation(isLandscape: isLandscape)
            }
            .onChange(of: geometry.size) { _, newSize in
                updateCameraOrientation(isLandscape: newSize.width > newSize.height)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .statusBarHidden(true)
        .task {
            if viewModel == nil {
                let vm = CommunicatorLiveViewModel(
                    cameraService: dependencies.cameraService,
                    handPoseDetector: dependencies.handPoseDetector,
                    signClassifier: dependencies.signClassifier,
                    signRecognitionService: dependencies.signRecognitionService,
                    speechRecognitionService: dependencies.speechRecognitionService,
                    speechSynthesisService: dependencies.speechSynthesisService,
                    conversationRepository: dependencies.conversationRepository,
                    userId: dependencies.authService.currentUserId ?? "guest",
                    mode: mode,
                    dominantHand: dominantHand
                )
                viewModel = vm
                await vm.startSession()
            }
        }
        .onDisappear {
            Task {
                await viewModel?.stopSession()
            }
        }
        .alert("End Conversation?", isPresented: $isShowingEndConfirmation) {
            Button("End & Save", role: .destructive) {
                Task {
                    _ = await viewModel?.endConversation()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your conversation transcript will be saved to Conversation History.")
        }
    }

    // MARK: - Camera Orientation Sync (iPad Step 14.2)

    private func updateCameraOrientation(isLandscape: Bool) {
        let orientation: AVCaptureVideoOrientation = isLandscape ? .landscapeRight : .portrait
        Task {
            await dependencies.cameraService.setOrientation(orientation)
        }
    }

    // MARK: - Portrait / Compact Stacked Layout

    private func portraitStackedView(_ viewModel: CommunicatorLiveViewModel, geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Sound Alerts Banner Slot (Phase 12)
            soundAlertsBannerSlot(viewModel)

            // Error & Permission Status Banner
            errorMessageBannerSlot(viewModel)

            // Top Pane: Partner Speech Transcript (Rotatable 180°)
            partnerTranscriptPane(viewModel, height: geometry.size.height * 0.44)

            // Middle Divider Bar
            middleDividerBar(viewModel)

            // Bottom Pane: Camera & Sign Recognition
            cameraSignPane(viewModel, height: geometry.size.height * 0.56 - 1)
        }
    }

    // MARK: - Landscape Side-by-Side Layout (iPad Step 14.2)

    private func landscapeSideBySideView(_ viewModel: CommunicatorLiveViewModel, geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Left Pane: Camera & Hand Skeleton Sign Recognition (50% width)
            cameraSignPane(viewModel, height: geometry.size.height)
                .frame(width: geometry.size.width * 0.50)

            // Vertical Border
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1)

            // Right Pane: Partner Speech Transcript, Type-to-Speak & Controls (50% width)
            VStack(spacing: 0) {
                soundAlertsBannerSlot(viewModel)
                errorMessageBannerSlot(viewModel)
                partnerTranscriptSidePane(viewModel, height: geometry.size.height)
            }
            .frame(width: geometry.size.width * 0.50 - 1)
        }
    }

    // MARK: - Sound Alerts Slot (Phase 12)

    @ViewBuilder
    private func soundAlertsBannerSlot(_ viewModel: CommunicatorLiveViewModel) -> some View {
        if let alert = viewModel.activeSoundAlert {
            HStack(spacing: 10) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.brandYellow)

                Text("Sound Alert: \(alert)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white)

                Spacer()

                Button {
                    viewModel.activeSoundAlert = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.brandYellow.opacity(0.25))
        }
    }

    // MARK: - Error & Permission Status Banner

    @ViewBuilder
    private func errorMessageBannerSlot(_ viewModel: CommunicatorLiveViewModel) -> some View {
        if let message = viewModel.errorMessage {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.danger)

                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white)
                    .lineLimit(2)

                Spacer()

                if message.contains("Settings") {
                    Button("Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.brandTurquoise)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12), in: Capsule())
                }

                Button {
                    viewModel.errorMessage = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.danger.opacity(0.25))
        }
    }

    // MARK: - Top Pane: Partner Speech Transcript (Portrait)

    private func partnerTranscriptPane(_ viewModel: CommunicatorLiveViewModel, height: CGFloat) -> some View {
        ZStack {
            Color(red: 16/255, green: 22/255, blue: 34/255)

            VStack(spacing: 8) {
                // Partner Controls Header
                HStack(spacing: 12) {
                    // Rotate 180° Toggle
                    Button {
                        viewModel.toggleRotation()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 12, weight: .bold))
                            Text(viewModel.isPartnerRotated180 ? "180° Flipped" : "Normal")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(Color.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.highlight)
                    .accessibilityLabel(viewModel.isPartnerRotated180 ? "Flip transcript back" : "Flip transcript 180 degrees")
                    .accessibilityHint("Rotates transcript for face-to-face partner viewing")
                    .accessibilityInputLabels(["Flip", "Rotate transcript"])

                    // Listening State Pill
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.isPaused ? Color.brandYellow : Color.green)
                            .frame(width: 8, height: 8)

                        Text(viewModel.isPaused ? "Paused" : (viewModel.isPartnerSpeaking ? "Hearing Speech" : "Listening…"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.85))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08), in: Capsule())
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(viewModel.isPaused ? "Microphone paused" : (viewModel.isPartnerSpeaking ? "Partner speaking" : "Listening for partner speech"))

                    Spacer()

                    // Replay Button
                    Button {
                        Task {
                            await viewModel.replayLastMessage()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.highlight)
                    .accessibilityLabel("Replay last message")
                    .accessibilityHint("Speaks the previous message aloud")
                    .accessibilityInputLabels(["Replay", "Repeat message"])

                    // Thumbs-Up Quick Button
                    Button {
                        Task {
                            await viewModel.sendThumbsUp()
                        }
                    } label: {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 19))
                            .foregroundStyle(Color.brandTurquoise)
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.highlight)
                    .accessibilityLabel("Send thumbs up acknowledgment")
                    .accessibilityInputLabels(["Thumbs up", "Acknowledge"])
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Waveform Audio Meter
                liveWaveformView(audioLevel: viewModel.partnerAudioLevel, isPaused: viewModel.isPaused)
                    .frame(height: 20)
                    .padding(.horizontal, 20)
                    .accessibilityHidden(true)

                Spacer(minLength: 4)

                // Partner Transcript Text
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            if viewModel.messages.isEmpty && viewModel.activePartnerTranscript.isEmpty {
                                Text("Partner's spoken words will appear here in real time…")
                                    .font(.system(size: 20, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.4))
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .accessibilityLabel("Transcript is empty. Spoken words will appear here in real time.")
                            } else {
                                ForEach(viewModel.messages) { msg in
                                    portraitMessageRow(msg, viewModel: viewModel)
                                }

                                if !viewModel.activePartnerTranscript.isEmpty {
                                    HStack(alignment: .top, spacing: 6) {
                                        Text("🗣️")
                                            .font(.system(size: 14))
                                            .accessibilityHidden(true)

                                        Text(viewModel.activePartnerTranscript)
                                            .font(.system(size: 22, weight: .bold, design: .rounded))
                                            .foregroundStyle(Color.brandYellow)
                                    }
                                    .id("activeTranscript")
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel("Live: \(viewModel.activePartnerTranscript)")
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .onChange(of: viewModel.activePartnerTranscript) { _, _ in
                        withAnimation(reduceMotion ? nil : .default) {
                            proxy.scrollTo("activeTranscript", anchor: .bottom)
                        }
                    }
                }

                Spacer(minLength: 4)

                // Type to speak in portrait
                typeToSpeakInputField(viewModel)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
            }
            .rotationEffect(.degrees(viewModel.isPartnerRotated180 ? 180 : 0))
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.75), value: viewModel.isPartnerRotated180)
        }
        .frame(height: height)
    }

    // MARK: - Right Side Pane: Partner Speech Transcript & Type-To-Speak (Landscape iPad)

    private func partnerTranscriptSidePane(_ viewModel: CommunicatorLiveViewModel, height: CGFloat) -> some View {
        ZStack {
            Color(red: 16/255, green: 22/255, blue: 34/255)

            VStack(spacing: 10) {
                // Partner Controls Header
                HStack(spacing: 12) {
                    // Rotate 180° Toggle
                    Button {
                        viewModel.toggleRotation()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 12, weight: .bold))
                            Text(viewModel.isPartnerRotated180 ? "180° Flipped" : "Normal")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(Color.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.highlight)
                    .accessibilityLabel(viewModel.isPartnerRotated180 ? "Flip transcript back" : "Flip transcript 180 degrees")
                    .accessibilityHint("Rotates transcript for face-to-face partner viewing")
                    .accessibilityInputLabels(["Flip", "Rotate transcript"])

                    // Listening State Pill
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.isPaused ? Color.brandYellow : Color.green)
                            .frame(width: 8, height: 8)

                        Text(viewModel.isPaused ? "Paused" : (viewModel.isPartnerSpeaking ? "Hearing Speech" : "Listening…"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.85))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08), in: Capsule())
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(viewModel.isPaused ? "Microphone paused" : (viewModel.isPartnerSpeaking ? "Partner speaking" : "Listening for partner speech"))

                    Spacer()

                    // Replay Button
                    Button {
                        Task { await viewModel.replayLastMessage() }
                    } label: {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.highlight)
                    .accessibilityLabel("Replay last message")
                    .accessibilityHint("Speaks the previous message aloud")
                    .accessibilityInputLabels(["Replay", "Repeat message"])

                    // Thumbs-Up Quick Button
                    Button {
                        Task { await viewModel.sendThumbsUp() }
                    } label: {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 19))
                            .foregroundStyle(Color.brandTurquoise)
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.highlight)
                    .accessibilityLabel("Send thumbs up acknowledgment")
                    .accessibilityInputLabels(["Thumbs up", "Acknowledge"])
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                // Waveform Audio Meter
                liveWaveformView(audioLevel: viewModel.partnerAudioLevel, isPaused: viewModel.isPaused)
                    .frame(height: 22)
                    .padding(.horizontal, 20)
                    .accessibilityHidden(true)

                // Partner Transcript Text
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            if viewModel.messages.isEmpty && viewModel.activePartnerTranscript.isEmpty {
                                Text("Partner's spoken words and your signed/typed messages appear here…")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.4))
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 24)
                                    .accessibilityLabel("Transcript is empty. Spoken words and signed messages will appear here.")
                            } else {
                                ForEach(viewModel.messages) { msg in
                                    landscapeMessageRow(msg, viewModel: viewModel)
                                }

                                if !viewModel.activePartnerTranscript.isEmpty {
                                    HStack(alignment: .top, spacing: 10) {
                                        Text("🗣️")
                                            .font(.system(size: 16))
                                            .accessibilityHidden(true)

                                        Text(viewModel.activePartnerTranscript)
                                            .font(.system(size: 20, weight: .bold, design: .rounded))
                                            .foregroundStyle(Color.brandYellow)
                                    }
                                    .padding(10)
                                    .background(Color.brandYellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                                    .id("activeTranscriptLandscape")
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel("Live: \(viewModel.activePartnerTranscript)")
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .onChange(of: viewModel.activePartnerTranscript) { _, _ in
                        withAnimation(reduceMotion ? nil : .default) {
                            proxy.scrollTo("activeTranscriptLandscape", anchor: .bottom)
                        }
                    }
                }

                // Quick Phrases Bar
                quickPhrasesRow(viewModel)
                    .padding(.horizontal, 14)

                // External Keyboard Type-to-Speak Input Field
                typeToSpeakInputField(viewModel)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 16)
            }
        }
        .frame(height: height)
    }

    // MARK: - Middle Divider Bar

    private func middleDividerBar(_ viewModel: CommunicatorLiveViewModel) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 1)

            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 10))
                Text("TWO-WAY LIVE TRANSLATION")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.0)
            }
            .foregroundStyle(Color.white.opacity(0.6))
            .padding(.horizontal, 12)
            .padding(.vertical, 3)
            .background(Color.black, in: Capsule())
        }
        .frame(height: 12)
        .background(Color.black)
    }

    // MARK: - Camera & Sign Recognition Pane

    private func cameraSignPane(_ viewModel: CommunicatorLiveViewModel, height: CGFloat) -> some View {
        ZStack {
            // Live Camera Viewport
            CameraPreviewView(
                session: dependencies.cameraService.captureSession,
                isMirrored: viewModel.cameraPosition == .front
            )
            .frame(height: height)
            .clipped()
            .accessibilityLabel("Camera preview for sign recognition")

            // Hand Skeleton Overlay
            HandSkeletonOverlay(
                pose: viewModel.detectedPose,
                isFrontCamera: viewModel.cameraPosition == .front,
                isLeftHanded: viewModel.dominantHand == .left
            )
            .frame(height: height)
            .accessibilityHidden(true)

            // Spoken Aloud Notification Chip
            if viewModel.showSpokenAloudChip, let word = viewModel.spokenAloudWord {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(red: 11/255, green: 42/255, blue: 74/255))
                            .accessibilityHidden(true)

                        Text("Spoken aloud:")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(red: 11/255, green: 42/255, blue: 74/255))

                        Text("\"\(word)\"")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(red: 11/255, green: 42/255, blue: 74/255))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.brandTurquoise, in: Capsule())
                    .shadow(color: Color.brandTurquoise.opacity(0.4), radius: 8, y: 3)
                    .padding(.top, 14)
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Spoken aloud: \(word)")
                    .accessibilityAddTraits(.isStaticText)

                    Spacer()
                }
            }

            // Fingerspelling Buffer & Bottom Controls Bar
            VStack(spacing: 8) {
                Spacer()

                // Fingerspelling Buffer Bar
                if !viewModel.fingerspellingBuffer.isEmpty {
                    fingerspellingBarView(viewModel)
                        .padding(.horizontal, 16)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }

                // Bottom Action Toolbar
                bottomToolbar(viewModel)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }
        }
        .frame(height: height)
    }

    // MARK: - Fingerspelling Buffer Bar

    private func fingerspellingBarView(_ viewModel: CommunicatorLiveViewModel) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Fingerspelling")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.brandTurquoise)

                Text(viewModel.fingerspellingBuffer)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white)
                    .kerning(3)
            }

            Spacer()

            // Speak Buffer Button
            Button {
                Task {
                    await viewModel.speakFingerspellingBuffer()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 12))
                        .accessibilityHidden(true)
                    Text("Speak")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Color(red: 11/255, green: 42/255, blue: 74/255))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.brandTurquoise, in: Capsule())
            }
            .buttonStyle(.plain)
            .hoverEffect(.lift)
            .accessibilityLabel("Speak fingerspelled word aloud")
            .accessibilityInputLabels(["Speak", "Speak word"])

            // Delete Last Letter
            Button {
                viewModel.deleteLastFingerspellingLetter()
            } label: {
                Image(systemName: "delete.left.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.white)
                    .padding(8)
                    .background(Color.white.opacity(0.15), in: Circle())
            }
            .buttonStyle(.plain)
            .hoverEffect(.lift)
            .accessibilityLabel("Delete last fingerspelled letter")
            .accessibilityInputLabels(["Delete letter", "Backspace"])

            // Clear Buffer
            Button {
                viewModel.clearFingerspellingBuffer()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .padding(8)
                    .background(Color.white.opacity(0.15), in: Circle())
            }
            .buttonStyle(.plain)
            .hoverEffect(.lift)
            .accessibilityLabel("Clear fingerspelling")
            .accessibilityInputLabels(["Clear", "Clear word"])
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(contrast == .increased ? Color.white : Color.brandTurquoise.opacity(0.3), lineWidth: contrast == .increased ? 1.5 : 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Fingerspelling: \(viewModel.fingerspellingBuffer)")
    }

    // MARK: - Bottom Action Toolbar

    private func bottomToolbar(_ viewModel: CommunicatorLiveViewModel) -> some View {
        HStack(spacing: 12) {
            // Pause / Resume Button
            Button {
                viewModel.togglePause()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 14))
                        .accessibilityHidden(true)
                    Text(viewModel.isPaused ? "Resume" : "Pause")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.65), in: Capsule())
                .overlay(Capsule().strokeBorder(contrast == .increased ? Color.white : Color.white.opacity(0.2), lineWidth: contrast == .increased ? 1.5 : 1))
            }
            .buttonStyle(.plain)
            .hoverEffect(.lift)
            .accessibilityLabel(viewModel.isPaused ? "Resume conversation" : "Pause conversation")
            .accessibilityHint(viewModel.isPaused ? "Resumes audio listening and video recognition" : "Pauses audio listening and video recognition")
            .accessibilityInputLabels(viewModel.isPaused ? ["Resume", "Resume conversation"] : ["Pause", "Pause conversation"])

            // Switch Camera Button
            Button {
                Task {
                    await viewModel.switchCamera()
                }
            } label: {
                Image(systemName: "camera.rotate.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.white)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.65), in: Circle())
                    .overlay(Circle().strokeBorder(contrast == .increased ? Color.white : Color.white.opacity(0.2), lineWidth: contrast == .increased ? 1.5 : 1))
            }
            .buttonStyle(.plain)
            .hoverEffect(.lift)
            .accessibilityLabel("Switch camera")
            .accessibilityHint("Switches between front and rear cameras")
            .accessibilityInputLabels(["Flip camera", "Switch camera", "Rotate camera"])

            Spacer()

            // End Conversation Button
            Button {
                isShowingEndConfirmation = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 13, weight: .bold))
                        .accessibilityHidden(true)
                    Text("End")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.danger, in: Capsule())
                .shadow(color: Color.danger.opacity(0.3), radius: 6, y: 3)
            }
            .buttonStyle(.plain)
            .hoverEffect(.lift)
            .accessibilityLabel("End conversation")
            .accessibilityHint("Ends session and saves transcript to history")
            .accessibilityInputLabels(["End", "End conversation", "Hang up"])
        }
    }

    // MARK: - External Keyboard Type-To-Speak Input Field (iPad Step 14.2)

    private func typeToSpeakInputField(_ viewModel: CommunicatorLiveViewModel) -> some View {
        HStack(spacing: 8) {
            TextField("Type to speak aloud (Return to send)…", text: $typeToSpeakText)
                .font(.system(size: 14))
                .foregroundStyle(Color.white)
                .focused($isTypeToSpeakFocused)
                .submitLabel(.send)
                .onSubmit {
                    submitTypeToSpeak(viewModel)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(contrast == .increased ? Color.white : Color.clear, lineWidth: 1)
                )
                .accessibilityLabel("Type phrase to speak aloud")

            Button {
                submitTypeToSpeak(viewModel)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(typeToSpeakText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.white.opacity(0.3) : Color.brandTurquoise)
            }
            .buttonStyle(.plain)
            .disabled(typeToSpeakText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .hoverEffect(.highlight)
            .accessibilityLabel("Speak typed phrase")
            .accessibilityInputLabels(["Send", "Speak text"])
        }
    }

    private func quickPhrasesRow(_ viewModel: CommunicatorLiveViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(["Hello! 👋", "Thank you! 🙏", "How can I help?", "One moment please", "Understood 👍"], id: \.self) { phrase in
                    Button {
                        Task { await viewModel.typeAndSpeak(phrase) }
                    } label: {
                        Text(phrase)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.12), in: Capsule())
                            .overlay(
                                Capsule().strokeBorder(contrast == .increased ? Color.white : Color.clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.lift)
                    .accessibilityLabel("Speak phrase: \(phrase)")
                    .accessibilityInputLabels([phrase])
                }
            }
        }
    }

    private func submitTypeToSpeak(_ viewModel: CommunicatorLiveViewModel) {
        let text = typeToSpeakText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        typeToSpeakText = ""
        Task {
            await viewModel.typeAndSpeak(text)
        }
    }

    // MARK: - Live Waveform Visualization

    private func liveWaveformView(audioLevel: Float, isPaused: Bool) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<18) { index in
                let normalizedIndex = Double(index) / 18.0
                let heightFactor = isPaused ? 0.1 : max(0.12, Double(audioLevel) * (1.0 - abs(0.5 - normalizedIndex)))
                RoundedRectangle(cornerRadius: 2)
                    .fill(isPaused ? Color.white.opacity(0.2) : Color.brandTurquoise)
                    .frame(width: 3, height: max(4, CGFloat(heightFactor * 22)))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.1), value: audioLevel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityHidden(true)
    }

    // MARK: - Accessible Message Rows

    private func portraitMessageRow(_ msg: ConversationMessage, viewModel: CommunicatorLiveViewModel) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(msg.speaker == "Partner" ? "🗣️" : "🤟")
                .font(.system(size: 14))
                .accessibilityHidden(true)

            Text(msg.text)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(msg.speaker == "Partner" ? Color.white : Color.brandTurquoise)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(msg.speaker): \(msg.text)")
        .accessibilityAction(named: "Speak message") {
            Task { await viewModel.typeAndSpeak(msg.text) }
        }
        .accessibilityAction(named: "Copy message") {
            UIPasteboard.general.string = msg.text
        }
    }

    private func landscapeMessageRow(_ msg: ConversationMessage, viewModel: CommunicatorLiveViewModel) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(msg.speaker == "Partner" ? "🗣️" : "🤟")
                .font(.system(size: 16))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(msg.speaker)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(msg.speaker == "Partner" ? Color.brandYellow : Color.brandTurquoise)

                Text(msg.text)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white)
            }
            Spacer()
        }
        .padding(10)
        .background(
            msg.speaker == "Partner" ? Color.white.opacity(0.08) : Color.brandTurquoise.opacity(0.15),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(msg.speaker): \(msg.text)")
        .accessibilityAction(named: "Speak message") {
            Task { await viewModel.typeAndSpeak(msg.text) }
        }
        .accessibilityAction(named: "Copy message") {
            UIPasteboard.general.string = msg.text
        }
    }
}
