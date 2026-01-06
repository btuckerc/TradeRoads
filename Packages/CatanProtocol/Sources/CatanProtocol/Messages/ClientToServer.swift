// MARK: - Client to Server Messages

import Foundation

/// All messages that a client can send to the server.
public enum ClientMessage: Sendable, Codable, Hashable {
    // MARK: - Authentication
    
    /// Authenticate with the server using dev auth.
    case authenticate(AuthenticateRequest)
    
    // MARK: - Lobby
    
    /// Create a new game lobby.
    case createLobby(CreateLobbyRequest)
    
    /// Join an existing lobby by code.
    case joinLobby(JoinLobbyRequest)
    
    /// Leave the current lobby.
    case leaveLobby
    
    /// Select a player color in the lobby.
    case selectColor(SelectColorRequest)
    
    /// Mark self as ready to start.
    case setReady(SetReadyRequest)
    
    /// Start the game (host only).
    case startGame
    
    // MARK: - Game Intents
    
    /// Roll the dice (active player only).
    case rollDice
    
    /// Discard resources when having more than 7 on a 7 roll.
    case discardResources(DiscardResourcesIntent)
    
    /// Move the robber to a new hex.
    case moveRobber(MoveRobberIntent)
    
    /// Steal a resource from an adjacent player after moving robber.
    case stealResource(StealResourceIntent)
    
    /// Build a road at an edge.
    case buildRoad(BuildRoadIntent)
    
    /// Build a settlement at a node.
    case buildSettlement(BuildSettlementIntent)
    
    /// Upgrade a settlement to a city.
    case buildCity(BuildCityIntent)
    
    /// Buy a development card.
    case buyDevelopmentCard
    
    /// Play a Knight card.
    case playKnight(PlayKnightIntent)
    
    /// Play Road Building card (activates road building mode).
    case playRoadBuilding
    
    /// Place a road from Road Building card (after playRoadBuilding).
    case placeRoadBuildingRoad(PlaceRoadBuildingRoadIntent)
    
    /// Play Year of Plenty card.
    case playYearOfPlenty(PlayYearOfPlentyIntent)
    
    /// Play Monopoly card.
    case playMonopoly(PlayMonopolyIntent)
    
    /// Propose a domestic trade to other players.
    case proposeTrade(ProposeTradeIntent)
    
    /// Accept a trade proposal.
    case acceptTrade(AcceptTradeIntent)
    
    /// Reject a trade proposal.
    case rejectTrade(RejectTradeIntent)
    
    /// Cancel own trade proposal.
    case cancelTrade(CancelTradeIntent)
    
    /// Execute a maritime (port) trade.
    case maritimeTrade(MaritimeTradeIntent)
    
    /// End the current turn.
    case endTurn
    
    // MARK: - 5-6 Player Extension
    
    /// Pass the paired player marker (5-6 player rules).
    case passPairedMarker
    
    /// Perform supply-only trade (player 2 in paired turn).
    case supplyTrade(SupplyTradeIntent)
    
    // MARK: - Reconnection
    
    /// Reconnect to an ongoing game.
    case reconnect(ReconnectRequest)
    
    // MARK: - Session State
    
    /// Request current session state (active lobby/game) for resume prompt.
    case getSessionState
    
    // MARK: - Misc
    
    /// Ping to keep connection alive.
    case ping
}

// MARK: - Request/Intent Payloads

public struct AuthenticateRequest: Sendable, Codable, Hashable {
    /// Username or email-like identifier.
    public let identifier: String
    
    /// Session token (if reconnecting with existing session).
    public let sessionToken: String?
    
    /// One-time code for initial auth (printed to server logs in dev mode).
    public let oneTimeCode: String?
    
    public init(identifier: String, sessionToken: String? = nil, oneTimeCode: String? = nil) {
        self.identifier = identifier
        self.sessionToken = sessionToken
        self.oneTimeCode = oneTimeCode
    }
}

public struct CreateLobbyRequest: Sendable, Codable, Hashable {
    /// Display name for the lobby.
    public let lobbyName: String
    
    /// Game mode: 3-4 players or 5-6 players.
    public let playerMode: PlayerMode
    
    /// Whether to use the beginner fixed layout.
    public let useBeginnerLayout: Bool
    
    public init(lobbyName: String, playerMode: PlayerMode, useBeginnerLayout: Bool = false) {
        self.lobbyName = lobbyName
        self.playerMode = playerMode
        self.useBeginnerLayout = useBeginnerLayout
    }
}

public enum PlayerMode: String, Sendable, Codable, Hashable, CaseIterable {
    case threeToFour = "3-4"
    case fiveToSix = "5-6"
    
    public var minPlayers: Int {
        switch self {
        case .threeToFour: return 3
        case .fiveToSix: return 5
        }
    }
    
    public var maxPlayers: Int {
        switch self {
        case .threeToFour: return 4
        case .fiveToSix: return 6
        }
    }
}

public struct JoinLobbyRequest: Sendable, Codable, Hashable {
    /// The lobby code to join.
    public let lobbyCode: String
    
    public init(lobbyCode: String) {
        self.lobbyCode = lobbyCode
    }
}

public struct SelectColorRequest: Sendable, Codable, Hashable {
    /// The color the player wants.
    public let color: PlayerColor
    
    public init(color: PlayerColor) {
        self.color = color
    }
}

public enum PlayerColor: String, Sendable, Codable, Hashable, CaseIterable {
    case red
    case blue
    case white
    case orange
    case green
    case brown
    
    /// Colors available in 3-4 player mode.
    public static let baseModeColors: [PlayerColor] = [.red, .blue, .white, .orange]
    
    /// All colors including 5-6 expansion.
    public static let extendedColors: [PlayerColor] = [.red, .blue, .white, .orange, .green, .brown]
}

public struct SetReadyRequest: Sendable, Codable, Hashable {
    public let ready: Bool
    
    public init(ready: Bool) {
        self.ready = ready
    }
}

// MARK: - Game Intent Payloads

public struct DiscardResourcesIntent: Sendable, Codable, Hashable {
    /// Resources to discard (must be exactly half, rounded down).
    public let resources: ResourceBundle
    
    public init(resources: ResourceBundle) {
        self.resources = resources
    }
}

public struct MoveRobberIntent: Sendable, Codable, Hashable {
    /// The hex ID to move the robber to.
    public let hexId: Int
    
    public init(hexId: Int) {
        self.hexId = hexId
    }
}

public struct StealResourceIntent: Sendable, Codable, Hashable {
    /// The player to steal from.
    public let targetPlayerId: String
    
    public init(targetPlayerId: String) {
        self.targetPlayerId = targetPlayerId
    }
}

public struct BuildRoadIntent: Sendable, Codable, Hashable {
    /// The edge ID where to build the road.
    public let edgeId: Int
    
    /// Whether this is a free road (setup phase or Road Building card).
    public let isFree: Bool
    
    public init(edgeId: Int, isFree: Bool = false) {
        self.edgeId = edgeId
        self.isFree = isFree
    }
}

public struct BuildSettlementIntent: Sendable, Codable, Hashable {
    /// The node ID where to build the settlement.
    public let nodeId: Int
    
    /// Whether this is a free settlement (setup phase).
    public let isFree: Bool
    
    public init(nodeId: Int, isFree: Bool = false) {
        self.nodeId = nodeId
        self.isFree = isFree
    }
}

public struct BuildCityIntent: Sendable, Codable, Hashable {
    /// The node ID where to upgrade settlement to city.
    public let nodeId: Int
    
    public init(nodeId: Int) {
        self.nodeId = nodeId
    }
}

public struct PlayKnightIntent: Sendable, Codable, Hashable {
    /// The hex to move the robber to.
    public let moveRobberTo: Int
    
    /// The player to steal from (optional if no adjacent players).
    public let stealFrom: String?
    
    public init(moveRobberTo: Int, stealFrom: String? = nil) {
        self.moveRobberTo = moveRobberTo
        self.stealFrom = stealFrom
    }
}

/// Intent to place a road from the Road Building development card.
public struct PlaceRoadBuildingRoadIntent: Sendable, Codable, Hashable {
    /// The edge ID where to place the road.
    public let edgeId: Int
    
    public init(edgeId: Int) {
        self.edgeId = edgeId
    }
}

public struct PlayYearOfPlentyIntent: Sendable, Codable, Hashable {
    /// First resource to take from bank.
    public let firstResource: ResourceType
    
    /// Second resource to take from bank.
    public let secondResource: ResourceType
    
    public init(firstResource: ResourceType, secondResource: ResourceType) {
        self.firstResource = firstResource
        self.secondResource = secondResource
    }
}

public struct PlayMonopolyIntent: Sendable, Codable, Hashable {
    /// The resource type to monopolize.
    public let resourceType: ResourceType
    
    public init(resourceType: ResourceType) {
        self.resourceType = resourceType
    }
}

public struct ProposeTradeIntent: Sendable, Codable, Hashable {
    /// Unique trade proposal ID.
    public let tradeId: String
    
    /// What the proposer is offering.
    public let offering: ResourceBundle
    
    /// What the proposer wants in return.
    public let requesting: ResourceBundle
    
    /// Specific players to offer to (nil = open to all).
    public let targetPlayerIds: [String]?
    
    public init(tradeId: String, offering: ResourceBundle, requesting: ResourceBundle, targetPlayerIds: [String]? = nil) {
        self.tradeId = tradeId
        self.offering = offering
        self.requesting = requesting
        self.targetPlayerIds = targetPlayerIds
    }
}

public struct AcceptTradeIntent: Sendable, Codable, Hashable {
    /// The trade proposal ID to accept.
    public let tradeId: String
    
    public init(tradeId: String) {
        self.tradeId = tradeId
    }
}

public struct RejectTradeIntent: Sendable, Codable, Hashable {
    /// The trade proposal ID to reject.
    public let tradeId: String
    
    public init(tradeId: String) {
        self.tradeId = tradeId
    }
}

public struct CancelTradeIntent: Sendable, Codable, Hashable {
    /// The trade proposal ID to cancel.
    public let tradeId: String
    
    public init(tradeId: String) {
        self.tradeId = tradeId
    }
}

public struct MaritimeTradeIntent: Sendable, Codable, Hashable {
    /// Resource type to give.
    public let giving: ResourceType
    
    /// How many of that resource to give.
    public let givingAmount: Int
    
    /// Resource type to receive.
    public let receiving: ResourceType
    
    public init(giving: ResourceType, givingAmount: Int, receiving: ResourceType) {
        self.giving = giving
        self.givingAmount = givingAmount
        self.receiving = receiving
    }
}

public struct SupplyTradeIntent: Sendable, Codable, Hashable {
    /// Resource type to give to the supply.
    public let giving: ResourceType
    
    /// Resource type to take from the supply.
    public let receiving: ResourceType
    
    public init(giving: ResourceType, receiving: ResourceType) {
        self.giving = giving
        self.receiving = receiving
    }
}

public struct ReconnectRequest: Sendable, Codable, Hashable {
    /// The game ID to reconnect to.
    public let gameId: String
    
    /// The last event index the client has.
    public let lastSeenEventIndex: Int
    
    public init(gameId: String, lastSeenEventIndex: Int) {
        self.gameId = gameId
        self.lastSeenEventIndex = lastSeenEventIndex
    }
}

// MARK: - Shared Types

public enum ResourceType: String, Sendable, Codable, Hashable, CaseIterable {
    case brick
    case lumber
    case ore
    case grain
    case wool
}

/// A bundle of resources (counts can be zero but not negative).
public struct ResourceBundle: Sendable, Codable, Hashable {
    public var brick: Int
    public var lumber: Int
    public var ore: Int
    public var grain: Int
    public var wool: Int
    
    public init(brick: Int = 0, lumber: Int = 0, ore: Int = 0, grain: Int = 0, wool: Int = 0) {
        self.brick = max(0, brick)
        self.lumber = max(0, lumber)
        self.ore = max(0, ore)
        self.grain = max(0, grain)
        self.wool = max(0, wool)
    }
    
    public var total: Int {
        brick + lumber + ore + grain + wool
    }
    
    public var isEmpty: Bool {
        total == 0
    }
    
    public subscript(type: ResourceType) -> Int {
        get {
            switch type {
            case .brick: return brick
            case .lumber: return lumber
            case .ore: return ore
            case .grain: return grain
            case .wool: return wool
            }
        }
        set {
            switch type {
            case .brick: brick = max(0, newValue)
            case .lumber: lumber = max(0, newValue)
            case .ore: ore = max(0, newValue)
            case .grain: grain = max(0, newValue)
            case .wool: wool = max(0, newValue)
            }
        }
    }
    
    public static let zero = ResourceBundle()
    
    /// Road cost: 1 brick + 1 lumber.
    public static let roadCost = ResourceBundle(brick: 1, lumber: 1)
    
    /// Settlement cost: 1 brick + 1 lumber + 1 grain + 1 wool.
    public static let settlementCost = ResourceBundle(brick: 1, lumber: 1, grain: 1, wool: 1)
    
    /// City cost: 2 grain + 3 ore.
    public static let cityCost = ResourceBundle(ore: 3, grain: 2)
    
    /// Development card cost: 1 ore + 1 grain + 1 wool.
    public static let developmentCardCost = ResourceBundle(ore: 1, grain: 1, wool: 1)
    
    public static func + (lhs: ResourceBundle, rhs: ResourceBundle) -> ResourceBundle {
        ResourceBundle(
            brick: lhs.brick + rhs.brick,
            lumber: lhs.lumber + rhs.lumber,
            ore: lhs.ore + rhs.ore,
            grain: lhs.grain + rhs.grain,
            wool: lhs.wool + rhs.wool
        )
    }
    
    public static func - (lhs: ResourceBundle, rhs: ResourceBundle) -> ResourceBundle {
        ResourceBundle(
            brick: lhs.brick - rhs.brick,
            lumber: lhs.lumber - rhs.lumber,
            ore: lhs.ore - rhs.ore,
            grain: lhs.grain - rhs.grain,
            wool: lhs.wool - rhs.wool
        )
    }
    
    /// Check if this bundle contains at least the resources in `other`.
    public func contains(_ other: ResourceBundle) -> Bool {
        brick >= other.brick &&
        lumber >= other.lumber &&
        ore >= other.ore &&
        grain >= other.grain &&
        wool >= other.wool
    }
}

