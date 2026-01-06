import XCTest
@testable import GameCore
import CatanProtocol

final class ModelTests: XCTestCase {
    
    // MARK: - Coordinate Tests
    
    func testAxialCoordNeighbors() {
        let center = AxialCoord(q: 0, r: 0)
        let neighbors = center.neighbors
        
        XCTAssertEqual(neighbors.count, 6)
        XCTAssertTrue(neighbors.contains(AxialCoord(q: 1, r: 0)))
        XCTAssertTrue(neighbors.contains(AxialCoord(q: -1, r: 0)))
        XCTAssertTrue(neighbors.contains(AxialCoord(q: 0, r: 1)))
        XCTAssertTrue(neighbors.contains(AxialCoord(q: 0, r: -1)))
    }
    
    func testCubeCoordDistance() {
        let a = CubeCoord(x: 0, y: 0, z: 0)
        let b = CubeCoord(x: 2, y: -1, z: -1)
        
        XCTAssertEqual(a.distance(to: b), 2)
    }
    
    func testCubeToAxialConversion() {
        let cube = CubeCoord(x: 1, y: -2, z: 1)
        let axial = cube.axial
        
        XCTAssertEqual(axial.q, 1)
        XCTAssertEqual(axial.r, 1)
        
        let backToCube = CubeCoord(axial: axial)
        XCTAssertEqual(backToCube.x, cube.x)
        XCTAssertEqual(backToCube.y, cube.y)
        XCTAssertEqual(backToCube.z, cube.z)
    }
    
    // MARK: - ResourceBundle Tests
    
    func testResourceBundleAddition() {
        let a = ResourceBundle(brick: 2, lumber: 1)
        let b = ResourceBundle(brick: 1, ore: 3)
        let sum = a + b
        
        XCTAssertEqual(sum.brick, 3)
        XCTAssertEqual(sum.lumber, 1)
        XCTAssertEqual(sum.ore, 3)
        XCTAssertEqual(sum.grain, 0)
        XCTAssertEqual(sum.wool, 0)
    }
    
    func testResourceBundleSubtraction() {
        let a = ResourceBundle(brick: 5, lumber: 3)
        let b = ResourceBundle(brick: 2, lumber: 1)
        let diff = a - b
        
        XCTAssertEqual(diff.brick, 3)
        XCTAssertEqual(diff.lumber, 2)
    }
    
    func testResourceBundleSubtractionClampsToZero() {
        let a = ResourceBundle(brick: 1)
        let b = ResourceBundle(brick: 5)
        let diff = a - b
        
        XCTAssertEqual(diff.brick, 0)  // Should clamp to 0, not go negative
    }
    
    func testResourceBundleContains() {
        let hand = ResourceBundle(brick: 3, lumber: 2, ore: 1, grain: 1, wool: 1)
        
        XCTAssertTrue(hand.contains(.roadCost))
        XCTAssertTrue(hand.contains(.settlementCost))
        XCTAssertFalse(hand.contains(.cityCost))  // Needs 3 ore, 2 grain
        XCTAssertTrue(hand.contains(.developmentCardCost))
    }
    
    func testResourceBundleTotal() {
        let bundle = ResourceBundle(brick: 1, lumber: 2, ore: 3, grain: 4, wool: 5)
        XCTAssertEqual(bundle.total, 15)
    }
    
    func testResourceBundleSingle() {
        let single = ResourceBundle.single(.brick)
        XCTAssertEqual(single.brick, 1)
        XCTAssertEqual(single.total, 1)
        
        let multiple = ResourceBundle.single(.ore, count: 5)
        XCTAssertEqual(multiple.ore, 5)
        XCTAssertEqual(multiple.total, 5)
    }
    
    // MARK: - Player Tests
    
    func testPlayerCanAfford() {
        let player = Player(
            id: "p1",
            userId: "u1",
            displayName: "Test",
            color: .red,
            turnOrder: 0,
            resources: ResourceBundle(brick: 1, lumber: 1, grain: 1, wool: 1)
        )
        
        XCTAssertTrue(player.canAfford(.roadCost))
        XCTAssertTrue(player.canAfford(.settlementCost))
        XCTAssertFalse(player.canAfford(.cityCost))
    }
    
    func testPlayerResourceMutations() {
        let player = Player(
            id: "p1", userId: "u1", displayName: "Test", color: .red, turnOrder: 0,
            resources: ResourceBundle(brick: 2)
        )
        
        let added = player.adding(resources: ResourceBundle(lumber: 3))
        XCTAssertEqual(added.resources.brick, 2)
        XCTAssertEqual(added.resources.lumber, 3)
        
        let removed = added.removing(resources: ResourceBundle(brick: 1))
        XCTAssertEqual(removed.resources.brick, 1)
        XCTAssertEqual(removed.resources.lumber, 3)
    }
    
    func testPlayerRemainingPieces() {
        var player = Player(
            id: "p1", userId: "u1", displayName: "Test", color: .red, turnOrder: 0
        )
        
        XCTAssertEqual(player.remainingSettlements, GameConstants.maxSettlements)
        XCTAssertEqual(player.remainingCities, GameConstants.maxCities)
        XCTAssertEqual(player.remainingRoads, GameConstants.maxRoads)
        
        player = player.adding(settlement: 1)
        player = player.adding(settlement: 2)
        XCTAssertEqual(player.remainingSettlements, GameConstants.maxSettlements - 2)
        
        player = player.adding(road: 1)
        XCTAssertEqual(player.remainingRoads, GameConstants.maxRoads - 1)
    }
    
    // MARK: - Bank Tests
    
    func testBankStandardSetup() {
        let bank = Bank.standard()
        
        XCTAssertEqual(bank.resources.brick, 19)
        XCTAssertEqual(bank.resources.lumber, 19)
        XCTAssertEqual(bank.resources.ore, 19)
        XCTAssertEqual(bank.resources.grain, 19)
        XCTAssertEqual(bank.resources.wool, 19)
        
        // 25 dev cards total
        XCTAssertEqual(bank.developmentCards.count, 25)
        
        // Count by type
        let knights = bank.developmentCards.filter { $0 == .knight }.count
        let vp = bank.developmentCards.filter { $0 == .victoryPoint }.count
        XCTAssertEqual(knights, 14)
        XCTAssertEqual(vp, 5)
    }
    
    func testBankDraw() {
        var bank = Bank.standard()
        let initialCount = bank.developmentCards.count
        
        let card = bank.drawDevelopmentCard()
        XCTAssertNotNil(card)
        XCTAssertEqual(bank.developmentCards.count, initialCount - 1)
    }
    
    func testBankTakeAndReturn() {
        let bank = Bank.standard()
        let toTake = ResourceBundle(brick: 5, lumber: 3)
        
        let takenBank = bank.taking(toTake)
        XCTAssertNotNil(takenBank)
        XCTAssertEqual(takenBank!.resources.brick, 14)
        XCTAssertEqual(takenBank!.resources.lumber, 16)
        
        let returnedBank = takenBank!.returning(toTake)
        XCTAssertEqual(returnedBank.resources.brick, 19)
        XCTAssertEqual(returnedBank.resources.lumber, 19)
    }
    
    // MARK: - Building State Tests
    
    func testBuildingStatePlacement() {
        var buildings = BuildingState()
        
        buildings = buildings.placingSettlement(at: 5, playerId: "p1")
        XCTAssertTrue(buildings.isOccupied(nodeId: 5))
        XCTAssertEqual(buildings.building(at: 5)?.playerId, "p1")
        XCTAssertEqual(buildings.building(at: 5)?.type, .settlement)
        
        buildings = buildings.placingRoad(at: 10, playerId: "p1")
        XCTAssertTrue(buildings.hasRoad(edgeId: 10))
        XCTAssertEqual(buildings.roadOwner(edgeId: 10), "p1")
    }
    
    func testBuildingStateUpgrade() {
        var buildings = BuildingState()
        buildings = buildings.placingSettlement(at: 5, playerId: "p1")
        
        buildings = buildings.upgradingToCity(at: 5)
        XCTAssertEqual(buildings.building(at: 5)?.type, .city)
        XCTAssertEqual(buildings.building(at: 5)?.playerId, "p1")
    }
    
    // MARK: - Awards Tests
    
    func testLongestRoadAward() {
        var awards = Awards()
        
        // Can't claim with < 5 roads
        let (awards1, changed1, _) = awards.checkLongestRoad(playerId: "p1", roadLength: 4)
        XCTAssertFalse(changed1)
        XCTAssertNil(awards1.longestRoadHolder)
        
        // Claim with 5 roads
        let (awards2, changed2, _) = awards.checkLongestRoad(playerId: "p1", roadLength: 5)
        XCTAssertTrue(changed2)
        XCTAssertEqual(awards2.longestRoadHolder, "p1")
        XCTAssertEqual(awards2.longestRoadLength, 5)
        
        // Someone else needs to beat, not tie
        awards = awards2
        let (awards3, changed3, _) = awards.checkLongestRoad(playerId: "p2", roadLength: 5)
        XCTAssertFalse(changed3)
        XCTAssertEqual(awards3.longestRoadHolder, "p1")
        
        // Beat the holder
        let (awards4, changed4, prev) = awards.checkLongestRoad(playerId: "p2", roadLength: 6)
        XCTAssertTrue(changed4)
        XCTAssertEqual(awards4.longestRoadHolder, "p2")
        XCTAssertEqual(prev, "p1")
    }
    
    func testLargestArmyAward() {
        var awards = Awards()
        
        // Can't claim with < 3 knights
        let (awards1, changed1, _) = awards.checkLargestArmy(playerId: "p1", knightsPlayed: 2)
        XCTAssertFalse(changed1)
        XCTAssertNil(awards1.largestArmyHolder)
        
        // Claim with 3 knights
        let (awards2, changed2, _) = awards.checkLargestArmy(playerId: "p1", knightsPlayed: 3)
        XCTAssertTrue(changed2)
        XCTAssertEqual(awards2.largestArmyHolder, "p1")
        
        awards = awards2
        // Beat the holder
        let (awards3, changed3, prev) = awards.checkLargestArmy(playerId: "p2", knightsPlayed: 4)
        XCTAssertTrue(changed3)
        XCTAssertEqual(awards3.largestArmyHolder, "p2")
        XCTAssertEqual(prev, "p1")
    }
    
    // MARK: - DiceRoll Tests
    
    func testDiceRollDeterministic() {
        var rng1 = SeededRNG(seed: 12345)
        var rng2 = SeededRNG(seed: 12345)
        
        let roll1 = DiceRoll.roll(using: &rng1)
        let roll2 = DiceRoll.roll(using: &rng2)
        
        XCTAssertEqual(roll1, roll2)
    }
    
    func testDiceRollRange() {
        var rng = SeededRNG(seed: 999)
        
        for _ in 0..<100 {
            let roll = DiceRoll.roll(using: &rng)
            XCTAssertTrue((1...6).contains(roll.die1))
            XCTAssertTrue((1...6).contains(roll.die2))
            XCTAssertTrue((2...12).contains(roll.total))
        }
    }
    
    // MARK: - Victory Points Tests
    
    func testVictoryPointBreakdown() {
        let breakdown = VictoryPointBreakdown(
            settlements: 3,
            cities: 2,
            longestRoad: 2,
            largestArmy: 2,
            victoryPointCards: 1
        )
        
        // 3 settlements = 3 VP, 2 cities = 4 VP, longest = 2, army = 2, VP cards = 1
        XCTAssertEqual(breakdown.total, 3 + 4 + 2 + 2 + 1)
    }
}

