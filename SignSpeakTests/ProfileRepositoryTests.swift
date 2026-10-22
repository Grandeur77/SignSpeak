import Foundation
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import SignSpeak

@Suite("Profile, PublicProfile & Avatar Repositories")
@MainActor
struct ProfileRepositoryTests {

    // MARK: - UserProfile Codable Tests

    @Test("UserProfile encodes and decodes all Section 6 data model fields")
    func userProfileCodableRoundTrip() throws {
        let reminder = ReminderSettings(enabled: true, practiceTime: "20:30", activeDays: [1, 2, 3, 4, 5])
        let original = UserProfile(
            id: "user-456",
            displayName: "Elena Rostova",
            email: "elena@example.com",
            role: "educator",
            dailyGoalMinutes: 20,
            dominantHand: "left",
            currentStreak: 12,
            xp: 1250,
            level: 5,
            longestStreak: 15,
            lastPracticeDay: "2026-10-21",
            streakFreezes: 2,
            onboardingComplete: true,
            reminderSettings: reminder,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(UserProfile.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.displayName == original.displayName)
        #expect(decoded.email == original.email)
        #expect(decoded.role == "educator")
        #expect(decoded.dailyGoalMinutes == 20)
        #expect(decoded.dominantHand == "left")
        #expect(decoded.xp == 1250)
        #expect(decoded.level == 5)
        #expect(decoded.currentStreak == 12)
        #expect(decoded.longestStreak == 15)
        #expect(decoded.lastPracticeDay == "2026-10-21")
        #expect(decoded.streakFreezes == 2)
        #expect(decoded.onboardingComplete == true)
        #expect(decoded.reminderSettings?.practiceTime == "20:30")
        #expect(decoded.reminderSettings?.activeDays == [1, 2, 3, 4, 5])
    }

    // MARK: - PublicProfile Tests

    @Test("PublicProfile encodes, decodes, and synchronizes from UserProfile")
    func publicProfileSynchronization() async throws {
        let profile = UserProfile(
            id: "user-789",
            displayName: "Carlos Diaz",
            email: "carlos@example.com",
            role: "family",
            dailyGoalMinutes: 15,
            currentStreak: 7,
            xp: 600,
            level: 3
        )

        let publicRepo = MockPublicProfileRepository()
        try await publicRepo.syncFromPrivateProfile(profile)

        #expect(publicRepo.syncCallCount == 1)
        let publicProfile = try await publicRepo.fetchPublicProfile(userId: "user-789")
        #expect(publicProfile != nil)
        #expect(publicProfile?.id == "user-789")
        #expect(publicProfile?.displayName == "Carlos Diaz")
        #expect(publicProfile?.role == "family")
        #expect(publicProfile?.level == 3)
        #expect(publicProfile?.currentStreak == 7)
        #expect(publicProfile?.followerCount == 0)
        #expect(publicProfile?.followingCount == 0)
    }

    // MARK: - Avatar Image Processing Tests

    @Test("AvatarImageHelper downscales images to <= 256 px JPEG thumbnails")
    func avatarImageDownscaling() {
        #if canImport(UIKit)
        let largeSize = CGSize(width: 1024, height: 768)
        let renderer = UIGraphicsImageRenderer(size: largeSize)
        let largeImage = renderer.image { ctx in
            ctx.cgContext.setFillColor(UIColor.systemTeal.cgColor)
            ctx.cgContext.fill(CGRect(origin: .zero, size: largeSize))
        }

        guard let inputData = largeImage.pngData() else {
            Issue.record("Failed to generate test image")
            return
        }

        let base64String = AvatarImageHelper.processAvatar(from: inputData, maxDimension: 256)
        #expect(base64String != nil)

        guard let resultString = base64String,
              let resultData = Data(base64Encoded: resultString),
              let resultImage = UIImage(data: resultData) else {
            Issue.record("Failed to decode processed avatar data")
            return
        }

        #expect(resultImage.size.width <= 256)
        #expect(resultImage.size.height <= 256)
        #expect(max(resultImage.size.width, resultImage.size.height) == 256)
        #endif
    }

    @Test("MockAvatarRepository saves, fetches, and deletes avatars")
    func avatarRepositoryLifecycle() async throws {
        let repo = MockAvatarRepository()
        let fakeImageData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // Simulated JPEG header

        let avatar = try await repo.saveAvatar(userId: "user-avatar-1", imageData: fakeImageData)
        #expect(repo.saveCallCount == 1)
        #expect(avatar.id == "user-avatar-1")
        #expect(!avatar.jpegBase64.isEmpty)

        let fetched = try await repo.fetchAvatar(userId: "user-avatar-1")
        #expect(repo.fetchCallCount == 1)
        #expect(fetched?.jpegBase64 == avatar.jpegBase64)

        try await repo.deleteAvatar(userId: "user-avatar-1")
        #expect(repo.deleteCallCount == 1)

        let deleted = try await repo.fetchAvatar(userId: "user-avatar-1")
        #expect(deleted == nil)
    }

    // MARK: - First Sign-In Profile Creation

    @Test("AppRouter initializes private and public profiles on first sign-in")
    func firstSignInProfileCreationFlow() async throws {
        let auth = MockAuthService(currentUserId: "new-user-1")
        let userProfileRepo = MockUserProfileRepository() // empty: profile does not exist yet
        let publicProfileRepo = MockPublicProfileRepository()
        let biometric = MockBiometricAuthService()
        let router = AppRouter(
            authService: auth,
            userProfileRepository: userProfileRepo,
            publicProfileRepository: publicProfileRepo,
            biometricAuthService: biometric
        )

        await router.resolveInitialRoute(minimumSplashDuration: 0)

        // Should create private profile
        #expect(userProfileRepo.createProfileIfNeededCallCount == 1)
        let createdProfile = try await userProfileRepo.fetchProfile(userId: "new-user-1")
        #expect(createdProfile != nil)
        #expect(createdProfile?.id == "new-user-1")
        #expect(createdProfile?.onboardingComplete == false)

        // Should sync to public profile
        #expect(publicProfileRepo.syncCallCount == 1)
        let publicProfile = try await publicProfileRepo.fetchPublicProfile(userId: "new-user-1")
        #expect(publicProfile != nil)
        #expect(publicProfile?.id == "new-user-1")

        // First sign-in routes to onboarding
        #expect(router.currentRoute == .onboarding)
    }
}
