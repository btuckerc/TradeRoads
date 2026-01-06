// MARK: - Server to Client Messages

import Foundation

/// All messages that the server can send to clients.
public enum ServerMessage: Sendable, Codable, Hashable {
    // MARK: - Protocol Errors
    
    /// Protocol-level error (version mismatch, malformed message, etc.).
    case protocolError(ProtocolError)
    
    // MARK: - Authentication
    
    /// Authentication result.
    case authenticated(AuthenticatedResponse)
    
    /// Authentication failed.
    case authenticationFailed(AuthenticationFailedResponse)
    
    // MARK: - Lobby
    
    /// Lobby was created successfully.
    case lobbyCreated(LobbyCreatedResponse)
    
    /// Joined a lobby successfully.
    case lobbyJoined(LobbyState)
    
    /// Lobby state updated (player joined/left, color change, ready state).
    case lobbyUpdated(LobbyState)
    
    /// Left the lobby.
    case lobbyLeft
    
    /// Lobby error (full, not found, etc.).
    case lobbyError(LobbyError)
    
    // MARK: - Game Events
    
    /// Game has started.
    case gameStarted(GameStartedEvent)
    
    /// Batch of domain events from the game.
    case gameEvents(GameEventsBatch)
    
    /// Game state snapshot (for reconnection).
    case gameSnapshot(GameSnapshot)
    
    /// Intent was rejected (rule violation).
    case intentRejected(IntentRejectedResponse)
    
    /// Game has ended.
    case gameEnded(GameEndedEvent)
    
    /// Reconnected to a game successfully (contains full state).
    case gameReconnected(GameReconnectedEvent)
    
    // MARK: - Session State
    
    /// Current session state (for resume prompt on login).
    case sessionState(SessionState)
    
    // MARK: - Misc
    
    /// Pong response to ping.
    case pong
    
    /// Server is shutting down.
    case serverShutdown(ServerShutdownNotice)
}

// MARK: - Protocol Errors

public struct ProtocolError: Sendable, Codable, Hashable {
    public let code: ProtocolErrorCode
    public let message: String
    
    public init(code: ProtocolErrorCode, message: String) {
        self.code = code
        self.message = message
    }
}

public enum ProtocolErrorCode: String, Sendable, Codable, Hashable {
    case unsupportedVersion
    case malformedMessage
    case unauthorized
    case rateLimited
    case internalError
}

// MARK: - Authentication Responses

public struct AuthenticatedResponse: Sendable, Codable, Hashable {
    public let userId: String
    public let sessionToken: String
    public let displayName: String
    
    public init(userId: String, sessionToken: String, displayName: String) {
        self.userId = userId
        self.sessionToken = sessionToken
        self.displayName = displayName
    }
}

public struct AuthenticationFailedResponse: Sendable, Codable, Hashable {
    public let reason: AuthFailureReason
    
    public init(reason: AuthFailureReason) {
        self.reason = reason
    }
}

public enum AuthFailureReason: String, Sendable, Codable, Hashable {
    case invalidCredentials
    case sessionExpired
    case accountDisabled
    case invalidOneTimeCode
}

// MARK: - Lobby Responses

public struct LobbyCreatedResponse: Sendable, Codable, Hashable {
    public let lobbyId: String
    public let lobbyCode: String
    public let lobby: LobbyState
    
    public init(lobbyId: String, lobbyCode: String, lobby: LobbyState) {
        self.lobbyId = lobbyId
        self.lobbyCode = lobbyCode
        self.lobby = lobby
    }
}

public struct LobbyState: Sendable, Codable, Hashable {
    public let lobbyId: String
    public let lobbyCode: String
    public let lobbyName: String
    public let hostId: String
    public let playerMode: PlayerMode
    public let useBeginnerLayout: Bool
    public let players: [LobbyPlayer]
    public let availableColors: [PlayerColor]
    
    public init(
        lobbyId: String,
        lobbyCode: String,
        lobbyName: String,
        hostId: String,
        playerMode: PlayerMode,
        useBeginnerLayout: Bool,
        players: [LobbyPlayer],
        availableColors: [PlayerColor]
    ) {
        self.lobbyId = lobbyId
        self.lobbyCode = lobbyCode
        self.lobbyName = lobbyName
        self.hostId = hostId
        self.playerMode = playerMode
        self.useBeginnerLayout = useBeginnerLayout
        self.players = players
        self.availableColors = availableColors
    }
    
    public var canStart: Bool {
        let readyCount = players.filter { $0.isReady }.count
        return readyCount >= playerMode.minPlayers && players.allSatisfy { $0.color != nil }
    }
}

public struct LobbyPlayer: Sendable, Codable, Hashable {
    public let userId: String
    public let displayName: String
    public let color: PlayerColor?
    public let isReady: Bool
    public let isHost: Bool
    
    public init(userId: String, displayName: String, color: PlayerColor?, isReady: Bool, isHost: Bool) {
        self.userId = userId
        self.displayName = displayName
        self.color = color
        self.isReady = isReady
        self.isHost = isHost
    }
}

public struct LobbyError: Sendable, Codable, Hashable {
    public let code: LobbyErrorCode
    public let message: String
    
    public init(code: LobbyErrorCode, message: String) {
        self.code = code
        self.message = message
    }
}

public enum LobbyErrorCode: String, Sendable, Codable, Hashable {
    case notFound
    case full
    case alreadyInLobby
    case colorTaken
    case notHost
    case notEnoughPlayers
    case gameAlreadyStarted
}

// MARK: - Game Events

public struct GameStartedEvent: Sendable, Codable, Hashable {
    public let gameId: String
    public let playerOrder: [GamePlayer]
    public let boardLayout: BoardLayout
    public let initialEventIndex: Int
    
    public init(gameId: String, playerOrder: [GamePlayer], boardLayout: BoardLayout, initialEventIndex: Int) {
        self.gameId = gameId
        self.playerOrder = playerOrder
        self.boardLayout = boardLayout
        self.initialEventIndex = initialEventIndex
    }
}

/// Event sent when a client successfully reconnects to an ongoing game.
public struct GameReconnectedEvent: Sendable, Codable, Hashable {
    public let gameId: String
    public let playerOrder: [GamePlayer]
    public let boardLayout: BoardLayout
    public let currentTurn: ReconnectTurnState
    public let buildings: ReconnectBuildingsState
    public let events: [GameDomainEvent]
    public let startEventIndex: Int
    public let endEventIndex: Int
    
    public init(
        gameId: String,
        playerOrder: [GamePlayer],
        boardLayout: BoardLayout,
        currentTurn: ReconnectTurnState,
        buildings: ReconnectBuildingsState,
        events: [GameDomainEvent],
        startEventIndex: Int,
        endEventIndex: Int
    ) {
        self.gameId = gameId
        self.playerOrder = playerOrder
        self.boardLayout = boardLayout
        self.currentTurn = currentTurn
        self.buildings = buildings
        self.events = events
        self.startEventIndex = startEventIndex
        self.endEventIndex = endEventIndex
    }
}

/// Current turn state for reconnection.
public struct ReconnectTurnState: Sendable, Codable, Hashable {
    public let phase: String
    public let activePlayerId: String
    public let turnNumber: Int
    public let setupRound: Int
    public let setupNeedsRoad: Bool
    
    public init(phase: String, activePlayerId: String, turnNumber: Int, setupRound: Int, setupNeedsRoad: Bool) {
        self.phase = phase
        self.activePlayerId = activePlayerId
        self.turnNumber = turnNumber
        self.setupRound = setupRound
        self.setupNeedsRoad = setupNeedsRoad
    }
}

/// Current buildings state for reconnection.
public struct ReconnectBuildingsState: Sendable, Codable, Hashable {
    public let settlements: [Int: String]  // nodeId -> playerId
    public let cities: [Int: String]       // nodeId -> playerId
    public let roads: [Int: String]        // edgeId -> playerId
    
    public init(settlements: [Int: String], cities: [Int: String], roads: [Int: String]) {
        self.settlements = settlements
        self.cities = cities
        self.roads = roads
    }
}

public struct GamePlayer: Sendable, Codable, Hashable {
    public let playerId: String
    public let userId: String
    public let displayName: String
    public let color: PlayerColor
    public let turnOrder: Int
    
    public init(playerId: String, userId: String, displayName: String, color: PlayerColor, turnOrder: Int) {
        self.playerId = playerId
        self.userId = userId
        self.displayName = displayName
        self.color = color
        self.turnOrder = turnOrder
    }
}

public struct BoardLayout: Sendable, Codable, Hashable {
    public let hexes: [HexTile]
    public let nodes: [NodePosition]
    public let edges: [EdgePosition]
    public let harbors: [Harbor]
    public let robberHexId: Int
    
    public init(hexes: [HexTile], nodes: [NodePosition], edges: [EdgePosition], harbors: [Harbor], robberHexId: Int) {
        self.hexes = hexes
        self.nodes = nodes
        self.edges = edges
        self.harbors = harbors
        self.robberHexId = robberHexId
    }
}

public struct HexTile: Sendable, Codable, Hashable {
    public let hexId: Int
    public let terrain: TerrainType
    public let numberToken: Int?
    public let center: HexCoordinate
    
    public init(hexId: Int, terrain: TerrainType, numberToken: Int?, center: HexCoordinate) {
        self.hexId = hexId
        self.terrain = terrain
        self.numberToken = numberToken
        self.center = center
    }
}

public enum TerrainType: String, Sendable, Codable, Hashable, CaseIterable {
    case hills      // Produces brick
    case forest     // Produces lumber
    case mountains  // Produces ore
    case fields     // Produces grain
    case pasture    // Produces wool
    case desert     // Produces nothing
}

extension TerrainType {
    public var producedResource: ResourceType? {
        switch self {
        case .hills: return .brick
        case .forest: return .lumber
        case .mountains: return .ore
        case .fields: return .grain
        case .pasture: return .wool
        case .desert: return nil
        }
    }
}

public struct HexCoordinate: Sendable, Codable, Hashable {
    public let q: Int
    public let r: Int
    
    public init(q: Int, r: Int) {
        self.q = q
        self.r = r
    }
}

public struct NodePosition: Sendable, Codable, Hashable {
    public let nodeId: Int
    public let adjacentHexIds: [Int]
    public let adjacentEdgeIds: [Int]
    public let adjacentNodeIds: [Int]
    
    public init(nodeId: Int, adjacentHexIds: [Int], adjacentEdgeIds: [Int], adjacentNodeIds: [Int]) {
        self.nodeId = nodeId
        self.adjacentHexIds = adjacentHexIds
        self.adjacentEdgeIds = adjacentEdgeIds
        self.adjacentNodeIds = adjacentNodeIds
    }
}

public struct EdgePosition: Sendable, Codable, Hashable {
    public let edgeId: Int
    public let nodeIds: (Int, Int)
    public let adjacentHexIds: [Int]
    
    public init(edgeId: Int, nodeIds: (Int, Int), adjacentHexIds: [Int]) {
        self.edgeId = edgeId
        self.nodeIds = nodeIds
        self.adjacentHexIds = adjacentHexIds
    }
    
    // Custom Codable for tuple
    private enum CodingKeys: String, CodingKey {
        case edgeId, nodeId1, nodeId2, adjacentHexIds
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        edgeId = try container.decode(Int.self, forKey: .edgeId)
        let nodeId1 = try container.decode(Int.self, forKey: .nodeId1)
        let nodeId2 = try container.decode(Int.self, forKey: .nodeId2)
        nodeIds = (nodeId1, nodeId2)
        adjacentHexIds = try container.decode([Int].self, forKey: .adjacentHexIds)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(edgeId, forKey: .edgeId)
        try container.encode(nodeIds.0, forKey: .nodeId1)
        try container.encode(nodeIds.1, forKey: .nodeId2)
        try container.encode(adjacentHexIds, forKey: .adjacentHexIds)
    }
    
    public static func == (lhs: EdgePosition, rhs: EdgePosition) -> Bool {
        lhs.edgeId == rhs.edgeId &&
        lhs.nodeIds.0 == rhs.nodeIds.0 &&
        lhs.nodeIds.1 == rhs.nodeIds.1 &&
        lhs.adjacentHexIds == rhs.adjacentHexIds
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(edgeId)
        hasher.combine(nodeIds.0)
        hasher.combine(nodeIds.1)
        hasher.combine(adjacentHexIds)
    }
}

public struct Harbor: Sendable, Codable, Hashable {
    public let harborId: Int
    public let type: HarborType
    public let nodeIds: [Int]
    
    public init(harborId: Int, type: HarborType, nodeIds: [Int]) {
        self.harborId = harborId
        self.type = type
        self.nodeIds = nodeIds
    }
}

public enum HarborType: Sendable, Codable, Hashable {
    case generic           // 3:1 any resource
    case specific(ResourceType)  // 2:1 specific resource
    
    public var tradeRatio: Int {
        switch self {
        case .generic: return 3
        case .specific: return 2
        }
    }
}

// MARK: - Game Events Batch

public struct GameEventsBatch: Sendable, Codable, Hashable {
    public let gameId: String
    public let events: [GameDomainEvent]
    public let startIndex: Int
    public let endIndex: Int
    
    public init(gameId: String, events: [GameDomainEvent], startIndex: Int, endIndex: Int) {
        self.gameId = gameId
        self.events = events
        self.startIndex = startIndex
        self.endIndex = endIndex
    }
}

/// Domain events that represent changes to game state.
/// These are the "facts" that both client and server agree on.
public enum GameDomainEvent: Sendable, Codable, Hashable {
    // MARK: - Setup
    
    case setupPhaseStarted(SetupPhaseStartedEvent)
    case setupPiecePlaced(SetupPiecePlacedEvent)
    case setupTurnAdvanced(SetupTurnAdvancedEvent)
    case setupPhaseEnded
    
    // MARK: - Turn Flow
    
    case turnStarted(TurnStartedEvent)
    case diceRolled(DiceRolledEvent)
    case resourcesProduced(ResourcesProducedEvent)
    case noResourcesProduced(NoResourcesProducedEvent)
    case turnEnded(TurnEndedEvent)
    
    // MARK: - Robber
    
    case mustDiscard(MustDiscardEvent)
    case playerDiscarded(PlayerDiscardedEvent)
    case robberMoved(RobberMovedEvent)
    case resourceStolen(ResourceStolenEvent)
    
    // MARK: - Building
    
    case roadBuilt(RoadBuiltEvent)
    case settlementBuilt(SettlementBuiltEvent)
    case cityBuilt(CityBuiltEvent)
    
    // MARK: - Development Cards
    
    case developmentCardBought(DevelopmentCardBoughtEvent)
    case knightPlayed(KnightPlayedEvent)
    case roadBuildingPlayed(RoadBuildingPlayedEvent)
    case yearOfPlentyPlayed(YearOfPlentyPlayedEvent)
    case monopolyPlayed(MonopolyPlayedEvent)
    case victoryPointRevealed(VictoryPointRevealedEvent)
    
    // MARK: - Trading
    
    case tradeProposed(TradeProposedEvent)
    case tradeAccepted(TradeAcceptedEvent)
    case tradeRejected(TradeRejectedEvent)
    case tradeCancelled(TradeCancelledEvent)
    case tradeExecuted(TradeExecutedEvent)
    case maritimeTradeExecuted(MaritimeTradeExecutedEvent)
    
    // MARK: - Awards
    
    case longestRoadAwarded(LongestRoadAwardedEvent)
    case largestArmyAwarded(LargestArmyAwardedEvent)
    
    // MARK: - Victory
    
    case playerWon(PlayerWonEvent)
    
    // MARK: - 5-6 Player Extension
    
    case pairedTurnStarted(PairedTurnStartedEvent)
    case pairedMarkerPassed(PairedMarkerPassedEvent)
    case supplyTradeExecuted(SupplyTradeExecutedEvent)
}

// MARK: - Event Payloads

public struct SetupPhaseStartedEvent: Sendable, Codable, Hashable {
    public let firstPlayerId: String
    
    public init(firstPlayerId: String) {
        self.firstPlayerId = firstPlayerId
    }
}

public struct SetupPiecePlacedEvent: Sendable, Codable, Hashable {
    public let playerId: String
    public let pieceType: SetupPieceType
    public let locationId: Int
    public let round: Int
    
    public init(playerId: String, pieceType: SetupPieceType, locationId: Int, round: Int) {
        self.playerId = playerId
        self.pieceType = pieceType
        self.locationId = locationId
        self.round = round
    }
}

/// Event emitted when the setup phase advances to a new player.
public struct SetupTurnAdvancedEvent: Sendable, Codable, Hashable {
    public let nextPlayerId: String
    public let setupRound: Int
    public let setupPlayerIndex: Int
    public let setupForward: Bool
    
    public init(nextPlayerId: String, setupRound: Int, setupPlayerIndex: Int, setupForward: Bool) {
        self.nextPlayerId = nextPlayerId
        self.setupRound = setupRound
        self.setupPlayerIndex = setupPlayerIndex
        self.setupForward = setupForward
    }
}

public enum SetupPieceType: String, Sendable, Codable, Hashable {
    case settlement
    case road
}

public struct TurnStartedEvent: Sendable, Codable, Hashable {
    public let playerId: String
    public let turnNumber: Int
    
    public init(playerId: String, turnNumber: Int) {
        self.playerId = playerId
        self.turnNumber = turnNumber
    }
}

public struct DiceRolledEvent: Sendable, Codable, Hashable {
    public let playerId: String
    public let die1: Int
    public let die2: Int
    public let total: Int
    
    public init(playerId: String, die1: Int, die2: Int) {
        self.playerId = playerId
        self.die1 = die1
        self.die2 = die2
        self.total = die1 + die2
    }
}

public struct ResourcesProducedEvent: Sendable, Codable, Hashable {
    public let diceTotal: Int
    public let production: [PlayerProduction]
    
    public init(diceTotal: Int, production: [PlayerProduction]) {
        self.diceTotal = diceTotal
        self.production = production
    }
}

public struct PlayerProduction: Sendable, Codable, Hashable {
    public let playerId: String
    public let resources: ResourceBundle
    public let sources: [ProductionSource]
    
    public init(playerId: String, resources: ResourceBundle, sources: [ProductionSource]) {
        self.playerId = playerId
        self.resources = resources
        self.sources = sources
    }
}

public struct ProductionSource: Sendable, Codable, Hashable {
    public let hexId: Int
    public let nodeId: Int
    public let buildingType: BuildingType
    public let resource: ResourceType
    public let amount: Int
    
    public init(hexId: Int, nodeId: Int, buildingType: BuildingType, resource: ResourceType, amount: Int) {
        self.hexId = hexId
        self.nodeId = nodeId
        self.buildingType = buildingType
        self.resource = resource
        self.amount = amount
    }
}

public enum BuildingType: String, Sendable, Codable, Hashable {
    case settlement
    case city
}

public struct NoResourcesProducedEvent: Sendable, Codable, Hashable {
    public let diceTotal: Int
    public let reason: NoProductionReason
    
    public init(diceTotal: Int, reason: NoProductionReason) {
        self.diceTotal = diceTotal
        self.reason = reason
    }
}

public enum NoProductionReason: String, Sendable, Codable, Hashable {
    case rolledSeven
    case noMatchingBuildings
    case allBlockedByRobber
}

public struct TurnEndedEvent: Sendable, Codable, Hashable {
    public let playerId: String
    public let turnNumber: Int
    
    public init(playerId: String, turnNumber: Int) {
        self.playerId = playerId
        self.turnNumber = turnNumber
    }
}

public struct MustDiscardEvent: Sendable, Codable, Hashable {
    public let playerDiscardRequirements: [PlayerDiscardRequirement]
    
    public init(playerDiscardRequirements: [PlayerDiscardRequirement]) {
        self.playerDiscardRequirements = playerDiscardRequirements
    }
}

public struct PlayerDiscardRequirement: Sendable, Codable, Hashable {
    public let playerId: String
    public let currentCount: Int
    public let mustDiscard: Int
    
    public init(playerId: String, currentCount: Int, mustDiscard: Int) {
        self.playerId = playerId
        self.currentCount = currentCount
        self.mustDiscard = mustDiscard
    }
}

public struct PlayerDiscardedEvent: Sendable, Codable, Hashable {
    public let playerId: String
    public let discarded: ResourceBundle
    
    public init(playerId: String, discarded: ResourceBundle) {
        self.playerId = playerId
        self.discarded = discarded
    }
}

public struct RobberMovedEvent: Sendable, Codable, Hashable {
    public let playerId: String
    public let fromHexId: Int
    public let toHexId: Int
    public let eligibleVictims: [String]
    
    public init(playerId: String, fromHexId: Int, toHexId: Int, eligibleVictims: [String]) {
        self.playerId = playerId
        self.fromHexId = fromHexId
        self.toHexId = toHexId
        self.eligibleVictims = eligibleVictims
    }
}

public struct ResourceStolenEvent: Sendable, Codable, Hashable {
    public let thiefId: String
    public let victimId: String
    /// The stolen resource type (visible to both thief and victim, hidden from others).
    /// Clients should only show this to the involved players.
    public let resourceType: ResourceType
    
    public init(thiefId: String, victimId: String, resourceType: ResourceType) {
        self.thiefId = thiefId
        self.victimId = victimId
        self.resourceType = resourceType
    }
}

public struct RoadBuiltEvent: Sendable, Codable, Hashable {
    public let playerId: String
    public let edgeId: Int
    public let wasFree: Bool
    public let resourcesSpent: ResourceBundle
    
    public init(playerId: String, edgeId: Int, wasFree: Bool, resourcesSpent: ResourceBundle) {
        self.playerId = playerId
        self.edgeId = edgeId
        self.wasFree = wasFree
        self.resourcesSpent = resourcesSpent
    }
}

public struct SettlementBuiltEvent: Sendable, Codable, Hashable {
    public let playerId: String
    public let nodeId: Int
    public let wasFree: Bool
    public let resourcesSpent: ResourceBundle
    
    public init(playerId: String, nodeId: Int, wasFree: Bool, resourcesSpent: ResourceBundle) {
        self.playerId = playerId
        self.nodeId = nodeId
        self.wasFree = wasFree
        self.resourcesSpent = resourcesSpent
    }
}

public struct CityBuiltEvent: Sendable, Codable, Hashable {
    public let playerId: String
    public let nodeId: Int
    public let resourcesSpent: ResourceBundle
    
    public init(playerId: String, nodeId: Int, resourcesSpent: ResourceBundle) {
        self.playerId = playerId
        self.nodeId = nodeId
        self.resourcesSpent = resourcesSpent
    }
}

public struct DevelopmentCardBoughtEvent: Sendable, Codable, Hashable {
    public let playerId: String
    /// The card type is only visible to the buying player until played.
    /// Server sends the real type; clients filter visibility.
    public let cardType: DevelopmentCardType
    public let resourcesSpent: ResourceBundle
    
    public init(playerId: String, cardType: DevelopmentCardType, resourcesSpent: ResourceBundle) {
        self.playerId = playerId
        self.cardType = cardType
        self.resourcesSpent = resourcesSpent
    }
}

public enum DevelopmentCardType: String, Sendable, Codable, Hashable, CaseIterable {
    case knight
    case roadBuilding
    case yearOfPlenty
    case monopoly
    case victoryPoint
}

public struct KnightPlayedEvent: Sendable, Codable, Hashable {
    public let playerId: String
    public let robberFromHexId: Int
    public let robberToHexId: Int
    public let knightsPlayed: Int
    
    public init(playerId: String, robberFromHexId: Int, robberToHexId: Int, knightsPlayed: Int) {
        self.playerId = playerId
        self.robberFromHexId = robberFromHexId
        self.robberToHexId = robberToHexId
        self.knightsPlayed = knightsPlayed
    }
}

public struct RoadBuildingPlayedEvent: Sendable, Codable, Hashable {
    public let playerId: String
    public let firstEdgeId: Int
    public let secondEdgeId: Int?
    
    public init(playerId: String, firstEdgeId: Int, secondEdgeId: Int?) {
        self.playerId = playerId
        self.firstEdgeId = firstEdgeId
        self.secondEdgeId = secondEdgeId
    }
}

public struct YearOfPlentyPlayedEvent: Sendable, Codable, Hashable {
    public let playerId: String
    public let firstResource: ResourceType
    public let secondResource: ResourceType
    
    public init(playerId: String, firstResource: ResourceType, secondResource: ResourceType) {
        self.playerId = playerId
        self.firstResource = firstResource
        self.secondResource = secondResource
    }
}

public struct MonopolyPlayedEvent: Sendable, Codable, Hashable {
    public let playerId: String
    public let resourceType: ResourceType
    public let stolenAmounts: [PlayerResourceStolen]
    public let totalStolen: Int
    
    public init(playerId: String, resourceType: ResourceType, stolenAmounts: [PlayerResourceStolen], totalStolen: Int) {
        self.playerId = playerId
        self.resourceType = resourceType
        self.stolenAmounts = stolenAmounts
        self.totalStolen = totalStolen
    }
}

public struct PlayerResourceStolen: Sendable, Codable, Hashable {
    public let playerId: String
    public let amount: Int
    
    public init(playerId: String, amount: Int) {
        self.playerId = playerId
        self.amount = amount
    }
}

public struct VictoryPointRevealedEvent: Sendable, Codable, Hashable {
    public let playerId: String
    public let cardCount: Int
    
    public init(playerId: String, cardCount: Int) {
        self.playerId = playerId
        self.cardCount = cardCount
    }
}

public struct TradeProposedEvent: Sendable, Codable, Hashable {
    public let tradeId: String
    public let proposerId: String
    public let offering: ResourceBundle
    public let requesting: ResourceBundle
    public let targetPlayerIds: [String]?
    
    public init(tradeId: String, proposerId: String, offering: ResourceBundle, requesting: ResourceBundle, targetPlayerIds: [String]?) {
        self.tradeId = tradeId
        self.proposerId = proposerId
        self.offering = offering
        self.requesting = requesting
        self.targetPlayerIds = targetPlayerIds
    }
}

public struct TradeAcceptedEvent: Sendable, Codable, Hashable {
    public let tradeId: String
    public let accepterId: String
    
    public init(tradeId: String, accepterId: String) {
        self.tradeId = tradeId
        self.accepterId = accepterId
    }
}

public struct TradeRejectedEvent: Sendable, Codable, Hashable {
    public let tradeId: String
    public let rejecterId: String
    
    public init(tradeId: String, rejecterId: String) {
        self.tradeId = tradeId
        self.rejecterId = rejecterId
    }
}

public struct TradeCancelledEvent: Sendable, Codable, Hashable {
    public let tradeId: String
    public let reason: TradeCancelReason
    
    public init(tradeId: String, reason: TradeCancelReason) {
        self.tradeId = tradeId
        self.reason = reason
    }
}

public enum TradeCancelReason: String, Sendable, Codable, Hashable {
    case proposerCancelled
    case turnEnded
    case proposerLacksResources
    case allRejected
}

public struct TradeExecutedEvent: Sendable, Codable, Hashable {
    public let tradeId: String
    public let proposerId: String
    public let accepterId: String
    public let proposerGave: ResourceBundle
    public let accepterGave: ResourceBundle
    
    public init(tradeId: String, proposerId: String, accepterId: String, proposerGave: ResourceBundle, accepterGave: ResourceBundle) {
        self.tradeId = tradeId
        self.proposerId = proposerId
        self.accepterId = accepterId
        self.proposerGave = proposerGave
        self.accepterGave = accepterGave
    }
}

public struct MaritimeTradeExecutedEvent: Sendable, Codable, Hashable {
    public let playerId: String
    public let gave: ResourceType
    public let gaveAmount: Int
    public let received: ResourceType
    public let harborType: HarborType?
    
    public init(playerId: String, gave: ResourceType, gaveAmount: Int, received: ResourceType, harborType: HarborType?) {
        self.playerId = playerId
        self.gave = gave
        self.gaveAmount = gaveAmount
        self.received = received
        self.harborType = harborType
    }
}

public struct LongestRoadAwardedEvent: Sendable, Codable, Hashable {
    public let newHolderId: String?
    public let previousHolderId: String?
    public let roadLength: Int
    
    public init(newHolderId: String?, previousHolderId: String?, roadLength: Int) {
        self.newHolderId = newHolderId
        self.previousHolderId = previousHolderId
        self.roadLength = roadLength
    }
}

public struct LargestArmyAwardedEvent: Sendable, Codable, Hashable {
    public let newHolderId: String?
    public let previousHolderId: String?
    public let knightCount: Int
    
    public init(newHolderId: String?, previousHolderId: String?, knightCount: Int) {
        self.newHolderId = newHolderId
        self.previousHolderId = previousHolderId
        self.knightCount = knightCount
    }
}

public struct PlayerWonEvent: Sendable, Codable, Hashable {
    public let playerId: String
    public let victoryPoints: Int
    public let breakdown: VictoryPointBreakdown
    
    public init(playerId: String, victoryPoints: Int, breakdown: VictoryPointBreakdown) {
        self.playerId = playerId
        self.victoryPoints = victoryPoints
        self.breakdown = breakdown
    }
}

public struct VictoryPointBreakdown: Sendable, Codable, Hashable {
    public let settlements: Int
    public let cities: Int
    public let longestRoad: Int
    public let largestArmy: Int
    public let victoryPointCards: Int
    
    public init(settlements: Int, cities: Int, longestRoad: Int, largestArmy: Int, victoryPointCards: Int) {
        self.settlements = settlements
        self.cities = cities
        self.longestRoad = longestRoad
        self.largestArmy = largestArmy
        self.victoryPointCards = victoryPointCards
    }
    
    public var total: Int {
        settlements + (cities * 2) + longestRoad + largestArmy + victoryPointCards
    }
}

// MARK: - 5-6 Player Extension Events

public struct PairedTurnStartedEvent: Sendable, Codable, Hashable {
    public let player1Id: String
    public let player2Id: String
    public let turnNumber: Int
    
    public init(player1Id: String, player2Id: String, turnNumber: Int) {
        self.player1Id = player1Id
        self.player2Id = player2Id
        self.turnNumber = turnNumber
    }
}

public struct PairedMarkerPassedEvent: Sendable, Codable, Hashable {
    public let fromPlayerId: String
    public let toPlayerId: String
    
    public init(fromPlayerId: String, toPlayerId: String) {
        self.fromPlayerId = fromPlayerId
        self.toPlayerId = toPlayerId
    }
}

public struct SupplyTradeExecutedEvent: Sendable, Codable, Hashable {
    public let playerId: String
    public let gave: ResourceType
    public let received: ResourceType
    
    public init(playerId: String, gave: ResourceType, received: ResourceType) {
        self.playerId = playerId
        self.gave = gave
        self.received = received
    }
}

// MARK: - Game Snapshot

public struct GameSnapshot: Sendable, Codable, Hashable {
    public let gameId: String
    public let eventIndex: Int
    public let snapshotData: Data
    
    public init(gameId: String, eventIndex: Int, snapshotData: Data) {
        self.gameId = gameId
        self.eventIndex = eventIndex
        self.snapshotData = snapshotData
    }
}

// MARK: - Intent Rejected

public struct IntentRejectedResponse: Sendable, Codable, Hashable {
    public let requestId: String
    public let violations: [RuleViolation]
    
    public init(requestId: String, violations: [RuleViolation]) {
        self.requestId = requestId
        self.violations = violations
    }
}

public struct RuleViolation: Sendable, Codable, Hashable {
    public let code: RuleViolationCode
    public let message: String
    
    public init(code: RuleViolationCode, message: String) {
        self.code = code
        self.message = message
    }
}

public enum RuleViolationCode: String, Sendable, Codable, Hashable {
    // Turn violations
    case notYourTurn
    case mustRollFirst
    case alreadyRolled
    case mustMoveRobber
    case mustDiscardFirst
    case mustStealFirst
    
    // Building violations
    case insufficientResources
    case noSupplyRemaining
    case invalidLocation
    case violatesDistanceRule
    case noAdjacentRoad
    case noSettlementToUpgrade
    case locationOccupied
    
    // Trading violations
    case cannotTradeWithSelf
    case inactivePlayerCannotTrade
    case invalidTradeRatio
    case noSuchTradeProposal
    case tradeAlreadyAccepted
    case notTargetOfTrade
    
    // Dev card violations
    case noDevCardToPlay
    case cannotPlayCardBoughtThisTurn
    case alreadyPlayedDevCard
    case invalidDevCardType
    
    // Robber violations
    case mustMoveRobberToNewHex
    case noEligibleVictim
    case victimHasNoResources
    
    // General
    case gameNotStarted
    case gameAlreadyEnded
    case invalidAction
}

// MARK: - Game Ended

public struct GameEndedEvent: Sendable, Codable, Hashable {
    public let gameId: String
    public let winnerId: String
    public let reason: GameEndReason
    public let finalStandings: [FinalStanding]
    
    public init(gameId: String, winnerId: String, reason: GameEndReason, finalStandings: [FinalStanding]) {
        self.gameId = gameId
        self.winnerId = winnerId
        self.reason = reason
        self.finalStandings = finalStandings
    }
}

public enum GameEndReason: String, Sendable, Codable, Hashable {
    case victoryPointsReached
    case allOthersDisconnected
    case hostEnded
}

public struct FinalStanding: Sendable, Codable, Hashable {
    public let playerId: String
    public let rank: Int
    public let victoryPoints: Int
    
    public init(playerId: String, rank: Int, victoryPoints: Int) {
        self.playerId = playerId
        self.rank = rank
        self.victoryPoints = victoryPoints
    }
}

// MARK: - Session State

/// Current session state returned on login to allow resume prompts.
public struct SessionState: Sendable, Codable, Hashable {
    /// Active waiting lobby the user is in (if any).
    public let activeLobby: LobbyState?
    
    /// Active game the user is in (if any).
    public let activeGame: ActiveGameSummary?
    
    public init(activeLobby: LobbyState?, activeGame: ActiveGameSummary?) {
        self.activeLobby = activeLobby
        self.activeGame = activeGame
    }
    
    /// Whether the user has any active session to resume.
    public var hasActiveSession: Bool {
        activeLobby != nil || activeGame != nil
    }
}

/// Summary of an active game for resume prompts.
public struct ActiveGameSummary: Sendable, Codable, Hashable {
    public let gameId: String
    public let playerMode: PlayerMode
    public let playerCount: Int
    public let playerNames: [String]
    public let lastEventIndex: Int
    
    public init(gameId: String, playerMode: PlayerMode, playerCount: Int, playerNames: [String], lastEventIndex: Int) {
        self.gameId = gameId
        self.playerMode = playerMode
        self.playerCount = playerCount
        self.playerNames = playerNames
        self.lastEventIndex = lastEventIndex
    }
}

// MARK: - Server Shutdown

public struct ServerShutdownNotice: Sendable, Codable, Hashable {
    public let reason: String
    public let reconnectAfterSeconds: Int?
    
    public init(reason: String, reconnectAfterSeconds: Int? = nil) {
        self.reason = reason
        self.reconnectAfterSeconds = reconnectAfterSeconds
    }
}

