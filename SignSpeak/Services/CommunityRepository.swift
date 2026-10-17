import Foundation

/// Community milestone or sharing post.
public struct CommunityPost: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let authorId: String
    public let authorName: String
    public let authorRole: String
    public let body: String
    public let createdAt: Date
    public var likeCount: Int

    public init(
        id: String = UUID().uuidString,
        authorId: String,
        authorName: String,
        authorRole: String = "learner",
        body: String,
        createdAt: Date = Date(),
        likeCount: Int = 0
    ) {
        self.id = id
        self.authorId = authorId
        self.authorName = authorName
        self.authorRole = authorRole
        self.body = body
        self.createdAt = createdAt
        self.likeCount = likeCount
    }
}

/// Protocol abstracting social feed interactions in Firestore.
public protocol CommunityRepository: Sendable {
    func fetchPosts() async throws -> [CommunityPost]
    func createPost(userId: String, post: CommunityPost) async throws
    func likePost(postId: String, userId: String) async throws
}

/// In-memory community repository stub.
public final class StubCommunityRepository: CommunityRepository, @unchecked Sendable {
    private var posts: [CommunityPost] = []

    public init(initialPosts: [CommunityPost] = []) {
        self.posts = initialPosts
    }

    public func fetchPosts() async throws -> [CommunityPost] {
        posts
    }

    public func createPost(userId: String, post: CommunityPost) async throws {
        posts.insert(post, at: 0)
    }

    public func likePost(postId: String, userId: String) async throws {
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            posts[index].likeCount += 1
        }
    }
}
