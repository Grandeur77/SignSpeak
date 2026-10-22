import SwiftUI

/// Full-screen privacy cover displayed in the iOS App Switcher and during app backgrounding
/// to prevent sensitive conversation transcripts and gesture video practice from being exposed.
public struct PrivacyShieldView: View {
    @Environment(AppRouter.self) private var router

    public init() {}

    public var body: some View {
        ZStack {
            // Deep background matching brand theme
            LinearGradient(
                colors: [
                    Color(red: 10/255, green: 22/255, blue: 40/255),
                    Color(red: 6/255, green: 14/255, blue: 28/255)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.l) {
                Spacer()

                AppLogoArtwork()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.black.opacity(0.3), radius: 12, y: 6)

                VStack(spacing: Theme.Spacing.xs) {
                    Text("SignSpeak")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(Color.brandTurquoise)
                        Text("Protected with \(router.biometricName)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: Capsule())
                }

                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("SignSpeak privacy screen. Protected with \(router.biometricName).")
    }
}
