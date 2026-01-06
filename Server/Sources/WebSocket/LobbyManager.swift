import Vapor
import Fluent
import GameCore

/// Result of a lobby operation, containing the response and optional broadcast info.
struct LobbyOperationResult {
    /// The response to send to the requester.
    let response: ServerMessage
    /// Other user IDs to broadcast an update to (excludes requester).
    let broadcastTo: [String]
    /// The message to broadcast (if different from response, e.g., lobbyUpdated vs lobbyJoined).
    let broadcastMessage: ServerMessage?
    
    init(response: ServerMessage, broadcastTo: [String] = [], broadcastMessage: ServerMessage? = nil) {
        self.response = response
        self.broadcastTo = broadcastTo
        self.broadcastMessage = broadcastMessage
    }
}

/// Manages game lobbies.
actor LobbyManager {
    /// User ID -> Lobby ID mapping (cache, but DB is source of truth).
    private var userLobbies: [String: UUID] = [:]
    
    /// Generate a unique lobby code.
    private func generateLobbyCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  // Avoid ambiguous characters
        return String((0..<4).map { _ in chars.randomElement()! })
    }
    
    /// Create a new lobby.
    func createLobby(request: CreateLobbyRequest, userId: String, app: Application) async -> LobbyOperationResult {
        do {
            // Check if user is already in a lobby (check DB as source of truth)
            if try await findUserLobby(userId: userId, app: app) != nil {
                return LobbyOperationResult(response: .lobbyError(LobbyError(code: .alreadyInLobby, message: "Already in a lobby")))
            }
            
            guard let userUUID = UUID(uuidString: userId) else {
                return LobbyOperationResult(response: .lobbyError(LobbyError(code: .notFound, message: "Invalid user ID")))
            }
            
            // Generate unique code
            var code = generateLobbyCode()
            while try await Lobby.query(on: app.db).filter(\.$code == code).first() != nil {
                code = generateLobbyCode()
            }
            
            // Get user
            guard let user = try await User.find(userUUID, on: app.db) else {
                return LobbyOperationResult(response: .lobbyError(LobbyError(code: .notFound, message: "User not found")))
            }
            
            // Create lobby
            let lobby = Lobby(
                code: code,
                name: request.lobbyName,
                hostUserId: userUUID,
                playerMode: request.playerMode,
                useBeginnerLayout: request.useBeginnerLayout
            )
            
            // Add host as first player
            let players = [LobbyPlayerInfo(
                userId: userId,
                displayName: user.displayName,
                color: nil,
                isReady: false,
                isHost: true
            )]
            lobby.players = players
            
            try await lobby.save(on: app.db)
            
            userLobbies[userId] = lobby.id!
            
            let state = buildLobbyState(lobby)
            return LobbyOperationResult(response: .lobbyCreated(LobbyCreatedResponse(
                lobbyId: lobby.id!.uuidString,
                lobbyCode: code,
                lobby: state
            )))
        } catch {
            app.logger.error("Create lobby error: \(error)")
            return LobbyOperationResult(response: .lobbyError(LobbyError(code: .notFound, message: "Failed to create lobby")))
        }
    }
    
    /// Join an existing lobby.
    func joinLobby(request: JoinLobbyRequest, userId: String, displayName: String, app: Application) async -> LobbyOperationResult {
        do {
            // Check if user is already in a lobby (check DB as source of truth)
            if try await findUserLobby(userId: userId, app: app) != nil {
                return LobbyOperationResult(response: .lobbyError(LobbyError(code: .alreadyInLobby, message: "Already in a lobby")))
            }
            
            // Find lobby by code
            guard let lobby = try await Lobby.query(on: app.db)
                .filter(\.$code == request.lobbyCode.uppercased())
                .first() else {
                return LobbyOperationResult(response: .lobbyError(LobbyError(code: .notFound, message: "Lobby not found")))
            }
            
            // Check status
            guard lobby.status == "waiting" else {
                return LobbyOperationResult(response: .lobbyError(LobbyError(code: .gameAlreadyStarted, message: "Game already started")))
            }
            
            // Check capacity
            var players = lobby.players
            if players.count >= lobby.playerModeEnum.maxPlayers {
                return LobbyOperationResult(response: .lobbyError(LobbyError(code: .full, message: "Lobby is full")))
            }
            
            // Get existing player IDs before adding the new player (for broadcasting)
            let otherPlayerIds = players.map { $0.userId }
            
            // Add player
            players.append(LobbyPlayerInfo(
                userId: userId,
                displayName: displayName,
                color: nil,
                isReady: false,
                isHost: false
            ))
            lobby.players = players
            try await lobby.save(on: app.db)
            
            userLobbies[userId] = lobby.id!
            
            let state = buildLobbyState(lobby)
            // Joiner gets lobbyJoined, others get lobbyUpdated
            return LobbyOperationResult(
                response: .lobbyJoined(state),
                broadcastTo: otherPlayerIds,
                broadcastMessage: .lobbyUpdated(state)
            )
        } catch {
            app.logger.error("Join lobby error: \(error)")
            return LobbyOperationResult(response: .lobbyError(LobbyError(code: .notFound, message: "Failed to join lobby")))
        }
    }
    
    /// Leave the current lobby.
    func leaveLobby(userId: String, app: Application) async -> LobbyOperationResult {
        do {
            // Find lobby from DB (source of truth)
            guard let lobby = try await findUserLobby(userId: userId, app: app) else {
                userLobbies.removeValue(forKey: userId)
                return LobbyOperationResult(response: .lobbyError(LobbyError(code: .notFound, message: "Not in a lobby")))
            }
            
            var players = lobby.players
            
            // Get other player IDs before removing (for broadcasting)
            let otherPlayerIds = players.filter { $0.userId != userId }.map { $0.userId }
            
            players.removeAll { $0.userId == userId }
            
            if players.isEmpty {
                // Delete empty lobby
                try await lobby.delete(on: app.db)
                userLobbies.removeValue(forKey: userId)
                return LobbyOperationResult(response: .lobbyLeft)
            } else {
                // If host left, assign new host
                if lobby.hostUserId.uuidString == userId {
                    lobby.hostUserId = UUID(uuidString: players[0].userId)!
                    players[0].isHost = true
                }
                lobby.players = players
                try await lobby.save(on: app.db)
                
                userLobbies.removeValue(forKey: userId)
                
                let state = buildLobbyState(lobby)
                return LobbyOperationResult(
                    response: .lobbyLeft,
                    broadcastTo: otherPlayerIds,
                    broadcastMessage: .lobbyUpdated(state)
                )
            }
        } catch {
            app.logger.error("Leave lobby error: \(error)")
            return LobbyOperationResult(response: .lobbyError(LobbyError(code: .notFound, message: "Failed to leave lobby")))
        }
    }
    
    /// Select a color.
    func selectColor(request: SelectColorRequest, userId: String, app: Application) async -> LobbyOperationResult {
        do {
            // Find lobby from DB (source of truth)
            guard let lobby = try await findUserLobby(userId: userId, app: app) else {
                return LobbyOperationResult(response: .lobbyError(LobbyError(code: .notFound, message: "Not in a lobby")))
            }
            
            var players = lobby.players
            
            // Check if color is taken
            if players.contains(where: { $0.color == request.color && $0.userId != userId }) {
                return LobbyOperationResult(response: .lobbyError(LobbyError(code: .colorTaken, message: "Color already taken")))
            }
            
            // Get other player IDs (for broadcasting)
            let otherPlayerIds = players.filter { $0.userId != userId }.map { $0.userId }
            
            // Update player's color
            if let idx = players.firstIndex(where: { $0.userId == userId }) {
                players[idx].color = request.color
            }
            
            lobby.players = players
            try await lobby.save(on: app.db)
            
            let state = buildLobbyState(lobby)
            return LobbyOperationResult(
                response: .lobbyUpdated(state),
                broadcastTo: otherPlayerIds,
                broadcastMessage: .lobbyUpdated(state)
            )
        } catch {
            app.logger.error("Select color error: \(error)")
            return LobbyOperationResult(response: .lobbyError(LobbyError(code: .notFound, message: "Failed to select color")))
        }
    }
    
    /// Set ready status.
    func setReady(request: SetReadyRequest, userId: String, app: Application) async -> LobbyOperationResult {
        do {
            // Find lobby from DB (source of truth)
            guard let lobby = try await findUserLobby(userId: userId, app: app) else {
                return LobbyOperationResult(response: .lobbyError(LobbyError(code: .notFound, message: "Not in a lobby")))
            }
            
            var players = lobby.players
            
            // Get other player IDs (for broadcasting)
            let otherPlayerIds = players.filter { $0.userId != userId }.map { $0.userId }
            
            // Update player's ready status
            if let idx = players.firstIndex(where: { $0.userId == userId }) {
                players[idx].isReady = request.ready
            }
            
            lobby.players = players
            try await lobby.save(on: app.db)
            
            let state = buildLobbyState(lobby)
            return LobbyOperationResult(
                response: .lobbyUpdated(state),
                broadcastTo: otherPlayerIds,
                broadcastMessage: .lobbyUpdated(state)
            )
        } catch {
            app.logger.error("Set ready error: \(error)")
            return LobbyOperationResult(response: .lobbyError(LobbyError(code: .notFound, message: "Failed to set ready")))
        }
    }
    
    /// Result of starting a game, containing the event and all player IDs.
    struct GameStartResult {
        let response: ServerMessage
        /// All player user IDs in the game (for broadcasting).
        let allPlayerIds: [String]
    }
    
    /// Start the game.
    func startGame(userId: String, gameManager: GameManager, handler: WebSocketHandler, app: Application) async -> GameStartResult {
        do {
            // Find lobby from DB (source of truth)
            guard let lobby = try await findUserLobby(userId: userId, app: app) else {
                return GameStartResult(response: .lobbyError(LobbyError(code: .notFound, message: "Not in a lobby")), allPlayerIds: [])
            }
            
            // Check if user is host
            guard lobby.hostUserId.uuidString == userId else {
                return GameStartResult(response: .lobbyError(LobbyError(code: .notHost, message: "Only host can start the game")), allPlayerIds: [])
            }
            
            let players = lobby.players
            
            // Check player count
            if players.count < lobby.playerModeEnum.minPlayers {
                return GameStartResult(response: .lobbyError(LobbyError(code: .notEnoughPlayers, message: "Not enough players")), allPlayerIds: [])
            }
            
            // Check all ready and have colors
            for player in players {
                if !player.isReady {
                    return GameStartResult(response: .lobbyError(LobbyError(code: .notEnoughPlayers, message: "Not all players are ready")), allPlayerIds: [])
                }
                if player.color == nil {
                    return GameStartResult(response: .lobbyError(LobbyError(code: .notEnoughPlayers, message: "Not all players have selected colors")), allPlayerIds: [])
                }
            }
            
            // Get all player IDs (for broadcasting)
            let allPlayerIds = players.map { $0.userId }
            
            // Create game
            let gameStarted = await gameManager.createGame(
                lobby: lobby,
                handler: handler,
                app: app
            )
            
            // Update lobby status
            lobby.status = "started"
            lobby.gameId = UUID(uuidString: gameStarted.gameId)
            try await lobby.save(on: app.db)
            
            // Clear user lobby mappings
            for player in players {
                userLobbies.removeValue(forKey: player.userId)
            }
            
            return GameStartResult(response: .gameStarted(gameStarted), allPlayerIds: allPlayerIds)
        } catch {
            app.logger.error("Start game error: \(error)")
            return GameStartResult(response: .lobbyError(LobbyError(code: .notFound, message: "Failed to start game")), allPlayerIds: [])
        }
    }
    
    /// Find a user's current waiting lobby from the database.
    /// This is the source of truth for lobby membership.
    func findUserLobby(userId: String, app: Application) async throws -> Lobby? {
        // Query all waiting lobbies and check if user is in any of them
        let waitingLobbies = try await Lobby.query(on: app.db)
            .filter(\.$status == "waiting")
            .all()
        
        for lobby in waitingLobbies {
            if lobby.players.contains(where: { $0.userId == userId }) {
                // Update cache
                userLobbies[userId] = lobby.id!
                return lobby
            }
        }
        
        // User not in any lobby, clear cache
        userLobbies.removeValue(forKey: userId)
        return nil
    }
    
    /// Find a user's active game from the database.
    func findUserGame(userId: String, app: Application) async throws -> Game? {
        let activeGames = try await Game.query(on: app.db)
            .filter(\.$status == "active")
            .all()
        
        for game in activeGames {
            if game.players.contains(where: { $0.userId == userId }) {
                return game
            }
        }
        return nil
    }
    
    /// Build lobby state for client.
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
}

