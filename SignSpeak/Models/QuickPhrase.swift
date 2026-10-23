import Foundation

/// Stored quick phrase entity (`39c-quick-phrases`, `39b-communicator-full-screen-text`).
/// Supports categorical organization, emergency SOS styling, play counting, and sign video linkage.
public struct QuickPhrase: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: String
    public var userId: String
    public var text: String
    public var category: String
    public var isEmergency: Bool
    public var playCount: Int
    public var signId: String?
    public var note: String?
    public var isKeyCard: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        userId: String = "system",
        text: String,
        category: String = "Essentials",
        isEmergency: Bool = false,
        playCount: Int = 0,
        signId: String? = nil,
        note: String? = nil,
        isKeyCard: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.text = text
        self.category = category
        self.isEmergency = isEmergency
        self.playCount = playCount
        self.signId = signId
        self.note = note
        self.isKeyCard = isKeyCard
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case text
        case category
        case isEmergency
        case playCount
        case signId
        case note
        case isKeyCard
        case createdAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.userId = (try? container.decode(String.self, forKey: .userId)) ?? "system"
        self.text = try container.decode(String.self, forKey: .text)
        self.category = (try? container.decode(String.self, forKey: .category)) ?? "Essentials"
        self.isEmergency = (try? container.decode(Bool.self, forKey: .isEmergency)) ?? false
        self.playCount = (try? container.decode(Int.self, forKey: .playCount)) ?? 0
        self.signId = try? container.decodeIfPresent(String.self, forKey: .signId)
        self.note = try? container.decodeIfPresent(String.self, forKey: .note)
        self.isKeyCard = (try? container.decode(Bool.self, forKey: .isKeyCard)) ?? false

        if let created = try? container.decode(Date.self, forKey: .createdAt) {
            self.createdAt = created
        } else if let timestamp = try? container.decode(Double.self, forKey: .createdAt) {
            self.createdAt = Date(timeIntervalSince1970: timestamp)
        } else {
            self.createdAt = Date()
        }

        if let updated = try? container.decode(Date.self, forKey: .updatedAt) {
            self.updatedAt = updated
        } else if let timestamp = try? container.decode(Double.self, forKey: .updatedAt) {
            self.updatedAt = Date(timeIntervalSince1970: timestamp)
        } else {
            self.updatedAt = Date()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(text, forKey: .text)
        try container.encode(category, forKey: .category)
        try container.encode(isEmergency, forKey: .isEmergency)
        try container.encode(playCount, forKey: .playCount)
        try container.encodeIfPresent(signId, forKey: .signId)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encode(isKeyCard, forKey: .isKeyCard)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

/// Backwards compatibility alias for existing references
public typealias QuickPhraseItem = QuickPhrase

extension QuickPhrase {
    /// Pre-seeded defaults conforming to design `39c-quick-phrases`.
    public static let defaults: [QuickPhrase] = [
        QuickPhrase(
            id: "preset-keycard",
            text: "Please speak slowly, I am deaf",
            category: "Essentials",
            playCount: 52,
            signId: "letter_m",
            note: "Key Card",
            isKeyCard: true
        ),
        QuickPhrase(
            id: "preset-thank-you",
            text: "Thank you",
            category: "Greetings",
            playCount: 50,
            signId: "thank_you",
            note: "Polite"
        ),
        QuickPhrase(
            id: "preset-bathroom",
            text: "Where is the bathroom?",
            category: "Questions",
            playCount: 47,
            signId: "bathroom",
            note: "Frequently used"
        ),
        QuickPhrase(
            id: "preset-help",
            text: "I need help",
            category: "Emergency",
            isEmergency: true,
            playCount: 41,
            signId: "help",
            note: "Immediate attention alert"
        ),
        QuickPhrase(
            id: "preset-write-down",
            text: "Can you write that down, please?",
            category: "Essentials",
            playCount: 35,
            signId: "write",
            note: "Communication assistance"
        ),
        QuickPhrase(
            id: "preset-cost",
            text: "How much does this cost?",
            category: "Shopping",
            playCount: 38,
            signId: "cost",
            note: "Shopping & Checkout"
        ),
        QuickPhrase(
            id: "preset-yes-please",
            text: "Yes, please",
            category: "Essentials",
            playCount: 39,
            signId: "yes",
            note: "Affirmative"
        ),
        QuickPhrase(
            id: "preset-no-thank-you",
            text: "No, thank you",
            category: "Essentials",
            playCount: 33,
            signId: "no",
            note: "Negative"
        ),
        QuickPhrase(
            id: "preset-hello",
            text: "Hello! Nice to meet you.",
            category: "Greetings",
            playCount: 44,
            signId: "hello",
            note: "Friendly greeting"
        ),
        QuickPhrase(
            id: "preset-call-emergency",
            text: "Please call emergency services for me.",
            category: "Emergency",
            isEmergency: true,
            playCount: 23,
            signId: "emergency",
            note: "Urgent 911"
        ),
        QuickPhrase(
            id: "preset-doctor",
            text: "I need a doctor",
            category: "Emergency",
            isEmergency: true,
            playCount: 31,
            signId: "doctor",
            note: "Medical"
        ),
        QuickPhrase(
            id: "preset-train",
            text: "Where is the train?",
            category: "Transport",
            playCount: 27,
            signId: "train",
            note: "Transit"
        ),
        QuickPhrase(
            id: "preset-menu",
            text: "Could I see the menu, please?",
            category: "Dining",
            playCount: 29,
            signId: "menu",
            note: "Dining"
        )
    ]
}
