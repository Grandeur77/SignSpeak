import Foundation
import CoreML
import CoreGraphics

/// A pure, thread-safe rolling buffer of hand-pose keypoints at a fixed frame rate (default 30 fps).
/// Keeps a sliding window of N frames (default 45 frames = 1.5s) for Create ML Hand Action Classification.
/// Detects hand movement displacement across the window to arbitrate between static and motion signs.
public final class MotionWindowBuffer: @unchecked Sendable {
    public let targetFrameRate: Double
    public let windowSize: Int
    public let minFrameInterval: TimeInterval

    private let lock = NSLock()
    private var buffer: [(pose: HandPose, keypoints: MLMultiArray, timestamp: TimeInterval)] = []
    private var lastAppendedTime: TimeInterval = 0

    public init(targetFrameRate: Double = 30.0, windowSize: Int = 45) {
        self.targetFrameRate = targetFrameRate
        self.windowSize = windowSize
        self.minFrameInterval = 1.0 / max(1.0, targetFrameRate)
    }

    /// Appends a new hand pose if the minimum temporal interval has elapsed since the previous sample.
    /// Returns true if the frame was accepted into the rolling buffer, false if dropped for rate-matching.
    @discardableResult
    public func append(pose: HandPose, timestamp: TimeInterval) -> Bool {
        guard let keypoints = pose.keypointsMultiArray else { return false }

        lock.lock()
        defer { lock.unlock() }

        if lastAppendedTime > 0 && (timestamp - lastAppendedTime) < (minFrameInterval * 0.85) {
            // Drop frame to preserve target frame rate spacing
            return false
        }

        lastAppendedTime = timestamp
        buffer.append((pose: pose, keypoints: keypoints, timestamp: timestamp))

        if buffer.count > windowSize {
            buffer.removeFirst(buffer.count - windowSize)
        }

        return true
    }

    /// Resets the buffer when no hand is detected in the camera frame.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        buffer.removeAll(keepingCapacity: true)
        lastAppendedTime = 0
    }

    /// Returns true when the buffer holds the full required sequence window.
    public var isFull: Bool {
        lock.lock()
        defer { lock.unlock() }
        return buffer.count >= windowSize
    }

    /// Current count of buffered frames.
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return buffer.count
    }

    /// Returns the array of raw MLMultiArray keypoints for the motion model.
    public var keypointWindow: [MLMultiArray] {
        lock.lock()
        defer { lock.unlock() }
        return buffer.map(\.keypoints)
    }

    /// Calculates the cumulative movement displacement of the hand across the window.
    /// Tracks both wrist position and fingertip trajectories.
    /// Returns a normalized Euclidean distance value (0.0 = completely still, >0.15 = active gesture).
    public var movementDisplacement: Double {
        lock.lock()
        defer { lock.unlock() }

        guard buffer.count >= 2 else { return 0.0 }

        var totalWristDisplacement: Double = 0.0
        var totalIndexTipDisplacement: Double = 0.0

        for i in 1..<buffer.count {
            let prevPose = buffer[i - 1].pose
            let currPose = buffer[i].pose

            // Wrist displacement
            if let prevWrist = prevPose.joint(named: "wrist"),
               let currWrist = currPose.joint(named: "wrist") {
                let dx = Double(currWrist.position.x - prevWrist.position.x)
                let dy = Double(currWrist.position.y - prevWrist.position.y)
                totalWristDisplacement += sqrt(dx * dx + dy * dy)
            }

            // Index tip displacement
            if let prevIndex = prevPose.joint(named: "index_tip"),
               let currIndex = currPose.joint(named: "index_tip") {
                let dx = Double(currIndex.position.x - prevIndex.position.x)
                let dy = Double(currIndex.position.y - prevIndex.position.y)
                totalIndexTipDisplacement += sqrt(dx * dx + dy * dy)
            }
        }

        // Weighted combination: finger motion has higher weight for letters (J, Z), wrist motion for greetings (Hello)
        return max(totalWristDisplacement, totalIndexTipDisplacement)
    }
}
