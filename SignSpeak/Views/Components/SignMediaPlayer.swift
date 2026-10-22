import SwiftUI
import AVKit

/// Reusable native video and photo player for American Sign Language demonstrations.
/// Matches designs `45-sign-detail-hello` and `33-sign-detail-letter-m`.
/// Supports dual-angle switching (Front/Side), 0.5x slow-motion study, continuous loop,
/// horizontal mirroring for left-handed signers, precision scrubbing, and photo fallback.
public struct SignMediaPlayer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel: SignMediaPlayerViewModel
    @State private var isFullscreenPresented: Bool = false

    public init(sign: Sign, defaultMirrored: Bool = false) {
        _viewModel = State(initialValue: SignMediaPlayerViewModel(sign: sign, defaultMirrored: defaultMirrored))
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                // Background
                Color.black.opacity(0.94)

                // 1. Media Viewport (Video or Photo Fallback)
                mediaViewport
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 2. Center Play Button Overlay (when paused)
                if viewModel.hasVideo && !viewModel.isPlaying && !viewModel.isScrubbing {
                    centerPlayButton
                }

                // 3. Top Overlay: Angle Switcher & Badges
                topControlsOverlay
                    .frame(maxHeight: .infinity, alignment: .top)

                // 4. Bottom Controls Overlay: Scrubber & Action Bar
                if viewModel.hasVideo {
                    bottomControlsOverlay
                }
            }
            .frame(height: 290)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 10, y: 4)
        }
        .onAppear {
            viewModel.setupPlayer(reduceMotion: reduceMotion)
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .sheet(isPresented: $isFullscreenPresented) {
            fullscreenPlayerModal
        }
    }

    // MARK: - Viewport

    @ViewBuilder
    private var mediaViewport: some View {
        if viewModel.hasVideo, let player = viewModel.player {
            VideoPlayer(player: player)
                .scaleEffect(x: viewModel.isMirrored ? -1 : 1, y: 1)
                .disabled(true) // Native player disabled so our custom controls intercept touches
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.togglePlayPause()
                    triggerHaptic()
                }
                .accessibilityLabel("Sign demonstration video for \(viewModel.sign.name)")
        } else {
            fallbackPhotoView
        }
    }

    private var fallbackPhotoView: some View {
        ZStack {
            if let imageName = viewModel.sign.imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(x: viewModel.isMirrored ? -1 : 1, y: 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.brandTurquoise)

                    Text(viewModel.sign.name)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }

            // Photo Reference Badge
            VStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 11))
                    Text("Photo Reference View")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color.white.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.65), in: Capsule())
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Center Play Button

    private var centerPlayButton: some View {
        Button {
            viewModel.play()
            triggerHaptic()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.55))
                    .frame(width: 64, height: 64)
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1.5))

                Image(systemName: "play.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.white)
                    .offset(x: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play video")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Top Controls Overlay

    private var topControlsOverlay: some View {
        HStack(alignment: .top) {
            // Angle Switcher (Front View / Side Angle)
            if viewModel.hasVideo || viewModel.sign.sideVideoName != nil {
                HStack(spacing: 2) {
                    ForEach(SignMediaAngle.allCases) { angle in
                        Button {
                            viewModel.selectAngle(angle)
                            triggerHaptic()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: angle.iconName)
                                    .font(.system(size: 11))
                                Text(angle.title)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(viewModel.selectedAngle == angle ? Color.black : Color.white.opacity(0.85))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                viewModel.selectedAngle == angle ? Color.brandTurquoise : Color.black.opacity(0.55),
                                in: Capsule()
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(angle.title)
                        .accessibilityAddTraits(viewModel.selectedAngle == angle ? .isSelected : [])
                    }
                }
                .padding(2)
                .background(Color.black.opacity(0.4), in: Capsule())
            }

            Spacer()

            // HD 60fps Badge
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.brandTurquoise)
                    .frame(width: 6, height: 6)
                Text("HD 60fps")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.55), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.top, Theme.Spacing.m)
    }

    // MARK: - Bottom Controls Overlay

    private var bottomControlsOverlay: some View {
        VStack(spacing: 8) {
            // Scrubber Slider
            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track background
                        Capsule()
                            .fill(Color.white.opacity(0.25))
                            .frame(height: 5)

                        // Progress fill
                        Capsule()
                            .fill(Color.brandTurquoise)
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(viewModel.progress))), height: 5)

                        // Scrubbing thumb
                        Circle()
                            .fill(Color.white)
                            .frame(width: 13, height: 13)
                            .shadow(radius: 2)
                            .offset(x: max(0, min(geo.size.width - 13, (geo.size.width * CGFloat(viewModel.progress)) - 6.5)))
                    }
                    .frame(height: 14)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                viewModel.startScrubbing()
                                let newProgress = max(0.0, min(1.0, Double(value.location.x / geo.size.width)))
                                viewModel.scrub(to: newProgress)
                            }
                            .onEnded { _ in
                                viewModel.finishScrubbing()
                            }
                    )
                }
                .frame(height: 14)
                .accessibilityLabel("Scrubber")
                .accessibilityValue("\(Int(viewModel.progress * 100)) percent, \(viewModel.formattedCurrentTime)")

                Text(viewModel.formattedTimeSummary)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.9))
            }

            // Action Buttons Row
            HStack(spacing: 8) {
                // Loop Button
                Button {
                    viewModel.toggleLoop()
                    triggerHaptic()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "repeat")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Loop")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(viewModel.isLooping ? Color.white : Color.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        viewModel.isLooping ? Color.white.opacity(0.22) : Color.black.opacity(0.55),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Loop video continuously")
                .accessibilityValue(viewModel.isLooping ? "On" : "Off")

                // 0.5x Slow-mo Button
                Button {
                    viewModel.toggleSpeed()
                    triggerHaptic()
                } label: {
                    HStack(spacing: 4) {
                        if viewModel.isSlowMo {
                            Image(systemName: "speedometer")
                                .font(.system(size: 11))
                        }
                        Text("0.5× Slow-mo")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(viewModel.isSlowMo ? Color.black : Color.white.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        viewModel.isSlowMo ? Color.brandTurquoise : Color.black.opacity(0.55),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Slow motion speed toggle")
                .accessibilityValue(viewModel.isSlowMo ? "0.5 speed enabled" : "Normal speed")

                Spacer()

                // Mirror Button (Left-handed Signers)
                Button {
                    viewModel.toggleMirror()
                    triggerHaptic()
                } label: {
                    Image(systemName: "rectangle.split.2x1")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(viewModel.isMirrored ? Color.brandYellow : Color.white.opacity(0.8))
                        .frame(width: 32, height: 32)
                        .background(
                            viewModel.isMirrored ? Color.brandYellow.opacity(0.25) : Color.black.opacity(0.55),
                            in: Circle()
                        )
                        .overlay(
                            Circle()
                                .stroke(viewModel.isMirrored ? Color.brandYellow : Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mirror demonstration horizontally for left-handed signers")
                .accessibilityValue(viewModel.isMirrored ? "Mirrored" : "Original")

                // Fullscreen Button
                Button {
                    isFullscreenPresented = true
                    triggerHaptic()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .frame(width: 32, height: 32)
                        .background(Color.black.opacity(0.55), in: Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View video in full screen")
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.bottom, Theme.Spacing.m)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.65), Color.black.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Fullscreen Modal

    private var fullscreenPlayerModal: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if viewModel.hasVideo, let player = viewModel.player {
                    VideoPlayer(player: player)
                        .scaleEffect(x: viewModel.isMirrored ? -1 : 1, y: 1)
                        .ignoresSafeArea()
                } else if let imageName = viewModel.sign.imageName {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(x: viewModel.isMirrored ? -1 : 1, y: 1)
                        .ignoresSafeArea()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        isFullscreenPresented = false
                    }
                    .foregroundStyle(Color.brandTurquoise)
                }
                ToolbarItem(placement: .principal) {
                    Text(viewModel.sign.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.toggleMirror()
                    } label: {
                        Image(systemName: "rectangle.split.2x1")
                            .foregroundStyle(viewModel.isMirrored ? Color.brandYellow : Color.white)
                    }
                }
            }
        }
    }

    private func triggerHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
