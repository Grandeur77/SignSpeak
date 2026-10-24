import Foundation
import OSLog

/// Unified system logging facility for SignSpeak using `os.Logger` (Phase 15).
/// Provides structured subsystems and categorized logging across camera, vision,
/// ML recognition, speech synthesis/recognition, network connectivity, and UI.
public enum AppLogger {
    public static let subsystem = "com.mileesha.SignSpeak"

    public static let camera = Logger(subsystem: subsystem, category: "camera")
    public static let vision = Logger(subsystem: subsystem, category: "vision")
    public static let recognition = Logger(subsystem: subsystem, category: "recognition")
    public static let speech = Logger(subsystem: subsystem, category: "speech")
    public static let network = Logger(subsystem: subsystem, category: "network")
    public static let auth = Logger(subsystem: subsystem, category: "auth")
    public static let data = Logger(subsystem: subsystem, category: "data")
    public static let soundAlerts = Logger(subsystem: subsystem, category: "soundAlerts")
    public static let ui = Logger(subsystem: subsystem, category: "ui")
    public static let performance = Logger(subsystem: subsystem, category: "performance")
    public static let accessibility = Logger(subsystem: subsystem, category: "accessibility")
}
