import SwiftUI
import AVFoundation

/// Camera angle perspective for sign video demonstration.
public enum SignMediaAngle: String, CaseIterable, Identifiable, Sendable {
    case front = "front"
    case side = "side"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .front: return "Front View"
        case .side: return "Side Angle"
        }
    }

    public var iconName: String {
        switch self {
        case .front: return "person.crop.rectangle"
        case .side: return "person.crop.rectangle.badge.plus"
        }
    }
}

/// Observable state coordinator driving `SignMediaPlayer`.
/// Handles AVPlayer lifecycle, slow-motion (0.5x), looping, mirroring, scrubbing, angle switching,
/// and fallback to static photo when video is unavailable.
@Observable
@MainActor
public final class SignMediaPlayerViewModel {
    public let sign: Sign

    public var selectedAngle: SignMediaAngle = .front
    public var isPlaying: Bool = false
    public var isSlowMo: Bool = false
    public var isMirrored: Bool = false
    public var isLooping: Bool = true
    public var currentTime: Double = 0.0
    public var duration: Double = 0.0
    public var progress: Double = 0.0
    public var isScrubbing: Bool = false
    public var hasVideo: Bool = false
    public var currentVideoURL: URL?

    public private(set) var player: AVPlayer?
    private var timeObserverToken: Any?
    private var didPlayToEndObserver: NSObjectProtocol?

    public init(sign: Sign, defaultMirrored: Bool = false) {
        self.sign = sign
        self.isMirrored = defaultMirrored
    }

    public func cleanup() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        if let observer = didPlayToEndObserver {
            NotificationCenter.default.removeObserver(observer)
            didPlayToEndObserver = nil
        }
        player?.pause()
        player = nil
    }

    /// Prepares media playback. Respects Reduce Motion to suppress autoplay.
    public func setupPlayer(reduceMotion: Bool) {
        loadAngle(selectedAngle, autoPlay: !reduceMotion)
    }

    /// Switches the camera view angle (Front or Side).
    public func selectAngle(_ angle: SignMediaAngle, autoPlay: Bool = true) {
        guard angle != selectedAngle else { return }
        selectedAngle = angle
        loadAngle(angle, autoPlay: autoPlay)
    }

    private func loadAngle(_ angle: SignMediaAngle, autoPlay: Bool) {
        cleanup()

        let videoName: String?
        switch angle {
        case .front:
            videoName = sign.frontVideoName
        case .side:
            videoName = sign.sideVideoName
        }

        guard let videoName, !videoName.isEmpty,
              let url = resolveVideoURL(named: videoName) else {
            hasVideo = false
            currentVideoURL = nil
            isPlaying = false
            return
        }

        hasVideo = true
        currentVideoURL = url

        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.actionAtItemEnd = .none
        self.player = newPlayer

        // Set duration when ready
        Task { [weak self] in
            guard let self else { return }
            if let durationTime = try? await asset.load(.duration) {
                let seconds = CMTimeGetSeconds(durationTime)
                if seconds.isFinite && seconds > 0 {
                    self.duration = seconds
                }
            }
        }

        // Time tracking observer (~30 fps updates)
        let interval = CMTime(seconds: 0.033, preferredTimescale: 600)
        timeObserverToken = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self, !self.isScrubbing else { return }
                let current = CMTimeGetSeconds(time)
                if current.isFinite {
                    self.currentTime = max(0, current)
                    if self.duration > 0 {
                        self.progress = min(1.0, max(0.0, current / self.duration))
                    }
                }
            }
        }

        // Loop observer
        didPlayToEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.isLooping {
                    self.player?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
                    if self.isPlaying {
                        self.applyRate()
                    }
                } else {
                    self.isPlaying = false
                }
            }
        }

        if autoPlay {
            play()
        } else {
            isPlaying = false
        }
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            // If at end, restart
            if duration > 0 && currentTime >= (duration - 0.05) {
                seek(to: 0.0)
            }
            play()
        }
    }

    public func play() {
        guard hasVideo, player != nil else { return }
        isPlaying = true
        applyRate()
    }

    public func pause() {
        guard let player else { return }
        isPlaying = false
        player.pause()
    }

    public func toggleSpeed() {
        isSlowMo.toggle()
        if isPlaying {
            applyRate()
        }
    }

    public func toggleMirror() {
        isMirrored.toggle()
    }

    public func toggleLoop() {
        isLooping.toggle()
    }

    public func startScrubbing() {
        isScrubbing = true
        player?.pause()
    }

    public func scrub(to targetProgress: Double) {
        progress = targetProgress
        currentTime = targetProgress * duration
        let targetTime = CMTime(seconds: currentTime, preferredTimescale: 600)
        player?.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    public func finishScrubbing() {
        isScrubbing = false
        if isPlaying {
            applyRate()
        }
    }

    public func seek(to targetProgress: Double) {
        progress = targetProgress
        currentTime = targetProgress * duration
        let targetTime = CMTime(seconds: currentTime, preferredTimescale: 600)
        player?.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func applyRate() {
        let rate: Float = isSlowMo ? 0.5 : 1.0
        player?.play()
        player?.rate = rate
    }

    /// Resolves video path from main bundle or fallback project resources.
    private func resolveVideoURL(named name: String) -> URL? {
        // 1. Bundle subdirectories
        if let url = Bundle.main.url(forResource: name, withExtension: "mp4", subdirectory: "SignVideos") {
            return url
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "mp4") {
            return url
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "mov") {
            return url
        }

        // 2. Direct development path fallback
        let devPath = "/Users/mileeshafernando/IOS/SignSpeak/SignSpeak/Resources/SignVideos/\(name).mp4"
        if FileManager.default.fileExists(atPath: devPath) {
            return URL(fileURLWithPath: devPath)
        }

        let devPathMov = "/Users/mileeshafernando/IOS/SignSpeak/SignSpeak/Resources/SignVideos/\(name).mov"
        if FileManager.default.fileExists(atPath: devPathMov) {
            return URL(fileURLWithPath: devPathMov)
        }

        return nil
    }

    public var formattedCurrentTime: String {
        formatTime(currentTime)
    }

    public var formattedDuration: String {
        formatTime(duration)
    }

    public var formattedTimeSummary: String {
        "\(formattedCurrentTime) / \(formattedDuration)"
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
