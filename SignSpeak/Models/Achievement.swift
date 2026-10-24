import Foundation
import SwiftUI

/// Category filter for achievements screen.
public enum AchievementCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case all = "All"
    case milestones = "Milestones"
    case vocabulary = "Vocabulary"
    case habits = "Habits"

    public var id: String { rawValue }
}

/// Tier rating determining medal color and rarity.
public enum AchievementTier: String, Codable, Sendable {
    case bronze = "Bronze"
    case silver = "Silver"
    case gold = "Gold"

    public var color: Color {
        switch self {
        case .bronze: return Color(red: 205/255, green: 127/255, blue: 50/255)
        case .silver: return Color(red: 192/255, green: 192/255, blue: 192/255)
        case .gold: return Color(red: 255/255, green: 215/255, blue: 0/255)
        }
    }
}

/// Represents an unlockable milestone badge in SignSpeak.
public struct Achievement: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let description: String
    public let iconName: String
    public let category: AchievementCategory
    public let tier: AchievementTier
    public let targetCount: Int
    public var currentCount: Int
    public var isUnlocked: Bool
    public var unlockedAt: Date?
    public let xpReward: Int

    public var progress: Double {
        guard targetCount > 0 else { return 0 }
        return min(1.0, Double(currentCount) / Double(targetCount))
    }

    public init(
        id: String,
        title: String,
        description: String,
        iconName: String,
        category: AchievementCategory,
        tier: AchievementTier,
        targetCount: Int,
        currentCount: Int = 0,
        isUnlocked: Bool = false,
        unlockedAt: Date? = nil,
        xpReward: Int = 100
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.iconName = iconName
        self.category = category
        self.tier = tier
        self.targetCount = targetCount
        self.currentCount = currentCount
        self.isUnlocked = isUnlocked
        self.unlockedAt = unlockedAt
        self.xpReward = xpReward
    }
}

/// Master catalog of all 16 badges per Step 9.4 specification.
public enum AchievementCatalog {
    public static let all: [Achievement] = [
        // 1. First Sign
        Achievement(
            id: "first_sign",
            title: "First Sign",
            description: "Practice your very first ASL sign with the camera.",
            iconName: "hand.raised.fill",
            category: .milestones,
            tier: .bronze,
            targetCount: 1,
            xpReward: 50
        ),
        // 2. 7-Day Streak
        Achievement(
            id: "streak_7",
            title: "7-Day Streak",
            description: "Practice consistently for 7 consecutive days.",
            iconName: "flame.fill",
            category: .habits,
            tier: .silver,
            targetCount: 7,
            xpReward: 150
        ),
        // 3. Conversation Starter
        Achievement(
            id: "conversation_starter",
            title: "Conversation Starter",
            description: "Complete your first live two-way communicator session.",
            iconName: "person.wave.2.fill",
            category: .milestones,
            tier: .bronze,
            targetCount: 1,
            xpReward: 75
        ),
        // 4. Alphabet Master
        Achievement(
            id: "alphabet_master",
            title: "Alphabet Master",
            description: "Master all 26 letters of the ASL fingerspelling alphabet.",
            iconName: "character.book.closed.fill",
            category: .vocabulary,
            tier: .gold,
            targetCount: 26,
            xpReward: 300
        ),
        // 5. Helpful Friend
        Achievement(
            id: "helpful_friend",
            title: "Helpful Friend",
            description: "React to or comment on a fellow signer's community clip.",
            iconName: "heart.fill",
            category: .milestones,
            tier: .bronze,
            targetCount: 1,
            xpReward: 50
        ),
        // 6. Sharp Eye
        Achievement(
            id: "sharp_eye",
            title: "Sharp Eye",
            description: "Complete a practice session with 95% or higher accuracy.",
            iconName: "eye.fill",
            category: .vocabulary,
            tier: .silver,
            targetCount: 1,
            xpReward: 100
        ),
        // 7. Century Club
        Achievement(
            id: "century_club",
            title: "Century Club",
            description: "Complete 100 total sign practice attempts.",
            iconName: "trophy.fill",
            category: .vocabulary,
            tier: .gold,
            targetCount: 100,
            xpReward: 500
        ),
        // 8. Night Owl
        Achievement(
            id: "night_owl",
            title: "Night Owl",
            description: "Complete a practice session after 9:00 PM.",
            iconName: "moon.stars.fill",
            category: .habits,
            tier: .bronze,
            targetCount: 1,
            xpReward: 50
        ),
        // 9. Early Bird
        Achievement(
            id: "early_bird",
            title: "Early Bird",
            description: "Complete a practice session before 8:00 AM.",
            iconName: "sun.horizon.fill",
            category: .habits,
            tier: .bronze,
            targetCount: 1,
            xpReward: 50
        ),
        // 10. Weekend Warrior
        Achievement(
            id: "weekend_warrior",
            title: "Weekend Warrior",
            description: "Practice on both Saturday and Sunday in the same weekend.",
            iconName: "shield.checkered",
            category: .habits,
            tier: .silver,
            targetCount: 2,
            xpReward: 120
        ),
        // 11. Speed Demon
        Achievement(
            id: "speed_demon",
            title: "Speed Demon",
            description: "Successfully recognize 5 signs within 30 seconds.",
            iconName: "bolt.fill",
            category: .vocabulary,
            tier: .silver,
            targetCount: 5,
            xpReward: 150
        ),
        // 12. Flawless Session
        Achievement(
            id: "flawless_session",
            title: "Flawless Session",
            description: "Score 100% correct across 5 or more signs in a single session.",
            iconName: "sparkles",
            category: .vocabulary,
            tier: .gold,
            targetCount: 5,
            xpReward: 250
        ),
        // 13. Quick Phrases Explorer
        Achievement(
            id: "quick_phrases_explorer",
            title: "Quick Phrases Explorer",
            description: "Speak 3 emergency or everyday phrases in the Communicator.",
            iconName: "text.bubble.fill",
            category: .milestones,
            tier: .bronze,
            targetCount: 3,
            xpReward: 75
        ),
        // 14. Gesture Calibrated
        Achievement(
            id: "gesture_calibrated",
            title: "Gesture Calibrated",
            description: "Complete lighting and dominant hand calibration.",
            iconName: "hand.point.up.left.and.text.fill",
            category: .milestones,
            tier: .bronze,
            targetCount: 1,
            xpReward: 50
        ),
        // 15. Steady Hands
        Achievement(
            id: "steady_hands",
            title: "Steady Hands",
            description: "Hold stable recognition poses across 10 completed practices.",
            iconName: "waveform.path.ecg",
            category: .vocabulary,
            tier: .silver,
            targetCount: 10,
            xpReward: 200
        ),
        // 16. Community Contributor
        Achievement(
            id: "community_contributor",
            title: "Community Contributor",
            description: "Share 3 sign video clips or demonstrations with the community.",
            iconName: "person.3.fill",
            category: .milestones,
            tier: .gold,
            targetCount: 3,
            xpReward: 350
        )
    ]
}
