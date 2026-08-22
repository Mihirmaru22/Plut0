import Foundation

/// Thread-safe reactive event bus supporting multi-subscriber AsyncStreams for note mutations.
public final class NotesEventBus: Sendable {
    
    private let lock = NSLock()
    private let subscribers = LockIsolated<[UUID: AsyncStream<NotesEvent>.Continuation]>([:])
    
    public init() {}
    
    /// Publish a lifecycle event to all active subscribers.
    public func publish(_ event: NotesEvent) {
        subscribers.withValue { dict in
            for (_, continuation) in dict {
                continuation.yield(event)
            }
        }
    }
    
    /// Returns an asynchronous stream that emits events as they occur.
    public func events() -> AsyncStream<NotesEvent> {
        let subscriptionID = UUID()
        return AsyncStream { continuation in
            subscribers.withValue { dict in
                dict[subscriptionID] = continuation
            }
            
            continuation.onTermination = { [subscribers] _ in
                subscribers.withValue { dict in
                    dict.removeValue(forKey: subscriptionID)
                }
            }
        }
    }
}

// MARK: - LockIsolated Helper for Thread Safety

public final class LockIsolated<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Value
    
    public init(_ value: Value) {
        self._value = value
    }
    
    public func withValue<T>(_ operation: (inout Value) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return operation(&_value)
    }
    
    public var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }
}
