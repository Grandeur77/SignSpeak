import SwiftUI

/// Standardized profile avatar button presented in screen headers across all app tabs.
/// Tapping opens the user Profile modal per design rule 101.
public struct ProfileAvatarButton: View {
    public var action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                // Circle border
                Circle()
                    .strokeBorder(Color.brandTurquoise.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 36, height: 36)

                // Avatar image if loaded, fallback to clean initials
                Image("UserAvatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            }
            .frame(minWidth: Theme.minTapTarget, minHeight: Theme.minTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile and account settings")
        .accessibilityHint("Opens your profile, streaks, and preferences")
    }
}

#Preview {
    ProfileAvatarButton(action: {})
        .padding()
        .background(Color.appBackground)
}
