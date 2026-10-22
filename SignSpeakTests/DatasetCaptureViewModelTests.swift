#if DEBUG
import Foundation
import Testing
import CoreMedia
@testable import SignSpeak

@Suite("Dataset Capture Pipeline & File Storage")
struct DatasetCaptureViewModelTests {
    @Test("Static vocabulary contains all 26 required Create ML classes")
    func staticVocabularyClassesCompleteness() {
        let vocab = DatasetCaptureViewModel.staticVocabulary

        // Must have exactly 24 letters + ILoveYou + Background = 26
        #expect(vocab.count == 26)
        #expect(vocab.contains("A"))
        #expect(vocab.contains("Y"))
        #expect(!vocab.contains("J")) // J is motion
        #expect(!vocab.contains("Z")) // Z is motion
        #expect(vocab.contains("ILoveYou"))
        #expect(vocab.contains("Background"))
    }

    @Test("Motion vocabulary contains all 13 required dynamic action classes")
    func motionVocabularyClassesCompleteness() {
        let motionVocab = DatasetCaptureViewModel.motionVocabulary

        #expect(motionVocab.count == 13)
        #expect(motionVocab.contains("J"))
        #expect(motionVocab.contains("Z"))
        #expect(motionVocab.contains("Hello"))
        #expect(motionVocab.contains("ThankYou"))
        #expect(motionVocab.contains("Please"))
        #expect(motionVocab.contains("Yes"))
        #expect(motionVocab.contains("No"))
        #expect(motionVocab.contains("Sorry"))
        #expect(motionVocab.contains("Water"))
        #expect(motionVocab.contains("Good"))
        #expect(motionVocab.contains("Mother"))
        #expect(motionVocab.contains("Father"))
        #expect(motionVocab.contains("Background"))
    }

    @Test("ViewModel initializes with default capture settings and paths")
    @MainActor
    func viewModelInitialization() {
        let mockCamera = MockCameraService(authorizationState: .authorized)
        let viewModel = DatasetCaptureViewModel(cameraService: mockCamera)

        #expect(viewModel.mode == .motionSigns)
        #expect(viewModel.selectedLabel == "J")
        #expect(viewModel.clipDuration == 2.0)
        #expect(viewModel.burstCount == 30)
        #expect(viewModel.burstInterval == 0.3)
        #expect(!viewModel.isCapturing)
        #expect(!viewModel.isRecordingVideo)
        #expect(!viewModel.isCountingDown)
        #expect(viewModel.datasetDirectoryURL.lastPathComponent == "Dataset")
        #expect(viewModel.labelDirectoryURL(for: "J").lastPathComponent == "J")
    }

    @Test("Mode switching updates vocabulary, selection, and directory targets")
    @MainActor
    func modeSwitching() {
        let mockCamera = MockCameraService(authorizationState: .authorized)
        let viewModel = DatasetCaptureViewModel(cameraService: mockCamera)

        #expect(viewModel.mode == .motionSigns)
        #expect(viewModel.currentVocabulary.count == 13)

        viewModel.mode = .staticSigns
        #expect(viewModel.mode == .staticSigns)
        #expect(viewModel.selectedLabel == "A")
        #expect(viewModel.currentVocabulary.count == 26)
        #expect(viewModel.labelDirectoryURL(for: "A").path.contains("Static/A"))

        viewModel.mode = .motionSigns
        #expect(viewModel.selectedLabel == "J")
        #expect(viewModel.labelDirectoryURL(for: "J").path.contains("Motion/J"))
    }

    @Test("Left hand mirror toggles correctly in DatasetCaptureViewModel")
    @MainActor
    func leftHandMirrorToggle() {
        let mockCamera = MockCameraService(authorizationState: .authorized)
        let viewModel = DatasetCaptureViewModel(cameraService: mockCamera)

        #expect(!viewModel.isLeftHanded)
        viewModel.toggleLeftHandMirror()
        #expect(viewModel.isLeftHanded)
        viewModel.toggleLeftHandMirror()
        #expect(!viewModel.isLeftHanded)
    }

    @Test("Burst cancellation resets capturing and countdown state")
    @MainActor
    func burstCancellation() {
        let mockCamera = MockCameraService(authorizationState: .authorized)
        let viewModel = DatasetCaptureViewModel(cameraService: mockCamera)

        viewModel.mode = .staticSigns
        viewModel.startBurstSequence()
        #expect(viewModel.isCountingDown)

        viewModel.cancelBurst()
        #expect(!viewModel.isCountingDown)
        #expect(!viewModel.isCapturing)
    }

    @Test("Motion video recording cancellation resets state cleanly")
    @MainActor
    func motionRecordingCancellation() {
        let mockCamera = MockCameraService(authorizationState: .authorized)
        let viewModel = DatasetCaptureViewModel(cameraService: mockCamera)

        viewModel.startMotionRecordingSequence()
        #expect(viewModel.isCountingDown)

        viewModel.cancelMotionRecording()
        #expect(!viewModel.isCountingDown)
        #expect(!viewModel.isRecordingVideo)
        #expect(viewModel.recordingProgress == 0.0)
    }

    @Test("Dataset counts dictionary initializes for all vocabulary keys")
    @MainActor
    func datasetCountsInitialization() {
        let mockCamera = MockCameraService(authorizationState: .authorized)
        let viewModel = DatasetCaptureViewModel(cameraService: mockCamera)

        #expect(viewModel.classCounts.count == 13)
        #expect(viewModel.classCounts["Background"] != nil)

        viewModel.mode = .staticSigns
        #expect(viewModel.classCounts.count == 26)
        #expect(viewModel.classCounts["Background"] != nil)
    }
}
#endif
