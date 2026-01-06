import Foundation
import GameCore

/// WebSocket connection state.
enum WebSocketConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case authenticating
    case authenticated(userId: String)
    case failed(String)
}

/// WebSocket client for server communication.
@MainActor
@Observable
final class WebSocketClient {
    private(set) var connectionState: WebSocketConnectionState = .disconnected
    private(set) var lastSeenEventIndex: Int = 0
    
    private var webSocket: URLSessionWebSocketTask?
    private var requestCounter: Int = 0
    private var sessionToken: String?
    
    /// Connection generation counter to track intentional disconnects.
    private var connectionGeneration: Int = 0
    
    /// Task for receiving messages.
    private var receiveTask: Task<Void, Never>?
    
    private weak var gameStateManager: GameStateManager?
    
    /// Server URL.
    private let serverURL: URL
    
    init(serverURL: URL = URL(string: "ws://localhost:8080/ws")!) {
        self.serverURL = serverURL
    }
    
    /// Set the game state manager to receive updates.
    func setGameStateManager(_ manager: GameStateManager) {
        self.gameStateManager = manager
    }
    
    /// Connect to the server.
    func connect() {
        // Allow connect from disconnected or failed states
        switch connectionState {
        case .disconnected, .failed:
            break
        default:
            return  // Already connecting/connected/authenticating/authenticated
        }
        
        connectionState = .connecting
        connectionGeneration += 1
        
        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: serverURL)
        webSocket?.resume()
        
        connectionState = .connected
        startReceiving()
    }
    
    /// Disconnect from the server.
    func disconnect() {
        connectionGeneration += 1  // Invalidate any pending receive loops
        receiveTask?.cancel()
        receiveTask = nil
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        connectionState = .disconnected
        // Keep sessionToken for potential re-auth
    }
    
    /// Reset connection state completely (for logout).
    func reset() {
        disconnect()
        sessionToken = nil
        lastSeenEventIndex = 0
        requestCounter = 0
    }
    
    /// Authenticate with the server.
    func authenticate(identifier: String, existingToken: String? = nil) async {
        connectionState = .authenticating
        
        let request = AuthenticateRequest(identifier: identifier, sessionToken: existingToken)
        await send(message: .authenticate(request))
    }
    
    /// Create a new lobby.
    func createLobby(name: String, playerMode: PlayerMode, useBeginnerLayout: Bool) async {
        let request = CreateLobbyRequest(
            lobbyName: name,
            playerMode: playerMode,
            useBeginnerLayout: useBeginnerLayout
        )
        await send(message: .createLobby(request))
    }
    
    /// Join an existing lobby.
    func joinLobby(code: String) async {
        let request = JoinLobbyRequest(lobbyCode: code)
        await send(message: .joinLobby(request))
    }
    
    /// Leave the current lobby.
    func leaveLobby() async {
        await send(message: .leaveLobby)
    }
    
    /// Select a color in the lobby.
    func selectColor(_ color: PlayerColor) async {
        let request = SelectColorRequest(color: color)
        await send(message: .selectColor(request))
    }
    
    /// Set ready status.
    func setReady(_ ready: Bool) async {
        let request = SetReadyRequest(ready: ready)
        await send(message: .setReady(request))
    }
    
    /// Start the game (host only).
    func startGame() async {
        await send(message: .startGame)
    }
    
    /// Roll dice.
    func rollDice() async {
        await send(message: .rollDice)
    }
    
    /// End turn.
    func endTurn() async {
        await send(message: .endTurn)
    }
    
    /// Build a road (costs resources, or free during setup phase).
    func buildRoad(edgeId: Int, isFree: Bool = false) async {
        let intent = BuildRoadIntent(edgeId: edgeId, isFree: isFree)
        await send(message: .buildRoad(intent))
    }
    
    /// Place a road from Road Building development card.
    func placeRoadBuildingRoad(edgeId: Int) async {
        let intent = PlaceRoadBuildingRoadIntent(edgeId: edgeId)
        await send(message: .placeRoadBuildingRoad(intent))
    }
    
    /// Play the Road Building development card (activates road building mode).
    func playRoadBuilding() async {
        await send(message: .playRoadBuilding)
    }
    
    /// Build a settlement.
    func buildSettlement(nodeId: Int, isFree: Bool = false) async {
        let intent = BuildSettlementIntent(nodeId: nodeId, isFree: isFree)
        await send(message: .buildSettlement(intent))
    }
    
    /// Build a city.
    func buildCity(nodeId: Int) async {
        let intent = BuildCityIntent(nodeId: nodeId)
        await send(message: .buildCity(intent))
    }
    
    /// Buy a development card.
    func buyDevelopmentCard() async {
        await send(message: .buyDevelopmentCard)
    }
    
    /// Discard resources (when robber rolled).
    func discardResources(_ resources: ResourceBundle) async {
        let intent = DiscardResourcesIntent(resources: resources)
        await send(message: .discardResources(intent))
    }
    
    /// Move the robber.
    func moveRobber(to hexId: Int) async {
        let intent = MoveRobberIntent(hexId: hexId)
        await send(message: .moveRobber(intent))
    }
    
    /// Steal a resource.
    func stealResource(from playerId: String) async {
        let intent = StealResourceIntent(targetPlayerId: playerId)
        await send(message: .stealResource(intent))
    }
    
    /// Propose a trade.
    func proposeTrade(offering: ResourceBundle, requesting: ResourceBundle, targetPlayerIds: [String]?) async {
        let intent = ProposeTradeIntent(
            tradeId: UUID().uuidString,
            offering: offering,
            requesting: requesting,
            targetPlayerIds: targetPlayerIds
        )
        await send(message: .proposeTrade(intent))
    }
    
    /// Accept a trade.
    func acceptTrade(tradeId: String) async {
        let intent = AcceptTradeIntent(tradeId: tradeId)
        await send(message: .acceptTrade(intent))
    }
    
    /// Reject a trade.
    func rejectTrade(tradeId: String) async {
        let intent = RejectTradeIntent(tradeId: tradeId)
        await send(message: .rejectTrade(intent))
    }
    
    /// Cancel a trade.
    func cancelTrade(tradeId: String) async {
        let intent = CancelTradeIntent(tradeId: tradeId)
        await send(message: .cancelTrade(intent))
    }
    
    /// Maritime trade.
    func maritimeTrade(giving: ResourceType, givingAmount: Int, receiving: ResourceType) async {
        let intent = MaritimeTradeIntent(giving: giving, givingAmount: givingAmount, receiving: receiving)
        await send(message: .maritimeTrade(intent))
    }
    
    /// Reconnect to a game.
    func reconnect(gameId: String, lastSeenIndex: Int) async {
        let request = ReconnectRequest(gameId: gameId, lastSeenEventIndex: lastSeenIndex)
        await send(message: .reconnect(request))
    }
    
    /// Send ping.
    func ping() async {
        await send(message: .ping)
    }
    
    /// Request current session state (for resume prompts).
    func getSessionState() async {
        await send(message: .getSessionState)
    }
    
    // MARK: - Private
    
    /// Generate next request ID.
    private func nextRequestId() -> String {
        requestCounter += 1
        return "req-\(requestCounter)"
    }
    
    /// Send a message to the server.
    private func send(message: ClientMessage) async {
        guard let webSocket = webSocket else { return }
        
        let envelope = ClientEnvelope(
            requestId: nextRequestId(),
            lastSeenEventIndex: lastSeenEventIndex,
            message: message
        )
        
        do {
            let json = try CatanJSON.encodeToString(envelope)
            try await webSocket.send(.string(json))
        } catch {
            print("Failed to send message: \(error)")
        }
    }
    
    /// Start receiving messages.
    private func startReceiving() {
        let generation = connectionGeneration
        
        receiveTask = Task {
            guard let webSocket = webSocket else { return }
            
            do {
                while webSocket.state == .running && !Task.isCancelled && connectionGeneration == generation {
                    let message = try await webSocket.receive()
                    
                    // Check if connection was intentionally closed
                    guard connectionGeneration == generation else { return }
                    
                    switch message {
                    case .string(let text):
                        await handleMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            await handleMessage(text)
                        }
                    @unknown default:
                        break
                    }
                }
            } catch {
                // Only set failed state if this was not an intentional disconnect
                guard connectionGeneration == generation else { return }
                
                print("WebSocket receive error: \(error)")
                await MainActor.run {
                    // Only mark as failed if we're still in a connected/authenticated state
                    switch self.connectionState {
                    case .connected, .authenticating, .authenticated:
                        self.connectionState = .failed(error.localizedDescription)
                    default:
                        break
                    }
                }
            }
        }
    }
    
    /// Handle incoming message.
    private func handleMessage(_ text: String) async {
        do {
            let envelope = try CatanJSON.decode(ServerEnvelope.self, from: text)
            await processServerMessage(envelope.message)
        } catch {
            print("Failed to decode server message: \(error)")
        }
    }
    
    /// Process server message.
    private func processServerMessage(_ message: ServerMessage) async {
        switch message {
        case .authenticated(let response):
            sessionToken = response.sessionToken
            connectionState = .authenticated(userId: response.userId)
            gameStateManager?.setAuthenticated(userId: response.userId, displayName: response.displayName)
            // Request session state to check for active lobby/game
            Task {
                await getSessionState()
            }
            
        case .authenticationFailed(let response):
            connectionState = .failed("Authentication failed: \(response.reason)")
            
        case .lobbyCreated(let response):
            gameStateManager?.setLobbyState(response.lobby)
            
        case .lobbyJoined(let state):
            gameStateManager?.setLobbyState(state)
            
        case .lobbyUpdated(let state):
            gameStateManager?.setLobbyState(state)
            
        case .lobbyLeft:
            gameStateManager?.clearLobby()
            
        case .lobbyError(let error):
            gameStateManager?.setError("Lobby error: \(error.message)")
            
        case .gameStarted(let event):
            gameStateManager?.startGame(event: event)
            
        case .gameEvents(let batch):
            lastSeenEventIndex = batch.endIndex
            gameStateManager?.applyEvents(batch.events)
            
        case .gameSnapshot(let snapshot):
            lastSeenEventIndex = snapshot.eventIndex
            gameStateManager?.loadSnapshot(snapshot)
            
        case .intentRejected(let response):
            let messages = response.violations.map { $0.message }.joined(separator: ", ")
            gameStateManager?.setError("Action rejected: \(messages)")
            
        case .gameEnded(let event):
            gameStateManager?.endGame(event: event)
            
        case .gameReconnected(let event):
            lastSeenEventIndex = event.endEventIndex
            gameStateManager?.reconnectToGame(event: event)
            
        case .protocolError(let error):
            gameStateManager?.setError("Protocol error: \(error.message)")
            
        case .sessionState(let state):
            gameStateManager?.handleSessionState(state)
            
        case .pong:
            break  // Heartbeat response
            
        case .serverShutdown(let notice):
            gameStateManager?.setError("Server shutting down: \(notice.reason)")
            disconnect()
        }
    }
}

