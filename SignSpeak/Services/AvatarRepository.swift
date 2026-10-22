import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Avatar document stored in `avatars/{uid}` containing base64-encoded compressed thumbnail.
public struct UserAvatar: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var jpegBase64: String
    public var updatedAt: Date

    public init(id: String, jpegBase64: String, updatedAt: Date = Date()) {
        self.id = id
        self.jpegBase64 = jpegBase64
        self.updatedAt = updatedAt
    }
}

/// Helper for downscaling and compressing avatar images to ≤ 256 px JPEG thumbnails.
public enum AvatarImageHelper {
    public static func processAvatar(from data: Data, maxDimension: CGFloat = 256) -> String? {
        #if canImport(UIKit)
        guard let image = UIImage(data: data), let cgImage = image.cgImage else { return nil }
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        guard width > 0, height > 0 else { return nil }

        let targetSize: CGSize
        if max(width, height) > maxDimension {
            let ratio = maxDimension / max(width, height)
            targetSize = CGSize(width: width * ratio, height: height * ratio)
        } else {
            targetSize = CGSize(width: width, height: height)
        }

        let targetWidth = max(1, Int(targetSize.width))
        let targetHeight = max(1, Int(targetSize.height))
        let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        guard let scaledCGImage = context.makeImage() else { return nil }
        let scaledImage = UIImage(cgImage: scaledCGImage)
        guard let jpegData = scaledImage.jpegData(compressionQuality: 0.8) else { return nil }
        return jpegData.base64EncodedString()
        #else
        return data.base64EncodedString()
        #endif
    }
}

/// Protocol abstracting user avatar image thumbnail persistence.
public protocol AvatarRepository: Sendable {
    func fetchAvatar(userId: String) async throws -> UserAvatar?
    func saveAvatar(userId: String, imageData: Data) async throws -> UserAvatar
    func deleteAvatar(userId: String) async throws
}

#if canImport(FirebaseFirestore)
/// Concrete implementation of `AvatarRepository` backed by Cloud Firestore.
public final class FirestoreAvatarRepository: AvatarRepository, @unchecked Sendable {
    private let db: Firestore
    private let collectionName = "avatars"

    public init(firestore: Firestore? = nil) {
        self.db = firestore ?? Firestore.firestore()
    }

    public func fetchAvatar(userId: String) async throws -> UserAvatar? {
        let doc = try await db.collection(collectionName).document(userId).getDocument()
        guard doc.exists else { return nil }
        return try doc.data(as: UserAvatar.self)
    }

    public func saveAvatar(userId: String, imageData: Data) async throws -> UserAvatar {
        guard let base64String = AvatarImageHelper.processAvatar(from: imageData) else {
            throw AuthError.unknown("Failed to compress and format avatar image.")
        }

        let avatar = UserAvatar(id: userId, jpegBase64: base64String, updatedAt: Date())
        try db.collection(collectionName).document(userId).setData(from: avatar, merge: true)
        return avatar
    }

    public func deleteAvatar(userId: String) async throws {
        try await db.collection(collectionName).document(userId).delete()
    }
}
#endif

/// In-memory repository stub for previews and unit tests.
public final class StubAvatarRepository: AvatarRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var avatars: [String: UserAvatar] = [:]

    public init(initialAvatars: [UserAvatar] = []) {
        for avatar in initialAvatars {
            avatars[avatar.id] = avatar
        }
    }

    public func fetchAvatar(userId: String) async throws -> UserAvatar? {
        lock.lock()
        defer { lock.unlock() }
        return avatars[userId]
    }

    public func saveAvatar(userId: String, imageData: Data) async throws -> UserAvatar {
        lock.lock()
        defer { lock.unlock() }
        let base64String = AvatarImageHelper.processAvatar(from: imageData) ?? imageData.base64EncodedString()
        let avatar = UserAvatar(id: userId, jpegBase64: base64String, updatedAt: Date())
        avatars[userId] = avatar
        return avatar
    }

    public func deleteAvatar(userId: String) async throws {
        lock.lock()
        defer { lock.unlock() }
        avatars.removeValue(forKey: userId)
    }
}
