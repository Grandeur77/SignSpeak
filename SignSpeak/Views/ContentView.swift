import SwiftUI

/// Root content view providing quick access to feature modules and debug screens.
struct ContentView: View {
    @State private var isShowingCameraTest = false
    #if DEBUG
    @State private var isShowingDatasetCapture = false
    #endif

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.l) {
                Spacer()

                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.brandTurquoise)
                    .accessibilityHidden(true)

                VStack(spacing: Theme.Spacing.xs) {
                    Text("SignSpeak")
                        .font(.appLargeTitle)
                        .foregroundStyle(.textPrimary)

                    Text("On-device ASL learning and communication")
                        .font(.appBody)
                        .foregroundStyle(.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: Theme.Spacing.m) {
                    Button {
                        isShowingCameraTest = true
                    } label: {
                        HStack(spacing: Theme.Spacing.s) {
                            Image(systemName: "camera.fill")
                                .accessibilityHidden(true)
                            Text("Open Camera Test")
                        }
                    }
                    .buttonStyle(.primary)
                    .frame(maxWidth: 300)
                    .accessibilityHint("Opens real-time camera capture test screen")

                    #if DEBUG
                    Button {
                        isShowingDatasetCapture = true
                    } label: {
                        HStack(spacing: Theme.Spacing.s) {
                            Image(systemName: "camera.badge.ellipsis")
                                .accessibilityHidden(true)
                            Text("Dataset Capture Tool")
                        }
                    }
                    .buttonStyle(.secondary)
                    .frame(maxWidth: 300)
                    .accessibilityHint("Opens developer dataset capture screen")
                    #endif
                }
            }
            .padding(Theme.Spacing.l)
            .background(.appBackground)
            .navigationTitle("SignSpeak")
            .navigationDestination(isPresented: $isShowingCameraTest) {
                CameraTestView()
            }
            #if DEBUG
            .navigationDestination(isPresented: $isShowingDatasetCapture) {
                DatasetCaptureView()
            }
            #endif
        }
    }
}

#Preview {
    ContentView()
        .environment(\.dependencies, .preview)
}
