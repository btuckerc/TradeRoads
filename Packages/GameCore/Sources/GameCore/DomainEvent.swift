// MARK: - Domain Events

import Foundation
import CatanProtocol

/// Domain events represent facts about what happened in the game.
/// These are used for event sourcing - the game state can be reconstructed
/// by replaying events from the beginning.
public enum DomainEvent: Sendable, Codable, Hashable {
    // MARK: - Game Lifecycle
    
    case gameCreated(GameCreatedEvent)
    case gameStarted(gameId: String)
    
    // MARK: - Setup Phase
    
    case setupPhaseStarted(firstPlayerId: String)
    case setupSettlementPlaced(playerId: String, nodeId: Int, round: Int)
    case setupRoadPlaced(playerId: String, edgeId: Int, round: Int)
    case setupResourcesGiven(playerId: String, resources: ResourceBundle)
    case setupTurnAdvanced(nextPlayerId: String, setupRound: Int, setupPlayerIndex: Int, setupForward: Bool)
    case setupPhaseEnded
    
    // MARK: - Turn Flow
    
    case turnStarted(playerId: String, turnNumber: Int)
    case diceRolled(playerId: String, die1: Int, die2: Int)
    case resourcesProduced(productions: [PlayerResourceProduction])
    case noResourcesProduced(diceTotal: Int, reason: NoProductionReason)
    case turnEnded(playerId: String, turnNumber: Int)
    
    // MARK: - Robber (on 7 or Knight)
    
    case discardRequired(requirements: [DiscardRequirement])
    case resourcesDiscarded(playerId: String, resources: ResourceBundle)
    case robberMoved(playerId: String, fromHexId: Int, toHexId: Int, eligibleVictims: [String])
    case resourceStolen(thiefId: String, victimId: String, resource: ResourceType)
    case noStealPossible(reason: String)
    
    // MARK: - Building
    
    case roadBuilt(playerId: String, edgeId: Int, cost: ResourceBundle)
    case settlementBuilt(playerId: String, nodeId: Int, cost: ResourceBundle)
    case cityBuilt(playerId: String, nodeId: Int, cost: ResourceBundle)
    
    // MARK: - Development Cards
    
    case developmentCardBought(playerId: String, cardId: String, cardType: DevelopmentCardType, cost: ResourceBundle)
    case knightPlayed(playerId: String, cardId: String, movedRobberTo: Int)
    case roadBuildingPlayed(playerId: String, cardId: String)
    case roadBuildingRoadPlaced(playerId: String, edgeId: Int, roadsRemaining: Int)
    case yearOfPlentyPlayed(playerId: String, cardId: String, resource1: ResourceType, resource2: ResourceType)
    case monopolyPlayed(playerId: String, cardId: String, resource: ResourceType, stolenAmounts: [String: Int])
    case victoryPointRevealed(playerId: String, cardCount: Int)
    
    // MARK: - Trading
    
    case tradeProposed(proposal: TradeProposal)
    case tradeAccepted(tradeId: String, accepterId: String)
    case tradeRejected(tradeId: String, rejecterId: String)
    case tradeCancelled(tradeId: String, reason: TradeCancelReason)
    case tradeExecuted(tradeId: String, proposerId: String, accepterId: String, proposerGave: ResourceBundle, accepterGave: ResourceBundle)
    case maritimeTradeExecuted(playerId: String, gave: ResourceType, gaveAmount: Int, received: ResourceType)
    
    // MARK: - Awards
    
    case longestRoadAwarded(newHolderId: String?, previousHolderId: String?, roadLength: Int)
    case largestArmyAwarded(newHolderId: String?, previousHolderId: String?, knightCount: Int)
    
    // MARK: - Victory
    
    case playerWon(playerId: String, victoryPoints: Int, breakdown: VictoryPointBreakdown)
    
    // MARK: - 5-6 Player Extension
    
    case pairedTurnStarted(player1Id: String, player2Id: String, turnNumber: Int)
    case pairedMarkerPassed(fromPlayerId: String, toPlayerId: String)
    case supplyTradeExecuted(playerId: String, gave: ResourceType, received: ResourceType)
}

// MARK: - Event Payloads

public struct GameCreatedEvent: Sendable, Codable, Hashable {
    public let gameId: String
    public let config: GameConfig
    public let playerIds: [String]
    public let boardSeed: UInt64
    
    public init(gameId: String, config: GameConfig, playerIds: [String], boardSeed: UInt64) {
        self.gameId = gameId
        self.config = config
        self.playerIds = playerIds
        self.boardSeed = boardSeed
    }
}

public struct PlayerResourceProduction: Sendable, Codable, Hashable {
    public let playerId: String
    public let resources: ResourceBundle
    public let sources: [ProductionDetail]
    
    public init(playerId: String, resources: ResourceBundle, sources: [ProductionDetail]) {
        self.playerId = playerId
        self.resources = resources
        self.sources = sources
    }
}

public struct ProductionDetail: Sendable, Codable, Hashable {
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

public struct DiscardRequirement: Sendable, Codable, Hashable {
    public let playerId: String
    public let currentCount: Int
    public let mustDiscard: Int
    
    public init(playerId: String, currentCount: Int, mustDiscard: Int) {
        self.playerId = playerId
        self.currentCount = currentCount
        self.mustDiscard = mustDiscard
    }
}

// MARK: - Event Application

extension GameState {
    /// Apply a domain event to produce a new state.
    /// This is the event-sourcing replay mechanism.
    public func applying(_ event: DomainEvent) -> GameState {
        var state = self
        
        switch event {
        case .gameCreated, .gameStarted:
            // These events create the initial state, handled elsewhere
            break
            
        case .setupPhaseStarted(let firstPlayerId):
            state.turn.phase = .setup
            state.turn.activePlayerId = firstPlayerId
            state.turn.setupRound = 1
            state.turn.setupPlayerIndex = 0
            state.turn.setupForward = true
            state.turn.setupNeedsRoad = false
            
        case .setupSettlementPlaced(let playerId, let nodeId, _):
            state.buildings = state.buildings.placingSettlement(at: nodeId, playerId: playerId)
            state = state.updatingPlayer(id: playerId) { $0.adding(settlement: nodeId) }
            state.turn.setupNeedsRoad = true
            
        case .setupRoadPlaced(let playerId, let edgeId, _):
            state.buildings = state.buildings.placingRoad(at: edgeId, playerId: playerId)
            state = state.updatingPlayer(id: playerId) { $0.adding(road: edgeId) }
            state.turn.setupNeedsRoad = false
            
        case .setupResourcesGiven(let playerId, let resources):
            state = state.updatingPlayer(id: playerId) { $0.adding(resources: resources) }
            state.bank = state.bank.returning(ResourceBundle.zero - resources)  // Take from bank (conceptually)
            
        case .setupTurnAdvanced(let nextPlayerId, let setupRound, let setupPlayerIndex, let setupForward):
            state.turn.activePlayerId = nextPlayerId
            state.turn.setupRound = setupRound
            state.turn.setupPlayerIndex = setupPlayerIndex
            state.turn.setupForward = setupForward
            state.turn.setupNeedsRoad = false
            
        case .setupPhaseEnded:
            state.turn.phase = .preRoll
            state.turn.turnNumber = 1
            
        case .turnStarted(let playerId, let turnNumber):
            state.turn.activePlayerId = playerId
            state.turn.turnNumber = turnNumber
            state.turn.phase = .preRoll
            state.turn.lastRoll = nil
            state.turn.activeTrades = []
            state = state.updatingPlayer(id: playerId) { $0.resettingTurnFlags() }
            
        case .diceRolled(_, let die1, let die2):
            state.turn.lastRoll = DiceRoll(die1: die1, die2: die2)
            
        case .resourcesProduced(let productions):
            for prod in productions {
                state = state.updatingPlayer(id: prod.playerId) { $0.adding(resources: prod.resources) }
                if let newBank = state.bank.taking(prod.resources) {
                    state.bank = newBank
                }
            }
            state.turn.phase = .main
            
        case .noResourcesProduced(let diceTotal, _):
            if diceTotal == 7 {
                // Will transition to discarding or moving robber
            } else {
                state.turn.phase = .main
            }
            
        case .discardRequired(let requirements):
            state.turn.phase = .discarding
            state.turn.playersToDiscard = Set(requirements.map { $0.playerId })
            
        case .resourcesDiscarded(let playerId, let resources):
            state = state.updatingPlayer(id: playerId) { $0.removing(resources: resources) }
            state.bank = state.bank.returning(resources)
            state.turn.playersToDiscard.remove(playerId)
            if state.turn.playersToDiscard.isEmpty {
                state.turn.phase = .movingRobber
            }
            
        case .robberMoved(_, _, let toHexId, let eligibleVictims):
            state.robberHexId = toHexId
            if eligibleVictims.isEmpty {
                state.turn.phase = .main
            } else {
                state.turn.stealCandidates = eligibleVictims
                state.turn.phase = .stealing
            }
            
        case .resourceStolen(let thiefId, let victimId, let resource):
            let bundle = ResourceBundle.single(resource)
            state = state.updatingPlayer(id: victimId) { $0.removing(resources: bundle) }
            state = state.updatingPlayer(id: thiefId) { $0.adding(resources: bundle) }
            state.turn.stealCandidates = []
            state.turn.phase = .main
            
        case .noStealPossible:
            state.turn.stealCandidates = []
            state.turn.phase = .main
            
        case .roadBuilt(let playerId, let edgeId, let cost):
            state.buildings = state.buildings.placingRoad(at: edgeId, playerId: playerId)
            state = state.updatingPlayer(id: playerId) {
                $0.removing(resources: cost).adding(road: edgeId)
            }
            state.bank = state.bank.returning(cost)
            
        case .settlementBuilt(let playerId, let nodeId, let cost):
            state.buildings = state.buildings.placingSettlement(at: nodeId, playerId: playerId)
            state = state.updatingPlayer(id: playerId) {
                $0.removing(resources: cost).adding(settlement: nodeId)
            }
            state.bank = state.bank.returning(cost)
            
        case .cityBuilt(let playerId, let nodeId, let cost):
            state.buildings = state.buildings.upgradingToCity(at: nodeId)
            state = state.updatingPlayer(id: playerId) {
                $0.removing(resources: cost).upgradingToCity(at: nodeId)
            }
            state.bank = state.bank.returning(cost)
            
        case .developmentCardBought(let playerId, let cardId, let cardType, let cost):
            let card = DevelopmentCard(id: cardId, type: cardType, isPlayed: false, boughtThisTurn: true)
            state = state.updatingPlayer(id: playerId) {
                var p = $0.removing(resources: cost).adding(developmentCard: card)
                p.developmentCardBoughtThisTurn = true
                return p
            }
            state.bank = state.bank.returning(cost)
            
        case .knightPlayed(let playerId, let cardId, _):
            state = state.updatingPlayer(id: playerId) {
                var p = $0.markingCardPlayed(cardId: cardId).incrementingKnights()
                p.developmentCardPlayedThisTurn = true
                return p
            }
            
        case .roadBuildingPlayed(let playerId, let cardId):
            state = state.updatingPlayer(id: playerId) {
                var p = $0.markingCardPlayed(cardId: cardId)
                p.developmentCardPlayedThisTurn = true
                return p
            }
            state.turn.roadBuildingRoadsRemaining = 2
            
        case .roadBuildingRoadPlaced(let playerId, let edgeId, let roadsRemaining):
            state.buildings = state.buildings.placingRoad(at: edgeId, playerId: playerId)
            state = state.updatingPlayer(id: playerId) { $0.adding(road: edgeId) }
            state.turn.roadBuildingRoadsRemaining = roadsRemaining
            
        case .yearOfPlentyPlayed(let playerId, let cardId, let resource1, let resource2):
            var gained = ResourceBundle.zero
            gained[resource1] += 1
            gained[resource2] += 1
            state = state.updatingPlayer(id: playerId) {
                var p = $0.markingCardPlayed(cardId: cardId).adding(resources: gained)
                p.developmentCardPlayedThisTurn = true
                return p
            }
            if let newBank = state.bank.taking(gained) {
                state.bank = newBank
            }
            
        case .monopolyPlayed(let playerId, let cardId, let resource, let stolenAmounts):
            var totalStolen = ResourceBundle.zero
            for (victimId, amount) in stolenAmounts {
                let stolen = ResourceBundle.single(resource, count: amount)
                state = state.updatingPlayer(id: victimId) { $0.removing(resources: stolen) }
                totalStolen = totalStolen + stolen
            }
            state = state.updatingPlayer(id: playerId) {
                var p = $0.markingCardPlayed(cardId: cardId).adding(resources: totalStolen)
                p.developmentCardPlayedThisTurn = true
                return p
            }
            
        case .victoryPointRevealed:
            // VP cards are revealed at game end, state already correct
            break
            
        case .tradeProposed(let proposal):
            state.turn.activeTrades.append(proposal)
            
        case .tradeAccepted(let tradeId, let accepterId):
            if let idx = state.turn.activeTrades.firstIndex(where: { $0.id == tradeId }) {
                state.turn.activeTrades[idx].acceptedBy.insert(accepterId)
            }
            
        case .tradeRejected(let tradeId, let rejecterId):
            if let idx = state.turn.activeTrades.firstIndex(where: { $0.id == tradeId }) {
                state.turn.activeTrades[idx].rejectedBy.insert(rejecterId)
            }
            
        case .tradeCancelled(let tradeId, _):
            state.turn.activeTrades.removeAll { $0.id == tradeId }
            
        case .tradeExecuted(_, let proposerId, let accepterId, let proposerGave, let accepterGave):
            state = state.updatingPlayer(id: proposerId) {
                $0.removing(resources: proposerGave).adding(resources: accepterGave)
            }
            state = state.updatingPlayer(id: accepterId) {
                $0.removing(resources: accepterGave).adding(resources: proposerGave)
            }
            
        case .maritimeTradeExecuted(let playerId, let gave, let gaveAmount, let received):
            let giving = ResourceBundle.single(gave, count: gaveAmount)
            let receiving = ResourceBundle.single(received)
            state = state.updatingPlayer(id: playerId) {
                $0.removing(resources: giving).adding(resources: receiving)
            }
            state.bank = state.bank.returning(giving)
            if let newBank = state.bank.taking(receiving) {
                state.bank = newBank
            }
            
        case .longestRoadAwarded(let newHolderId, _, let roadLength):
            state.awards.longestRoadHolder = newHolderId
            state.awards.longestRoadLength = roadLength
            
        case .largestArmyAwarded(let newHolderId, _, let knightCount):
            state.awards.largestArmyHolder = newHolderId
            state.awards.largestArmySize = knightCount
            
        case .playerWon(let playerId, _, _):
            state.winnerId = playerId
            state.turn.phase = .ended
            
        case .turnEnded:
            // Next turn will be started by turnStarted event
            break
            
        case .pairedTurnStarted(let player1Id, let player2Id, let turnNumber):
            state.turn.isPairedTurn = true
            state.turn.pairedPlayer1Id = player1Id
            state.turn.pairedPlayer2Id = player2Id
            state.turn.pairedMarkerWith = player1Id
            state.turn.turnNumber = turnNumber
            
        case .pairedMarkerPassed(_, let toPlayerId):
            state.turn.pairedMarkerWith = toPlayerId
            
        case .supplyTradeExecuted(let playerId, let gave, let received):
            let giving = ResourceBundle.single(gave)
            let receiving = ResourceBundle.single(received)
            state = state.updatingPlayer(id: playerId) {
                $0.removing(resources: giving).adding(resources: receiving)
            }
        }
        
        return state.incrementingEventIndex()
    }
    
    /// Rebuild state from a sequence of events.
    public static func rebuild(from events: [DomainEvent], initialState: GameState) -> GameState {
        events.reduce(initialState) { state, event in
            state.applying(event)
        }
    }
}

// MARK: - ResourceBundle Helpers

extension ResourceBundle {
    /// Create a bundle with a single resource type.
    public static func single(_ type: ResourceType, count: Int = 1) -> ResourceBundle {
        var bundle = ResourceBundle.zero
        bundle[type] = count
        return bundle
    }
}

