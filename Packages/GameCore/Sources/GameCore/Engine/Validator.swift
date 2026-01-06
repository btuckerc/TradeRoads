// MARK: - Action Validator

import Foundation
import CatanProtocol

/// Validates game actions against the current state.
public enum Validator {
    
    /// Validate an action against the current state.
    /// Returns an empty array if the action is valid, or a list of violations if invalid.
    public static func validate(_ action: GameAction, state: GameState) -> ValidationResult {
        // Check game hasn't ended
        if state.turn.phase == .ended {
            return [.gameAlreadyEnded()]
        }
        
        // Check player exists
        guard state.player(id: action.playerId) != nil else {
            return [.invalidAction("Player not found")]
        }
        
        switch action {
        case .setupPlaceSettlement(let playerId, let nodeId):
            return validateSetupSettlement(playerId: playerId, nodeId: nodeId, state: state)
            
        case .setupPlaceRoad(let playerId, let edgeId):
            return validateSetupRoad(playerId: playerId, edgeId: edgeId, state: state)
            
        case .rollDice(let playerId):
            return validateRollDice(playerId: playerId, state: state)
            
        case .discardResources(let playerId, let resources):
            return validateDiscard(playerId: playerId, resources: resources, state: state)
            
        case .moveRobber(let playerId, let hexId):
            return validateMoveRobber(playerId: playerId, hexId: hexId, state: state)
            
        case .stealResource(let playerId, let victimId):
            return validateSteal(playerId: playerId, victimId: victimId, state: state)
            
        case .skipSteal(let playerId):
            return validateSkipSteal(playerId: playerId, state: state)
            
        case .buildRoad(let playerId, let edgeId):
            return validateBuildRoad(playerId: playerId, edgeId: edgeId, state: state)
            
        case .buildSettlement(let playerId, let nodeId):
            return validateBuildSettlement(playerId: playerId, nodeId: nodeId, state: state)
            
        case .buildCity(let playerId, let nodeId):
            return validateBuildCity(playerId: playerId, nodeId: nodeId, state: state)
            
        case .buyDevelopmentCard(let playerId):
            return validateBuyDevCard(playerId: playerId, state: state)
            
        case .playKnight(let playerId, let cardId, let moveRobberTo, let stealFrom):
            return validatePlayKnight(playerId: playerId, cardId: cardId, moveRobberTo: moveRobberTo, stealFrom: stealFrom, state: state)
            
        case .playRoadBuilding(let playerId, let cardId):
            return validatePlayRoadBuilding(playerId: playerId, cardId: cardId, state: state)
            
        case .placeRoadBuildingRoad(let playerId, let edgeId):
            return validatePlaceRoadBuildingRoad(playerId: playerId, edgeId: edgeId, state: state)
            
        case .playYearOfPlenty(let playerId, let cardId, let resource1, let resource2):
            return validatePlayYearOfPlenty(playerId: playerId, cardId: cardId, resource1: resource1, resource2: resource2, state: state)
            
        case .playMonopoly(let playerId, let cardId, _):
            return validatePlayMonopoly(playerId: playerId, cardId: cardId, state: state)
            
        case .proposeTrade(let playerId, _, let offering, let requesting, let targetPlayerIds):
            return validateProposeTrade(playerId: playerId, offering: offering, requesting: requesting, targetPlayerIds: targetPlayerIds, state: state)
            
        case .acceptTrade(let playerId, let tradeId):
            return validateAcceptTrade(playerId: playerId, tradeId: tradeId, state: state)
            
        case .rejectTrade(let playerId, let tradeId):
            return validateRejectTrade(playerId: playerId, tradeId: tradeId, state: state)
            
        case .cancelTrade(let playerId, let tradeId):
            return validateCancelTrade(playerId: playerId, tradeId: tradeId, state: state)
            
        case .executeTrade(let playerId, let tradeId, let withPlayerId):
            return validateExecuteTrade(playerId: playerId, tradeId: tradeId, withPlayerId: withPlayerId, state: state)
            
        case .maritimeTrade(let playerId, let giving, let givingAmount, let receiving):
            return validateMaritimeTrade(playerId: playerId, giving: giving, givingAmount: givingAmount, receiving: receiving, state: state)
            
        case .endTurn(let playerId):
            return validateEndTurn(playerId: playerId, state: state)
            
        case .passPairedMarker(let playerId):
            return validatePassPairedMarker(playerId: playerId, state: state)
            
        case .supplyTrade(let playerId, let giving, let receiving):
            return validateSupplyTrade(playerId: playerId, giving: giving, receiving: receiving, state: state)
        }
    }
    
    // MARK: - Setup Phase Validation
    
    private static func validateSetupSettlement(playerId: String, nodeId: Int, state: GameState) -> ValidationResult {
        var violations: [Violation] = []
        
        // Must be setup phase
        guard state.turn.phase == .setup else {
            return [.wrongPhase(expected: "setup", actual: state.turn.phase.rawValue)]
        }
        
        // Must be active player
        guard state.turn.activePlayerId == playerId else {
            return [.notYourTurn()]
        }
        
        // Must not be waiting for road
        guard !state.turn.setupNeedsRoad else {
            return [.invalidAction("Must place a road first")]
        }
        
        // Node must exist
        guard let node = state.board.node(id: nodeId) else {
            return [.invalidLocation()]
        }
        
        // Node must be empty
        if state.buildings.isOccupied(nodeId: nodeId) {
            violations.append(.locationOccupied())
        }
        
        // Distance rule: no adjacent settlements/cities
        for adjNodeId in node.adjacentNodeIds {
            if state.buildings.isOccupied(nodeId: adjNodeId) {
                violations.append(.violatesDistanceRule())
                break
            }
        }
        
        // Check supply
        if let player = state.player(id: playerId), player.remainingSettlements == 0 {
            violations.append(.noSupplyRemaining(piece: "settlements"))
        }
        
        return violations
    }
    
    private static func validateSetupRoad(playerId: String, edgeId: Int, state: GameState) -> ValidationResult {
        var violations: [Violation] = []
        
        // Must be setup phase
        guard state.turn.phase == .setup else {
            return [.wrongPhase(expected: "setup", actual: state.turn.phase.rawValue)]
        }
        
        // Must be active player
        guard state.turn.activePlayerId == playerId else {
            return [.notYourTurn()]
        }
        
        // Must be waiting for road
        guard state.turn.setupNeedsRoad else {
            return [.invalidAction("Must place a settlement first")]
        }
        
        // Edge must exist
        guard let edge = state.board.edge(id: edgeId) else {
            return [.invalidLocation()]
        }
        
        // Edge must be empty
        if state.buildings.hasRoad(edgeId: edgeId) {
            violations.append(.locationOccupied())
        }
        
        // Must be adjacent to the just-placed settlement
        guard let player = state.player(id: playerId) else {
            return [.invalidAction("Player not found")]
        }
        
        // Find the most recently placed settlement (the one without a road adjacent yet)
        let playerSettlements = player.settlements
        var adjacentToNewSettlement = false
        for settlementNodeId in playerSettlements {
            // Check if this edge connects to this settlement
            if edge.nodeIds.0 == settlementNodeId || edge.nodeIds.1 == settlementNodeId {
                adjacentToNewSettlement = true
                break
            }
        }
        
        if !adjacentToNewSettlement {
            violations.append(.noAdjacentRoad())
        }
        
        // Check supply
        if player.remainingRoads == 0 {
            violations.append(.noSupplyRemaining(piece: "roads"))
        }
        
        return violations
    }
    
    // MARK: - Dice Validation
    
    private static func validateRollDice(playerId: String, state: GameState) -> ValidationResult {
        // Must be active player
        guard state.turn.activePlayerId == playerId else {
            return [.notYourTurn()]
        }
        
        // Must be in pre-roll phase
        guard state.turn.phase == .preRoll else {
            if state.turn.lastRoll != nil {
                return [.alreadyRolled()]
            }
            return [.wrongPhase(expected: "preRoll", actual: state.turn.phase.rawValue)]
        }
        
        return []
    }
    
    // MARK: - Robber Validation
    
    private static func validateDiscard(playerId: String, resources: ResourceBundle, state: GameState) -> ValidationResult {
        var violations: [Violation] = []
        
        // Must be in discard phase
        guard state.turn.phase == .discarding else {
            return [.wrongPhase(expected: "discarding", actual: state.turn.phase.rawValue)]
        }
        
        // Player must need to discard
        guard state.turn.playersToDiscard.contains(playerId) else {
            return [.invalidAction("You don't need to discard")]
        }
        
        // Check player has these resources
        guard let player = state.player(id: playerId) else {
            return [.invalidAction("Player not found")]
        }
        
        if !player.resources.contains(resources) {
            violations.append(.insufficientResources(need: "the resources you're trying to discard"))
        }
        
        // Check correct amount
        let requiredDiscard = player.totalResources / 2
        if resources.total != requiredDiscard {
            violations.append(.wrongDiscardAmount(required: requiredDiscard, provided: resources.total))
        }
        
        return violations
    }
    
    private static func validateMoveRobber(playerId: String, hexId: Int, state: GameState) -> ValidationResult {
        // Must be active player
        guard state.turn.activePlayerId == playerId else {
            return [.notYourTurn()]
        }
        
        // Must be in moving robber phase
        guard state.turn.phase == .movingRobber else {
            return [.wrongPhase(expected: "movingRobber", actual: state.turn.phase.rawValue)]
        }
        
        // Hex must exist
        guard state.board.hex(id: hexId) != nil else {
            return [.invalidLocation()]
        }
        
        // Must move to a different hex
        if hexId == state.robberHexId {
            return [.mustMoveRobberToNewHex()]
        }
        
        return []
    }
    
    private static func validateSteal(playerId: String, victimId: String, state: GameState) -> ValidationResult {
        // Must be active player
        guard state.turn.activePlayerId == playerId else {
            return [.notYourTurn()]
        }
        
        // Must be in stealing phase
        guard state.turn.phase == .stealing else {
            return [.wrongPhase(expected: "stealing", actual: state.turn.phase.rawValue)]
        }
        
        // Victim must be eligible
        guard state.turn.stealCandidates.contains(victimId) else {
            return [.noEligibleVictim()]
        }
        
        // Victim must have resources
        guard let victim = state.player(id: victimId), victim.totalResources > 0 else {
            return [.victimHasNoResources()]
        }
        
        return []
    }
    
    private static func validateSkipSteal(playerId: String, state: GameState) -> ValidationResult {
        // Must be active player
        guard state.turn.activePlayerId == playerId else {
            return [.notYourTurn()]
        }
        
        // Must be in stealing phase
        guard state.turn.phase == .stealing else {
            return [.wrongPhase(expected: "stealing", actual: state.turn.phase.rawValue)]
        }
        
        // Can only skip if no valid targets (all have 0 resources)
        for candidateId in state.turn.stealCandidates {
            if let candidate = state.player(id: candidateId), candidate.totalResources > 0 {
                return [.invalidAction("You must steal from a player with resources")]
            }
        }
        
        return []
    }
    
    // MARK: - Building Validation
    
    private static func validateBuildRoad(playerId: String, edgeId: Int, state: GameState) -> ValidationResult {
        var violations: [Violation] = []
        
        // Must be active player in main phase
        guard state.turn.activePlayerId == playerId else {
            return [.notYourTurn()]
        }
        guard state.turn.phase == .main else {
            return [.wrongPhase(expected: "main", actual: state.turn.phase.rawValue)]
        }
        
        guard let player = state.player(id: playerId) else {
            return [.invalidAction("Player not found")]
        }
        
        // Edge must exist
        guard let edge = state.board.edge(id: edgeId) else {
            return [.invalidLocation()]
        }
        
        // Edge must be empty
        if state.buildings.hasRoad(edgeId: edgeId) {
            violations.append(.locationOccupied())
        }
        
        // Must be adjacent to existing road or building
        let adjacentToNetwork = isAdjacentToPlayerNetwork(
            playerId: playerId,
            nodeIds: [edge.nodeIds.0, edge.nodeIds.1],
            state: state
        )
        if !adjacentToNetwork {
            violations.append(.noAdjacentRoad())
        }
        
        // Check resources
        if !player.canAfford(.roadCost) {
            violations.append(.insufficientResources(need: "1 brick, 1 lumber"))
        }
        
        // Check supply
        if player.remainingRoads == 0 {
            violations.append(.noSupplyRemaining(piece: "roads"))
        }
        
        return violations
    }
    
    private static func validateBuildSettlement(playerId: String, nodeId: Int, state: GameState) -> ValidationResult {
        var violations: [Violation] = []
        
        // Must be active player in main phase
        guard state.turn.activePlayerId == playerId else {
            return [.notYourTurn()]
        }
        guard state.turn.phase == .main else {
            return [.wrongPhase(expected: "main", actual: state.turn.phase.rawValue)]
        }
        
        guard let player = state.player(id: playerId) else {
            return [.invalidAction("Player not found")]
        }
        
        // Node must exist
        guard let node = state.board.node(id: nodeId) else {
            return [.invalidLocation()]
        }
        
        // Node must be empty
        if state.buildings.isOccupied(nodeId: nodeId) {
            violations.append(.locationOccupied())
        }
        
        // Distance rule
        for adjNodeId in node.adjacentNodeIds {
            if state.buildings.isOccupied(nodeId: adjNodeId) {
                violations.append(.violatesDistanceRule())
                break
            }
        }
        
        // Must be adjacent to player's road
        let adjacentToRoad = node.adjacentEdgeIds.contains { edgeId in
            state.buildings.roadOwner(edgeId: edgeId) == playerId
        }
        if !adjacentToRoad {
            violations.append(.noAdjacentRoad())
        }
        
        // Check resources
        if !player.canAfford(.settlementCost) {
            violations.append(.insufficientResources(need: "1 brick, 1 lumber, 1 grain, 1 wool"))
        }
        
        // Check supply
        if player.remainingSettlements == 0 {
            violations.append(.noSupplyRemaining(piece: "settlements"))
        }
        
        return violations
    }
    
    private static func validateBuildCity(playerId: String, nodeId: Int, state: GameState) -> ValidationResult {
        var violations: [Violation] = []
        
        // Must be active player in main phase
        guard state.turn.activePlayerId == playerId else {
            return [.notYourTurn()]
        }
        guard state.turn.phase == .main else {
            return [.wrongPhase(expected: "main", actual: state.turn.phase.rawValue)]
        }
        
        guard let player = state.player(id: playerId) else {
            return [.invalidAction("Player not found")]
        }
        
        // Must have a settlement there
        guard player.settlements.contains(nodeId) else {
            return [.noSettlementToUpgrade()]
        }
        
        // Check resources
        if !player.canAfford(.cityCost) {
            violations.append(.insufficientResources(need: "2 grain, 3 ore"))
        }
        
        // Check supply
        if player.remainingCities == 0 {
            violations.append(.noSupplyRemaining(piece: "cities"))
        }
        
        return violations
    }
    
    // MARK: - Development Card Validation
    
    private static func validateBuyDevCard(playerId: String, state: GameState) -> ValidationResult {
        var violations: [Violation] = []
        
        // Must be active player in main phase
        guard state.turn.activePlayerId == playerId else {
            return [.notYourTurn()]
        }
        guard state.turn.phase == .main else {
            return [.wrongPhase(expected: "main", actual: state.turn.phase.rawValue)]
        }
        
        guard let player = state.player(id: playerId) else {
            return [.invalidAction("Player not found")]
        }
        
        // Check resources
        if !player.canAfford(.developmentCardCost) {
            violations.append(.insufficientResources(need: "1 ore, 1 grain, 1 wool"))
        }
        
        // Check deck not empty
        if state.bank.developmentCards.isEmpty {
            violations.append(.invalidAction("No development cards remaining"))
        }
        
        return violations
    }
    
    private static func validatePlayKnight(playerId: String, cardId: String, moveRobberTo: Int, stealFrom: String?, state: GameState) -> ValidationResult {
        var violations: [Violation] = []
        
        // Can play knight before or during main phase
        guard state.turn.activePlayerId == playerId else {
            return [.notYourTurn()]
        }
        guard state.turn.phase == .preRoll || state.turn.phase == .main else {
            return [.wrongPhase(expected: "preRoll or main", actual: state.turn.phase.rawValue)]
        }
        
        // Validate card ownership and playability
        violations.append(contentsOf: validateCanPlayCard(playerId: playerId, cardId: cardId, cardType: .knight, state: state))
        
        // Validate robber move
        guard state.board.hex(id: moveRobberTo) != nil else {
            return violations + [.invalidLocation()]
        }
        if moveRobberTo == state.robberHexId {
            violations.append(.mustMoveRobberToNewHex())
        }
        
        // Validate steal target if provided
        if let victimId = stealFrom {
            let eligibleVictims = findEligibleStealVictims(hexId: moveRobberTo, thiefId: playerId, state: state)
            if !eligibleVictims.contains(victimId) {
                violations.append(.noEligibleVictim())
            }
        }
        
        return violations
    }
    
    private static func validatePlayRoadBuilding(playerId: String, cardId: String, state: GameState) -> ValidationResult {
        var violations: [Violation] = []
        
        guard state.turn.activePlayerId == playerId else {
            return [.notYourTurn()]
        }
        guard state.turn.phase == .main else {
            return [.wrongPhase(expected: "main", actual: state.turn.phase.rawValue)]
        }
        
        violations.append(contentsOf: validateCanPlayCard(playerId: playerId, cardId: cardId, cardType: .roadBuilding, state: state))
        
        // Check player has roads in supply
        if let player = state.player(id: playerId), player.remainingRoads == 0 {
            violations.append(.noSupplyRemaining(piece: "roads"))
        }
        
        return violations
    }
    
    private static func validatePlaceRoadBuildingRoad(playerId: String, edgeId: Int, state: GameState) -> ValidationResult {
        var violations: [Violation] = []
        
        guard state.turn.activePlayerId == playerId else {
            return [.notYourTurn()]
        }
        guard state.turn.roadBuildingRoadsRemaining > 0 else {
            return [.invalidAction("Not in Road Building mode")]
        }
        
        guard let player = state.player(id: playerId) else {
            return [.invalidAction("Player not found")]
        }
        
        // Edge must exist
        guard let edge = state.board.edge(id: edgeId) else {
            return [.invalidLocation()]
        }
        
        // Edge must be empty
        if state.buildings.hasRoad(edgeId: edgeId) {
            violations.append(.locationOccupied())
        }
        
        // Must be adjacent to network
        let adjacentToNetwork = isAdjacentToPlayerNetwork(
            playerId: playerId,
            nodeIds: [edge.nodeIds.0, edge.nodeIds.1],
            state: state
        )
        if !adjacentToNetwork {
            violations.append(.noAdjacentRoad())
        }
        
        // Check supply (no cost but need pieces)
        if player.remainingRoads == 0 {
            violations.append(.noSupplyRemaining(piece: "roads"))
        }
        
        return violations
    }
    
    private static func validatePlayYearOfPlenty(playerId: String, cardId: String, resource1: ResourceType, resource2: ResourceType, state: GameState) -> ValidationResult {
        var violations: [Violation] = []
        
        guard state.turn.activePlayerId == playerId else {
            return [.notYourTurn()]
        }
        guard state.turn.phase == .main else {
            return [.wrongPhase(expected: "main", actual: state.turn.phase.rawValue)]
        }
        
        violations.append(contentsOf: validateCanPlayCard(playerId: playerId, cardId: cardId, cardType: .yearOfPlenty, state: state))
        
        // Check bank has the resources
        if !state.bank.has(resource1, amount: 1) {
            violations.append(.invalidAction("Bank has no \(resource1.rawValue)"))
        }
        if resource1 == resource2 {
            if !state.bank.has(resource1, amount: 2) {
                violations.append(.invalidAction("Bank doesn't have 2 \(resource1.rawValue)"))
            }
        } else {
            if !state.bank.has(resource2, amount: 1) {
                violations.append(.invalidAction("Bank has no \(resource2.rawValue)"))
            }
        }
        
        return violations
    }
    
    private static func validatePlayMonopoly(playerId: String, cardId: String, state: GameState) -> ValidationResult {
        var violations: [Violation] = []
        
        guard state.turn.activePlayerId == playerId else {
            return [.notYourTurn()]
        }
        guard state.turn.phase == .main else {
            return [.wrongPhase(expected: "main", actual: state.turn.phase.rawValue)]
        }
        
        violations.append(contentsOf: validateCanPlayCard(playerId: playerId, cardId: cardId, cardType: .monopoly, state: state))
        
        return violations
    }
    
    private static func validateCanPlayCard(playerId: String, cardId: String, cardType: DevelopmentCardType, state: GameState) -> [Violation] {
        var violations: [Violation] = []
        
        guard let player = state.player(id: playerId) else {
            return [.invalidAction("Player not found")]
        }
        
        // Find the card
        guard let card = player.developmentCards.first(where: { $0.id == cardId }) else {
            return [.noDevCardToPlay()]
        }
        
        // Check card type
        if card.type != cardType {
            violations.append(.invalidDevCardType())
        }
        
        // Check not already played
        if card.isPlayed {
            violations.append(.noDevCardToPlay())
        }
        
        // Check not bought this turn
        if card.boughtThisTurn {
            violations.append(.cannotPlayCardBoughtThisTurn())
        }
        
        // Check not already played a dev card this turn
        if player.developmentCardPlayedThisTurn {
            violations.append(.alreadyPlayedDevCard())
        }
        
        return violations
    }
    
    // MARK: - Trading Validation
    
    private static func validateProposeTrade(playerId: String, offering: ResourceBundle, requesting: ResourceBundle, targetPlayerIds: [String]?, state: GameState) -> ValidationResult {
        var violations: [Violation] = []
        
        // Must be active player in main phase (domestic trade rule)
        guard state.turn.activePlayerId == playerId else {
            return [.inactivePlayerCannotTrade()]
        }
        guard state.turn.phase == .main else {
            return [.wrongPhase(expected: "main", actual: state.turn.phase.rawValue)]
        }
        
        guard let player = state.player(id: playerId) else {
            return [.invalidAction("Player not found")]
        }
        
        // Check player has the resources being offered
        if !player.resources.contains(offering) {
            violations.append(.insufficientResources(need: "the resources you're offering"))
        }
        
        // Trade must not be empty
        if offering.isEmpty && requesting.isEmpty {
            violations.append(.invalidAction("Trade cannot be empty"))
        }
        
        // Validate targets exist
        if let targets = targetPlayerIds {
            for targetId in targets {
                if state.player(id: targetId) == nil {
                    violations.append(.invalidAction("Target player not found"))
                }
                if targetId == playerId {
                    violations.append(.cannotTradeWithSelf())
                }
            }
        }
        
        return violations
    }
    
    private static func validateAcceptTrade(playerId: String, tradeId: String, state: GameState) -> ValidationResult {
        var violations: [Violation] = []
        
        // Find the trade
        guard let trade = state.turn.activeTrades.first(where: { $0.id == tradeId }) else {
            return [.noSuchTradeProposal()]
        }
        
        // Cannot accept own trade
        if trade.proposerId == playerId {
            return [.cannotTradeWithSelf()]
        }
        
        // Check if already responded
        if trade.acceptedBy.contains(playerId) || trade.rejectedBy.contains(playerId) {
            return [.tradeAlreadyAccepted()]
        }
        
        // Check if targeted
        if let targets = trade.targetPlayerIds, !targets.contains(playerId) {
            return [.notTargetOfTrade()]
        }
        
        // Check player has the resources to fulfill
        guard let player = state.player(id: playerId) else {
            return [.invalidAction("Player not found")]
        }
        
        if !player.resources.contains(trade.requesting) {
            violations.append(.insufficientResources(need: "the resources being requested"))
        }
        
        return violations
    }
    
    private static func validateRejectTrade(playerId: String, tradeId: String, state: GameState) -> ValidationResult {
        // Find the trade
        guard let trade = state.turn.activeTrades.first(where: { $0.id == tradeId }) else {
            return [.noSuchTradeProposal()]
        }
        
        // Cannot reject own trade
        if trade.proposerId == playerId {
            return [.invalidAction("Cannot reject your own trade")]
        }
        
        // Check if already responded
        if trade.acceptedBy.contains(playerId) || trade.rejectedBy.contains(playerId) {
            return [.tradeAlreadyAccepted()]
        }
        
        return []
    }
    
    private static func validateCancelTrade(playerId: String, tradeId: String, state: GameState) -> ValidationResult {
        // Find the trade
        guard let trade = state.turn.activeTrades.first(where: { $0.id == tradeId }) else {
            return [.noSuchTradeProposal()]
        }
        
        // Must be proposer
        if trade.proposerId != playerId {
            return [.invalidAction("You can only cancel your own trade")]
        }
        
        return []
    }
    
    private static func validateExecuteTrade(playerId: String, tradeId: String, withPlayerId: String, state: GameState) -> ValidationResult {
        // Find the trade
        guard let trade = state.turn.activeTrades.first(where: { $0.id == tradeId }) else {
            return [.noSuchTradeProposal()]
        }
        
        // Must be proposer
        if trade.proposerId != playerId {
            return [.invalidAction("Only the proposer can execute the trade")]
        }
        
        // Target must have accepted
        if !trade.acceptedBy.contains(withPlayerId) {
            return [.invalidAction("That player has not accepted")]
        }
        
        // Verify both parties still have resources
        guard let proposer = state.player(id: playerId),
              let accepter = state.player(id: withPlayerId) else {
            return [.invalidAction("Player not found")]
        }
        
        var violations: [Violation] = []
        if !proposer.resources.contains(trade.offering) {
            violations.append(.insufficientResources(need: "your offered resources"))
        }
        if !accepter.resources.contains(trade.requesting) {
            violations.append(.insufficientResources(need: "accepter's resources"))
        }
        
        return violations
    }
    
    private static func validateMaritimeTrade(playerId: String, giving: ResourceType, givingAmount: Int, receiving: ResourceType, state: GameState) -> ValidationResult {
        var violations: [Violation] = []
        
        // Must be active player in main phase
        guard state.turn.activePlayerId == playerId else {
            return [.notYourTurn()]
        }
        guard state.turn.phase == .main else {
            return [.wrongPhase(expected: "main", actual: state.turn.phase.rawValue)]
        }
        
        guard let player = state.player(id: playerId) else {
            return [.invalidAction("Player not found")]
        }
        
        // Check trade ratio
        let requiredRatio = state.tradeRatio(for: playerId, resource: giving)
        if givingAmount != requiredRatio {
            violations.append(.invalidTradeRatio())
        }
        
        // Check player has resources
        if player.resources[giving] < givingAmount {
            violations.append(.insufficientResources(need: "\(givingAmount) \(giving.rawValue)"))
        }
        
        // Check bank has resource to give
        if !state.bank.has(receiving, amount: 1) {
            violations.append(.invalidAction("Bank has no \(receiving.rawValue)"))
        }
        
        return violations
    }
    
    // MARK: - Turn Control Validation
    
    private static func validateEndTurn(playerId: String, state: GameState) -> ValidationResult {
        // Must be active player
        guard state.turn.activePlayerId == playerId else {
            return [.notYourTurn()]
        }
        
        // Must be in main phase (not in middle of something)
        guard state.turn.phase == .main else {
            switch state.turn.phase {
            case .preRoll:
                return [.mustRollFirst()]
            case .discarding:
                return [.mustDiscardFirst()]
            case .movingRobber:
                return [.mustMoveRobber()]
            case .stealing:
                return [.mustStealFirst()]
            default:
                return [.wrongPhase(expected: "main", actual: state.turn.phase.rawValue)]
            }
        }
        
        // Cannot end turn during Road Building
        if state.turn.roadBuildingRoadsRemaining > 0 {
            return [.invalidAction("Must finish placing Road Building roads")]
        }
        
        return []
    }
    
    // MARK: - 5-6 Player Extension
    
    private static func validatePassPairedMarker(playerId: String, state: GameState) -> ValidationResult {
        guard state.turn.isPairedTurn else {
            return [.invalidAction("Not a paired turn")]
        }
        guard state.turn.pairedMarkerWith == playerId else {
            return [.invalidAction("You don't have the marker")]
        }
        return []
    }
    
    private static func validateSupplyTrade(playerId: String, giving: ResourceType, receiving: ResourceType, state: GameState) -> ValidationResult {
        var violations: [Violation] = []
        
        // Must be player 2 in a paired turn with marker
        guard state.turn.isPairedTurn else {
            return [.invalidAction("Not a paired turn")]
        }
        guard state.turn.pairedPlayer2Id == playerId && state.turn.pairedMarkerWith == playerId else {
            return [.invalidAction("Only player 2 with marker can supply trade")]
        }
        
        guard let player = state.player(id: playerId) else {
            return [.invalidAction("Player not found")]
        }
        
        // Check player has resource
        if player.resources[giving] < 1 {
            violations.append(.insufficientResources(need: "1 \(giving.rawValue)"))
        }
        
        // Check bank has resource
        if !state.bank.has(receiving, amount: 1) {
            violations.append(.invalidAction("Bank has no \(receiving.rawValue)"))
        }
        
        return violations
    }
    
    // MARK: - Helpers
    
    private static func isAdjacentToPlayerNetwork(playerId: String, nodeIds: [Int], state: GameState) -> Bool {
        guard let player = state.player(id: playerId) else { return false }
        
        for nodeId in nodeIds {
            // Check if player has a building at this node
            if player.settlements.contains(nodeId) || player.cities.contains(nodeId) {
                return true
            }
            
            // Check if player has a road from this node
            if let node = state.board.node(id: nodeId) {
                for edgeId in node.adjacentEdgeIds {
                    if player.roads.contains(edgeId) {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    /// Find players who can be stolen from at a given hex.
    public static func findEligibleStealVictims(hexId: Int, thiefId: String, state: GameState) -> [String] {
        var victims: Set<String> = []
        
        // Get all nodes adjacent to this hex
        let adjacentNodes = state.board.nodes(adjacentToHex: hexId)
        
        for node in adjacentNodes {
            if let (_, ownerId) = state.buildings.building(at: node.id) {
                if ownerId != thiefId {
                    victims.insert(ownerId)
                }
            }
        }
        
        // Filter to those with resources
        return victims.filter { playerId in
            if let player = state.player(id: playerId) {
                return player.totalResources > 0
            }
            return false
        }
    }
}

