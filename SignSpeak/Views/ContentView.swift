import SwiftUI

/// Root content view providing quick access to feature modules and debug screens.
struct ContentView: View {
    @State private var isShowingCameraTest = false

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
            }
            .padding(Theme.Spacing.l)
            .background(.appBackground)
            .navigationTitle("SignSpeak")
            .navigationDestination(isPresented: $isShowingCameraTest) {
                CameraTestView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.dependencies, .preview)
}
