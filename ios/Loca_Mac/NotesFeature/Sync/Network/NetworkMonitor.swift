import Foundation
import Network

/// Reactive network reachability monitor backed by NWPathMonitor.
public final class NetworkMonitor: @unchecked Sendable {
    
    public static let shared = NetworkMonitor()
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.pluto.notes.networkmonitor")
    private let isConnectedState = LockIsolated<Bool>(true)
    private let statusSubscribers = LockIsolated<[UUID: AsyncStream<Bool>.Continuation]>([:])
    
    public init() {
        self.monitor = NWPathMonitor()
        self.monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            self?.updateStatus(connected)
        }
        self.monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
    
    public var isConnected: Bool {
        isConnectedState.value
    }
    
    public func observeStatus() -> AsyncStream<Bool> {
        let subID = UUID()
        return AsyncStream { continuation in
            statusSubscribers.withValue { dict in
                dict[subID] = continuation
            }
            continuation.yield(self.isConnected)
            
            continuation.onTermination = { [statusSubscribers] _ in
                statusSubscribers.withValue { dict in
                    dict.removeValue(forKey: subID)
                }
            }
        }
    }
    
    private func updateStatus(_ connected: Bool) {
        isConnectedState.withValue { $0 = connected }
        statusSubscribers.withValue { dict in
            for (_, continuation) in dict {
                continuation.yield(connected)
            }
        }
    }
}
