import Vapor
import Fluent
import GameCore

/// Handles WebSocket connections and message routing.
actor WebSocketHandler {
    static let shared = WebSocketHandler()
    
    /// Connected clients by user ID.
    private var connections: [String: WebSocketConnection] = [:]
    
    /// Connection states by connection ID.
    private var connectionStates: [String: ConnectionState] = [:]
    
    /// Lobby manager.
    private let lobbyManager = LobbyManager()
    
    /// Game engine manager.
    private let gameManager = GameManager()
    
    private init() {}
    
    /// Handle a new WebSocket connection.
    nonisolated func handleConnection(req: Request, ws: WebSocket, app: Application) async {
        let connectionId = UUID().uuidString
        
        // Initialize connection state
        await setConnectionState(connectionId: connectionId, state: ConnectionState())
        
        ws.onText { [self] ws, text in
            await self.handleTextMessage(
                text: text,
                ws: ws,
                connectionId: connectionId,
                app: app
            )
        }
        
        ws.onClose.whenComplete { [self] _ in
            Task {
                await self.handleDisconnection(connectionId: connectionId)
            }
        }
    }
    
    /// Handle incoming text message.
    private func handleTextMessage(
        text: String,
        ws: WebSocket,
        connectionId: String,
        app: Application
    ) async {
        do {
            let envelope = try CatanJSON.decode(ClientEnvelope.self, from: text)
            
            // Validate protocol version
            guard envelope.protocolVersion.isSupported else {
                let error = ProtocolError(
                    code: .unsupportedVersion,
                    message: "Protocol version \(envelope.protocolVersion) not supported. Range: \(ProtocolVersion.minSupported)-\(ProtocolVersion.current)"
                )
                try await sendError(ws: ws, error: error, correlationId: envelope.requestId)
                return
            }
            
            // Get current connection state
            let state = connectionStates[connectionId] ?? ConnectionState()
            
            // Handle message
            let response = await handleMessage(
                envelope: envelope,
                userId: state.userId,
                user: state.user,
                ws: ws,
                app: app
            )
            
            // Update auth state if authenticated
            if case .authenticated(let authResp) = response {
                var newState = state
                newState.userId = authResp.userId
                newState.user = try? await User.find(UUID(uuidString: authResp.userId), on: app.db)
                connectionStates[connectionId] = newState
                registerConnection(userId: authResp.userId, ws: ws, connectionId: connectionId)
            }
            
            // Send response
            if let response = response {
                let responseEnvelope = ServerEnvelope(
                    correlationId: envelope.requestId,
                    message: response
                )
                try await send(ws: ws, envelope: responseEnvelope)
            }
        } catch {
            app.logger.error("WebSocket message error: \(error)")
            let protocolError = ProtocolError(
                code: .malformedMessage,
                message: "Failed to parse message: \(error.localizedDescription)"
            )
            try? await sendError(ws: ws, error: protocolError, correlationId: nil)
        }
    }
    
    /// Handle disconnection.
    private func handleDisconnection(connectionId: String) {
        if let state = connectionStates[connectionId], let userId = state.userId {
            unregisterConnection(userId: userId, connectionId: connectionId)
        }
        connectionStates.removeValue(forKey: connectionId)
    }
    
    /// Set connection state.
    private func setConnectionState(connectionId: String, state: ConnectionState) {
        connectionStates[connectionId] = state
    }
    
    /// Register a connection for a user.
    private func registerConnection(userId: String, ws: WebSocket, connectionId: String) {
        connections[userId] = WebSocketConnection(id: connectionId, ws: ws)
    }
    
    /// Unregister a connection.
    private func unregisterConnection(userId: String, connectionId: String) {
        if connections[userId]?.id == connectionId {
            connections.removeValue(forKey: userId)
        }
    }
    
    /// Handle a client message.
    private func handleMessage(
        envelope: ClientEnvelope,
        userId: String?,
        user: User?,
        ws: WebSocket,
        app: Application
    ) async -> ServerMessage? {
        switch envelope.message {
        case .authenticate(let request):
            return await handleAuth(request: request, app: app)
            
        case .ping:
            return .pong
            
        case .createLobby(let request):
            guard let userId = userId else {
                return .protocolError(ProtocolError(code: .unauthorized, message: "Not authenticated"))
            }
            let result = await lobbyManager.createLobby(request: request, userId: userId, app: app)
            // No broadcast needed for create (user is alone)
            return result.response
            
        case .joinLobby(let request):
            guard let userId = userId, let user = user else {
                return .protocolError(ProtocolError(code: .unauthorized, message: "Not authenticated"))
            }
            let result = await lobbyManager.joinLobby(request: request, userId: userId, displayName: user.displayName, app: app)
            // Broadcast lobbyUpdated to other members
            if let broadcastMsg = result.broadcastMessage, !result.broadcastTo.isEmpty {
                await broadcast(to: result.broadcastTo, message: broadcastMsg)
            }
            return result.response
            
        case .leaveLobby:
            guard let userId = userId else {
                return .protocolError(ProtocolError(code: .unauthorized, message: "Not authenticated"))
            }
            let result = await lobbyManager.leaveLobby(userId: userId, app: app)
            // Broadcast lobbyUpdated to remaining members
            if let broadcastMsg = result.broadcastMessage, !result.broadcastTo.isEmpty {
                await broadcast(to: result.broadcastTo, message: broadcastMsg)
            }
            return result.response
            
        case .selectColor(let request):
            guard let userId = userId else {
                return .protocolError(ProtocolError(code: .unauthorized, message: "Not authenticated"))
            }
            let result = await lobbyManager.selectColor(request: request, userId: userId, app: app)
            // Broadcast lobbyUpdated to other members
            if let broadcastMsg = result.broadcastMessage, !result.broadcastTo.isEmpty {
                await broadcast(to: result.broadcastTo, message: broadcastMsg)
            }
            return result.response
            
        case .setReady(let request):
            guard let userId = userId else {
                return .protocolError(ProtocolError(code: .unauthorized, message: "Not authenticated"))
            }
            let result = await lobbyManager.setReady(request: request, userId: userId, app: app)
            // Broadcast lobbyUpdated to other members
            if let broadcastMsg = result.broadcastMessage, !result.broadcastTo.isEmpty {
                await broadcast(to: result.broadcastTo, message: broadcastMsg)
            }
            return result.response
            
        case .startGame:
            guard let userId = userId else {
                return .protocolError(ProtocolError(code: .unauthorized, message: "Not authenticated"))
            }
            let result = await lobbyManager.startGame(userId: userId, gameManager: gameManager, handler: self, app: app)
            // Broadcast gameStarted to ALL players (including host via the normal response)
            // We broadcast to non-host players here, host gets it as the direct response
            let otherPlayerIds = result.allPlayerIds.filter { $0 != userId }
            if !otherPlayerIds.isEmpty {
                await broadcast(to: otherPlayerIds, message: result.response)
            }
            return result.response
            
        case .reconnect(let request):
            guard let userId = userId else {
                return .protocolError(ProtocolError(code: .unauthorized, message: "Not authenticated"))
            }
            return await gameManager.handleReconnect(request: request, userId: userId, handler: self, app: app)
            
        case .getSessionState:
            guard let userId = userId else {
                return .protocolError(ProtocolError(code: .unauthorized, message: "Not authenticated"))
            }
            return await getSessionState(userId: userId, app: app)
            
        // Game actions
        case .rollDice, .discardResources, .moveRobber, .stealResource,
             .buildRoad, .buildSettlement, .buildCity,
             .buyDevelopmentCard, .playKnight, .playRoadBuilding, .placeRoadBuildingRoad,
             .playYearOfPlenty, .playMonopoly,
             .proposeTrade, .acceptTrade, .rejectTrade, .cancelTrade,
             .maritimeTrade, .endTurn, .passPairedMarker, .supplyTrade:
            guard let userId = userId else {
                return .protocolError(ProtocolError(code: .unauthorized, message: "Not authenticated"))
            }
            return await gameManager.handleGameAction(
                message: envelope.message,
                userId: userId,
                requestId: envelope.requestId,
                handler: self,
                app: app
            )
        }
    }
    
    /// Handle authentication request.
    private func handleAuth(request: AuthenticateRequest, app: Application) async -> ServerMessage {
        do {
            // Try session token first
            if let token = request.sessionToken {
                if let user = try await AuthService.validateSession(token: token, on: app.db) {
                    return .authenticated(AuthenticatedResponse(
                        userId: user.id!.uuidString,
                        sessionToken: token,
                        displayName: user.displayName
                    ))
                }
                return .authenticationFailed(AuthenticationFailedResponse(reason: .sessionExpired))
            }
            
            // Find or create user
            let user: User
            if let existingUser = try await User.query(on: app.db)
                .filter(\.$identifier == request.identifier)
                .first() {
                user = existingUser
            } else {
                // Create new user (dev auth allows auto-registration)
                user = User(identifier: request.identifier, displayName: request.identifier)
                try await user.save(on: app.db)
            }
            
            // Create session
            let session = try await AuthService.createSession(for: user, on: app.db)
            
            return .authenticated(AuthenticatedResponse(
                userId: user.id!.uuidString,
                sessionToken: session.token,
                displayName: user.displayName
            ))
        } catch {
            app.logger.error("Auth error: \(error)")
            return .authenticationFailed(AuthenticationFailedResponse(reason: .invalidCredentials))
        }
    }
    
    /// Get the current session state for a user (active lobby and/or game).
    private func getSessionState(userId: String, app: Application) async -> ServerMessage {
        do {
            // Check for active lobby
            let activeLobby: LobbyState?
            if let lobby = try await lobbyManager.findUserLobby(userId: userId, app: app) {
                activeLobby = buildLobbyState(lobby)
            } else {
                activeLobby = nil
            }
            
            // Check for active game
            let activeGame: ActiveGameSummary?
            if let game = try await lobbyManager.findUserGame(userId: userId, app: app) {
                activeGame = ActiveGameSummary(
                    gameId: game.id!.uuidString,
                    playerMode: game.playerModeEnum,
                    playerCount: game.players.count,
                    playerNames: game.players.map { $0.displayName },
                    lastEventIndex: game.eventCount
                )
            } else {
                activeGame = nil
            }
            
            return .sessionState(SessionState(activeLobby: activeLobby, activeGame: activeGame))
        } catch {
            app.logger.error("Get session state error: \(error)")
            return .sessionState(SessionState(activeLobby: nil, activeGame: nil))
        }
    }
    
    /// Build lobby state from a Lobby model.
    private func buildLobbyState(_ lobby: Lobby) -> LobbyState {
        let players = lobby.players
        let takenColors = Set(players.compactMap { $0.color })
        let allColors = lobby.playerModeEnum == .fiveToSix ? PlayerColor.extendedColors : PlayerColor.baseModeColors
        let availableColors = allColors.filter { !takenColors.contains($0) }
        
        return LobbyState(
            lobbyId: lobby.id!.uuidString,
            lobbyCode: lobby.code,
            lobbyName: lobby.name,
            hostId: lobby.hostUserId.uuidString,
            playerMode: lobby.playerModeEnum,
            useBeginnerLayout: lobby.useBeginnerLayout,
            players: players.map { p in
                LobbyPlayer(
                    userId: p.userId,
                    displayName: p.displayName,
                    color: p.color,
                    isReady: p.isReady,
                    isHost: p.isHost
                )
            },
            availableColors: availableColors
        )
    }
    
    /// Send a message to a specific user.
    func sendToUser(userId: String, message: ServerMessage) async {
        guard let connection = connections[userId] else { return }
        let envelope = ServerEnvelope(message: message)
        try? await send(ws: connection.ws, envelope: envelope)
    }
    
    /// Broadcast a message to multiple users.
    func broadcast(to userIds: [String], message: ServerMessage) async {
        for userId in userIds {
            await sendToUser(userId: userId, message: message)
        }
    }
    
    /// Send an envelope.
    private func send(ws: WebSocket, envelope: ServerEnvelope) async throws {
        let json = try CatanJSON.encodeToString(envelope)
        try await ws.send(json)
    }
    
    /// Send an error.
    private func sendError(ws: WebSocket, error: ProtocolError, correlationId: String?) async throws {
        let envelope = ServerEnvelope(
            correlationId: correlationId,
            message: .protocolError(error)
        )
        try await send(ws: ws, envelope: envelope)
    }
}

/// Connection state for tracking authentication.
struct ConnectionState: Sendable {
    var userId: String?
    var user: User?
}

/// Represents a WebSocket connection.
struct WebSocketConnection: @unchecked Sendable {
    let id: String
    let ws: WebSocket
}
