#if DEBUG
import SwiftUI
import AVFoundation

/// DEBUG-only screen for capturing training datasets for Create ML Hand Pose Classification.
/// Lets developer select an ASL label, burst-capture N frames into `Documents/Dataset/<Label>/`,
/// and export/share the dataset directly to Mac via AirDrop or Finder file sharing.
struct DatasetCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies

    @State private var viewModel: DatasetCaptureViewModel
    @State private var isShowingManageSheet = false
    @State private var isShowingClearConfirm = false
    @State private var labelToClear: String?

    init(viewModel: DatasetCaptureViewModel? = nil, dependencies: AppDependencies = .live) {
        if let viewModel {
            _viewModel = State(initialValue: viewModel)
        } else {
            _viewModel = State(initialValue: DatasetCaptureViewModel(
                cameraService: dependencies.cameraService,
                handPoseDetector: dependencies.handPoseDetector
            ))
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch viewModel.authorizationState {
            case .authorized:
                cameraActiveContent
            case .notDetermined:
                CameraPermissionView(
                    isDenied: false,
                    onRequestAccess: {
                        Task {
                            let granted = await dependencies.cameraService.requestAuthorization()
                            if granted {
                                await viewModel.onAppear()
                            }
                        }
                    },
                    onSkip: { dismiss() }
                )
            case .denied, .restricted:
                CameraPermissionView(
                    isDenied: true,
                    onRequestAccess: {},
                    onSkip: { dismiss() }
                )
            case .unavailableOnSimulator:
                simulatorNoticeView
            }
        }
        .navigationTitle("Dataset Capture")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
                .foregroundStyle(.white)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingManageSheet = true
                } label: {
                    Image(systemName: "folder.badge.gearshape")
                        .foregroundStyle(Color.brandTurquoise)
                }
                .accessibilityLabel("Manage and share dataset")
            }
        }
        .task {
            await viewModel.onAppear()
        }
        .onDisappear {
            Task { await viewModel.onDisappear() }
        }
        .sheet(isPresented: $isShowingManageSheet) {
            datasetManagementSheet
        }
    }

    // MARK: - Active Camera Content

    private var cameraActiveContent: some View {
        GeometryReader { geometry in
            ZStack {
                // Live camera preview
                CameraPreviewView(
                    session: dependencies.cameraService.captureSession,
                    isMirrored: viewModel.currentPosition == .front
                )
                .ignoresSafeArea()

                // Vision hand skeleton and guide
                HandSkeletonOverlay(
                    pose: viewModel.detectedPose,
                    isFrontCamera: viewModel.currentPosition == .front,
                    isLeftHanded: viewModel.isLeftHanded
                )
                .ignoresSafeArea()

                // Countdown overlay
                if viewModel.isCountingDown {
                    countdownOverlay
                }

                // Burst progress HUD
                if viewModel.isCapturing {
                    capturingProgressHUD
                }

                // Controls & HUD
                VStack(spacing: Theme.Spacing.m) {
                    topStatusHeader
                        .padding(.top, geometry.safeAreaInsets.top > 0 ? 0 : Theme.Spacing.m)

                    labelSelectionBar

                    Spacer()

                    bottomCaptureControls
                        .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 0 : Theme.Spacing.m)
                }
                .padding(.horizontal, Theme.Spacing.m)
            }
        }
    }

    // MARK: - Top Header & Label Selection

    private var topStatusHeader: some View {
        HStack {
            // Label count pill
            HStack(spacing: Theme.Spacing.xs) {
                Circle()
                    .fill(Color.brandTurquoise)
                    .frame(width: 8, height: 8)
                Text("\(viewModel.selectedLabel): \(viewModel.classCounts[viewModel.selectedLabel] ?? 0) photos")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.65), in: Capsule())

            Spacer()

            // Total dataset count
            Text("Total: \(viewModel.totalPhotosCount) photos")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.65), in: Capsule())
        }
    }

    private var labelSelectionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(DatasetCaptureViewModel.vocabulary, id: \.self) { label in
                    let isSelected = (viewModel.selectedLabel == label)
                    let count = viewModel.classCounts[label] ?? 0

                    Button {
                        viewModel.selectedLabel = label
                    } label: {
                        HStack(spacing: 4) {
                            Text(label)
                                .fontWeight(isSelected ? .bold : .medium)

                            if count > 0 {
                                Text("\(count)")
                                    .font(.caption2)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(isSelected ? Color.brandNavy : Color.brandTurquoise, in: Capsule())
                                    .foregroundStyle(.white)
                            }
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.brandTurquoise : Color.black.opacity(0.6), in: Capsule())
                        .foregroundStyle(isSelected ? Color.brandNavy : Color.white)
                    }
                    .accessibilityLabel("\(label), \(count) photos captured")
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Countdown & HUD

    private var countdownOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()

            VStack(spacing: Theme.Spacing.m) {
                Text("\(viewModel.countdownRemaining)")
                    .font(.system(size: 96, weight: .black, design: .rounded))
                    .foregroundStyle(Color.brandYellow)
                    .scaleEffect(1.2)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.countdownRemaining)

                Text("Get ready for sign '\(viewModel.selectedLabel)'")
                    .font(.appHeadline)
                    .foregroundStyle(.white)
            }
        }
    }

    private var capturingProgressHUD: some View {
        VStack {
            Spacer()

            HStack(spacing: Theme.Spacing.m) {
                ProgressView()
                    .tint(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Burst Capturing '\(viewModel.selectedLabel)'")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("\(viewModel.capturedInCurrentBurst) / \(viewModel.burstCount) frames (every \(String(format: "%.1f", viewModel.burstInterval))s)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                Button("Cancel") {
                    viewModel.cancelBurst()
                }
                .font(.subheadline.bold())
                .foregroundStyle(Color.brandYellow)
            }
            .padding(Theme.Spacing.m)
            .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Bottom Controls

    private var bottomCaptureControls: some View {
        HStack(spacing: Theme.Spacing.l) {
            // Flip camera lens
            Button {
                Task { await viewModel.switchCamera() }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Color.black.opacity(0.6), in: Circle())
            }
            .accessibilityLabel("Flip camera lens")

            // Burst count selector
            Menu {
                ForEach([10, 20, 30, 50, 100], id: \.self) { count in
                    Button("\(count) frames") {
                        viewModel.burstCount = count
                    }
                }
            } label: {
                VStack(spacing: 2) {
                    Text("\(viewModel.burstCount)")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("frames")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(width: 52, height: 52)
                .background(Color.black.opacity(0.6), in: Circle())
            }
            .accessibilityLabel("Burst count: \(viewModel.burstCount) frames")

            // Big Start Burst Button
            Button {
                if viewModel.isCapturing || viewModel.isCountingDown {
                    viewModel.cancelBurst()
                } else {
                    viewModel.startBurstSequence()
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 72, height: 72)

                    Circle()
                        .fill(viewModel.isCapturing ? Color.danger : Color.brandTurquoise)
                        .frame(width: 58, height: 58)

                    Image(systemName: viewModel.isCapturing ? "stop.fill" : "camera.fill")
                        .font(.title2)
                        .foregroundStyle(viewModel.isCapturing ? .white : Color.brandNavy)
                }
            }
            .accessibilityLabel(viewModel.isCapturing ? "Stop burst capture" : "Start burst capture")

            // Left-hand mirror toggle
            Button {
                viewModel.toggleLeftHandMirror()
            } label: {
                Image(systemName: viewModel.isLeftHanded ? "hand.point.left.fill" : "hand.point.right.fill")
                    .font(.title2)
                    .foregroundStyle(viewModel.isLeftHanded ? Color.brandYellow : .white)
                    .frame(width: 52, height: 52)
                    .background(Color.black.opacity(0.6), in: Circle())
            }
            .accessibilityLabel("Toggle left-hand mode")
        }
        .padding(Theme.Spacing.m)
    }

    // MARK: - Manage Dataset Sheet

    private var datasetManagementSheet: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    HStack {
                        Text("Total Captured Photos")
                        Spacer()
                        Text("\(viewModel.totalPhotosCount)")
                            .fontWeight(.bold)
                            .foregroundStyle(Color.brandTurquoise)
                    }

                    ShareLink(
                        item: viewModel.datasetDirectoryURL,
                        subject: Text("SignSpeak Dataset"),
                        message: Text("Exported SignSpeak training dataset photos.")
                    ) {
                        Label("Share / AirDrop Dataset Folder", systemImage: "square.and.arrow.up")
                            .foregroundStyle(Color.brandTurquoise)
                    }

                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Color.brandYellow)
                        Text("Photos are also accessible via Finder file sharing in the app's Documents/Dataset folder.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Classes Breakdown") {
                    ForEach(DatasetCaptureViewModel.vocabulary, id: \.self) { label in
                        classBreakdownRow(for: label)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        isShowingClearConfirm = true
                    } label: {
                        Label("Clear Entire Dataset", systemImage: "trash.fill")
                    }
                }
            }
            .navigationTitle("Dataset Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isShowingManageSheet = false
                    }
                }
            }
            .confirmationDialog("Clear Entire Dataset?", isPresented: $isShowingClearConfirm, titleVisibility: .visible) {
                Button("Delete All Photos", role: .destructive) {
                    viewModel.clearAllDataset()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes all images from Documents/Dataset.")
            }
        }
    }

    private func classBreakdownRow(for label: String) -> some View {
        let count = viewModel.classCounts[label] ?? 0
        return HStack {
            Text(label)
                .fontWeight(.medium)

            Spacer()

            Text("\(count) photos")
                .foregroundStyle(count >= 80 ? Color.success : Color.secondary)

            if count > 0 {
                Button(role: .destructive) {
                    viewModel.deletePhotos(for: label)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.danger)
                }
                .buttonStyle(.borderless)
                .padding(.leading, Theme.Spacing.s)
            }
        }
    }

    // MARK: - Simulator Notice

    private var simulatorNoticeView: some View {
        VStack(spacing: Theme.Spacing.l) {
            Image(systemName: "camera.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.brandTurquoise)

            Text("Camera Hardware Required")
                .font(.appTitle)
                .foregroundStyle(.white)

            Text("The iOS Simulator does not provide video camera input. Connect a physical iPhone to use the burst Dataset Capture tool.")
                .font(.appBody)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.l)

            Button("Close") {
                dismiss()
            }
            .buttonStyle(.secondary)
            .frame(maxWidth: 200)
        }
        .padding(Theme.Spacing.l)
    }
}
#endif
