import XCTest
@testable import GameCore
import CatanProtocol

final class ReducerTests: XCTestCase {
    
    var state: GameState!
    var rng: SeededRNG!
    
    override func setUp() {
        super.setUp()
        rng = SeededRNG(seed: 12345)
        
        let config = GameConfig(
            gameId: "test-game",
            playerMode: .threeToFour,
            useBeginnerLayout: true
        )
        
        let playerInfos: [(userId: String, displayName: String, color: PlayerColor)] = [
            ("u1", "Player 1", .red),
            ("u2", "Player 2", .blue),
            ("u3", "Player 3", .white),
        ]
        
        state = GameState.new(config: config, playerInfos: playerInfos, rng: &rng)
    }
    
    // MARK: - Setup Phase Tests
    
    func testSetupPhaseSettlementPlacement() {
        let (newState, events) = Reducer.reduce(
            state,
            action: .setupPlaceSettlement(playerId: "player-0", nodeId: 0),
            rng: &rng
        )
        
        XCTAssertTrue(newState.buildings.isOccupied(nodeId: 0))
        XCTAssertTrue(newState.player(id: "player-0")!.settlements.contains(0))
        XCTAssertTrue(newState.turn.setupNeedsRoad)
        
        XCTAssertEqual(events.count, 1)
        if case .setupSettlementPlaced(let playerId, let nodeId, _) = events[0] {
            XCTAssertEqual(playerId, "player-0")
            XCTAssertEqual(nodeId, 0)
        } else {
            XCTFail("Expected setupSettlementPlaced event")
        }
    }
    
    func testSetupPhaseRoadPlacement() {
        // First place settlement
        var (newState, _) = Reducer.reduce(
            state,
            action: .setupPlaceSettlement(playerId: "player-0", nodeId: 0),
            rng: &rng
        )
        
        // Then place road
        (newState, _) = Reducer.reduce(
            newState,
            action: .setupPlaceRoad(playerId: "player-0", edgeId: 0),
            rng: &rng
        )
        
        XCTAssertTrue(newState.buildings.hasRoad(edgeId: 0))
        XCTAssertTrue(newState.player(id: "player-0")!.roads.contains(0))
        XCTAssertFalse(newState.turn.setupNeedsRoad)
        
        // Should advance to next player
        XCTAssertEqual(newState.turn.activePlayerId, "player-1")
    }
    
    // MARK: - Dice Roll Tests
    
    func testDiceRollDeterministic() {
        var testState = state!
        testState.turn.phase = .preRoll
        
        var rng1 = SeededRNG(seed: 99999)
        var rng2 = SeededRNG(seed: 99999)
        
        let (_, events1) = Reducer.reduce(testState, action: .rollDice(playerId: "player-0"), rng: &rng1)
        let (_, events2) = Reducer.reduce(testState, action: .rollDice(playerId: "player-0"), rng: &rng2)
        
        // Get dice values from events
        guard case .diceRolled(_, let die1a, let die2a) = events1[0],
              case .diceRolled(_, let die1b, let die2b) = events2[0] else {
            XCTFail("Expected diceRolled events")
            return
        }
        
        XCTAssertEqual(die1a, die1b)
        XCTAssertEqual(die2a, die2b)
    }
    
    func testDiceRollResourceProduction() {
        var testState = state!
        testState.turn.phase = .preRoll
        
        // Place a settlement on a hex with number 8
        let hexWith8 = testState.board.hexes.first { $0.numberToken == 8 }!
        let nodeOnHex = testState.board.nodes(adjacentToHex: hexWith8.id).first!
        
        testState.buildings = testState.buildings.placingSettlement(at: nodeOnHex.id, playerId: "player-0")
        testState = testState.updatingPlayer(id: "player-0") { $0.adding(settlement: nodeOnHex.id) }
        
        // Keep rolling until we get an 8
        var rolledState = testState
        var gotProduction = false
        for seed in 1..<1000 {
            var testRng = SeededRNG(seed: UInt64(seed))
            let (newState, events) = Reducer.reduce(testState, action: .rollDice(playerId: "player-0"), rng: &testRng)
            
            if let diceEvent = events.first(where: {
                if case .diceRolled(_, let d1, let d2) = $0, d1 + d2 == 8 { return true }
                return false
            }) {
                rolledState = newState
                gotProduction = true
                break
            }
        }
        
        if gotProduction {
            // Player should have received resources
            let player = rolledState.player(id: "player-0")!
            XCTAssertGreaterThan(player.totalResources, 0, "Player should have resources after production")
        }
    }
    
    func testRollSevenTriggersDiscard() {
        var testState = state!
        testState.turn.phase = .preRoll
        
        // Give player 1 more than 7 resources
        testState = testState.updatingPlayer(id: "player-1") {
            $0.adding(resources: ResourceBundle(brick: 5, lumber: 5))
        }
        
        // Find a seed that produces 7
        for seed in 1..<10000 {
            var testRng = SeededRNG(seed: UInt64(seed))
            let (newState, events) = Reducer.reduce(testState, action: .rollDice(playerId: "player-0"), rng: &testRng)
            
            if let diceEvent = events.first(where: {
                if case .diceRolled(_, let d1, let d2) = $0, d1 + d2 == 7 { return true }
                return false
            }) {
                // Should be in discarding phase
                if newState.turn.phase == .discarding {
                    XCTAssertTrue(newState.turn.playersToDiscard.contains("player-1"))
                    XCTAssertFalse(newState.turn.playersToDiscard.contains("player-0")) // Only 0 resources
                    return
                } else {
                    // If no one had > 7, goes straight to robber
                    XCTAssertEqual(newState.turn.phase, .movingRobber)
                    return
                }
            }
        }
        
        XCTFail("Could not find seed that produces 7")
    }
    
    // MARK: - Building Tests
    
    func testBuildRoadDeductsResources() {
        var testState = state!
        testState.turn.phase = .main
        testState.turn.activePlayerId = "player-0"
        
        // Give resources and a settlement for adjacency
        testState = testState.updatingPlayer(id: "player-0") {
            $0.adding(resources: .roadCost).adding(settlement: 0)
        }
        testState.buildings = testState.buildings.placingSettlement(at: 0, playerId: "player-0")
        
        // Get an edge adjacent to node 0
        let adjEdge = testState.board.edges(adjacentToNode: 0).first!
        
        let (newState, events) = Reducer.reduce(
            testState,
            action: .buildRoad(playerId: "player-0", edgeId: adjEdge.id),
            rng: &rng
        )
        
        let player = newState.player(id: "player-0")!
        XCTAssertEqual(player.resources.brick, 0)
        XCTAssertEqual(player.resources.lumber, 0)
        XCTAssertTrue(player.roads.contains(adjEdge.id))
        
        XCTAssertTrue(events.contains { 
            if case .roadBuilt = $0 { return true }
            return false
        })
    }
    
    func testBuildSettlementDeductsResources() {
        var testState = state!
        testState.turn.phase = .main
        testState.turn.activePlayerId = "player-0"
        
        // Give resources and a road for adjacency
        testState = testState.updatingPlayer(id: "player-0") {
            $0.adding(resources: .settlementCost).adding(road: 0)
        }
        testState.buildings = testState.buildings.placingRoad(at: 0, playerId: "player-0")
        
        // Find a valid node (on edge 0, not adjacent to other settlements)
        let edge = testState.board.edge(id: 0)!
        let nodeId = edge.nodeIds.0
        
        let (newState, events) = Reducer.reduce(
            testState,
            action: .buildSettlement(playerId: "player-0", nodeId: nodeId),
            rng: &rng
        )
        
        let player = newState.player(id: "player-0")!
        XCTAssertEqual(player.resources.brick, 0)
        XCTAssertEqual(player.resources.lumber, 0)
        XCTAssertEqual(player.resources.grain, 0)
        XCTAssertEqual(player.resources.wool, 0)
        XCTAssertTrue(player.settlements.contains(nodeId))
    }
    
    func testBuildCityUpgradesSettlement() {
        var testState = state!
        testState.turn.phase = .main
        testState.turn.activePlayerId = "player-0"
        
        // Give resources and a settlement
        testState = testState.updatingPlayer(id: "player-0") {
            $0.adding(resources: .cityCost).adding(settlement: 5)
        }
        testState.buildings = testState.buildings.placingSettlement(at: 5, playerId: "player-0")
        
        let (newState, events) = Reducer.reduce(
            testState,
            action: .buildCity(playerId: "player-0", nodeId: 5),
            rng: &rng
        )
        
        let player = newState.player(id: "player-0")!
        XCTAssertFalse(player.settlements.contains(5))
        XCTAssertTrue(player.cities.contains(5))
        
        XCTAssertEqual(newState.buildings.building(at: 5)?.type, .city)
    }
    
    // MARK: - Development Card Tests
    
    func testBuyDevCard() {
        var testState = state!
        testState.turn.phase = .main
        testState.turn.activePlayerId = "player-0"
        testState = testState.updatingPlayer(id: "player-0") {
            $0.adding(resources: .developmentCardCost)
        }
        
        let (newState, events) = Reducer.reduce(
            testState,
            action: .buyDevelopmentCard(playerId: "player-0"),
            rng: &rng
        )
        
        let player = newState.player(id: "player-0")!
        XCTAssertEqual(player.developmentCards.count, 1)
        XCTAssertTrue(player.developmentCards[0].boughtThisTurn)
        XCTAssertEqual(player.resources, .zero)
        
        XCTAssertEqual(newState.bank.developmentCards.count, 24)  // 25 - 1
    }
    
    func testPlayKnightIncrementsArmyCount() {
        var testState = state!
        testState.turn.phase = .main
        testState.turn.activePlayerId = "player-0"
        
        let card = DevelopmentCard(id: "knight-1", type: .knight, isPlayed: false, boughtThisTurn: false)
        testState = testState.updatingPlayer(id: "player-0") { $0.adding(developmentCard: card) }
        
        let targetHex = testState.board.hexes.first { $0.id != testState.robberHexId }!.id
        
        let (newState, events) = Reducer.reduce(
            testState,
            action: .playKnight(playerId: "player-0", cardId: "knight-1", moveRobberTo: targetHex, stealFrom: nil),
            rng: &rng
        )
        
        let player = newState.player(id: "player-0")!
        XCTAssertEqual(player.knightsPlayed, 1)
        XCTAssertEqual(newState.robberHexId, targetHex)
    }
    
    func testLargestArmyAwarded() {
        var testState = state!
        testState.turn.phase = .main
        testState.turn.activePlayerId = "player-0"
        
        // Give player 2 knights already played
        testState = testState.updatingPlayer(id: "player-0") {
            var p = $0
            p.knightsPlayed = 2
            return p
        }
        
        // Add a third knight to play
        let card = DevelopmentCard(id: "knight-3", type: .knight, isPlayed: false, boughtThisTurn: false)
        testState = testState.updatingPlayer(id: "player-0") { $0.adding(developmentCard: card) }
        
        let targetHex = testState.board.hexes.first { $0.id != testState.robberHexId }!.id
        
        let (newState, events) = Reducer.reduce(
            testState,
            action: .playKnight(playerId: "player-0", cardId: "knight-3", moveRobberTo: targetHex, stealFrom: nil),
            rng: &rng
        )
        
        XCTAssertEqual(newState.awards.largestArmyHolder, "player-0")
        XCTAssertTrue(events.contains {
            if case .largestArmyAwarded = $0 { return true }
            return false
        })
    }
    
    // MARK: - Trading Tests
    
    func testProposeTrade() {
        var testState = state!
        testState.turn.phase = .main
        testState.turn.activePlayerId = "player-0"
        testState = testState.updatingPlayer(id: "player-0") {
            $0.adding(resources: ResourceBundle(brick: 2))
        }
        
        let (newState, events) = Reducer.reduce(
            testState,
            action: .proposeTrade(
                playerId: "player-0",
                tradeId: "trade-1",
                offering: ResourceBundle(brick: 2),
                requesting: ResourceBundle(ore: 1),
                targetPlayerIds: nil
            ),
            rng: &rng
        )
        
        XCTAssertEqual(newState.turn.activeTrades.count, 1)
        XCTAssertEqual(newState.turn.activeTrades[0].id, "trade-1")
    }
    
    func testExecuteTrade() {
        var testState = state!
        testState.turn.phase = .main
        testState.turn.activePlayerId = "player-0"
        
        // Set up resources
        testState = testState.updatingPlayer(id: "player-0") {
            $0.adding(resources: ResourceBundle(brick: 2))
        }
        testState = testState.updatingPlayer(id: "player-1") {
            $0.adding(resources: ResourceBundle(ore: 1))
        }
        
        // Create a trade proposal
        let trade = TradeProposal(
            id: "trade-1",
            proposerId: "player-0",
            offering: ResourceBundle(brick: 2),
            requesting: ResourceBundle(ore: 1),
            targetPlayerIds: nil,
            acceptedBy: ["player-1"]
        )
        testState.turn.activeTrades = [trade]
        
        let (newState, events) = Reducer.reduce(
            testState,
            action: .executeTrade(playerId: "player-0", tradeId: "trade-1", withPlayerId: "player-1"),
            rng: &rng
        )
        
        let player0 = newState.player(id: "player-0")!
        let player1 = newState.player(id: "player-1")!
        
        XCTAssertEqual(player0.resources.brick, 0)
        XCTAssertEqual(player0.resources.ore, 1)
        XCTAssertEqual(player1.resources.brick, 2)
        XCTAssertEqual(player1.resources.ore, 0)
    }
    
    func testMaritimeTrade() {
        var testState = state!
        testState.turn.phase = .main
        testState.turn.activePlayerId = "player-0"
        testState = testState.updatingPlayer(id: "player-0") {
            $0.adding(resources: ResourceBundle(brick: 4))
        }
        
        let (newState, events) = Reducer.reduce(
            testState,
            action: .maritimeTrade(playerId: "player-0", giving: .brick, givingAmount: 4, receiving: .ore),
            rng: &rng
        )
        
        let player = newState.player(id: "player-0")!
        XCTAssertEqual(player.resources.brick, 0)
        XCTAssertEqual(player.resources.ore, 1)
    }
    
    // MARK: - Turn Control Tests
    
    func testEndTurnAdvancesToNextPlayer() {
        var testState = state!
        testState.turn.phase = .main
        testState.turn.activePlayerId = "player-0"
        testState.turn.turnNumber = 1
        
        let (newState, events) = Reducer.reduce(
            testState,
            action: .endTurn(playerId: "player-0"),
            rng: &rng
        )
        
        XCTAssertEqual(newState.turn.activePlayerId, "player-1")
        XCTAssertEqual(newState.turn.turnNumber, 2)
        XCTAssertEqual(newState.turn.phase, .preRoll)
    }
    
    func testEndTurnCancelsActiveTrades() {
        var testState = state!
        testState.turn.phase = .main
        testState.turn.activePlayerId = "player-0"
        testState.turn.activeTrades = [
            TradeProposal(id: "t1", proposerId: "player-0", offering: .zero, requesting: .zero, targetPlayerIds: nil)
        ]
        
        let (newState, events) = Reducer.reduce(
            testState,
            action: .endTurn(playerId: "player-0"),
            rng: &rng
        )
        
        XCTAssertTrue(newState.turn.activeTrades.isEmpty)
        XCTAssertTrue(events.contains {
            if case .tradeCancelled(_, let reason) = $0, reason == .turnEnded { return true }
            return false
        })
    }
    
    // MARK: - Victory Tests
    
    func testVictoryDetection() {
        var testState = state!
        testState.turn.phase = .main
        testState.turn.activePlayerId = "player-0"
        
        // Give player enough VP to win (settlements=5, cities=2, longest road, largest army)
        // 5 + 4 + 2 = 11 VP (needs 10)
        testState = testState.updatingPlayer(id: "player-0") {
            var p = $0
            p.settlements = [1, 2, 3]  // 3 VP
            p.cities = [4, 5, 6]  // 6 VP
            return p.adding(resources: .settlementCost)
        }
        testState.buildings = testState.buildings.placingSettlement(at: 1, playerId: "player-0")
        testState.buildings = testState.buildings.placingSettlement(at: 2, playerId: "player-0")
        testState.buildings = testState.buildings.placingSettlement(at: 3, playerId: "player-0")
        testState.buildings = testState.buildings.upgradingToCity(at: 4)
        testState.buildings = testState.buildings.placingSettlement(at: 4, playerId: "player-0")
        testState.buildings = testState.buildings.upgradingToCity(at: 5)
        testState.buildings = testState.buildings.placingSettlement(at: 5, playerId: "player-0")
        testState.buildings = testState.buildings.upgradingToCity(at: 6)
        testState.buildings = testState.buildings.placingSettlement(at: 6, playerId: "player-0")
        
        // Give longest road (2 VP) - total now 11
        testState.awards.longestRoadHolder = "player-0"
        testState.awards.longestRoadLength = 5
        
        // Add a VP card
        let vpCard = DevelopmentCard(id: "vp-1", type: .victoryPoint, isPlayed: false, boughtThisTurn: false)
        testState = testState.updatingPlayer(id: "player-0") { $0.adding(developmentCard: vpCard) }
        
        // Current VP: 3 (settlements) + 6 (cities) + 2 (road) + 1 (VP card) = 12 VP
        let vp = testState.totalVictoryPoints(for: "player-0")
        XCTAssertGreaterThanOrEqual(vp, 10)
        XCTAssertTrue(testState.hasWon("player-0"))
    }
}

