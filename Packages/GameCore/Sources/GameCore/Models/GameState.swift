// MARK: - Complete Game State

import Foundation
import CatanProtocol

/// Configuration for a game.
public struct GameConfig: Sendable, Hashable, Codable {
    public let gameId: String
    public let playerMode: PlayerMode
    public let useBeginnerLayout: Bool
    public let useCombinedTradeBuild: Bool  // "experienced" rules
    
    public init(
        gameId: String,
        playerMode: PlayerMode,
        useBeginnerLayout: Bool = false,
        useCombinedTradeBuild: Bool = true
    ) {
        self.gameId = gameId
        self.playerMode = playerMode
        self.useBeginnerLayout = useBeginnerLayout
        self.useCombinedTradeBuild = useCombinedTradeBuild
    }
}

/// The complete, immutable game state.
public struct GameState: Sendable, Codable {
    // Configuration
    public let config: GameConfig
    
    // Board
    public let board: Board
    
    // Players (ordered by turn order)
    public var players: [Player]
    
    // Bank
    public var bank: Bank
    
    // Building placements
    public var buildings: BuildingState
    
    // Robber position (hex ID)
    public var robberHexId: Int
    
    // Awards
    public var awards: Awards
    
    // Turn state
    public var turn: TurnState
    
    // Event index for replay
    public var eventIndex: Int
    
    // Winner (set when game ends)
    public var winnerId: String?
    
    public init(
        config: GameConfig,
        board: Board,
        players: [Player],
        bank: Bank,
        buildings: BuildingState = BuildingState(),
        robberHexId: Int,
        awards: Awards = Awards(),
        turn: TurnState,
        eventIndex: Int = 0,
        winnerId: String? = nil
    ) {
        self.config = config
        self.board = board
        self.players = players
        self.bank = bank
        self.buildings = buildings
        self.robberHexId = robberHexId
        self.awards = awards
        self.turn = turn
        self.eventIndex = eventIndex
        self.winnerId = winnerId
    }
    
    // MARK: - Player Lookup
    
    /// Get a player by ID.
    public func player(id: String) -> Player? {
        players.first { $0.id == id }
    }
    
    /// Get the index of a player.
    public func playerIndex(id: String) -> Int? {
        players.firstIndex { $0.id == id }
    }
    
    /// Get the active player.
    public var activePlayer: Player? {
        player(id: turn.activePlayerId)
    }
    
    /// Get players in turn order.
    public var playersInTurnOrder: [Player] {
        players.sorted { $0.turnOrder < $1.turnOrder }
    }
    
    /// Update a player by ID.
    public func updatingPlayer(id: String, transform: (Player) -> Player) -> GameState {
        var copy = self
        if let idx = playerIndex(id: id) {
            copy.players[idx] = transform(copy.players[idx])
        }
        return copy
    }
    
    // MARK: - Victory Point Calculation
    
    /// Calculate victory points for a player.
    /// Note: VictoryPointBreakdown stores counts (not VP values) for settlements/cities.
    /// The total property computes VP: settlements*1 + cities*2 + awards + VP cards.
    public func victoryPoints(for playerId: String) -> VictoryPointBreakdown {
        guard let player = player(id: playerId) else {
            return VictoryPointBreakdown(settlements: 0, cities: 0, longestRoad: 0, largestArmy: 0, victoryPointCards: 0)
        }
        
        let settlements = player.settlements.count  // Each worth 1 VP
        let cities = player.cities.count  // Each worth 2 VP (calculated in total)
        let longestRoad = awards.longestRoadHolder == playerId ? 2 : 0
        let largestArmy = awards.largestArmyHolder == playerId ? 2 : 0
        let vpCards = player.victoryPointCards
        
        return VictoryPointBreakdown(
            settlements: settlements,
            cities: cities,
            longestRoad: longestRoad,
            largestArmy: largestArmy,
            victoryPointCards: vpCards
        )
    }
    
    /// Total victory points for a player.
    public func totalVictoryPoints(for playerId: String) -> Int {
        victoryPoints(for: playerId).total
    }
    
    /// Check if a player has won.
    public func hasWon(_ playerId: String) -> Bool {
        totalVictoryPoints(for: playerId) >= GameConstants.victoryPointsToWin
    }
    
    // MARK: - Harbor Access
    
    /// Get the best trade ratio for a player for a resource type.
    public func tradeRatio(for playerId: String, resource: ResourceType) -> Int {
        guard let player = player(id: playerId) else { return 4 }
        
        var bestRatio = 4  // Default 4:1
        
        // Check all nodes the player has buildings on
        let buildingNodes = player.settlements.union(player.cities)
        for nodeId in buildingNodes {
            if let harbor = board.harbor(forNode: nodeId) {
                switch harbor.type {
                case .generic:
                    bestRatio = min(bestRatio, 3)
                case .specific(let harborResource):
                    if harborResource == resource {
                        bestRatio = min(bestRatio, 2)
                    }
                }
            }
        }
        
        return bestRatio
    }
    
    // MARK: - State Transitions
    
    /// Increment event index.
    public func incrementingEventIndex() -> GameState {
        var copy = self
        copy.eventIndex += 1
        return copy
    }
}

