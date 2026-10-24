import SwiftUI
import PhotosUI

/// Screen 50: Edit Profile view per Step 9.4 specifications.
/// Allows updating photo (via PhotosPicker), full name, sign-in provider info,
/// "How you use SignSpeak" role selection, and dominant hand calibration/toggle.
public struct EditProfileView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String = ""
    @State private var email: String = ""
    @State private var selectedRole: String = "learner"
    @State private var selectedHand: String = "right"
    @State private var dailyGoalMinutes: Int = 10
    @State private var isSaving: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var avatarImageData: Data? = nil
    @State private var showSavedToast: Bool = false

    private let roles: [(id: String, title: String, subtitle: String, icon: String)] = [
        ("learner", "ASL Learner", "Learning sign language for conversations", "graduationcap.fill"),
        ("deaf", "Deaf / Hard of Hearing", "Sound alerts and live two-way transcription prioritized", "waveform.badge.magnifyingglass"),
        ("family", "Hearing Ally / Family", "Communicating with deaf family members and friends", "heart.fill"),
        ("educator", "Educator / Teacher", "Classroom and accessibility teaching", "books.vertical.fill")
    ]

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                // MARK: - Avatar Picker
                avatarPickerSection

                // MARK: - Account Information Card
                accountDetailsCard

                // MARK: - How You Use SignSpeak (Role)
                roleSelectionSection

                // MARK: - Dominant Hand Selection
                dominantHandSection

                // MARK: - Daily Goal Minutes
                dailyGoalSection

                // MARK: - Save Changes Button
                Button {
                    Task {
                        await saveProfile()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView()
                                .tint(Color.brandNavy)
                        } else {
                            Image(systemName: "checkmark")
                            Text("Save Changes")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .foregroundStyle(Color.brandNavy)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.brandYellow, in: Capsule())
                }
                .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                .buttonStyle(.plain)
                .padding(.top, Theme.Spacing.s)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.m)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadExistingProfile()
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    self.avatarImageData = data
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showSavedToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.brandTurquoise)
                    Text("Profile updated successfully")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.brandNavy, in: Capsule())
                .shadow(radius: 8)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Avatar Picker Section
    private var avatarPickerSection: some View {
        VStack(spacing: 10) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    if let avatarImageData, let uiImage = UIImage(data: avatarImageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 96, height: 96)
                            .clipShape(Circle())
                    } else {
                        Image("UserAvatar")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 96, height: 96)
                            .clipShape(Circle())
                    }

                    // Edit Badge Icon
                    Circle()
                        .fill(Color.brandNavy)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.white)
                        )
                }
            }
            .buttonStyle(.plain)

            Text("Tap to Change Photo")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.brandTurquoise)
        }
        .padding(.top, Theme.Spacing.s)
    }

    // MARK: - Account Details Card
    private var accountDetailsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Personal Details")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Display Name")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)

                TextField("Your name", text: $displayName)
                    .font(.system(size: 15))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.cardBackground.opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Email Address")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)

                HStack {
                    Text(email.isEmpty ? "guest@signspeak.app" : email)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    Text("Verified")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.brandTurquoise)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    // MARK: - Role Selection
    private var roleSelectionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text("How You Use SignSpeak")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Text("Customizes your dashboard cards and alert priorities")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }

            VStack(spacing: 8) {
                ForEach(roles, id: \.id) { role in
                    Button {
                        selectedRole = role.id
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(selectedRole == role.id ? Color.brandTurquoise : Color.gray.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Image(systemName: role.icon)
                                    .font(.system(size: 15))
                                    .foregroundStyle(selectedRole == role.id ? Color.brandNavy : Color.textSecondary)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(role.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)
                                Text(role.subtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.textSecondary)
                            }

                            Spacer()

                            Image(systemName: selectedRole == role.id ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundStyle(selectedRole == role.id ? Color.brandTurquoise : Color.textSecondary.opacity(0.4))
                        }
                        .padding(Theme.Spacing.m)
                        .background(
                            Color.cardBackground,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedRole == role.id ? Color.brandTurquoise : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Dominant Hand Section
    private var dominantHandSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Dominant Signing Hand")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Text("Calibrates the Vision hand pose skeleton and reference demonstrations")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }

            HStack(spacing: 12) {
                dominantHandOption(title: "Right Handed", icon: "hand.raised.fill", id: "right")
                dominantHandOption(title: "Left Handed", icon: "hand.raised.fill", id: "left", isMirrored: true)
            }
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private func dominantHandOption(title: String, icon: String, id: String, isMirrored: Bool = false) -> some View {
        Button {
            selectedHand = id
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .scaleEffect(x: isMirrored ? -1 : 1, y: 1)
                    .foregroundStyle(selectedHand == id ? Color.brandNavy : Color.brandTurquoise)

                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(selectedHand == id ? Color.brandNavy : Color.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                selectedHand == id ? Color.brandTurquoise : Color.cardBackground.opacity(0.6),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selectedHand == id ? Color.brandTurquoise : Color.gray.opacity(0.2), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Daily Goal Minutes
    private var dailyGoalSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                Text("Daily Practice Goal")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text("\(dailyGoalMinutes) mins/day")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.brandTurquoise)
            }

            HStack(spacing: 8) {
                ForEach([5, 10, 15, 20], id: \.self) { mins in
                    Button {
                        dailyGoalMinutes = mins
                    } label: {
                        Text("\(mins)m")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(dailyGoalMinutes == mins ? Color.brandNavy : Color.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(
                                dailyGoalMinutes == mins ? Color.brandYellow : Color.cardBackground,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(dailyGoalMinutes == mins ? Color.brandYellow : Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Theme.Spacing.m)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    // MARK: - Persistence
    private func loadExistingProfile() async {
        let uid = dependencies.authService.currentUserId ?? "guest"
        if let profile = try? await dependencies.userProfileRepository.fetchProfile(userId: uid) {
            self.displayName = profile.displayName
            self.email = profile.email ?? dependencies.authService.currentUser?.email ?? ""
            self.selectedRole = profile.role
            self.selectedHand = profile.dominantHand
            self.dailyGoalMinutes = profile.dailyGoalMinutes
        } else {
            self.displayName = "Alex Rivera"
            self.email = "alex@signspeak.app"
        }
    }

    private func saveProfile() async {
        isSaving = true
        defer { isSaving = false }

        let uid = dependencies.authService.currentUserId ?? "guest"
        var profile: UserProfile
        if let existing = try? await dependencies.userProfileRepository.fetchProfile(userId: uid) {
            profile = existing
        } else {
            profile = UserProfile(id: uid, displayName: displayName)
        }

        profile.displayName = displayName.trimmingCharacters(in: .whitespaces)
        profile.role = selectedRole
        profile.dominantHand = selectedHand
        profile.dailyGoalMinutes = dailyGoalMinutes

        try? await dependencies.userProfileRepository.saveProfile(profile)

        withAnimation {
            showSavedToast = true
        }

        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation {
                showSavedToast = false
                dismiss()
            }
        }
    }
}
