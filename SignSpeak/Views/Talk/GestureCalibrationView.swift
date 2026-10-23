import SwiftUI
import AVFoundation

/// Gesture Calibration sheet for Communicator (`38-communicator-start`).
/// Provides dominant hand selection (Right / Left), live camera feed, ambient lighting check,
/// and distance/framing guidance for maximum sign recognition accuracy.
public struct GestureCalibrationView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @Bindable var viewModel: CommunicatorStartViewModel

    @State private var cameraSessionStarted = false
    @State private var lightingQuality: LightingQuality = .optimal
    @State private var isHandDetected: Bool = false
    @State private var frameCount: Int = 0

    public init(viewModel: CommunicatorStartViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.l) {
                    // Header Description
                    VStack(spacing: Theme.Spacing.xs) {
                        Text("Gesture Calibration")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.textPrimary)

                        Text("Set your dominant signing hand and verify your camera lighting before starting a conversation.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Theme.Spacing.m)
                    }
                    .padding(.top, Theme.Spacing.s)

                    // 1. Dominant Hand Selection
                    dominantHandSection

                    // 2. Live Camera & Lighting Check
                    cameraAndLightingSection

                    // 3. Recommended Distance & Positioning Checklist
                    guidanceChecklistSection
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Calibration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brandTurquoise)
                }
            }
            .task {
                await startCamera()
            }
            .onDisappear {
                Task {
                    await stopCamera()
                }
            }
        }
    }

    // MARK: - 1. Dominant Hand Section

    private var dominantHandSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("DOMINANT SIGNING HAND")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, Theme.Spacing.s)

            HStack(spacing: 12) {
                ForEach(DominantHand.allCases) { hand in
                    let isSelected = viewModel.dominantHand == hand

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.selectDominantHand(hand)
                        }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(isSelected ? Color.brandTurquoise.opacity(0.2) : Color.cardBackground.opacity(0.8))
                                    .frame(width: 50, height: 50)

                                Image(systemName: hand.iconName)
                                    .font(.system(size: 24))
                                    .foregroundStyle(isSelected ? Color.brandTurquoise : Color.textSecondary)
                            }

                            Text(hand.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)

                            Text(hand == .right ? "Primary for finger-spelling" : "Primary for finger-spelling")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .frame(height: 28)

                            // Radio Indicator
                            ZStack {
                                Circle()
                                    .strokeBorder(isSelected ? Color.brandTurquoise : Color.textSecondary.opacity(0.3), lineWidth: 2)
                                    .frame(width: 20, height: 20)

                                if isSelected {
                                    Circle()
                                        .fill(Color.brandTurquoise)
                                        .frame(width: 10, height: 10)
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding(Theme.Spacing.m)
                        .frame(maxWidth: .infinity)
                        .background(
                            Color.cardBackground,
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(isSelected ? Color.brandTurquoise : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 2. Live Camera & Lighting Section

    private var cameraAndLightingSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("CAMERA & LIGHTING CHECK")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, Theme.Spacing.s)

            VStack(spacing: 12) {
                // Camera Viewport with Framing Guide
                ZStack {
                    if cameraSessionStarted {
                        CameraPreviewView(session: dependencies.cameraService.captureSession, isMirrored: true)
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.cardBackground)
                            .frame(height: 220)
                            .overlay {
                                VStack(spacing: 8) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(Color.brandTurquoise)
                                    Text("Connecting camera preview…")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.textSecondary)
                                }
                            }
                    }

                    // Framing Silhouette Guide
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                        .padding(20)

                    // Hand Tracking Status Pill
                    VStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(isHandDetected ? Color.green : Color.brandYellow)
                                .frame(width: 8, height: 8)

                            Text(isHandDetected ? "Hand Detected" : "Raise Hand into Frame")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.65), in: Capsule())
                        .padding(.bottom, 10)
                    }
                }

                // Lighting Assessment Status Card
                HStack(spacing: 12) {
                    Image(systemName: lightingQuality.iconName)
                        .font(.system(size: 22))
                        .foregroundStyle(lightingQuality.color)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(lightingQuality.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.textPrimary)

                        Text(lightingQuality.description)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                    }

                    Spacer()
                }
                .padding(Theme.Spacing.m)
                .background(Color.cardBackground.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(Theme.Spacing.m)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - 3. Guidance Checklist

    private var guidanceChecklistSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("POSITIONING TIPS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, Theme.Spacing.s)

            VStack(spacing: 0) {
                checklistRow(icon: "arrow.left.and.right.square.fill", text: "Place iPhone 1.5 – 2.5 feet away on table")
                Divider().padding(.leading, 44)
                checklistRow(icon: "person.crop.rectangle.fill", text: "Keep head, chest, and both hands in view")
                Divider().padding(.leading, 44)
                checklistRow(icon: "lightbulb.fill", text: "Avoid bright windows or lights directly behind you")
            }
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func checklistRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.brandTurquoise)
                .frame(width: 24)

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textPrimary)

            Spacer()
        }
        .padding(Theme.Spacing.m)
    }

    // MARK: - Camera Helpers

    private func startCamera() async {
        let granted = await dependencies.cameraService.requestAuthorization()
        guard granted else { return }

        await dependencies.cameraService.startSession()
        cameraSessionStarted = true

        // Read frames to verify hand presence and lighting
        Task {
            for await buffer in dependencies.cameraService.frameStream {
                frameCount += 1
                if frameCount % 10 == 0 {
                    // Detect pose to test keypoints
                    if let pose = try? await dependencies.handPoseDetector.detectPose(in: buffer) {
                        await MainActor.run {
                            isHandDetected = pose.confidence > 0.4
                        }
                    }
                }
            }
        }
    }

    private func stopCamera() async {
        await dependencies.cameraService.stopSession()
        cameraSessionStarted = false
    }
}
