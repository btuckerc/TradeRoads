import XCTest
@testable import GameCore
import CatanProtocol

final class ValidatorTests: XCTestCase {
    
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
    
    func testSetupSettlement_ValidPlacement() {
        let action = GameAction.setupPlaceSettlement(playerId: "player-0", nodeId: 0)
        let violations = Validator.validate(action, state: state)
        
        XCTAssertTrue(violations.isValid, "Should be valid: \(violations)")
    }
    
    func testSetupSettlement_WrongPlayer() {
        let action = GameAction.setupPlaceSettlement(playerId: "player-1", nodeId: 0)
        let violations = Validator.validate(action, state: state)
        
        XCTAssertFalse(violations.isValid)
        XCTAssertTrue(violations.contains { $0.code == .notYourTurn })
    }
    
    func testSetupSettlement_InvalidNode() {
        let action = GameAction.setupPlaceSettlement(playerId: "player-0", nodeId: 9999)
        let violations = Validator.validate(action, state: state)
        
        XCTAssertFalse(violations.isValid)
        XCTAssertTrue(violations.contains { $0.code == .invalidLocation })
    }
    
    func testSetupSettlement_OccupiedNode() {
        // Place first settlement
        var (newState, _) = Reducer.reduce(state, action: .setupPlaceSettlement(playerId: "player-0", nodeId: 0), rng: &rng)
        
        // Place road to advance
        (newState, _) = Reducer.reduce(newState, action: .setupPlaceRoad(playerId: "player-0", edgeId: 0), rng: &rng)
        
        // Try to place another settlement on the same node (by another player)
        let action = GameAction.setupPlaceSettlement(playerId: "player-1", nodeId: 0)
        let violations = Validator.validate(action, state: newState)
        
        XCTAssertFalse(violations.isValid)
        XCTAssertTrue(violations.contains { $0.code == .locationOccupied })
    }
    
    func testSetupRoad_MustPlaceSettlementFirst() {
        let action = GameAction.setupPlaceRoad(playerId: "player-0", edgeId: 0)
        let violations = Validator.validate(action, state: state)
        
        XCTAssertFalse(violations.isValid)
    }
    
    // MARK: - Dice Roll Tests
    
    func testRollDice_WrongPhase() {
        // In setup phase
        let action = GameAction.rollDice(playerId: "player-0")
        let violations = Validator.validate(action, state: state)
        
        XCTAssertFalse(violations.isValid)
    }
    
    func testRollDice_NotYourTurn() {
        var testState = state!
        testState.turn.phase = .preRoll
        
        let action = GameAction.rollDice(playerId: "player-1")
        let violations = Validator.validate(action, state: testState)
        
        XCTAssertFalse(violations.isValid)
        XCTAssertTrue(violations.contains { $0.code == .notYourTurn })
    }
    
    func testRollDice_Valid() {
        var testState = state!
        testState.turn.phase = .preRoll
        
        let action = GameAction.rollDice(playerId: "player-0")
        let violations = Validator.validate(action, state: testState)
        
        XCTAssertTrue(violations.isValid)
    }
    
    // MARK: - Building Tests
    
    func testBuildRoad_WrongPhase() {
        let action = GameAction.buildRoad(playerId: "player-0", edgeId: 0)
        let violations = Validator.validate(action, state: state)
        
        XCTAssertFalse(violations.isValid)
    }
    
    func testBuildRoad_InsufficientResources() {
        var testState = state!
        testState.turn.phase = .main
        testState.turn.activePlayerId = "player-0"
        // Player has no resources
        
        let action = GameAction.buildRoad(playerId: "player-0", edgeId: 5)
        let violations = Validator.validate(action, state: testState)
        
        XCTAssertFalse(violations.isValid)
        XCTAssertTrue(violations.contains { $0.code == .insufficientResources })
    }
    
    func testBuildSettlement_DistanceRule() {
        var testState = state!
        testState.turn.phase = .main
        testState.turn.activePlayerId = "player-0"
        
        // Place a settlement at node 0
        testState.buildings = testState.buildings.placingSettlement(at: 0, playerId: "player-0")
        testState = testState.updatingPlayer(id: "player-0") {
            $0.adding(settlement: 0).adding(resources: .settlementCost).adding(road: 0)
        }
        testState.buildings = testState.buildings.placingRoad(at: 0, playerId: "player-0")
        
        // Try to place settlement at adjacent node (violates distance rule)
        if let node = testState.board.node(id: 0), let adjNodeId = node.adjacentNodeIds.first {
            let action = GameAction.buildSettlement(playerId: "player-0", nodeId: adjNodeId)
            let violations = Validator.validate(action, state: testState)
            
            XCTAssertFalse(violations.isValid)
            XCTAssertTrue(violations.contains { $0.code == .violatesDistanceRule })
        }
    }
    
    func testBuildCity_NoSettlement() {
        var testState = state!
        testState.turn.phase = .main
        testState.turn.activePlayerId = "player-0"
        testState = testState.updatingPlayer(id: "player-0") {
            $0.adding(resources: .cityCost)
        }
        
        let action = GameAction.buildCity(playerId: "player-0", nodeId: 5)
        let violations = Validator.validate(action, state: testState)
        
        XCTAssertFalse(violations.isValid)
        XCTAssertTrue(violations.contains { $0.code == .noSettlementToUpgrade })
    }
    
    // MARK: - Development Card Tests
    
    func testBuyDevCard_Valid() {
        var testState = state!
        testState.turn.phase = .main
        testState.turn.activePlayerId = "player-0"
        testState = testState.updatingPlayer(id: "player-0") {
            $0.adding(resources: .developmentCardCost)
        }
        
        let action = GameAction.buyDevelopmentCard(playerId: "player-0")
        let violations = Validator.validate(action, state: testState)
        
        XCTAssertTrue(violations.isValid)
    }
    
    func testBuyDevCard_EmptyDeck() {
        var testState = state!
        testState.turn.phase = .main
        testState.turn.activePlayerId = "player-0"
        testState = testState.updatingPlayer(id: "player-0") {
            $0.adding(resources: .developmentCardCost)
        }
        testState.bank.developmentCards = []  // Empty deck
        
        let action = GameAction.buyDevelopmentCard(playerId: "player-0")
        let violations = Validator.validate(action, state: testState)
        
        XCTAssertFalse(violations.isValid)
    }
    
    func testPlayDevCard_BoughtThisTurn() {
        var testState = state!
        testState.turn.phase = .main
        testState.turn.activePlayerId = "player-0"
        
        let card = DevelopmentCard(id: "card-1", type: .knight, isPlayed: false, boughtThisTurn: true)
        testState = testState.updatingPlayer(id: "player-0") {
            $0.adding(developmentCard: card)
        }
        
        let action = GameAction.playKnight(playerId: "player-0", cardId: "card-1", moveRobberTo: 1, stealFrom: nil)
        let violations = Validator.validate(action, state: testState)
        
        XCTAssertFalse(violations.isValid)
        XCTAssertTrue(violations.contains { $0.code == .cannotPlayCardBoughtThisTurn })
    }
    
    func testPlayDevCard_AlreadyPlayedThisTurn() {
        var testState = state!
        testState.turn.phase = .main
        testState.turn.activePlayerId = "player-0"
        
        let card = DevelopmentCard(id: "card-1", type: .knight, isPlayed: false, boughtThisTurn: false)
        testState = testState.updatingPlayer(id: "player-0") {
            var p = $0.adding(developmentCard: card)
            p.developmentCardPlayedThisTurn = true
            return p
        }
        
        let action = GameAction.playKnight(playerId: "player-0", cardId: "card-1", moveRobberTo: 1, stealFrom: nil)
        let violations = Validator.validate(action, state: testState)
        
        XCTAssertFalse(violations.isValid)
        XCTAssertTrue(violations.contains { $0.code == .alreadyPlayedDevCard })
    }
    
    // MARK: - Trading Tests
    
    func testProposeTrade_InactivePlayer() {
        var testState = state!
        testState.turn.phase = .main
        testState.turn.activePlayerId = "player-0"
        
        let action = GameAction.proposeTrade(
            playerId: "player-1",  // Not active
            tradeId: "trade-1",
            offering: ResourceBundle(brick: 1),
            requesting: ResourceBundle(ore: 1),
            targetPlayerIds: nil
        )
        let violations = Validator.validate(action, state: testState)
        
        XCTAssertFalse(violations.isValid)
        XCTAssertTrue(violations.contains { $0.code == .inactivePlayerCannotTrade })
    }
    
    func testMaritimeTrade_InvalidRatio() {
        var testState = state!
        testState.turn.phase = .main
        testState.turn.activePlayerId = "player-0"
        testState = testState.updatingPlayer(id: "player-0") {
            $0.adding(resources: ResourceBundle(brick: 4))
        }
        
        // Try 3:1 trade when player doesn't have a 3:1 harbor
        let action = GameAction.maritimeTrade(
            playerId: "player-0",
            giving: .brick,
            givingAmount: 3,  // Invalid - should be 4 for default
            receiving: .ore
        )
        let violations = Validator.validate(action, state: testState)
        
        XCTAssertFalse(violations.isValid)
        XCTAssertTrue(violations.contains { $0.code == .invalidTradeRatio })
    }
    
    // MARK: - Robber Tests
    
    func testMoveRobber_WrongPhase() {
        let action = GameAction.moveRobber(playerId: "player-0", hexId: 1)
        let violations = Validator.validate(action, state: state)
        
        XCTAssertFalse(violations.isValid)
    }
    
    func testMoveRobber_SameHex() {
        var testState = state!
        testState.turn.phase = .movingRobber
        testState.turn.activePlayerId = "player-0"
        
        let action = GameAction.moveRobber(playerId: "player-0", hexId: testState.robberHexId)
        let violations = Validator.validate(action, state: testState)
        
        XCTAssertFalse(violations.isValid)
        XCTAssertTrue(violations.contains { $0.code == .mustMoveRobberToNewHex })
    }
    
    // MARK: - End Turn Tests
    
    func testEndTurn_MustRollFirst() {
        var testState = state!
        testState.turn.phase = .preRoll
        testState.turn.activePlayerId = "player-0"
        
        let action = GameAction.endTurn(playerId: "player-0")
        let violations = Validator.validate(action, state: testState)
        
        XCTAssertFalse(violations.isValid)
        XCTAssertTrue(violations.contains { $0.code == .mustRollFirst })
    }
    
    func testEndTurn_Valid() {
        var testState = state!
        testState.turn.phase = .main
        testState.turn.activePlayerId = "player-0"
        
        let action = GameAction.endTurn(playerId: "player-0")
        let violations = Validator.validate(action, state: testState)
        
        XCTAssertTrue(violations.isValid)
    }
    
    // MARK: - Game Ended Tests
    
    func testActionAfterGameEnded() {
        var testState = state!
        testState.turn.phase = .ended
        testState.winnerId = "player-0"
        
        let action = GameAction.rollDice(playerId: "player-0")
        let violations = Validator.validate(action, state: testState)
        
        XCTAssertFalse(violations.isValid)
        XCTAssertTrue(violations.contains { $0.code == .gameAlreadyEnded })
    }
}

