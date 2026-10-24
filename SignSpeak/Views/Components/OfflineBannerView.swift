import SwiftUI

/// Accessible offline banner observing `NetworkMonitorServicing` (Phase 15.3).
/// Displays a high-contrast banner when network is unavailable, informing the user
/// that on-device sign recognition, manual alphabet practice, and communicator features remain active.
public struct OfflineBannerView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var isConnected: Bool = true
    @State private var showReconnectedToast: Bool = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            if !isConnected {
                offlineBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if showReconnectedToast {
                onlineBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isConnected)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showReconnectedToast)
        .task {
            isConnected = dependencies.networkMonitorService.isConnected
            for await status in dependencies.networkMonitorService.statusStream {
                let wasOffline = !isConnected
                isConnected = status
                if wasOffline && status {
                    showReconnectedToast = true
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    showReconnectedToast = false
                }
            }
        }
    }

    private var offlineBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.white)

            VStack(alignment: .leading, spacing: 2) {
                Text("Offline Mode Active")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white)

                Text("On-device recognition, speech & curriculum are fully operational.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.9))
            }

            Spacer()

            Text("ON-DEVICE")
                .font(.system(size: 10, weight: .black))
                .tracking(0.6)
                .foregroundStyle(Color.black)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.brandYellow, in: Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color.brandNavy, Color(red: 0.08, green: 0.15, blue: 0.28)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(
            Rectangle()
                .fill(Color.brandYellow)
                .frame(height: 2),
            alignment: .bottom
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Offline Mode Active. On-device sign recognition, speech and curriculum are fully operational.")
        .accessibilityAddTraits(.isStaticText)
    }

    private var onlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.white)

            Text("Back Online — Community & cloud sync resumed.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.brandTurquoise)
        .accessibilityLabel("Back online. Community and cloud sync resumed.")
    }
}

#Preview("Offline Banner") {
    OfflineBannerView()
        .environment(\.dependencies, .preview)
}
