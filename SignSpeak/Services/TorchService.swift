import Foundation
import AVFoundation

/// Service for visual flash alerts using the device camera LED torch.
/// Automatically verifies hardware capability and gracefully handles devices without a flash (e.g. certain iPads).
public final class TorchService: Sendable {
    public static let shared = TorchService()

    public init() {}

    /// Rapidly flashes the device LED torch a specified number of times to attract attention.
    public func flash(times: Int = 3, interval: TimeInterval = 0.15) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch,
              device.isTorchAvailable else {
            return
        }

        Task {
            for _ in 0..<times {
                setTorch(on: true, device: device)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                setTorch(on: false, device: device)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    private func setTorch(on: Bool, device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            if on {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            // Ignore hardware lock errors
        }
    }
}
