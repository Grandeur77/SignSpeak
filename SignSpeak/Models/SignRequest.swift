import Foundation

/// User-submitted sign request document stored in `signRequests/{requestId}`.
/// Adheres to Firestore security rules: `requesterId == request.auth.uid`.
public struct SignRequest: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let requesterId: String
    public let term: String
    public let category: String
    public let notes: String?
    public let requestedAt: Date
    public let status: String // "pending" | "reviewed" | "completed"

    public init(
        id: String = UUID().uuidString,
        requesterId: String,
        term: String,
        category: String = "General",
        notes: String? = nil,
        requestedAt: Date = Date(),
        status: String = "pending"
    ) {
        self.id = id
        self.requesterId = requesterId
        self.term = term
        self.category = category
        self.notes = notes
        self.requestedAt = requestedAt
        self.status = status
    }
}
