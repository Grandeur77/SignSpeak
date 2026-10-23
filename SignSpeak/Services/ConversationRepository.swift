import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Conversation Message

/// Individual utterance in a Communicator session (`40-conversation-history`, `41-conversation-transcript`).
public struct ConversationMessage: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var speaker: String
    public var text: String
    public var at: Date
    public var source: String // "speech" | "sign" | "typed"
    public var confidence: Double? // e.g. 0.99 for 99%
    public var signsCount: Int? // e.g. 8 signs recognized

    public init(
        id: String = UUID().uuidString,
        speaker: String,
        text: String,
        at: Date = Date(),
        source: String,
        confidence: Double? = nil,
        signsCount: Int? = nil
    ) {
        self.id = id
        self.speaker = speaker
        self.text = text
        self.at = at
        self.source = source
        self.confidence = confidence
        self.signsCount = signsCount
    }
}

// MARK: - Saved Conversation

/// Saved transcript of a two-way Communicator session.
public struct SavedConversation: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var userId: String
    public var title: String
    public var venueIcon: String // SF Symbol: "cross.case.fill", "cup.and.saucer.fill", "tram.fill", etc.
    public var startedAt: Date
    public var endedAt: Date?
    public var durationSeconds: TimeInterval
    public var isSaved: Bool
    public var signsRecognizedCount: Int
    public var accuracyPercentage: Int
    public var messages: [ConversationMessage]

    public init(
        id: String = UUID().uuidString,
        userId: String = "",
        title: String,
        venueIcon: String = "bubble.left.and.bubble.right.fill",
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        durationSeconds: TimeInterval? = nil,
        isSaved: Bool = false,
        signsRecognizedCount: Int = 0,
        accuracyPercentage: Int = 98,
        messages: [ConversationMessage] = []
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.venueIcon = venueIcon
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds ?? (endedAt != nil ? max(0, endedAt!.timeIntervalSince(startedAt)) : 0)
        self.isSaved = isSaved
        self.signsRecognizedCount = signsRecognizedCount > 0 ? signsRecognizedCount : messages.filter { $0.source == "sign" }.count
        self.accuracyPercentage = accuracyPercentage
        self.messages = messages
    }

    /// Formatted human-readable session duration (e.g., "4m 32s" or "45s")
    public var formattedDuration: String {
        let secs = Int(durationSeconds)
        let mins = secs / 60
        let remainder = secs % 60
        if mins > 0 {
            return "\(mins)m \(remainder)s"
        } else {
            return "\(remainder)s"
        }
    }

    /// Formatted date header matching Design `40` (e.g. "Today, 2:15 PM • 4m 32s")
    public var formattedDateWithDuration: String {
        let calendar = Calendar.current
        let timeString = startedAt.formatted(date: .omitted, time: .shortened)
        let prefix: String
        if calendar.isDateInToday(startedAt) {
            prefix = "Today, \(timeString)"
        } else if calendar.isDateInYesterday(startedAt) {
            prefix = "Yesterday, \(timeString)"
        } else {
            let dateStr = startedAt.formatted(.dateTime.month(.abbreviated).day())
            prefix = "\(dateStr), \(timeString)"
        }

        if durationSeconds > 0 {
            return "\(prefix) • \(formattedDuration)"
        }
        return prefix
    }

    /// Full detailed date string for transcript header (e.g. "October 26, 2026 • 2:15 PM (4m 32s)")
    public var fullFormattedDateHeader: String {
        let datePart = startedAt.formatted(.dateTime.month(.wide).day().year())
        let timePart = startedAt.formatted(date: .omitted, time: .shortened)
        if durationSeconds > 0 {
            return "\(datePart) • \(timePart) (\(formattedDuration))"
        }
        return "\(datePart) • \(timePart)"
    }

    /// Partner quote for preview box
    public var partnerPreview: (speaker: String, text: String)? {
        if let msg = messages.first(where: { $0.source == "speech" || $0.speaker != "Maya" && $0.speaker != "You" }) {
            return (msg.speaker, msg.text)
        }
        return nil
    }

    /// User signed quote for preview box
    public var userPreview: (speaker: String, text: String)? {
        if let msg = messages.first(where: { $0.source == "sign" || $0.speaker == "Maya" || $0.speaker == "You" }) {
            return (msg.speaker, msg.text)
        }
        return nil
    }

    /// Pre-seeded sample conversations matching Design `40-conversation-history` and `41-conversation-transcript`.
    public static var defaults: [SavedConversation] {
        let now = Date()
        let todayAfternoon = Calendar.current.date(bySettingHour: 14, minute: 15, second: 0, of: now) ?? now
        let yesterdayMorning = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.date(bySettingHour: 10, minute: 40, second: 0, of: now) ?? now) ?? now
        let twoDaysAgoEvening = Calendar.current.date(byAdding: .day, value: -2, to: Calendar.current.date(bySettingHour: 18, minute: 5, second: 0, of: now) ?? now) ?? now

        return [
            SavedConversation(
                id: "clinic-session-1",
                title: "Dr. Henderson Clinic",
                venueIcon: "cross.case.fill",
                startedAt: todayAfternoon,
                endedAt: todayAfternoon.addingTimeInterval(272),
                durationSeconds: 272,
                isSaved: true,
                signsRecognizedCount: 14,
                accuracyPercentage: 98,
                messages: [
                    ConversationMessage(
                        speaker: "Dr. Henderson",
                        text: "Good afternoon Maya! How has the healing felt this week?",
                        at: todayAfternoon,
                        source: "speech"
                    ),
                    ConversationMessage(
                        speaker: "Maya",
                        text: "Much better! The swelling went down after day three.",
                        at: todayAfternoon.addingTimeInterval(60),
                        source: "sign",
                        confidence: 0.99,
                        signsCount: 8
                    ),
                    ConversationMessage(
                        speaker: "Dr. Henderson",
                        text: "That's great news. Let me take a quick look at your range of motion.",
                        at: todayAfternoon.addingTimeInterval(120),
                        source: "speech"
                    ),
                    ConversationMessage(
                        speaker: "Maya",
                        text: "Thank you doctor! Your recovery explanation really helped.",
                        at: todayAfternoon.addingTimeInterval(180),
                        source: "sign",
                        confidence: 0.98,
                        signsCount: 6
                    )
                ]
            ),
            SavedConversation(
                id: "coffee-session-2",
                title: "Blue Bottle Coffee",
                venueIcon: "cup.and.saucer.fill",
                startedAt: yesterdayMorning,
                endedAt: yesterdayMorning.addingTimeInterval(130),
                durationSeconds: 130,
                isSaved: false,
                signsRecognizedCount: 6,
                accuracyPercentage: 95,
                messages: [
                    ConversationMessage(
                        speaker: "Barista",
                        text: "Oat milk latte for Maya?",
                        at: yesterdayMorning,
                        source: "speech"
                    ),
                    ConversationMessage(
                        speaker: "Maya",
                        text: "Yes please, extra hot with cinnamon on top.",
                        at: yesterdayMorning.addingTimeInterval(45),
                        source: "sign",
                        confidence: 0.96,
                        signsCount: 6
                    )
                ]
            ),
            SavedConversation(
                id: "transit-session-3",
                title: "Metro Transit Info",
                venueIcon: "tram.fill",
                startedAt: twoDaysAgoEvening,
                endedAt: twoDaysAgoEvening.addingTimeInterval(525),
                durationSeconds: 525,
                isSaved: true,
                signsRecognizedCount: 22,
                accuracyPercentage: 97,
                messages: [
                    ConversationMessage(
                        speaker: "Agent",
                        text: "Platform 3 for downtown express; departs in 4 mins.",
                        at: twoDaysAgoEvening,
                        source: "speech"
                    ),
                    ConversationMessage(
                        speaker: "Maya",
                        text: "Which train connects to Airport line? Thank you!",
                        at: twoDaysAgoEvening.addingTimeInterval(90),
                        source: "sign",
                        confidence: 0.97,
                        signsCount: 7
                    )
                ]
            )
        ]
    }
}

// MARK: - Conversation Repository Protocol

/// Protocol abstracting storage of Communicator conversation transcripts.
public protocol ConversationRepository: Sendable {
    func fetchConversations(userId: String) async throws -> [SavedConversation]
    func saveConversation(userId: String, conversation: SavedConversation) async throws
    @discardableResult
    func toggleSaved(userId: String, conversationId: String) async throws -> Bool
    func deleteConversation(userId: String, conversationId: String) async throws
}

// MARK: - In-Memory Stub Repository

/// In-memory conversation repository stub.
public final class StubConversationRepository: ConversationRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var conversations: [String: [SavedConversation]] = [:]

    public init() {}

    public func fetchConversations(userId: String) async throws -> [SavedConversation] {
        lock.withLock {
            if let existing = conversations[userId], !existing.isEmpty {
                return existing.sorted { $0.startedAt > $1.startedAt }
            }

            // Pre-seed defaults for initial experience
            let initial = SavedConversation.defaults.map {
                var copy = $0
                copy.userId = userId
                return copy
            }
            conversations[userId] = initial
            return initial.sorted { $0.startedAt > $1.startedAt }
        }
    }

    public func saveConversation(userId: String, conversation: SavedConversation) async throws {
        lock.withLock {
            var userList = conversations[userId] ?? SavedConversation.defaults.map {
                var copy = $0; copy.userId = userId; return copy
            }
            var convoToSave = conversation
            if convoToSave.userId.isEmpty {
                convoToSave.userId = userId
            }
            userList.removeAll { $0.id == conversation.id }
            userList.insert(convoToSave, at: 0)
            conversations[userId] = userList
        }
    }

    @discardableResult
    public func toggleSaved(userId: String, conversationId: String) async throws -> Bool {
        lock.withLock {
            var userList = conversations[userId] ?? SavedConversation.defaults.map {
                var copy = $0; copy.userId = userId; return copy
            }
            if let idx = userList.firstIndex(where: { $0.id == conversationId }) {
                userList[idx].isSaved.toggle()
                let newState = userList[idx].isSaved
                conversations[userId] = userList
                return newState
            }
            return false
        }
    }

    public func deleteConversation(userId: String, conversationId: String) async throws {
        lock.withLock {
            var userList = conversations[userId] ?? SavedConversation.defaults.map {
                var copy = $0; copy.userId = userId; return copy
            }
            userList.removeAll { $0.id == conversationId }
            conversations[userId] = userList
        }
    }
}

// MARK: - Firestore Concrete Implementation

#if canImport(FirebaseFirestore)
/// Firestore-backed conversation repository storing transcripts under `users/{uid}/conversations/{convoId}`.
public final class FirestoreConversationRepository: ConversationRepository, @unchecked Sendable {
    private let customFirestore: Firestore?
    private let fallbackStub = StubConversationRepository()

    private var db: Firestore? {
        if let customFirestore { return customFirestore }
        #if canImport(FirebaseCore)
        if FirebaseApp.app() != nil {
            return Firestore.firestore()
        }
        #endif
        return nil
    }

    public init(firestore: Firestore? = nil) {
        self.customFirestore = firestore
    }

    public func fetchConversations(userId: String) async throws -> [SavedConversation] {
        guard let db = db else {
            return try await fallbackStub.fetchConversations(userId: userId)
        }

        let ref = db.collection("users").document(userId).collection("conversations")
        do {
            let snapshot = try await ref.order(by: "startedAt", descending: true).getDocuments()
            if snapshot.documents.isEmpty {
                // If user has no conversations in cloud yet, fallback to default seed
                return try await fallbackStub.fetchConversations(userId: userId)
            }

            var results: [SavedConversation] = []
            for doc in snapshot.documents {
                if let convo = try? doc.data(as: SavedConversation.self) {
                    results.append(convo)
                }
            }
            return results
        } catch {
            return try await fallbackStub.fetchConversations(userId: userId)
        }
    }

    public func saveConversation(userId: String, conversation: SavedConversation) async throws {
        try await fallbackStub.saveConversation(userId: userId, conversation: conversation)

        guard let db = db else { return }
        let ref = db.collection("users").document(userId).collection("conversations").document(conversation.id)
        try ref.setData(from: conversation)
    }

    @discardableResult
    public func toggleSaved(userId: String, conversationId: String) async throws -> Bool {
        let newState = try await fallbackStub.toggleSaved(userId: userId, conversationId: conversationId)

        guard let db = db else { return newState }
        let ref = db.collection("users").document(userId).collection("conversations").document(conversationId)
        try? await ref.updateData(["isSaved": newState])
        return newState
    }

    public func deleteConversation(userId: String, conversationId: String) async throws {
        try await fallbackStub.deleteConversation(userId: userId, conversationId: conversationId)

        guard let db = db else { return }
        let ref = db.collection("users").document(userId).collection("conversations").document(conversationId)
        try? await ref.delete()
    }
}
#else
public typealias FirestoreConversationRepository = StubConversationRepository
#endif
