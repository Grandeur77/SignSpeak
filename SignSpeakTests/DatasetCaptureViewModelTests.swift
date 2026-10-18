#if DEBUG
import Foundation
import Testing
import CoreMedia
@testable import SignSpeak

@Suite("Dataset Capture Pipeline & File Storage")
struct DatasetCaptureViewModelTests {
    @Test("Vocabulary contains all 26 required Create ML classes")
    func vocabularyClassesCompleteness() {
        let vocab = DatasetCaptureViewModel.vocabulary

        // Must have exactly 24 letters + ILoveYou + Background = 26
        #expect(vocab.count == 26)
        #expect(vocab.contains("A"))
        #expect(vocab.contains("Y"))
        #expect(!vocab.contains("J")) // J is motion, Phase 2
        #expect(!vocab.contains("Z")) // Z is motion, Phase 2
        #expect(vocab.contains("ILoveYou"))
        #expect(vocab.contains("Background"))
    }

    @Test("ViewModel initializes with default capture settings and paths")
    @MainActor
    func viewModelInitialization() {
        let mockCamera = MockCameraService(authorizationState: .authorized)
        let viewModel = DatasetCaptureViewModel(cameraService: mockCamera)

        #expect(viewModel.selectedLabel == "A")
        #expect(viewModel.burstCount == 30)
        #expect(viewModel.burstInterval == 0.3)
        #expect(!viewModel.isCapturing)
        #expect(!viewModel.isCountingDown)
        #expect(viewModel.datasetDirectoryURL.lastPathComponent == "Dataset")
        #expect(viewModel.labelDirectoryURL(for: "A").lastPathComponent == "A")
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

        viewModel.startBurstSequence()
        #expect(viewModel.isCountingDown)

        viewModel.cancelBurst()
        #expect(!viewModel.isCountingDown)
        #expect(!viewModel.isCapturing)
    }

    @Test("Dataset counts dictionary initializes for all vocabulary keys")
    @MainActor
    func datasetCountsInitialization() {
        let mockCamera = MockCameraService(authorizationState: .authorized)
        let viewModel = DatasetCaptureViewModel(cameraService: mockCamera)

        #expect(viewModel.classCounts.count == 26)
        #expect(viewModel.classCounts["Background"] != nil)
    }
}
#endif
