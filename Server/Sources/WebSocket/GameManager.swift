import Vapor
import Fluent
import GameCore

/// Manages active games.
actor GameManager {
    /// Active game engines by game ID.
    private var engines: [String: GameEngine] = [:]
    
    /// User ID -> Game ID mapping.
    private var userGames: [String: String] = [:]
    
    /// Create a new game from a lobby.
    func createGame(lobby: Lobby, handler: WebSocketHandler, app: Application) async -> GameStartedEvent {
        let gameId = UUID().uuidString
        let boardSeed = UInt64.random(in: 0..<UInt64.max)
        
        // Convert lobby players to game players
        let players = lobby.players.enumerated().map { (idx, p) in
            GamePlayerInfo(
                playerId: "player-\(idx)",
                userId: p.userId,
                displayName: p.displayName,
                color: p.color!,
                turnOrder: idx
            )
        }
        
        // Create game record
        let game = Game(
            id: UUID(uuidString: gameId),
            playerMode: lobby.playerModeEnum,
            useBeginnerLayout: lobby.useBeginnerLayout,
            boardSeed: Int64(bitPattern: boardSeed),
            players: players
        )
        try? await game.save(on: app.db)
        
        // Create game engine
        let config = GameConfig(
            gameId: gameId,
            playerMode: lobby.playerModeEnum,
            useBeginnerLayout: lobby.useBeginnerLayout
        )
        
        let playerInfos = players.map { p in
            (userId: p.userId, displayName: p.displayName, color: p.color)
        }
        
        var rng = SeededRNG(seed: boardSeed)
        let initialState = GameState.new(config: config, playerInfos: playerInfos, rng: &rng)
        
        let engine = GameEngine(
            gameId: gameId,
            initialState: initialState,
            players: players,
            db: app.db
        )
        
        engines[gameId] = engine
        for player in players {
            userGames[player.userId] = gameId
        }
        
        // Build board layout for client
        let boardLayout = buildBoardLayout(from: initialState.board, robberHexId: initialState.robberHexId)
        
        return GameStartedEvent(
            gameId: gameId,
            playerOrder: players.map { p in
                GamePlayer(
                    playerId: p.playerId,
                    userId: p.userId,
                    displayName: p.displayName,
                    color: p.color,
                    turnOrder: p.turnOrder
                )
            },
            boardLayout: boardLayout,
            initialEventIndex: 0
        )
    }
    
    /// Handle a game action from a client.
    func handleGameAction(
        message: ClientMessage,
        userId: String,
        requestId: String,
        handler: WebSocketHandler,
        app: Application
    ) async -> ServerMessage? {
        guard let gameId = userGames[userId],
              let engine = engines[gameId] else {
            return .protocolError(ProtocolError(code: .unauthorized, message: "Not in a game"))
        }
        
        // Find player ID for this user
        let playerId = await engine.playerIdForUser(userId)
        
        // Convert client message to game action
        guard let action = convertToGameAction(message: message, playerId: playerId) else {
            return .intentRejected(IntentRejectedResponse(
                requestId: requestId,
                violations: [RuleViolation(code: .invalidAction, message: "Invalid action")]
            ))
        }
        
        // Verify the action is for this player (anti-cheat)
        if action.playerId != playerId {
            return .intentRejected(IntentRejectedResponse(
                requestId: requestId,
                violations: [RuleViolation(code: .notYourTurn, message: "Cannot perform actions for other players")]
            ))
        }
        
        // Process action
        let result = await engine.processAction(action)
        
        switch result {
        case .success(let events):
            // Broadcast events to all players
            let protocolEvents = events.map { EventConverter.toProtocol($0) }
            let eventIndex = await engine.currentEventIndex()
            let batch = GameEventsBatch(
                gameId: gameId,
                events: protocolEvents,
                startIndex: eventIndex - events.count + 1,
                endIndex: eventIndex
            )
            
            // Get all user IDs in this game
            let userIds = getUsersInGame(gameId: gameId)
            await handler.broadcast(to: userIds, message: .gameEvents(batch))
            return nil  // Events already broadcast
            
        case .rejected(let violations):
            return .intentRejected(IntentRejectedResponse(requestId: requestId, violations: violations))
            
        case .error(let message):
            return .protocolError(ProtocolError(code: .internalError, message: message))
        }
    }
    
    /// Get all user IDs in a game.
    private func getUsersInGame(gameId: String) -> [String] {
        userGames.filter { $0.value == gameId }.map { $0.key }
    }
    
    /// Handle reconnection request.
    func handleReconnect(request: ReconnectRequest, userId: String, handler: WebSocketHandler, app: Application) async -> ServerMessage {
        // Try to find the game
        guard let game = try? await Game.find(UUID(uuidString: request.gameId), on: app.db) else {
            return .protocolError(ProtocolError(code: .internalError, message: "Game not found"))
        }
        
        // Check user is a player in this game
        guard game.players.contains(where: { $0.userId == userId }) else {
            return .protocolError(ProtocolError(code: .unauthorized, message: "Not a player in this game"))
        }
        
        // Get or recreate engine
        let engine: GameEngine
        if let existingEngine = engines[request.gameId] {
            engine = existingEngine
        } else {
            // Recreate engine from persistence
            do {
                engine = try await recreateEngine(game: game, db: app.db)
                engines[request.gameId] = engine
            } catch {
                return .protocolError(ProtocolError(code: .internalError, message: "Failed to restore game: \(error)"))
            }
        }
        
        // Register this user as in this game
        userGames[userId] = request.gameId
        for player in game.players {
            userGames[player.userId] = request.gameId
        }
        
        // Get current state and events
        do {
            let events = try await engine.getEventsSince(request.lastSeenEventIndex)
            let protocolEvents = events.map { EventConverter.toProtocol($0) }
            let currentIndex = await engine.currentEventIndex()
            let currentState = await engine.currentState()
            
            // Build board layout
            let boardLayout = buildBoardLayout(from: currentState.board, robberHexId: currentState.robberHexId)
            
            // Build player order
            let playerOrder = game.players.map { p in
                GamePlayer(
                    playerId: p.playerId,
                    userId: p.userId,
                    displayName: p.displayName,
                    color: p.color,
                    turnOrder: p.turnOrder
                )
            }
            
            // Build current turn state
            let turnState = ReconnectTurnState(
                phase: currentState.turn.phase.rawValue,
                activePlayerId: currentState.turn.activePlayerId,
                turnNumber: currentState.turn.turnNumber,
                setupRound: currentState.turn.setupRound,
                setupNeedsRoad: currentState.turn.setupNeedsRoad
            )
            
            // Build buildings state
            let buildingsState = ReconnectBuildingsState(
                settlements: currentState.buildings.settlements,
                cities: currentState.buildings.cities,
                roads: currentState.buildings.roads
            )
            
            return .gameReconnected(GameReconnectedEvent(
                gameId: request.gameId,
                playerOrder: playerOrder,
                boardLayout: boardLayout,
                currentTurn: turnState,
                buildings: buildingsState,
                events: protocolEvents,
                startEventIndex: request.lastSeenEventIndex + 1,
                endEventIndex: currentIndex
            ))
        } catch {
            return .protocolError(ProtocolError(code: .internalError, message: "Failed to get game state"))
        }
    }
    
    /// Recreate a game engine from persistence.
    private func recreateEngine(game: Game, db: any Database) async throws -> GameEngine {
        let gameId = game.id!.uuidString
        
        // Try to find latest snapshot
        let snapshot = try await GameSnapshotModel.query(on: db)
            .filter(\.$game.$id == game.id!)
            .sort(\.$eventIndex, .descending)
            .first()
        
        let config = GameConfig(
            gameId: gameId,
            playerMode: game.playerModeEnum,
            useBeginnerLayout: game.useBeginnerLayout
        )
        
        let state: GameState
        let startEventIndex: Int
        
        if let snapshot = snapshot {
            // Start from snapshot
            state = try snapshot.decodeState()
            startEventIndex = snapshot.eventIndex + 1
        } else {
            // Replay from beginning
            let playerInfos = game.players.map { p in
                (userId: p.userId, displayName: p.displayName, color: p.color)
            }
            var rng = SeededRNG(seed: UInt64(bitPattern: game.boardSeed))
            state = GameState.new(config: config, playerInfos: playerInfos, rng: &rng)
            startEventIndex = 0
        }
        
        // Get events to replay
        let events = try await GameEventModel.query(on: db)
            .filter(\.$game.$id == game.id!)
            .filter(\.$eventIndex >= startEventIndex)
            .sort(\.$eventIndex)
            .all()
        
        // Replay events
        var currentState = state
        for event in events {
            let domainEvent = try event.decodeEvent()
            currentState = currentState.applying(domainEvent)
        }
        
        return GameEngine(
            gameId: gameId,
            initialState: currentState,
            players: game.players,
            db: db
        )
    }
    
    /// Convert client message to game action.
    private func convertToGameAction(message: ClientMessage, playerId: String) -> GameAction? {
        switch message {
        case .rollDice:
            return .rollDice(playerId: playerId)
        case .discardResources(let intent):
            return .discardResources(playerId: playerId, resources: intent.resources)
        case .moveRobber(let intent):
            return .moveRobber(playerId: playerId, hexId: intent.hexId)
        case .stealResource(let intent):
            return .stealResource(playerId: playerId, victimId: intent.targetPlayerId)
        case .buildRoad(let intent):
            // isFree is ONLY for setup phase - Road Building card uses placeRoadBuildingRoad
            if intent.isFree {
                return .setupPlaceRoad(playerId: playerId, edgeId: intent.edgeId)
            } else {
                return .buildRoad(playerId: playerId, edgeId: intent.edgeId)
            }
        case .buildSettlement(let intent):
            // isFree is ONLY for setup phase
            if intent.isFree {
                return .setupPlaceSettlement(playerId: playerId, nodeId: intent.nodeId)
            } else {
                return .buildSettlement(playerId: playerId, nodeId: intent.nodeId)
            }
        case .placeRoadBuildingRoad(let intent):
            // Explicit message for Road Building card roads
            return .placeRoadBuildingRoad(playerId: playerId, edgeId: intent.edgeId)
        case .buildCity(let intent):
            return .buildCity(playerId: playerId, nodeId: intent.nodeId)
        case .buyDevelopmentCard:
            return .buyDevelopmentCard(playerId: playerId)
        case .playKnight(let intent):
            return .playKnight(playerId: playerId, cardId: "", moveRobberTo: intent.moveRobberTo, stealFrom: intent.stealFrom)
        case .playRoadBuilding:
            return .playRoadBuilding(playerId: playerId, cardId: "")
        case .playYearOfPlenty(let intent):
            return .playYearOfPlenty(playerId: playerId, cardId: "", resource1: intent.firstResource, resource2: intent.secondResource)
        case .playMonopoly(let intent):
            return .playMonopoly(playerId: playerId, cardId: "", resource: intent.resourceType)
        case .proposeTrade(let intent):
            return .proposeTrade(playerId: playerId, tradeId: intent.tradeId, offering: intent.offering, requesting: intent.requesting, targetPlayerIds: intent.targetPlayerIds)
        case .acceptTrade(let intent):
            return .acceptTrade(playerId: playerId, tradeId: intent.tradeId)
        case .rejectTrade(let intent):
            return .rejectTrade(playerId: playerId, tradeId: intent.tradeId)
        case .cancelTrade(let intent):
            return .cancelTrade(playerId: playerId, tradeId: intent.tradeId)
        case .maritimeTrade(let intent):
            return .maritimeTrade(playerId: playerId, giving: intent.giving, givingAmount: intent.givingAmount, receiving: intent.receiving)
        case .endTurn:
            return .endTurn(playerId: playerId)
        case .passPairedMarker:
            return .passPairedMarker(playerId: playerId)
        case .supplyTrade(let intent):
            return .supplyTrade(playerId: playerId, giving: intent.giving, receiving: intent.receiving)
        default:
            return nil
        }
    }
    
    /// Build board layout for client.
    private func buildBoardLayout(from board: Board, robberHexId: Int) -> BoardLayout {
        BoardLayout(
            hexes: board.hexes.map { hex in
                HexTile(
                    hexId: hex.id,
                    terrain: hex.terrain,
                    numberToken: hex.numberToken,
                    center: HexCoordinate(q: hex.coord.q, r: hex.coord.r)
                )
            },
            nodes: board.nodes.map { node in
                NodePosition(
                    nodeId: node.id,
                    adjacentHexIds: node.adjacentHexIds,
                    adjacentEdgeIds: node.adjacentEdgeIds,
                    adjacentNodeIds: node.adjacentNodeIds
                )
            },
            edges: board.edges.map { edge in
                EdgePosition(
                    edgeId: edge.id,
                    nodeIds: edge.nodeIds,
                    adjacentHexIds: edge.adjacentHexIds
                )
            },
            harbors: board.harbors.map { harbor in
                Harbor(harborId: harbor.id, type: harbor.type, nodeIds: harbor.nodeIds)
            },
            robberHexId: robberHexId
        )
    }
}
