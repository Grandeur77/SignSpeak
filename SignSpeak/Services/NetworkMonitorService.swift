import Foundation
import Network
import Combine
import os

/// Protocol abstracting network connectivity observation (Phase 15.3).
public protocol NetworkMonitorServicing: Sendable {
    var isConnected: Bool { get }
    var isCellular: Bool { get }
    var isConstrained: Bool { get }
    var statusStream: AsyncStream<Bool> { get }
}

/// Production network monitor leveraging `NWPathMonitor` on a background queue.
/// Publishes connectivity state changes and logs network path updates.
public final class NetworkMonitorService: NetworkMonitorServicing, @unchecked Sendable {
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.mileesha.SignSpeak.NetworkMonitor", qos: .utility)
    private let lock = NSLock()

    private var _isConnected: Bool = true
    private var _isCellular: Bool = false
    private var _isConstrained: Bool = false
    private var continuations: [UUID: AsyncStream<Bool>.Continuation] = [:]

    public var isConnected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isConnected
    }

    public var isCellular: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isCellular
    }

    public var isConstrained: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isConstrained
    }

    public var statusStream: AsyncStream<Bool> {
        AsyncStream { continuation in
            let id = UUID()
            self.lock.lock()
            self.continuations[id] = continuation
            let current = self._isConnected
            self.lock.unlock()

            continuation.yield(current)

            continuation.onTermination = { [weak self] _ in
                self?.removeContinuation(id: id)
            }
        }
    }

    private func removeContinuation(id: UUID) {
        lock.lock()
        continuations.removeValue(forKey: id)
        lock.unlock()
    }

    public init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
        setupMonitor()
    }

    deinit {
        monitor.cancel()
        lock.lock()
        let targets = Array(continuations.values)
        continuations.removeAll()
        lock.unlock()
        for continuation in targets {
            continuation.finish()
        }
    }

    private func setupMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let connected = (path.status == .satisfied)
            let cellular = path.usesInterfaceType(.cellular)
            let constrained = path.isConstrained

            self.lock.lock()
            let previous = self._isConnected
            self._isConnected = connected
            self._isCellular = cellular
            self._isConstrained = constrained
            let targets = Array(self.continuations.values)
            self.lock.unlock()

            if previous != connected {
                if connected {
                    AppLogger.network.info("Network path satisfied (online). Cellular: \(cellular), Constrained: \(constrained)")
                } else {
                    AppLogger.network.notice("Network path unsatisfied (offline). On-device mode engaged.")
                }
            }

            for continuation in targets {
                continuation.yield(connected)
            }
        }

        monitor.start(queue: queue)
    }
}

/// Configurable stub network monitor for unit tests and SwiftUI previews.
public final class StubNetworkMonitorService: NetworkMonitorServicing, @unchecked Sendable {
    private let lock = NSLock()
    private var _isConnected: Bool
    public var isCellular: Bool
    public var isConstrained: Bool
    private var continuations: [UUID: AsyncStream<Bool>.Continuation] = [:]

    public var isConnected: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _isConnected
        }
        set {
            lock.lock()
            _isConnected = newValue
            let targets = Array(continuations.values)
            lock.unlock()
            for continuation in targets {
                continuation.yield(newValue)
            }
        }
    }

    public func setConnected(_ value: Bool) {
        self.isConnected = value
    }

    public var statusStream: AsyncStream<Bool> {
        AsyncStream { continuation in
            let id = UUID()
            self.lock.lock()
            self.continuations[id] = continuation
            let current = self._isConnected
            self.lock.unlock()

            continuation.yield(current)

            continuation.onTermination = { [weak self] _ in
                self?.lock.lock()
                self?.continuations.removeValue(forKey: id)
                self?.lock.unlock()
            }
        }
    }

    public init(isConnected: Bool = true, isCellular: Bool = false, isConstrained: Bool = false) {
        self._isConnected = isConnected
        self.isCellular = isCellular
        self.isConstrained = isConstrained
    }
}
