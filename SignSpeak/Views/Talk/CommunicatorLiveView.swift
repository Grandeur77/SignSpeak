import SwiftUI
import AVFoundation

/// Live two-way Communicator session view (`39a-communicator-live`).
/// Split-screen interface:
/// - Top: Partner transcript with 180° rotation toggle, live waveform, and listening state.
/// - Bottom: Camera preview with hand skeleton overlay, immediate text-to-speech chip for recognized words,
///   fingerspelling buffer controls (speak/delete/clear), pause, camera switch, and end conversation.
public struct CommunicatorLiveView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: CommunicatorLiveViewModel?
    @State private var isShowingEndConfirmation: Bool = false

    public let mode: ConversationMode
    public let dominantHand: DominantHand

    public init(mode: ConversationMode = .faceToFaceSplit, dominantHand: DominantHand = .right) {
        self.mode = mode
        self.dominantHand = dominantHand
    }

    public var body: some View {
        GeometryReader { geometry in
            if let viewModel {
                VStack(spacing: 0) {
                    // Sound Alerts Banner Slot (Phase 12 preparation)
                    soundAlertsBannerSlot(viewModel)

                    // Top Pane: Partner Speech Transcript (Rotatable 180°)
                    partnerTranscriptPane(viewModel, height: geometry.size.height * 0.44)

                    // Middle Divider Bar
                    middleDividerBar(viewModel)

                    // Bottom Pane: Camera & Sign Recognition
                    cameraSignPane(viewModel, height: geometry.size.height * 0.56 - 1)
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

    // MARK: - Top Pane: Partner Speech Transcript

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
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Waveform Audio Meter
                liveWaveformView(audioLevel: viewModel.partnerAudioLevel, isPaused: viewModel.isPaused)
                    .frame(height: 20)
                    .padding(.horizontal, 20)

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
                            } else {
                                ForEach(viewModel.messages) { msg in
                                    HStack(alignment: .top, spacing: 6) {
                                        Text(msg.speaker == "Partner" ? "🗣️" : "🤟")
                                            .font(.system(size: 14))

                                        Text(msg.text)
                                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                                            .foregroundStyle(msg.speaker == "Partner" ? Color.white : Color.brandTurquoise)
                                    }
                                }

                                if !viewModel.activePartnerTranscript.isEmpty {
                                    HStack(alignment: .top, spacing: 6) {
                                        Text("🗣️")
                                            .font(.system(size: 14))

                                        Text(viewModel.activePartnerTranscript)
                                            .font(.system(size: 22, weight: .bold, design: .rounded))
                                            .foregroundStyle(Color.brandYellow)
                                    }
                                    .id("activeTranscript")
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .onChange(of: viewModel.activePartnerTranscript) { _, _ in
                        withAnimation {
                            proxy.scrollTo("activeTranscript", anchor: .bottom)
                        }
                    }
                }

                Spacer(minLength: 4)
            }
            .rotationEffect(.degrees(viewModel.isPartnerRotated180 ? 180 : 0))
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.isPartnerRotated180)
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

    // MARK: - Bottom Pane: Camera & Sign Recognition

    private func cameraSignPane(_ viewModel: CommunicatorLiveViewModel, height: CGFloat) -> some View {
        ZStack {
            // Live Camera Viewport
            CameraPreviewView(
                session: dependencies.cameraService.captureSession,
                isMirrored: viewModel.cameraPosition == .front
            )
            .frame(height: height)
            .clipped()

            // Hand Skeleton Overlay
            HandSkeletonOverlay(
                pose: viewModel.detectedPose,
                isFrontCamera: viewModel.cameraPosition == .front,
                isLeftHanded: viewModel.dominantHand == .left
            )
            .frame(height: height)

            // Spoken Aloud Notification Chip
            if viewModel.showSpokenAloudChip, let word = viewModel.spokenAloudWord {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(red: 11/255, green: 42/255, blue: 74/255))

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
                    .transition(.scale.combined(with: .opacity))

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
                        .transition(.move(edge: .bottom).combined(with: .opacity))
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
                    Text("Speak")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Color(red: 11/255, green: 42/255, blue: 74/255))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.brandTurquoise, in: Capsule())
            }
            .buttonStyle(.plain)

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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.brandTurquoise.opacity(0.3), lineWidth: 1)
        )
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
                    Text(viewModel.isPaused ? "Resume" : "Pause")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.65), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)

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
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            // End Conversation Button
            Button {
                isShowingEndConfirmation = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 13, weight: .bold))
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
                    .animation(.easeInOut(duration: 0.1), value: audioLevel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
