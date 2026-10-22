#if DEBUG
import Foundation
import Testing
@testable import SignSpeak

@Suite("Sign Media Player & ViewModel Tests (Step 4.3)")
struct SignMediaPlayerTests {

    private func makeSampleSign(
        id: String = "sign-test-hello",
        name: String = "Hello",
        frontVideo: String? = "video_hello_front",
        sideVideo: String? = "video_hello_side",
        imageName: String? = "sign_hello"
    ) -> Sign {
        Sign(
            id: id,
            name: name,
            pronunciationHint: "həˈloʊ",
            category: "greetings",
            level: .beginner,
            frequencyTag: "High Frequency",
            handedness: .oneHanded,
            recognition: .motionSign,
            description: "Standard ASL greeting sign.",
            howToSteps: [
                "Dominant hand shape: Extend fingers straight with thumb in B-handshape.",
                "Starting position: Touch fingertips lightly to temple.",
                "Outward motion: Move hand smoothly outward like a salute."
            ],
            commonMistake: "Avoid stiff robotic movement.",
            mnemonicTip: "Like tipping your hat to greet someone.",
            imageName: imageName,
            frontVideoName: frontVideo,
            sideVideoName: sideVideo
        )
    }

    private func makePhotoOnlySign() -> Sign {
        Sign(
            id: "sign-letter-m",
            name: "M",
            pronunciationHint: "/ɛm/",
            category: "alphabet",
            level: .beginner,
            frequencyTag: "High Frequency",
            handedness: .oneHanded,
            recognition: .staticSign,
            description: "Manual alphabet letter M.",
            howToSteps: [
                "Hand shape: Make a fist with thumb tucked under 3 fingers.",
                "Finger position: Index, middle, ring draped over thumb.",
                "Hold steady: Keep steady in front of chest."
            ],
            commonMistake: "Confused with N (N has two fingers over thumb).",
            mnemonicTip: "M for Mountain (3 finger peaks).",
            imageName: "sign_m",
            frontVideoName: nil,
            sideVideoName: nil
        )
    }

    // MARK: - Initial State & Defaults

    @Test("Initial state has correct defaults")
    @MainActor
    func initialStateDefaults() {
        let sign = makeSampleSign()
        let vm = SignMediaPlayerViewModel(sign: sign)

        #expect(vm.sign.id == sign.id)
        #expect(vm.selectedAngle == .front)
        #expect(vm.isPlaying == false)
        #expect(vm.isSlowMo == false)
        #expect(vm.isMirrored == false)
        #expect(vm.isLooping == true)
        #expect(vm.currentTime == 0.0)
        #expect(vm.duration == 0.0)
        #expect(vm.progress == 0.0)
        #expect(vm.isScrubbing == false)
    }

    @Test("Initial state respects defaultMirrored for left-handed signers")
    @MainActor
    func initialDefaultMirrored() {
        let sign = makeSampleSign()
        let vm = SignMediaPlayerViewModel(sign: sign, defaultMirrored: true)

        #expect(vm.isMirrored == true)
    }

    // MARK: - Mirror, Slow-mo, and Loop Toggles

    @Test("Mirror toggle flips horizontal mirroring")
    @MainActor
    func mirrorToggle() {
        let vm = SignMediaPlayerViewModel(sign: makeSampleSign())
        #expect(vm.isMirrored == false)

        vm.toggleMirror()
        #expect(vm.isMirrored == true)

        vm.toggleMirror()
        #expect(vm.isMirrored == false)
    }

    @Test("Slow-mo toggle alternates between 0.5x and 1.0x speed")
    @MainActor
    func slowMoToggle() {
        let vm = SignMediaPlayerViewModel(sign: makeSampleSign())
        #expect(vm.isSlowMo == false)

        vm.toggleSpeed()
        #expect(vm.isSlowMo == true)

        vm.toggleSpeed()
        #expect(vm.isSlowMo == false)
    }

    @Test("Loop toggle flips continuous loop setting")
    @MainActor
    func loopToggle() {
        let vm = SignMediaPlayerViewModel(sign: makeSampleSign())
        #expect(vm.isLooping == true)

        vm.toggleLoop()
        #expect(vm.isLooping == false)

        vm.toggleLoop()
        #expect(vm.isLooping == true)
    }

    // MARK: - Time Formatting

    @Test("Time formatting handles seconds and minutes accurately")
    @MainActor
    func timeFormatting() {
        let vm = SignMediaPlayerViewModel(sign: makeSampleSign())

        #expect(vm.formattedCurrentTime == "0:00")
        #expect(vm.formattedDuration == "0:00")
        #expect(vm.formattedTimeSummary == "0:00 / 0:00")

        vm.currentTime = 3.5
        vm.duration = 65.0

        #expect(vm.formattedCurrentTime == "0:03")
        #expect(vm.formattedDuration == "1:05")
        #expect(vm.formattedTimeSummary == "0:03 / 1:05")

        // Edge case: negative or NaN values
        vm.currentTime = -10.0
        #expect(vm.formattedCurrentTime == "0:00")
    }

    // MARK: - Scrubbing & Seeking

    @Test("Scrubbing updates progress and currentTime correctly")
    @MainActor
    func scrubbingAndSeeking() {
        let vm = SignMediaPlayerViewModel(sign: makeSampleSign())
        vm.duration = 10.0

        vm.startScrubbing()
        #expect(vm.isScrubbing == true)

        vm.scrub(to: 0.5)
        #expect(vm.progress == 0.5)
        #expect(vm.currentTime == 5.0)

        vm.finishScrubbing()
        #expect(vm.isScrubbing == false)

        vm.seek(to: 0.8)
        #expect(vm.progress == 0.8)
        #expect(vm.currentTime == 8.0)
    }

    // MARK: - Reduce Motion & Autoplay

    @Test("Reduce motion suppresses autoplay on setup")
    @MainActor
    func reduceMotionSuppressesAutoplay() {
        let vm = SignMediaPlayerViewModel(sign: makeSampleSign())

        // When reduceMotion is true, player must not auto-play
        vm.setupPlayer(reduceMotion: true)
        #expect(vm.isPlaying == false)
    }

    // MARK: - Photo Fallback when Video is Missing

    @Test("Photo fallback activates when sign has no video")
    @MainActor
    func photoFallbackWhenVideoMissing() {
        let photoSign = makePhotoOnlySign()
        let vm = SignMediaPlayerViewModel(sign: photoSign)

        vm.setupPlayer(reduceMotion: false)

        #expect(vm.hasVideo == false)
        #expect(vm.currentVideoURL == nil)
        #expect(vm.player == nil)
        #expect(vm.isPlaying == false)

        // Toggling mirror still works for the photo view
        vm.toggleMirror()
        #expect(vm.isMirrored == true)
    }

    // MARK: - Angle Selection

    @Test("Angle selection switches between front and side perspectives")
    @MainActor
    func angleSelection() {
        let vm = SignMediaPlayerViewModel(sign: makeSampleSign())

        #expect(vm.selectedAngle == .front)

        vm.selectAngle(.side, autoPlay: false)
        #expect(vm.selectedAngle == .side)

        vm.selectAngle(.front, autoPlay: false)
        #expect(vm.selectedAngle == .front)
    }
}
#endif
