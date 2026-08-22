import Foundation

/// In-process mock WebSocket client & relay server for deterministic distributed integration testing.
public final class MockWebSocketClient: WebSocketClientProtocol, @unchecked Sendable {
    
    public let deviceID: String
    private let relay: MockRelayServer
    private let incomingContinuation = LockIsolated<[UUID: AsyncStream<SyncMessage>.Continuation]>([:])
    private let isConnectedState = LockIsolated<Bool>(true)
    
    public init(deviceID: String, relay: MockRelayServer) {
        self.deviceID = deviceID
        self.relay = relay
        relay.register(client: self)
    }
    
    public var isConnected: Bool {
        isConnectedState.value
    }
    
    public func connect() async {
        isConnectedState.withValue { $0 = true }
    }
    
    public func disconnect() async {
        isConnectedState.withValue { $0 = false }
    }
    
    public func send(message: SyncMessage) async throws {
        guard isConnected else {
            throw NotesError.persistenceFailure("Mock socket disconnected")
        }
        await relay.broadcast(message: message, from: deviceID)
    }
    
    public func incomingMessages() -> AsyncStream<SyncMessage> {
        let id = UUID()
        return AsyncStream { continuation in
            incomingContinuation.withValue { dict in
                dict[id] = continuation
            }
            
            continuation.onTermination = { [incomingContinuation] _ in
                incomingContinuation.withValue { dict in
                    dict.removeValue(forKey: id)
                }
            }
        }
    }
    
    public func receive(message: SyncMessage) {
        guard isConnected else { return }
        incomingContinuation.withValue { dict in
            for (_, c) in dict {
                c.yield(message)
            }
        }
    }
}

/// In-process zero-knowledge message relay for multi-device simulation with configurable ACK behavior.
public final class MockRelayServer: @unchecked Sendable {
    
    private let clients = LockIsolated<[String: MockWebSocketClient]>([:])
    public let autoAck = LockIsolated<Bool>(true)
    
    public init(autoAck: Bool = true) {
        self.autoAck.withValue { $0 = autoAck }
    }
    
    public func register(client: MockWebSocketClient) {
        clients.withValue { $0[client.deviceID] = client }
    }
    
    public func broadcast(message: SyncMessage, from senderDeviceID: String) async {
        if case .pushDelta(let messageID, let noteID, _, _, _) = message {
            // Auto ACK back to sender if enabled
            if autoAck.value, let sender = clients.value[senderDeviceID] {
                sender.receive(message: .ack(messageID: messageID, noteID: noteID))
            }
        }
        
        let targets = clients.value.filter { $0.key != senderDeviceID }
        for (_, client) in targets {
            client.receive(message: message)
        }
    }
}
