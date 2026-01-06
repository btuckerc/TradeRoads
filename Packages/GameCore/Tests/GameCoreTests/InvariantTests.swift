import XCTest
@testable import GameCore
import CatanProtocol

/// Property and invariant tests to ensure game rules are always respected.
final class InvariantTests: XCTestCase {
    
    // MARK: - Resource Invariants
    
    func testNoNegativeResources() {
        var rng = SeededRNG(seed: 42)
        let config = GameConfig(gameId: "test", playerMode: .threeToFour, useBeginnerLayout: true)
        let playerInfos = [
            ("u1", "P1", PlayerColor.red),
            ("u2", "P2", PlayerColor.blue),
            ("u3", "P3", PlayerColor.white),
        ]
        
        var state = GameState.new(config: config, playerInfos: playerInfos, rng: &rng)
        
        // Simulate many random resource operations
        for _ in 0..<100 {
            for player in state.players {
                // Verify no negative resources
                XCTAssertGreaterThanOrEqual(player.resources.brick, 0)
                XCTAssertGreaterThanOrEqual(player.resources.lumber, 0)
                XCTAssertGreaterThanOrEqual(player.resources.ore, 0)
                XCTAssertGreaterThanOrEqual(player.resources.grain, 0)
                XCTAssertGreaterThanOrEqual(player.resources.wool, 0)
            }
            
            // Add some resources randomly
            let playerId = state.players.randomElement()!.id
            let resources = ResourceBundle(
                brick: Int.random(in: 0...3),
                lumber: Int.random(in: 0...3),
                ore: Int.random(in: 0...3),
                grain: Int.random(in: 0...3),
                wool: Int.random(in: 0...3)
            )
            state = state.updatingPlayer(id: playerId) { $0.adding(resources: resources) }
            
            // Remove some resources randomly (clamped by the implementation)
            let toRemove = ResourceBundle(
                brick: Int.random(in: 0...5),
                lumber: Int.random(in: 0...5),
                ore: Int.random(in: 0...5),
                grain: Int.random(in: 0...5),
                wool: Int.random(in: 0...5)
            )
            state = state.updatingPlayer(id: playerId) { $0.removing(resources: toRemove) }
        }
        
        // Final check
        for player in state.players {
            XCTAssertGreaterThanOrEqual(player.resources.brick, 0)
            XCTAssertGreaterThanOrEqual(player.resources.lumber, 0)
            XCTAssertGreaterThanOrEqual(player.resources.ore, 0)
            XCTAssertGreaterThanOrEqual(player.resources.grain, 0)
            XCTAssertGreaterThanOrEqual(player.resources.wool, 0)
        }
    }
    
    // MARK: - Piece Supply Invariants
    
    func testCannotExceedPieceSupply() {
        var rng = SeededRNG(seed: 42)
        let config = GameConfig(gameId: "test", playerMode: .threeToFour, useBeginnerLayout: true)
        let playerInfos = [
            ("u1", "P1", PlayerColor.red),
            ("u2", "P2", PlayerColor.blue),
            ("u3", "P3", PlayerColor.white),
        ]
        
        let state = GameState.new(config: config, playerInfos: playerInfos, rng: &rng)
        
        for player in state.players {
            XCTAssertEqual(player.remainingSettlements, GameConstants.maxSettlements)
            XCTAssertEqual(player.remainingCities, GameConstants.maxCities)
            XCTAssertEqual(player.remainingRoads, GameConstants.maxRoads)
        }
        
        // Verify adding pieces decrements remaining
        var testPlayer = state.players[0]
        for i in 0..<GameConstants.maxSettlements {
            testPlayer = testPlayer.adding(settlement: i * 10)
        }
        XCTAssertEqual(testPlayer.remainingSettlements, 0)
        XCTAssertEqual(testPlayer.settlements.count, GameConstants.maxSettlements)
        
        for i in 0..<GameConstants.maxRoads {
            testPlayer = testPlayer.adding(road: i * 10)
        }
        XCTAssertEqual(testPlayer.remainingRoads, 0)
        XCTAssertEqual(testPlayer.roads.count, GameConstants.maxRoads)
    }
    
    // MARK: - Distance Rule Invariant
    
    func testDistanceRuleAlwaysEnforced() {
        var rng = SeededRNG(seed: 42)
        let config = GameConfig(gameId: "test", playerMode: .threeToFour, useBeginnerLayout: true)
        let playerInfos = [
            ("u1", "P1", PlayerColor.red),
            ("u2", "P2", PlayerColor.blue),
            ("u3", "P3", PlayerColor.white),
        ]
        
        var state = GameState.new(config: config, playerInfos: playerInfos, rng: &rng)
        state.turn.phase = .main
        state.turn.activePlayerId = "player-0"
        
        // Place a settlement
        state.buildings = state.buildings.placingSettlement(at: 0, playerId: "player-0")
        state = state.updatingPlayer(id: "player-0") {
            $0.adding(settlement: 0).adding(road: 0).adding(resources: .settlementCost)
        }
        state.buildings = state.buildings.placingRoad(at: 0, playerId: "player-0")
        
        // Try to place at all adjacent nodes - should all fail
        if let node = state.board.node(id: 0) {
            for adjNodeId in node.adjacentNodeIds {
                // Give player resources and road access
                state = state.updatingPlayer(id: "player-0") { $0.adding(resources: .settlementCost) }
                
                let action = GameAction.buildSettlement(playerId: "player-0", nodeId: adjNodeId)
                let violations = Validator.validate(action, state: state)
                
                XCTAssertTrue(violations.contains { $0.code == .violatesDistanceRule },
                             "Settlement at node \(adjNodeId) should violate distance rule")
            }
        }
    }
    
    // MARK: - Robber Blocks Production
    
    func testRobberBlocksProduction() {
        var rng = SeededRNG(seed: 42)
        let config = GameConfig(gameId: "test", playerMode: .threeToFour, useBeginnerLayout: true)
        let playerInfos = [
            ("u1", "P1", PlayerColor.red),
            ("u2", "P2", PlayerColor.blue),
            ("u3", "P3", PlayerColor.white),
        ]
        
        var state = GameState.new(config: config, playerInfos: playerInfos, rng: &rng)
        
        // Find a non-desert hex with a number
        let productiveHex = state.board.hexes.first { $0.terrain != .desert && $0.numberToken != nil }!
        let hexNode = state.board.nodes(adjacentToHex: productiveHex.id).first!
        
        // Place settlement
        state.buildings = state.buildings.placingSettlement(at: hexNode.id, playerId: "player-0")
        state = state.updatingPlayer(id: "player-0") { $0.adding(settlement: hexNode.id) }
        
        // Move robber to that hex
        state.robberHexId = productiveHex.id
        
        // Simulate rolling the number on that hex
        state.turn.phase = .preRoll
        
        // Roll many times with different seeds looking for the target number
        let targetNumber = productiveHex.numberToken!
        
        for seed in 1..<10000 {
            var testRng = SeededRNG(seed: UInt64(seed))
            let roll = DiceRoll.roll(using: &testRng)
            
            if roll.total == targetNumber {
                var testRng2 = SeededRNG(seed: UInt64(seed))
                let (newState, events) = Reducer.reduce(state, action: .rollDice(playerId: "player-0"), rng: &testRng2)
                
                // Player should NOT have received resources from the robbed hex
                let resourcesEvent = events.first {
                    if case .resourcesProduced(let productions) = $0 {
                        return productions.contains { prod in
                            prod.sources.contains { $0.hexId == productiveHex.id }
                        }
                    }
                    return false
                }
                
                XCTAssertNil(resourcesEvent, "Robbed hex should not produce resources")
                return
            }
        }
    }
    
    // MARK: - Event Replay Consistency
    
    func testEventReplayProducesSameState() {
        var rng = SeededRNG(seed: 42)
        let config = GameConfig(gameId: "test", playerMode: .threeToFour, useBeginnerLayout: true)
        let playerInfos = [
            ("u1", "P1", PlayerColor.red),
            ("u2", "P2", PlayerColor.blue),
            ("u3", "P3", PlayerColor.white),
        ]
        
        var state = GameState.new(config: config, playerInfos: playerInfos, rng: &rng)
        var allEvents: [DomainEvent] = []
        
        // Perform some actions and collect events
        let actions: [GameAction] = [
            .setupPlaceSettlement(playerId: "player-0", nodeId: 0),
            .setupPlaceRoad(playerId: "player-0", edgeId: 0),
            .setupPlaceSettlement(playerId: "player-1", nodeId: 10),
            .setupPlaceRoad(playerId: "player-1", edgeId: 10),
        ]
        
        for action in actions {
            if Validator.validate(action, state: state).isValid {
                let (newState, events) = Reducer.reduce(state, action: action, rng: &rng)
                state = newState
                allEvents.append(contentsOf: events)
            }
        }
        
        // Now replay events on a fresh state
        var rng2 = SeededRNG(seed: 42)
        let initialState = GameState.new(config: config, playerInfos: playerInfos, rng: &rng2)
        let replayedState = GameState.rebuild(from: allEvents, initialState: initialState)
        
        // Compare key state properties - buildings should match exactly
        XCTAssertEqual(state.buildings.settlements.count, replayedState.buildings.settlements.count)
        XCTAssertEqual(state.buildings.roads.count, replayedState.buildings.roads.count)
        
        // Verify specific placements
        for (nodeId, playerId) in state.buildings.settlements {
            XCTAssertEqual(replayedState.buildings.settlements[nodeId], playerId)
        }
        for (edgeId, playerId) in state.buildings.roads {
            XCTAssertEqual(replayedState.buildings.roads[edgeId], playerId)
        }
    }
    
    // MARK: - Bank Conservation
    
    func testResourcesAreConserved() {
        var rng = SeededRNG(seed: 42)
        let config = GameConfig(gameId: "test", playerMode: .threeToFour, useBeginnerLayout: true)
        let playerInfos = [
            ("u1", "P1", PlayerColor.red),
            ("u2", "P2", PlayerColor.blue),
            ("u3", "P3", PlayerColor.white),
        ]
        
        var state = GameState.new(config: config, playerInfos: playerInfos, rng: &rng)
        
        // Calculate total resources in the system
        func totalResources(_ s: GameState) -> ResourceBundle {
            var total = s.bank.resources
            for player in s.players {
                total = total + player.resources
            }
            return total
        }
        
        // Do some trades (which should conserve resources)
        state.turn.phase = .main
        state.turn.activePlayerId = "player-0"
        
        // Give player resources from the bank properly
        let toGive = ResourceBundle(brick: 5)
        guard let newBank = state.bank.taking(toGive) else {
            XCTFail("Bank should have resources")
            return
        }
        state.bank = newBank
        state = state.updatingPlayer(id: "player-0") { $0.adding(resources: toGive) }
        
        let beforeTradeTotal = totalResources(state)
        
        // Maritime trade: give 4 brick, get 1 ore
        let (afterTrade, _) = Reducer.reduce(
            state,
            action: .maritimeTrade(playerId: "player-0", giving: .brick, givingAmount: 4, receiving: .ore),
            rng: &rng
        )
        
        let afterTradeTotal = totalResources(afterTrade)
        
        // Maritime trade is 4:1, so total resources should stay the same
        XCTAssertEqual(beforeTradeTotal.total, afterTradeTotal.total)
    }
    
    // MARK: - Victory Point Calculation
    
    func testVictoryPointCalculationIsConsistent() {
        var rng = SeededRNG(seed: 42)
        let config = GameConfig(gameId: "test", playerMode: .threeToFour, useBeginnerLayout: true)
        let playerInfos = [
            ("u1", "P1", PlayerColor.red),
            ("u2", "P2", PlayerColor.blue),
            ("u3", "P3", PlayerColor.white),
        ]
        
        var state = GameState.new(config: config, playerInfos: playerInfos, rng: &rng)
        
        // Give player 0 various VP sources
        state = state.updatingPlayer(id: "player-0") {
            var p = $0
            p.settlements = [1, 2]  // 2 settlements = 2 VP
            p.cities = [3]  // 1 city = 2 VP (cities are worth 2 each)
            return p
        }
        state.awards.longestRoadHolder = "player-0"  // 2 VP
        state.awards.largestArmyHolder = "player-0"  // 2 VP
        
        let vpCard = DevelopmentCard(id: "vp", type: .victoryPoint, isPlayed: false, boughtThisTurn: false)
        state = state.updatingPlayer(id: "player-0") { $0.adding(developmentCard: vpCard) }  // 1 VP
        
        let breakdown = state.victoryPoints(for: "player-0")
        
        // breakdown stores counts, total computes VP value
        XCTAssertEqual(breakdown.settlements, 2)  // 2 settlements
        XCTAssertEqual(breakdown.cities, 1)  // 1 city
        XCTAssertEqual(breakdown.longestRoad, 2)  // 2 VP for longest road
        XCTAssertEqual(breakdown.largestArmy, 2)  // 2 VP for largest army
        XCTAssertEqual(breakdown.victoryPointCards, 1)  // 1 VP card
        
        // Total: 2 (settlements) + 2 (1 city * 2) + 2 (road) + 2 (army) + 1 (VP card) = 9
        XCTAssertEqual(breakdown.total, 9)
        XCTAssertEqual(state.totalVictoryPoints(for: "player-0"), 9)
    }
}

