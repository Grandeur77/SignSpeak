import SwiftUI
import UIKit

/// Camera permission screen implementing the design from `docs/design/11-permission-camera.png`.
/// Features Deaf Flag styling, privacy guarantees, clear device-only processing claims,
/// and handles both initial request and denied states with Settings deep-linking.
struct CameraPermissionView: View {
    let isDenied: Bool
    let onRequestAccess: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                // MARK: - Progress Header
                stepperHeader

                // MARK: - Viewfinder Illustration Card
                viewfinderCard

                // MARK: - Title & Body
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text(isDenied ? "Camera access is needed" : "Enable your camera")
                        .font(.appLargeTitle)
                        .foregroundStyle(.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Text(
                        isDenied
                        ? "SignSpeak needs camera permission to track hand gestures in real time. Please enable camera access in your device Settings."
                        : "SignSpeak uses live computer vision to translate signs, verify fingerspelling accuracy, and provide instant visual feedback as you practice."
                    )
                    .font(.appBody)
                    .foregroundStyle(.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // MARK: - Privacy Guarantee Card
                privacyCard

                // MARK: - System Prompt Disclaimer
                if !isDenied {
                    systemPromptNotice
                }

                // MARK: - Action Buttons
                VStack(spacing: Theme.Spacing.m) {
                    if isDenied {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: Theme.Spacing.s) {
                                Image(systemName: "gearshape.fill")
                                    .accessibilityHidden(true)
                                Text("Open Settings")
                            }
                        }
                        .buttonStyle(.primary)
                        .accessibilityHint("Opens iOS Settings to enable camera access")
                    } else {
                        Button(action: onRequestAccess) {
                            HStack(spacing: Theme.Spacing.s) {
                                Image(systemName: "camera.fill")
                                    .accessibilityHidden(true)
                                Text("Allow Camera Access")
                                Image(systemName: "arrow.right")
                                    .accessibilityHidden(true)
                            }
                        }
                        .buttonStyle(.primary)
                        .accessibilityHint("Requests permission to use the camera for sign detection")
                    }

                    Button("Not now, practise with flashcards", action: onSkip)
                        .font(.appBody)
                        .foregroundStyle(.textSecondary)
                        .frame(minHeight: Theme.minTapTarget)
                        .accessibilityHint("Proceeds without enabling the camera")
                }
                .padding(.top, Theme.Spacing.s)
            }
            .padding(Theme.Spacing.l)
        }
        .background(.appBackground)
    }

    // MARK: - Subviews

    private var stepperHeader: some View {
        VStack(spacing: Theme.Spacing.s) {
            HStack {
                HStack(spacing: Theme.Spacing.xs) {
                    Circle()
                        .fill(Color.brandTurquoise)
                        .frame(width: 8, height: 8)
                    Text("STEP 3 OF 3 • PERMISSIONS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.brandTurquoise)
                }
                Spacer()
                Text("Ready to sign")
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
            }

            // Stepper progress segments
            HStack(spacing: Theme.Spacing.xs) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.brandTurquoise)
                    .frame(height: 4)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.brandTurquoise)
                    .frame(height: 4)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.brandTurquoise)
                    .frame(height: 4)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step 3 of 3: Permissions. Ready to sign.")
    }

    private var viewfinderCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Color.brandNavy)
                .frame(height: 240)

            // Viewfinder Corner Brackets
            VStack {
                HStack {
                    cornerBracket(topLeft: true)
                    Spacer()
                    cornerBracket(topRight: true)
                }
                Spacer()
                HStack {
                    cornerBracket(bottomLeft: true)
                    Spacer()
                    cornerBracket(bottomRight: true)
                }
            }
            .padding(Theme.Spacing.m)

            // Center skeleton / gesture illustration
            VStack(spacing: Theme.Spacing.m) {
                // Tracking chip
                HStack(spacing: Theme.Spacing.xs) {
                    Circle()
                        .fill(Color.brandTurquoise)
                        .frame(width: 6, height: 6)
                    Text("Processed on this iPhone")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, Theme.Spacing.s)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.12), in: Capsule())

                // Hand illustration
                ZStack {
                    Circle()
                        .fill(Color.brandTurquoise.opacity(0.2))
                        .frame(width: 84, height: 84)

                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.brandTurquoise)
                }

                // Detection status pill
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.brandTurquoise)
                    Text("Hand Pose Detected • ASL Ready")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.brandNavy)
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, 6)
                .background(.white, in: Capsule())
            }
            .padding(Theme.Spacing.m)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Camera gesture viewfinder preview: Hand pose detected, processed on this iPhone")
    }

    private var privacyCard: some View {
        CardView {
            HStack(alignment: .top, spacing: Theme.Spacing.m) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.title2)
                    .foregroundStyle(.brandTurquoise)
                    .frame(width: 44, height: 44)
                    .background(Color.brandTurquoise.opacity(0.15), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Privacy Protected by Design")
                        .font(.appSectionTitle)
                        .foregroundStyle(.textPrimary)

                    Text("Video is analyzed entirely on your device and never uploaded to any cloud server. Your camera stream and personal space remain strictly confidential.")
                        .font(.appBody)
                        .foregroundStyle(.textSecondary)
                }
            }

            // Chips
            HStack(spacing: Theme.Spacing.s) {
                privacyChip(icon: "iphone", title: "On-Device Neural Engine")
                privacyChip(icon: "icloud.slash", title: "No Cloud Uploads")
            }
            .padding(.top, Theme.Spacing.xs)
        }
    }

    private func privacyChip(icon: String, title: String) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.brandTurquoise)
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.textPrimary)
        }
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.vertical, 6)
        .background(Color.cardBackground.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.brandTurquoise.opacity(0.2), lineWidth: 1)
        )
    }

    private var systemPromptNotice: some View {
        HStack {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
                Text("System prompt will appear next")
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
            }
            Spacer()
            Text("iOS Secure")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.brandTurquoise)
        }
        .padding(.horizontal, Theme.Spacing.xs)
    }

    private func cornerBracket(topLeft: Bool = false, topRight: Bool = false, bottomLeft: Bool = false, bottomRight: Bool = false) -> some View {
        Path { path in
            let length: CGFloat = 18
            if topLeft {
                path.move(to: CGPoint(x: 0, y: length))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: length, y: 0))
            } else if topRight {
                path.move(to: CGPoint(x: -length, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: length))
            } else if bottomLeft {
                path.move(to: CGPoint(x: 0, y: -length))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: length, y: 0))
            } else if bottomRight {
                path.move(to: CGPoint(x: -length, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: -length))
            }
        }
        .stroke(Color.brandTurquoise, lineWidth: 3)
        .frame(width: 18, height: 18)
    }
}

#Preview("Initial Permission Request") {
    CameraPermissionView(
        isDenied: false,
        onRequestAccess: {},
        onSkip: {}
    )
}

#Preview("Permission Denied (Settings)") {
    CameraPermissionView(
        isDenied: true,
        onRequestAccess: {},
        onSkip: {}
    )
}
