import Foundation

/// Learning lesson grouping a curated sequence of signs with instructions and practice.
public struct Lesson: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: String
    public let unitId: String
    public let title: String
    public let subtitle: String
    public let category: String
    public let signIds: [String]
    public let order: Int
    public let proTip: String?

    public init(
        id: String,
        unitId: String,
        title: String,
        subtitle: String,
        category: String,
        signIds: [String],
        order: Int,
        proTip: String? = nil
    ) {
        self.id = id
        self.unitId = unitId
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.signIds = signIds
        self.order = order
        self.proTip = proTip
    }
}

/// Overarching curriculum unit containing one or more lessons.
public struct LearningUnit: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let description: String
    public let lessonIds: [String]
    public let order: Int

    public init(
        id: String,
        title: String,
        description: String,
        lessonIds: [String],
        order: Int
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.lessonIds = lessonIds
        self.order = order
    }
}
