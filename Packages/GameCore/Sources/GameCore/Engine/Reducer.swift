// MARK: - Game Reducer

import Foundation
import CatanProtocol

/// Applies game actions to produce new state and domain events.
public enum Reducer {
    
    /// Reduce an action on the current state.
    /// Returns the new state and a list of domain events that occurred.
    /// Assumes the action has already been validated.
    public static func reduce<R: RandomNumberGenerator>(
        _ state: GameState,
        action: GameAction,
        rng: inout R
    ) -> (GameState, [DomainEvent]) {
        switch action {
        case .setupPlaceSettlement(let playerId, let nodeId):
            return reduceSetupSettlement(state, playerId: playerId, nodeId: nodeId)
            
        case .setupPlaceRoad(let playerId, let edgeId):
            return reduceSetupRoad(state, playerId: playerId, edgeId: edgeId, rng: &rng)
            
        case .rollDice(let playerId):
            return reduceRollDice(state, playerId: playerId, rng: &rng)
            
        case .discardResources(let playerId, let resources):
            return reduceDiscard(state, playerId: playerId, resources: resources)
            
        case .moveRobber(let playerId, let hexId):
            return reduceMoveRobber(state, playerId: playerId, hexId: hexId)
            
        case .stealResource(let playerId, let victimId):
            return reduceSteal(state, playerId: playerId, victimId: victimId, rng: &rng)
            
        case .skipSteal(let playerId):
            return reduceSkipSteal(state, playerId: playerId)
            
        case .buildRoad(let playerId, let edgeId):
            return reduceBuildRoad(state, playerId: playerId, edgeId: edgeId)
            
        case .buildSettlement(let playerId, let nodeId):
            return reduceBuildSettlement(state, playerId: playerId, nodeId: nodeId)
            
        case .buildCity(let playerId, let nodeId):
            return reduceBuildCity(state, playerId: playerId, nodeId: nodeId)
            
        case .buyDevelopmentCard(let playerId):
            return reduceBuyDevCard(state, playerId: playerId, rng: &rng)
            
        case .playKnight(let playerId, let cardId, let moveRobberTo, let stealFrom):
            return reducePlayKnight(state, playerId: playerId, cardId: cardId, moveRobberTo: moveRobberTo, stealFrom: stealFrom, rng: &rng)
            
        case .playRoadBuilding(let playerId, let cardId):
            return reducePlayRoadBuilding(state, playerId: playerId, cardId: cardId)
            
        case .placeRoadBuildingRoad(let playerId, let edgeId):
            return reducePlaceRoadBuildingRoad(state, playerId: playerId, edgeId: edgeId)
            
        case .playYearOfPlenty(let playerId, let cardId, let resource1, let resource2):
            return reducePlayYearOfPlenty(state, playerId: playerId, cardId: cardId, resource1: resource1, resource2: resource2)
            
        case .playMonopoly(let playerId, let cardId, let resource):
            return reducePlayMonopoly(state, playerId: playerId, cardId: cardId, resource: resource)
            
        case .proposeTrade(let playerId, let tradeId, let offering, let requesting, let targetPlayerIds):
            return reduceProposeTrade(state, playerId: playerId, tradeId: tradeId, offering: offering, requesting: requesting, targetPlayerIds: targetPlayerIds)
            
        case .acceptTrade(let playerId, let tradeId):
            return reduceAcceptTrade(state, playerId: playerId, tradeId: tradeId)
            
        case .rejectTrade(let playerId, let tradeId):
            return reduceRejectTrade(state, playerId: playerId, tradeId: tradeId)
            
        case .cancelTrade(let playerId, let tradeId):
            return reduceCancelTrade(state, playerId: playerId, tradeId: tradeId)
            
        case .executeTrade(let playerId, let tradeId, let withPlayerId):
            return reduceExecuteTrade(state, playerId: playerId, tradeId: tradeId, withPlayerId: withPlayerId)
            
        case .maritimeTrade(let playerId, let giving, let givingAmount, let receiving):
            return reduceMaritimeTrade(state, playerId: playerId, giving: giving, givingAmount: givingAmount, receiving: receiving)
            
        case .endTurn(let playerId):
            return reduceEndTurn(state, playerId: playerId)
            
        case .passPairedMarker(let playerId):
            return reducePassPairedMarker(state, playerId: playerId)
            
        case .supplyTrade(let playerId, let giving, let receiving):
            return reduceSupplyTrade(state, playerId: playerId, giving: giving, receiving: receiving)
        }
    }
    
    // MARK: - Setup Phase
    
    private static func reduceSetupSettlement(_ state: GameState, playerId: String, nodeId: Int) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        // Place settlement
        newState.buildings = newState.buildings.placingSettlement(at: nodeId, playerId: playerId)
        newState = newState.updatingPlayer(id: playerId) { $0.adding(settlement: nodeId) }
        newState.turn.setupNeedsRoad = true
        
        events.append(.setupSettlementPlaced(playerId: playerId, nodeId: nodeId, round: newState.turn.setupRound))
        
        return (newState, events)
    }
    
    private static func reduceSetupRoad<R: RandomNumberGenerator>(_ state: GameState, playerId: String, edgeId: Int, rng: inout R) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        // Place road
        newState.buildings = newState.buildings.placingRoad(at: edgeId, playerId: playerId)
        newState = newState.updatingPlayer(id: playerId) { $0.adding(road: edgeId) }
        newState.turn.setupNeedsRoad = false
        
        events.append(.setupRoadPlaced(playerId: playerId, edgeId: edgeId, round: newState.turn.setupRound))
        
        // On round 2, give starting resources for the second settlement
        if newState.turn.setupRound == 2 {
            // Find the most recent settlement for this player
            if let player = newState.player(id: playerId),
               let lastSettlement = player.settlements.max() {
                let resources = calculateStartingResources(nodeId: lastSettlement, board: newState.board)
                if !resources.isEmpty {
                    newState = newState.updatingPlayer(id: playerId) { $0.adding(resources: resources) }
                    events.append(.setupResourcesGiven(playerId: playerId, resources: resources))
                }
            }
        }
        
        // Advance to next player or phase
        let (advancedState, advanceEvents) = advanceSetup(newState, rng: &rng)
        newState = advancedState
        events.append(contentsOf: advanceEvents)
        
        return (newState, events)
    }
    
    private static func calculateStartingResources(nodeId: Int, board: Board) -> ResourceBundle {
        var resources = ResourceBundle.zero
        
        guard let node = board.node(id: nodeId) else { return resources }
        
        for hexId in node.adjacentHexIds {
            if let hex = board.hex(id: hexId), let resource = hex.producedResource {
                resources[resource] += 1
            }
        }
        
        return resources
    }
    
    private static func advanceSetup<R: RandomNumberGenerator>(_ state: GameState, rng: inout R) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        let playerCount = newState.players.count
        
        if newState.turn.setupForward {
            // Going forward in round 1 or 2
            newState.turn.setupPlayerIndex += 1
            
            if newState.turn.setupPlayerIndex >= playerCount {
                if newState.turn.setupRound == 1 {
                    // End of round 1, reverse direction for round 2
                    newState.turn.setupRound = 2
                    newState.turn.setupForward = false
                    newState.turn.setupPlayerIndex = playerCount - 1
                } else {
                    // Setup complete
                    return endSetup(newState, rng: &rng)
                }
            }
        } else {
            // Going backward in round 2
            newState.turn.setupPlayerIndex -= 1
            
            if newState.turn.setupPlayerIndex < 0 {
                // Setup complete
                return endSetup(newState, rng: &rng)
            }
        }
        
        // Set next active player
        let nextPlayer = newState.playersInTurnOrder[newState.turn.setupPlayerIndex]
        newState.turn.activePlayerId = nextPlayer.id
        
        // Emit event to notify clients of the turn change
        events.append(.setupTurnAdvanced(
            nextPlayerId: nextPlayer.id,
            setupRound: newState.turn.setupRound,
            setupPlayerIndex: newState.turn.setupPlayerIndex,
            setupForward: newState.turn.setupForward
        ))
        
        return (newState, events)
    }
    
    private static func endSetup<R: RandomNumberGenerator>(_ state: GameState, rng: inout R) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        events.append(.setupPhaseEnded)
        
        // Start the first real turn
        let firstPlayer = newState.playersInTurnOrder[0]
        newState.turn.phase = .preRoll
        newState.turn.activePlayerId = firstPlayer.id
        newState.turn.turnNumber = 1
        
        events.append(.turnStarted(playerId: firstPlayer.id, turnNumber: 1))
        
        return (newState, events)
    }
    
    // MARK: - Dice Roll
    
    private static func reduceRollDice<R: RandomNumberGenerator>(_ state: GameState, playerId: String, rng: inout R) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        // Roll dice
        let roll = DiceRoll.roll(using: &rng)
        newState.turn.lastRoll = roll
        
        events.append(.diceRolled(playerId: playerId, die1: roll.die1, die2: roll.die2))
        
        if roll.total == 7 {
            // Handle 7 - discard and robber
            let (sevenState, sevenEvents) = handleSevenRolled(newState)
            return (sevenState, events + sevenEvents)
        } else {
            // Produce resources
            let (prodState, prodEvents) = produceResources(newState, diceTotal: roll.total)
            newState = prodState
            events.append(contentsOf: prodEvents)
            newState.turn.phase = .main
            
            // Check for victory
            let (victoryState, victoryEvents) = checkVictory(newState, playerId: playerId)
            if !victoryEvents.isEmpty {
                return (victoryState, events + victoryEvents)
            }
            
            return (newState, events)
        }
    }
    
    private static func handleSevenRolled(_ state: GameState) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        events.append(.noResourcesProduced(diceTotal: 7, reason: .rolledSeven))
        
        // Find players who must discard
        var discardRequirements: [DiscardRequirement] = []
        for player in newState.players {
            if player.totalResources > GameConstants.discardThreshold {
                let mustDiscard = player.totalResources / 2
                discardRequirements.append(DiscardRequirement(
                    playerId: player.id,
                    currentCount: player.totalResources,
                    mustDiscard: mustDiscard
                ))
            }
        }
        
        if !discardRequirements.isEmpty {
            events.append(.discardRequired(requirements: discardRequirements))
            newState.turn.phase = .discarding
            newState.turn.playersToDiscard = Set(discardRequirements.map { $0.playerId })
        } else {
            // Go straight to moving robber
            newState.turn.phase = .movingRobber
        }
        
        return (newState, events)
    }
    
    private static func produceResources(_ state: GameState, diceTotal: Int) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        // Find all hexes with this number
        let producingHexes = newState.board.hexes(forRoll: diceTotal)
        
        var productions: [PlayerResourceProduction] = []
        var playerResources: [String: (bundle: ResourceBundle, sources: [ProductionDetail])] = [:]
        
        for hex in producingHexes {
            // Skip if robber is here
            if hex.id == newState.robberHexId { continue }
            
            guard let resource = hex.producedResource else { continue }
            
            // Find all buildings adjacent to this hex
            for node in newState.board.nodes(adjacentToHex: hex.id) {
                if let (buildingType, playerId) = newState.buildings.building(at: node.id) {
                    let amount = buildingType == .city ? 2 : 1
                    
                    var entry = playerResources[playerId] ?? (bundle: .zero, sources: [])
                    entry.bundle[resource] += amount
                    entry.sources.append(ProductionDetail(
                        hexId: hex.id,
                        nodeId: node.id,
                        buildingType: buildingType,
                        resource: resource,
                        amount: amount
                    ))
                    playerResources[playerId] = entry
                }
            }
        }
        
        // Apply resources and build events
        for (playerId, entry) in playerResources {
            if !entry.bundle.isEmpty {
                newState = newState.updatingPlayer(id: playerId) { $0.adding(resources: entry.bundle) }
                if let newBank = newState.bank.taking(entry.bundle) {
                    newState.bank = newBank
                }
                productions.append(PlayerResourceProduction(
                    playerId: playerId,
                    resources: entry.bundle,
                    sources: entry.sources
                ))
            }
        }
        
        if productions.isEmpty {
            events.append(.noResourcesProduced(diceTotal: diceTotal, reason: .noMatchingBuildings))
        } else {
            events.append(.resourcesProduced(productions: productions))
        }
        
        return (newState, events)
    }
    
    // MARK: - Robber
    
    private static func reduceDiscard(_ state: GameState, playerId: String, resources: ResourceBundle) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        // Remove resources
        newState = newState.updatingPlayer(id: playerId) { $0.removing(resources: resources) }
        newState.bank = newState.bank.returning(resources)
        newState.turn.playersToDiscard.remove(playerId)
        
        events.append(.resourcesDiscarded(playerId: playerId, resources: resources))
        
        // Check if all done discarding
        if newState.turn.playersToDiscard.isEmpty {
            newState.turn.phase = .movingRobber
        }
        
        return (newState, events)
    }
    
    private static func reduceMoveRobber(_ state: GameState, playerId: String, hexId: Int) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        let fromHexId = newState.robberHexId
        newState.robberHexId = hexId
        
        // Find eligible victims
        let eligibleVictims = Validator.findEligibleStealVictims(hexId: hexId, thiefId: playerId, state: newState)
        
        events.append(.robberMoved(playerId: playerId, fromHexId: fromHexId, toHexId: hexId, eligibleVictims: eligibleVictims))
        
        if eligibleVictims.isEmpty {
            newState.turn.phase = .main
            events.append(.noStealPossible(reason: "No players with resources adjacent to this hex"))
        } else {
            newState.turn.stealCandidates = eligibleVictims
            newState.turn.phase = .stealing
        }
        
        return (newState, events)
    }
    
    private static func reduceSteal<R: RandomNumberGenerator>(_ state: GameState, playerId: String, victimId: String, rng: inout R) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        // Pick a random resource from victim
        guard let victim = newState.player(id: victimId) else {
            return (state, [])
        }
        
        // Build a list of resources to pick from
        var resourcePool: [ResourceType] = []
        for resourceType in ResourceType.allCases {
            for _ in 0..<victim.resources[resourceType] {
                resourcePool.append(resourceType)
            }
        }
        
        guard !resourcePool.isEmpty else {
            events.append(.noStealPossible(reason: "Victim has no resources"))
            newState.turn.stealCandidates = []
            newState.turn.phase = .main
            return (newState, events)
        }
        
        let stolenResource = resourcePool[Int.random(in: 0..<resourcePool.count, using: &rng)]
        let stolenBundle = ResourceBundle.single(stolenResource)
        
        // Transfer resource
        newState = newState.updatingPlayer(id: victimId) { $0.removing(resources: stolenBundle) }
        newState = newState.updatingPlayer(id: playerId) { $0.adding(resources: stolenBundle) }
        
        events.append(.resourceStolen(thiefId: playerId, victimId: victimId, resource: stolenResource))
        
        newState.turn.stealCandidates = []
        newState.turn.phase = .main
        
        return (newState, events)
    }
    
    private static func reduceSkipSteal(_ state: GameState, playerId: String) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        events.append(.noStealPossible(reason: "All eligible players have no resources"))
        newState.turn.stealCandidates = []
        newState.turn.phase = .main
        
        return (newState, events)
    }
    
    // MARK: - Building
    
    private static func reduceBuildRoad(_ state: GameState, playerId: String, edgeId: Int) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        let cost = ResourceBundle.roadCost
        
        // Build road
        newState.buildings = newState.buildings.placingRoad(at: edgeId, playerId: playerId)
        newState = newState.updatingPlayer(id: playerId) {
            $0.removing(resources: cost).adding(road: edgeId)
        }
        newState.bank = newState.bank.returning(cost)
        
        events.append(.roadBuilt(playerId: playerId, edgeId: edgeId, cost: cost))
        
        // Check longest road
        let (roadState, roadEvents) = LongestRoadCalculator.recalculateAll(state: newState)
        newState = roadState
        events.append(contentsOf: roadEvents)
        
        // Check for victory
        let (victoryState, victoryEvents) = checkVictory(newState, playerId: playerId)
        if !victoryEvents.isEmpty {
            return (victoryState, events + victoryEvents)
        }
        
        return (newState, events)
    }
    
    private static func reduceBuildSettlement(_ state: GameState, playerId: String, nodeId: Int) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        let cost = ResourceBundle.settlementCost
        
        // Build settlement
        newState.buildings = newState.buildings.placingSettlement(at: nodeId, playerId: playerId)
        newState = newState.updatingPlayer(id: playerId) {
            $0.removing(resources: cost).adding(settlement: nodeId)
        }
        newState.bank = newState.bank.returning(cost)
        
        events.append(.settlementBuilt(playerId: playerId, nodeId: nodeId, cost: cost))
        
        // Settlement might break someone's longest road
        let (roadState, roadEvents) = LongestRoadCalculator.recalculateAll(state: newState)
        newState = roadState
        events.append(contentsOf: roadEvents)
        
        // Check for victory
        let (victoryState, victoryEvents) = checkVictory(newState, playerId: playerId)
        if !victoryEvents.isEmpty {
            return (victoryState, events + victoryEvents)
        }
        
        return (newState, events)
    }
    
    private static func reduceBuildCity(_ state: GameState, playerId: String, nodeId: Int) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        let cost = ResourceBundle.cityCost
        
        // Build city
        newState.buildings = newState.buildings.upgradingToCity(at: nodeId)
        newState = newState.updatingPlayer(id: playerId) {
            $0.removing(resources: cost).upgradingToCity(at: nodeId)
        }
        newState.bank = newState.bank.returning(cost)
        
        events.append(.cityBuilt(playerId: playerId, nodeId: nodeId, cost: cost))
        
        // Check for victory
        let (victoryState, victoryEvents) = checkVictory(newState, playerId: playerId)
        if !victoryEvents.isEmpty {
            return (victoryState, events + victoryEvents)
        }
        
        return (newState, events)
    }
    
    // MARK: - Development Cards
    
    private static func reduceBuyDevCard<R: RandomNumberGenerator>(_ state: GameState, playerId: String, rng: inout R) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        let cost = ResourceBundle.developmentCardCost
        
        // Draw card
        guard let cardType = newState.bank.drawDevelopmentCard() else {
            return (state, [])
        }
        
        let cardId = UUID().uuidString
        let card = DevelopmentCard(id: cardId, type: cardType, isPlayed: false, boughtThisTurn: true)
        
        // Pay and receive card
        newState = newState.updatingPlayer(id: playerId) {
            var p = $0.removing(resources: cost).adding(developmentCard: card)
            p.developmentCardBoughtThisTurn = true
            return p
        }
        newState.bank = newState.bank.returning(cost)
        
        events.append(.developmentCardBought(playerId: playerId, cardId: cardId, cardType: cardType, cost: cost))
        
        return (newState, events)
    }
    
    private static func reducePlayKnight<R: RandomNumberGenerator>(_ state: GameState, playerId: String, cardId: String, moveRobberTo: Int, stealFrom: String?, rng: inout R) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        let fromHexId = newState.robberHexId
        
        // Play card
        newState = newState.updatingPlayer(id: playerId) {
            var p = $0.markingCardPlayed(cardId: cardId).incrementingKnights()
            p.developmentCardPlayedThisTurn = true
            return p
        }
        
        events.append(.knightPlayed(playerId: playerId, cardId: cardId, movedRobberTo: moveRobberTo))
        
        // Move robber
        newState.robberHexId = moveRobberTo
        
        let eligibleVictims = Validator.findEligibleStealVictims(hexId: moveRobberTo, thiefId: playerId, state: newState)
        events.append(.robberMoved(playerId: playerId, fromHexId: fromHexId, toHexId: moveRobberTo, eligibleVictims: eligibleVictims))
        
        // Handle steal
        if let victimId = stealFrom, eligibleVictims.contains(victimId) {
            let (stealState, stealEvents) = reduceSteal(newState, playerId: playerId, victimId: victimId, rng: &rng)
            newState = stealState
            events.append(contentsOf: stealEvents)
        } else if eligibleVictims.isEmpty {
            events.append(.noStealPossible(reason: "No eligible victims"))
        }
        
        // Ensure we're in main phase
        newState.turn.phase = .main
        newState.turn.stealCandidates = []
        
        // Check largest army
        if let player = newState.player(id: playerId) {
            let (armyAwards, changed, previousHolder) = newState.awards.checkLargestArmy(
                playerId: playerId,
                knightsPlayed: player.knightsPlayed
            )
            if changed {
                newState.awards = armyAwards
                events.append(.largestArmyAwarded(
                    newHolderId: playerId,
                    previousHolderId: previousHolder,
                    knightCount: player.knightsPlayed
                ))
            }
        }
        
        // Check for victory
        let (victoryState, victoryEvents) = checkVictory(newState, playerId: playerId)
        if !victoryEvents.isEmpty {
            return (victoryState, events + victoryEvents)
        }
        
        return (newState, events)
    }
    
    private static func reducePlayRoadBuilding(_ state: GameState, playerId: String, cardId: String) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        // Play card
        newState = newState.updatingPlayer(id: playerId) {
            var p = $0.markingCardPlayed(cardId: cardId)
            p.developmentCardPlayedThisTurn = true
            return p
        }
        
        // Check how many roads player can build (might only have 1 left)
        if let player = newState.player(id: playerId) {
            newState.turn.roadBuildingRoadsRemaining = min(2, player.remainingRoads)
        } else {
            newState.turn.roadBuildingRoadsRemaining = 2
        }
        
        events.append(.roadBuildingPlayed(playerId: playerId, cardId: cardId))
        
        return (newState, events)
    }
    
    private static func reducePlaceRoadBuildingRoad(_ state: GameState, playerId: String, edgeId: Int) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        // Place road (free)
        newState.buildings = newState.buildings.placingRoad(at: edgeId, playerId: playerId)
        newState = newState.updatingPlayer(id: playerId) { $0.adding(road: edgeId) }
        newState.turn.roadBuildingRoadsRemaining -= 1
        
        events.append(.roadBuildingRoadPlaced(playerId: playerId, edgeId: edgeId, roadsRemaining: newState.turn.roadBuildingRoadsRemaining))
        
        // If no more roads to place (or player out of supply), end road building
        if newState.turn.roadBuildingRoadsRemaining <= 0 {
            newState.turn.roadBuildingRoadsRemaining = 0
        }
        
        // Check longest road
        let (roadState, roadEvents) = LongestRoadCalculator.recalculateAll(state: newState)
        newState = roadState
        events.append(contentsOf: roadEvents)
        
        // Check for victory
        let (victoryState, victoryEvents) = checkVictory(newState, playerId: playerId)
        if !victoryEvents.isEmpty {
            return (victoryState, events + victoryEvents)
        }
        
        return (newState, events)
    }
    
    private static func reducePlayYearOfPlenty(_ state: GameState, playerId: String, cardId: String, resource1: ResourceType, resource2: ResourceType) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        var gained = ResourceBundle.zero
        gained[resource1] += 1
        gained[resource2] += 1
        
        // Play card
        newState = newState.updatingPlayer(id: playerId) {
            var p = $0.markingCardPlayed(cardId: cardId).adding(resources: gained)
            p.developmentCardPlayedThisTurn = true
            return p
        }
        
        if let newBank = newState.bank.taking(gained) {
            newState.bank = newBank
        }
        
        events.append(.yearOfPlentyPlayed(playerId: playerId, cardId: cardId, resource1: resource1, resource2: resource2))
        
        return (newState, events)
    }
    
    private static func reducePlayMonopoly(_ state: GameState, playerId: String, cardId: String, resource: ResourceType) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        // Collect resource from all other players
        var stolenAmounts: [String: Int] = [:]
        var totalStolen = ResourceBundle.zero
        
        for player in newState.players {
            if player.id != playerId {
                let amount = player.resources[resource]
                if amount > 0 {
                    stolenAmounts[player.id] = amount
                    let stolen = ResourceBundle.single(resource, count: amount)
                    totalStolen = totalStolen + stolen
                    newState = newState.updatingPlayer(id: player.id) { $0.removing(resources: stolen) }
                }
            }
        }
        
        // Give to monopoly player
        newState = newState.updatingPlayer(id: playerId) {
            var p = $0.markingCardPlayed(cardId: cardId).adding(resources: totalStolen)
            p.developmentCardPlayedThisTurn = true
            return p
        }
        
        events.append(.monopolyPlayed(playerId: playerId, cardId: cardId, resource: resource, stolenAmounts: stolenAmounts))
        
        return (newState, events)
    }
    
    // MARK: - Trading
    
    private static func reduceProposeTrade(_ state: GameState, playerId: String, tradeId: String, offering: ResourceBundle, requesting: ResourceBundle, targetPlayerIds: [String]?) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        let proposal = TradeProposal(
            id: tradeId,
            proposerId: playerId,
            offering: offering,
            requesting: requesting,
            targetPlayerIds: targetPlayerIds
        )
        
        newState.turn.activeTrades.append(proposal)
        events.append(.tradeProposed(proposal: proposal))
        
        return (newState, events)
    }
    
    private static func reduceAcceptTrade(_ state: GameState, playerId: String, tradeId: String) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        if let idx = newState.turn.activeTrades.firstIndex(where: { $0.id == tradeId }) {
            newState.turn.activeTrades[idx].acceptedBy.insert(playerId)
        }
        
        events.append(.tradeAccepted(tradeId: tradeId, accepterId: playerId))
        
        return (newState, events)
    }
    
    private static func reduceRejectTrade(_ state: GameState, playerId: String, tradeId: String) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        if let idx = newState.turn.activeTrades.firstIndex(where: { $0.id == tradeId }) {
            newState.turn.activeTrades[idx].rejectedBy.insert(playerId)
        }
        
        events.append(.tradeRejected(tradeId: tradeId, rejecterId: playerId))
        
        return (newState, events)
    }
    
    private static func reduceCancelTrade(_ state: GameState, playerId: String, tradeId: String) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        newState.turn.activeTrades.removeAll { $0.id == tradeId }
        events.append(.tradeCancelled(tradeId: tradeId, reason: .proposerCancelled))
        
        return (newState, events)
    }
    
    private static func reduceExecuteTrade(_ state: GameState, playerId: String, tradeId: String, withPlayerId: String) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        guard let trade = newState.turn.activeTrades.first(where: { $0.id == tradeId }) else {
            return (state, [])
        }
        
        // Exchange resources
        newState = newState.updatingPlayer(id: playerId) {
            $0.removing(resources: trade.offering).adding(resources: trade.requesting)
        }
        newState = newState.updatingPlayer(id: withPlayerId) {
            $0.removing(resources: trade.requesting).adding(resources: trade.offering)
        }
        
        // Remove trade
        newState.turn.activeTrades.removeAll { $0.id == tradeId }
        
        events.append(.tradeExecuted(
            tradeId: tradeId,
            proposerId: playerId,
            accepterId: withPlayerId,
            proposerGave: trade.offering,
            accepterGave: trade.requesting
        ))
        
        return (newState, events)
    }
    
    private static func reduceMaritimeTrade(_ state: GameState, playerId: String, giving: ResourceType, givingAmount: Int, receiving: ResourceType) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        let givingBundle = ResourceBundle.single(giving, count: givingAmount)
        let receivingBundle = ResourceBundle.single(receiving)
        
        newState = newState.updatingPlayer(id: playerId) {
            $0.removing(resources: givingBundle).adding(resources: receivingBundle)
        }
        newState.bank = newState.bank.returning(givingBundle)
        if let newBank = newState.bank.taking(receivingBundle) {
            newState.bank = newBank
        }
        
        events.append(.maritimeTradeExecuted(playerId: playerId, gave: giving, gaveAmount: givingAmount, received: receiving))
        
        return (newState, events)
    }
    
    // MARK: - Turn Control
    
    private static func reduceEndTurn(_ state: GameState, playerId: String) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        // Cancel all active trades
        for trade in newState.turn.activeTrades {
            events.append(.tradeCancelled(tradeId: trade.id, reason: .turnEnded))
        }
        newState.turn.activeTrades = []
        
        events.append(.turnEnded(playerId: playerId, turnNumber: newState.turn.turnNumber))
        
        // Advance to next player
        let currentIndex = newState.players.firstIndex { $0.id == playerId } ?? 0
        let nextIndex = (currentIndex + 1) % newState.players.count
        let nextPlayer = newState.playersInTurnOrder[nextIndex]
        
        newState.turn.activePlayerId = nextPlayer.id
        newState.turn.turnNumber += 1
        newState.turn.phase = .preRoll
        newState.turn.lastRoll = nil
        newState.turn.roadBuildingRoadsRemaining = 0
        
        // Reset player's turn flags
        newState = newState.updatingPlayer(id: nextPlayer.id) { $0.resettingTurnFlags() }
        
        events.append(.turnStarted(playerId: nextPlayer.id, turnNumber: newState.turn.turnNumber))
        
        return (newState, events)
    }
    
    // MARK: - 5-6 Player Extension
    
    private static func reducePassPairedMarker(_ state: GameState, playerId: String) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        guard let player2Id = newState.turn.pairedPlayer2Id else {
            return (state, [])
        }
        
        newState.turn.pairedMarkerWith = player2Id
        events.append(.pairedMarkerPassed(fromPlayerId: playerId, toPlayerId: player2Id))
        
        return (newState, events)
    }
    
    private static func reduceSupplyTrade(_ state: GameState, playerId: String, giving: ResourceType, receiving: ResourceType) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        let givingBundle = ResourceBundle.single(giving)
        let receivingBundle = ResourceBundle.single(receiving)
        
        newState = newState.updatingPlayer(id: playerId) {
            $0.removing(resources: givingBundle).adding(resources: receivingBundle)
        }
        
        events.append(.supplyTradeExecuted(playerId: playerId, gave: giving, received: receiving))
        
        return (newState, events)
    }
    
    // MARK: - Victory Check
    
    private static func checkVictory(_ state: GameState, playerId: String) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        // Only check on active player's turn (can only win on your turn)
        guard state.turn.activePlayerId == playerId else {
            return (state, [])
        }
        
        let vp = state.totalVictoryPoints(for: playerId)
        if vp >= GameConstants.victoryPointsToWin {
            let breakdown = state.victoryPoints(for: playerId)
            
            // Reveal victory point cards if any
            if let player = state.player(id: playerId) {
                let vpCards = player.developmentCards.filter { $0.type == .victoryPoint && !$0.isPlayed }.count
                if vpCards > 0 {
                    events.append(.victoryPointRevealed(playerId: playerId, cardCount: vpCards))
                }
            }
            
            newState.winnerId = playerId
            newState.turn.phase = .ended
            
            events.append(.playerWon(playerId: playerId, victoryPoints: vp, breakdown: breakdown))
        }
        
        return (newState, events)
    }
}

