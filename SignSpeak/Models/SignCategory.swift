import Foundation

/// Thematic sign category grouping (Greetings, Everyday, Emergency, etc.).
public struct SignCategory: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let iconName: String
    public let description: String
    public let order: Int
    public let introVideoName: String?

    public init(
        id: String,
        name: String,
        iconName: String,
        description: String,
        order: Int,
        introVideoName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.description = description
        self.order = order
        self.introVideoName = introVideoName
    }
}
