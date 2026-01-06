import Vapor
import Fluent
import GameCore

/// Result of processing a game action.
enum ActionResult: Sendable {
    case success([DomainEvent])
    case rejected([RuleViolation])
    case error(String)
}

/// Game engine that processes actions and maintains state.
/// This actor ensures serialized access to game state.
actor GameEngine {
    let gameId: String
    private var state: GameState
    private let players: [GamePlayerInfo]
    private let db: any Database
    
    /// Snapshot every N events.
    private let snapshotInterval = 50
    
    /// RNG for dice and card draws.
    private var rng = SystemRNG()
    
    init(
        gameId: String,
        initialState: GameState,
        players: [GamePlayerInfo],
        db: any Database
    ) {
        self.gameId = gameId
        self.state = initialState
        self.players = players
        self.db = db
    }
    
    /// Get player ID for a user ID.
    func playerIdForUser(_ userId: String) -> String {
        players.first { $0.userId == userId }?.playerId ?? ""
    }
    
    /// Get current game state.
    func currentState() -> GameState {
        state
    }
    
    /// Get current event index.
    func currentEventIndex() -> Int {
        state.eventIndex
    }
    
    /// Check if a user is a player in this game.
    func isPlayer(_ userId: String) -> Bool {
        players.contains { $0.userId == userId }
    }
    
    /// Process a game action.
    func processAction(_ action: GameAction) async -> ActionResult {
        // Validate action
        let violations = Validator.validate(action, state: state)
        
        if !violations.isValid {
            return .rejected(violations.map { v in
                RuleViolation(code: v.code, message: v.message)
            })
        }
        
        // Apply action
        let (newState, events) = Reducer.reduce(state, action: action, rng: &rng)
        state = newState
        
        // Persist events
        do {
            let baseIndex = state.eventIndex - events.count
            for (i, event) in events.enumerated() {
                let gameEvent = try GameEventModel(
                    gameId: UUID(uuidString: gameId)!,
                    eventIndex: baseIndex + i + 1,
                    event: event
                )
                try await gameEvent.save(on: db)
            }
            
            // Update game record
            if let game = try await Game.find(UUID(uuidString: gameId), on: db) {
                game.eventCount = state.eventIndex
                game.updatedAt = Date()
                
                if let winnerId = state.winnerId,
                   let winner = players.first(where: { $0.playerId == winnerId }) {
                    game.winnerUserId = UUID(uuidString: winner.userId)
                    game.status = "completed"
                }
                
                try await game.save(on: db)
            }
            
            // Maybe snapshot
            if state.eventIndex % snapshotInterval == 0 {
                try await createSnapshot()
            }
        } catch {
            return .error("Failed to persist events: \(error.localizedDescription)")
        }
        
        return .success(events)
    }
    
    /// Get events since a given index.
    func getEventsSince(_ index: Int) async throws -> [DomainEvent] {
        guard let gameUUID = UUID(uuidString: gameId) else { return [] }
        
        let events = try await GameEventModel.query(on: db)
            .filter(\.$game.$id == gameUUID)
            .filter(\.$eventIndex > index)
            .sort(\.$eventIndex)
            .all()
        
        return try events.map { try $0.decodeEvent() }
    }
    
    /// Create a snapshot of current state.
    private func createSnapshot() async throws {
        let snapshot = try GameSnapshotModel(
            gameId: UUID(uuidString: gameId)!,
            eventIndex: state.eventIndex,
            state: state
        )
        try await snapshot.save(on: db)
    }
}

/// Converts GameCore DomainEvents to protocol GameDomainEvents.
enum EventConverter {
    /// Convert GameCore DomainEvent to protocol GameDomainEvent.
    static func toProtocol(_ event: DomainEvent) -> GameDomainEvent {
        switch event {
        case .gameCreated:
            return .setupPhaseEnded  // Handled separately via GameStartedEvent
            
        case .gameStarted:
            return .setupPhaseEnded  // Handled separately
            
        case .setupPhaseStarted(let playerId):
            return .setupPhaseStarted(SetupPhaseStartedEvent(firstPlayerId: playerId))
            
        case .setupSettlementPlaced(let playerId, let nodeId, let round):
            return .setupPiecePlaced(SetupPiecePlacedEvent(playerId: playerId, pieceType: .settlement, locationId: nodeId, round: round))
            
        case .setupRoadPlaced(let playerId, let edgeId, let round):
            return .setupPiecePlaced(SetupPiecePlacedEvent(playerId: playerId, pieceType: .road, locationId: edgeId, round: round))
            
        case .setupResourcesGiven(let playerId, let resources):
            // This is an internal event, not exposed to clients directly
            // Instead it manifests as the player's hand being updated
            return .resourcesProduced(ResourcesProducedEvent(
                diceTotal: 0,
                production: [PlayerProduction(playerId: playerId, resources: resources, sources: [])]
            ))
            
        case .setupTurnAdvanced(let nextPlayerId, let setupRound, let setupPlayerIndex, let setupForward):
            return .setupTurnAdvanced(SetupTurnAdvancedEvent(
                nextPlayerId: nextPlayerId,
                setupRound: setupRound,
                setupPlayerIndex: setupPlayerIndex,
                setupForward: setupForward
            ))
            
        case .setupPhaseEnded:
            return .setupPhaseEnded
            
        case .turnStarted(let playerId, let turnNumber):
            return .turnStarted(TurnStartedEvent(playerId: playerId, turnNumber: turnNumber))
            
        case .diceRolled(let playerId, let die1, let die2):
            return .diceRolled(DiceRolledEvent(playerId: playerId, die1: die1, die2: die2))
            
        case .resourcesProduced(let productions):
            let diceTotal = productions.first?.sources.first.map { _ in 0 } ?? 0
            return .resourcesProduced(ResourcesProducedEvent(
                diceTotal: diceTotal,
                production: productions.map { p in
                    PlayerProduction(
                        playerId: p.playerId,
                        resources: p.resources,
                        sources: p.sources.map { s in
                            ProductionSource(hexId: s.hexId, nodeId: s.nodeId, buildingType: s.buildingType, resource: s.resource, amount: s.amount)
                        }
                    )
                }
            ))
            
        case .noResourcesProduced(let total, let reason):
            return .noResourcesProduced(NoResourcesProducedEvent(diceTotal: total, reason: reason))
            
        case .turnEnded(let playerId, let turnNumber):
            return .turnEnded(TurnEndedEvent(playerId: playerId, turnNumber: turnNumber))
            
        case .discardRequired(let requirements):
            return .mustDiscard(MustDiscardEvent(playerDiscardRequirements: requirements.map { r in
                PlayerDiscardRequirement(playerId: r.playerId, currentCount: r.currentCount, mustDiscard: r.mustDiscard)
            }))
            
        case .resourcesDiscarded(let playerId, let resources):
            return .playerDiscarded(PlayerDiscardedEvent(playerId: playerId, discarded: resources))
            
        case .robberMoved(let playerId, let from, let to, let victims):
            return .robberMoved(RobberMovedEvent(playerId: playerId, fromHexId: from, toHexId: to, eligibleVictims: victims))
            
        case .resourceStolen(let thief, let victim, let resource):
            return .resourceStolen(ResourceStolenEvent(thiefId: thief, victimId: victim, resourceType: resource))
            
        case .noStealPossible:
            // No direct equivalent; robberMoved with empty eligibleVictims handles this
            return .setupPhaseEnded  // Placeholder, this event won't typically be sent
            
        case .roadBuilt(let playerId, let edgeId, let cost):
            return .roadBuilt(RoadBuiltEvent(playerId: playerId, edgeId: edgeId, wasFree: cost.isEmpty, resourcesSpent: cost))
            
        case .settlementBuilt(let playerId, let nodeId, let cost):
            return .settlementBuilt(SettlementBuiltEvent(playerId: playerId, nodeId: nodeId, wasFree: cost.isEmpty, resourcesSpent: cost))
            
        case .cityBuilt(let playerId, let nodeId, let cost):
            return .cityBuilt(CityBuiltEvent(playerId: playerId, nodeId: nodeId, resourcesSpent: cost))
            
        case .developmentCardBought(let playerId, _, let cardType, let cost):
            return .developmentCardBought(DevelopmentCardBoughtEvent(playerId: playerId, cardType: cardType, resourcesSpent: cost))
            
        case .knightPlayed(let playerId, _, let to):
            return .knightPlayed(KnightPlayedEvent(playerId: playerId, robberFromHexId: 0, robberToHexId: to, knightsPlayed: 0))
            
        case .roadBuildingPlayed(let playerId, _):
            return .roadBuildingPlayed(RoadBuildingPlayedEvent(playerId: playerId, firstEdgeId: 0, secondEdgeId: nil))
            
        case .roadBuildingRoadPlaced(let playerId, let edgeId, _):
            // Use roadBuilt for the individual road placements
            return .roadBuilt(RoadBuiltEvent(playerId: playerId, edgeId: edgeId, wasFree: true, resourcesSpent: .zero))
            
        case .yearOfPlentyPlayed(let playerId, _, let r1, let r2):
            return .yearOfPlentyPlayed(YearOfPlentyPlayedEvent(playerId: playerId, firstResource: r1, secondResource: r2))
            
        case .monopolyPlayed(let playerId, _, let resource, let amounts):
            return .monopolyPlayed(MonopolyPlayedEvent(
                playerId: playerId,
                resourceType: resource,
                stolenAmounts: amounts.map { PlayerResourceStolen(playerId: $0.key, amount: $0.value) },
                totalStolen: amounts.values.reduce(0, +)
            ))
            
        case .victoryPointRevealed(let playerId, let count):
            return .victoryPointRevealed(VictoryPointRevealedEvent(playerId: playerId, cardCount: count))
            
        case .tradeProposed(let proposal):
            return .tradeProposed(TradeProposedEvent(
                tradeId: proposal.id,
                proposerId: proposal.proposerId,
                offering: proposal.offering,
                requesting: proposal.requesting,
                targetPlayerIds: proposal.targetPlayerIds
            ))
            
        case .tradeAccepted(let tradeId, let accepterId):
            return .tradeAccepted(TradeAcceptedEvent(tradeId: tradeId, accepterId: accepterId))
            
        case .tradeRejected(let tradeId, let rejecterId):
            return .tradeRejected(TradeRejectedEvent(tradeId: tradeId, rejecterId: rejecterId))
            
        case .tradeCancelled(let tradeId, let reason):
            return .tradeCancelled(TradeCancelledEvent(tradeId: tradeId, reason: reason))
            
        case .tradeExecuted(let tradeId, let proposer, let accepter, let gave, let got):
            return .tradeExecuted(TradeExecutedEvent(tradeId: tradeId, proposerId: proposer, accepterId: accepter, proposerGave: gave, accepterGave: got))
            
        case .maritimeTradeExecuted(let playerId, let gave, let amount, let got):
            return .maritimeTradeExecuted(MaritimeTradeExecutedEvent(playerId: playerId, gave: gave, gaveAmount: amount, received: got, harborType: nil))
            
        case .longestRoadAwarded(let new, let prev, let length):
            return .longestRoadAwarded(LongestRoadAwardedEvent(newHolderId: new, previousHolderId: prev, roadLength: length))
            
        case .largestArmyAwarded(let new, let prev, let count):
            return .largestArmyAwarded(LargestArmyAwardedEvent(newHolderId: new, previousHolderId: prev, knightCount: count))
            
        case .playerWon(let playerId, let vp, let breakdown):
            return .playerWon(PlayerWonEvent(playerId: playerId, victoryPoints: vp, breakdown: breakdown))
            
        case .pairedTurnStarted(let p1, let p2, let turn):
            return .pairedTurnStarted(PairedTurnStartedEvent(player1Id: p1, player2Id: p2, turnNumber: turn))
            
        case .pairedMarkerPassed(let from, let to):
            return .pairedMarkerPassed(PairedMarkerPassedEvent(fromPlayerId: from, toPlayerId: to))
            
        case .supplyTradeExecuted(let playerId, let gave, let got):
            return .supplyTradeExecuted(SupplyTradeExecutedEvent(playerId: playerId, gave: gave, received: got))
        }
    }
}
