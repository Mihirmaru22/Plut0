import Foundation

public protocol WebSocketClientProtocol: Sendable {
    func connect() async
    func disconnect() async
    func send(message: SyncMessage) async throws
    func incomingMessages() -> AsyncStream<SyncMessage>
    var isConnected: Bool { get async }
}

/// Actor-isolated WebSocket client with automatic exponential backoff reconnection and streaming incoming messages.
public actor WebSocketClient: WebSocketClientProtocol {
    
    private let serverURL: URL
    private let deviceID: String
    private var webSocketTask: URLSessionWebSocketTask?
    private var isConnectedState: Bool = false
    private var reconnectAttempt: Int = 0
    private var isRunning: Bool = false
    
    private var messageContinuations: [UUID: AsyncStream<SyncMessage>.Continuation] = [:]
    
    public init(serverURL: URL, deviceID: String = "local-device") {
        self.serverURL = serverURL
        self.deviceID = deviceID
    }
    
    public var isConnected: Bool {
        isConnectedState
    }
    
    public func connect() {
        guard !isRunning else { return }
        isRunning = true
        establishConnection()
    }
    
    public func disconnect() {
        isRunning = false
        isConnectedState = false
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }
    
    public func send(message: SyncMessage) async throws {
        guard let task = webSocketTask, isConnectedState else {
            throw NotesError.persistenceFailure("WebSocket not connected")
        }
        let data = try JSONEncoder().encode(message)
        try await task.send(.data(data))
    }
    
    public func incomingMessages() -> AsyncStream<SyncMessage> {
        let id = UUID()
        return AsyncStream { continuation in
            self.messageContinuations[id] = continuation
            
            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in
                    await self?.removeContinuation(id: id)
                }
            }
        }
    }
    
    private func removeContinuation(id: UUID) {
        messageContinuations.removeValue(forKey: id)
    }
    
    // MARK: - Connection Loop
    
    private func establishConnection() {
        guard isRunning else { return }
        
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: serverURL)
        self.webSocketTask = task
        task.resume()
        
        Task {
            // Send auth message
            let auth = SyncMessage.auth(deviceID: self.deviceID, token: "pluto_token_\(self.deviceID)")
            if let data = try? JSONEncoder().encode(auth) {
                try? await task.send(.data(data))
                self.isConnectedState = true
                self.reconnectAttempt = 0
            }
            
            self.listenLoop(task: task)
        }
    }
    
    private func listenLoop(task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            guard let self = self else { return }
            
            Task {
                switch result {
                case .success(let message):
                    let data: Data?
                    switch message {
                    case .data(let d): data = d
                    case .string(let s): data = s.data(using: .utf8)
                    @unknown default: data = nil
                    }
                    
                    if let d = data, let syncMsg = try? JSONDecoder().decode(SyncMessage.self, from: d) {
                        await self.broadcastIncoming(syncMsg)
                    }
                    
                    // Continue listening
                    if await self.isRunning {
                        await self.listenLoop(task: task)
                    }
                    
                case .failure:
                    await self.handleDisconnect()
                }
            }
        }
    }
    
    private func broadcastIncoming(_ message: SyncMessage) {
        for (_, continuation) in messageContinuations {
            continuation.yield(message)
        }
    }
    
    private func handleDisconnect() {
        isConnectedState = false
        webSocketTask = nil
        
        guard isRunning else { return }
        
        // Exponential backoff
        reconnectAttempt += 1
        let delay = min(pow(2.0, Double(reconnectAttempt)), 30.0)
        
        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if self.isRunning {
                self.establishConnection()
            }
        }
    }
}
