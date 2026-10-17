import Foundation

/// Individual utterance in a Communicator session.
public struct ConversationMessage: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let speaker: String
    public let text: String
    public let at: Date
    public let source: String // "speech" | "sign" | "typed"

    public init(
        id: String = UUID().uuidString,
        speaker: String,
        text: String,
        at: Date = Date(),
        source: String
    ) {
        self.id = id
        self.speaker = speaker
        self.text = text
        self.at = at
        self.source = source
    }
}

/// Saved transcript of a two-way Communicator session.
public struct SavedConversation: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var title: String
    public var startedAt: Date
    public var endedAt: Date?
    public var messages: [ConversationMessage]

    public init(
        id: String = UUID().uuidString,
        title: String,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        messages: [ConversationMessage] = []
    ) {
        self.id = id
        self.title = title
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.messages = messages
    }
}

/// Protocol abstracting storage of Communicator conversation transcripts.
public protocol ConversationRepository: Sendable {
    func fetchConversations(userId: String) async throws -> [SavedConversation]
    func saveConversation(userId: String, conversation: SavedConversation) async throws
    func deleteConversation(userId: String, conversationId: String) async throws
}

/// In-memory conversation repository stub.
public final class StubConversationRepository: ConversationRepository, @unchecked Sendable {
    private var conversations: [String: [SavedConversation]] = [:]

    public init() {}

    public func fetchConversations(userId: String) async throws -> [SavedConversation] {
        conversations[userId] ?? []
    }

    public func saveConversation(userId: String, conversation: SavedConversation) async throws {
        var userList = conversations[userId] ?? []
        userList.removeAll { $0.id == conversation.id }
        userList.append(conversation)
        conversations[userId] = userList
    }

    public func deleteConversation(userId: String, conversationId: String) async throws {
        conversations[userId]?.removeAll { $0.id == conversationId }
    }
}
