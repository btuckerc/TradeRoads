// MARK: - Turn and Phase State

import Foundation
import CatanProtocol

/// The current phase of the game.
public enum GamePhase: String, Sendable, Codable, Hashable {
    /// Initial setup phase (place starting settlements/roads).
    case setup
    /// Waiting for dice roll at start of turn.
    case preRoll
    /// After rolling 7, some players must discard.
    case discarding
    /// After rolling 7, active player must move robber.
    case movingRobber
    /// After moving robber, active player may steal.
    case stealing
    /// Main phase: trade and build.
    case main
    /// Game has ended.
    case ended
}

/// Tracks the current turn state.
public struct TurnState: Sendable, Hashable, Codable {
    /// Current game phase.
    public var phase: GamePhase
    
    /// The player whose turn it is (by player ID).
    public var activePlayerId: String
    
    /// Current turn number (1-indexed).
    public var turnNumber: Int
    
    /// The last dice roll result (nil if not rolled this turn).
    public var lastRoll: DiceRoll?
    
    /// Players who still need to discard (on a 7).
    public var playersToDiscard: Set<String>
    
    /// Eligible victims for stealing after moving robber.
    public var stealCandidates: [String]
    
    /// Active trade proposals.
    public var activeTrades: [TradeProposal]
    
    /// Development card play state for Road Building.
    public var roadBuildingRoadsRemaining: Int
    
    // Setup phase tracking
    public var setupRound: Int  // 1 or 2
    public var setupPlayerIndex: Int
    public var setupForward: Bool  // true = going forward, false = going backward
    public var setupNeedsRoad: Bool  // waiting for road after settlement
    
    // 5-6 player paired turn state
    public var isPairedTurn: Bool
    public var pairedPlayer1Id: String?
    public var pairedPlayer2Id: String?
    public var pairedMarkerWith: String?  // who currently has the marker
    
    public init(
        phase: GamePhase = .setup,
        activePlayerId: String,
        turnNumber: Int = 0,
        lastRoll: DiceRoll? = nil,
        playersToDiscard: Set<String> = [],
        stealCandidates: [String] = [],
        activeTrades: [TradeProposal] = [],
        roadBuildingRoadsRemaining: Int = 0,
        setupRound: Int = 1,
        setupPlayerIndex: Int = 0,
        setupForward: Bool = true,
        setupNeedsRoad: Bool = false,
        isPairedTurn: Bool = false,
        pairedPlayer1Id: String? = nil,
        pairedPlayer2Id: String? = nil,
        pairedMarkerWith: String? = nil
    ) {
        self.phase = phase
        self.activePlayerId = activePlayerId
        self.turnNumber = turnNumber
        self.lastRoll = lastRoll
        self.playersToDiscard = playersToDiscard
        self.stealCandidates = stealCandidates
        self.activeTrades = activeTrades
        self.roadBuildingRoadsRemaining = roadBuildingRoadsRemaining
        self.setupRound = setupRound
        self.setupPlayerIndex = setupPlayerIndex
        self.setupForward = setupForward
        self.setupNeedsRoad = setupNeedsRoad
        self.isPairedTurn = isPairedTurn
        self.pairedPlayer1Id = pairedPlayer1Id
        self.pairedPlayer2Id = pairedPlayer2Id
        self.pairedMarkerWith = pairedMarkerWith
    }
    
    /// Check if it's a specific player's turn.
    public func isActivePlayer(_ playerId: String) -> Bool {
        activePlayerId == playerId
    }
    
    /// Check if player can act (either active player or paired player 2 in some cases).
    public func canAct(_ playerId: String) -> Bool {
        if activePlayerId == playerId { return true }
        if isPairedTurn && pairedPlayer2Id == playerId && pairedMarkerWith == playerId {
            return true
        }
        return false
    }
}

/// A domestic trade proposal.
public struct TradeProposal: Sendable, Hashable, Codable {
    public let id: String
    public let proposerId: String
    public let offering: ResourceBundle
    public let requesting: ResourceBundle
    public let targetPlayerIds: [String]?  // nil = open to all
    public var acceptedBy: Set<String>
    public var rejectedBy: Set<String>
    
    public init(
        id: String,
        proposerId: String,
        offering: ResourceBundle,
        requesting: ResourceBundle,
        targetPlayerIds: [String]?,
        acceptedBy: Set<String> = [],
        rejectedBy: Set<String> = []
    ) {
        self.id = id
        self.proposerId = proposerId
        self.offering = offering
        self.requesting = requesting
        self.targetPlayerIds = targetPlayerIds
        self.acceptedBy = acceptedBy
        self.rejectedBy = rejectedBy
    }
    
    /// Check if a player can respond to this trade.
    public func canRespond(_ playerId: String) -> Bool {
        guard playerId != proposerId else { return false }
        guard !acceptedBy.contains(playerId) && !rejectedBy.contains(playerId) else { return false }
        if let targets = targetPlayerIds {
            return targets.contains(playerId)
        }
        return true
    }
}

