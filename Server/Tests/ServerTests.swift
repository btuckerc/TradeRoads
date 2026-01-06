import XCTest
import XCTVapor
import Fluent
import FluentPostgresDriver
@testable import TradeRoadsServer
import GameCore

// MARK: - Protocol Version Tests

final class ProtocolTests: XCTestCase {
    
    func testProtocolVersionSupport() {
        let current = ProtocolVersion.current
        let minSupported = ProtocolVersion.minSupported
        
        XCTAssertTrue(current.isSupported)
        XCTAssertTrue(minSupported.isSupported)
        
        // Older versions should not be supported
        let oldVersion = ProtocolVersion(major: 0, minor: 1)
        XCTAssertFalse(oldVersion.isSupported)
    }
    
    func testProtocolVersionComparison() {
        let v1_0 = ProtocolVersion(major: 1, minor: 0)
        let v1_1 = ProtocolVersion(major: 1, minor: 1)
        let v2_0 = ProtocolVersion(major: 2, minor: 0)
        
        XCTAssertLessThan(v1_0, v1_1)
        XCTAssertLessThan(v1_1, v2_0)
        XCTAssertEqual(v1_0, ProtocolVersion(major: 1, minor: 0))
    }
    
    func testProtocolVersionString() {
        let version = ProtocolVersion(major: 1, minor: 2)
        XCTAssertEqual(version.stringValue, "1.2")
    }
}

// MARK: - Event Conversion Tests

final class EventConversionTests: XCTestCase {
    
    func testDomainEventConversion() {
        // Test dice rolled event conversion
        let diceEvent = DomainEvent.diceRolled(playerId: "player-0", die1: 3, die2: 4)
        let protocolEvent = EventConverter.toProtocol(diceEvent)
        
        if case .diceRolled(let event) = protocolEvent {
            XCTAssertEqual(event.playerId, "player-0")
            XCTAssertEqual(event.die1, 3)
            XCTAssertEqual(event.die2, 4)
        } else {
            XCTFail("Expected diceRolled event")
        }
    }
    
    func testTurnEventsConversion() {
        // Test turn started
        let turnStarted = DomainEvent.turnStarted(playerId: "player-1", turnNumber: 5)
        let protocolTurnStarted = EventConverter.toProtocol(turnStarted)
        
        if case .turnStarted(let event) = protocolTurnStarted {
            XCTAssertEqual(event.playerId, "player-1")
            XCTAssertEqual(event.turnNumber, 5)
        } else {
            XCTFail("Expected turnStarted event")
        }
        
        // Test turn ended
        let turnEnded = DomainEvent.turnEnded(playerId: "player-1", turnNumber: 5)
        let protocolTurnEnded = EventConverter.toProtocol(turnEnded)
        
        if case .turnEnded(let event) = protocolTurnEnded {
            XCTAssertEqual(event.playerId, "player-1")
            XCTAssertEqual(event.turnNumber, 5)
        } else {
            XCTFail("Expected turnEnded event")
        }
    }
    
    func testBuildingEventsConversion() {
        // Test road built (brick, lumber, ore, grain, wool)
        let roadCost = ResourceBundle(brick: 1, lumber: 1, ore: 0, grain: 0, wool: 0)
        let roadBuilt = DomainEvent.roadBuilt(playerId: "player-0", edgeId: 42, cost: roadCost)
        let protocolRoad = EventConverter.toProtocol(roadBuilt)
        
        if case .roadBuilt(let event) = protocolRoad {
            XCTAssertEqual(event.playerId, "player-0")
            XCTAssertEqual(event.edgeId, 42)
            XCTAssertFalse(event.wasFree)
        } else {
            XCTFail("Expected roadBuilt event")
        }
        
        // Test settlement built (brick, lumber, ore, grain, wool)
        let settlementCost = ResourceBundle(brick: 1, lumber: 1, ore: 0, grain: 1, wool: 1)
        let settlementBuilt = DomainEvent.settlementBuilt(playerId: "player-0", nodeId: 15, cost: settlementCost)
        let protocolSettlement = EventConverter.toProtocol(settlementBuilt)
        
        if case .settlementBuilt(let event) = protocolSettlement {
            XCTAssertEqual(event.playerId, "player-0")
            XCTAssertEqual(event.nodeId, 15)
            XCTAssertFalse(event.wasFree)
        } else {
            XCTFail("Expected settlementBuilt event")
        }
    }
    
    func testFreeRoadConversion() {
        // Free road during road building should have wasFree = true
        let freeRoad = DomainEvent.roadBuildingRoadPlaced(playerId: "player-0", edgeId: 30, roadsRemaining: 1)
        let protocolRoad = EventConverter.toProtocol(freeRoad)
        
        if case .roadBuilt(let event) = protocolRoad {
            XCTAssertEqual(event.edgeId, 30)
            XCTAssertTrue(event.wasFree)
        } else {
            XCTFail("Expected roadBuilt event")
        }
    }
    
    func testSetupEventsConversion() {
        let setupStarted = DomainEvent.setupPhaseStarted(firstPlayerId: "player-0")
        let protocolSetup = EventConverter.toProtocol(setupStarted)
        
        if case .setupPhaseStarted(let event) = protocolSetup {
            XCTAssertEqual(event.firstPlayerId, "player-0")
        } else {
            XCTFail("Expected setupPhaseStarted event")
        }
    }
    
    func testTradeEventsConversion() {
        let tradeId = "trade-123"
        let accepted = DomainEvent.tradeAccepted(tradeId: tradeId, accepterId: "player-1")
        let protocolAccepted = EventConverter.toProtocol(accepted)
        
        if case .tradeAccepted(let event) = protocolAccepted {
            XCTAssertEqual(event.tradeId, tradeId)
            XCTAssertEqual(event.accepterId, "player-1")
        } else {
            XCTFail("Expected tradeAccepted event")
        }
    }
    
    func testAwardEventsConversion() {
        let longestRoad = DomainEvent.longestRoadAwarded(newHolderId: "player-0", previousHolderId: nil, roadLength: 5)
        let protocolLongest = EventConverter.toProtocol(longestRoad)
        
        if case .longestRoadAwarded(let event) = protocolLongest {
            XCTAssertEqual(event.newHolderId, "player-0")
            XCTAssertNil(event.previousHolderId)
            XCTAssertEqual(event.roadLength, 5)
        } else {
            XCTFail("Expected longestRoadAwarded event")
        }
        
        let largestArmy = DomainEvent.largestArmyAwarded(newHolderId: "player-1", previousHolderId: "player-0", knightCount: 3)
        let protocolArmy = EventConverter.toProtocol(largestArmy)
        
        if case .largestArmyAwarded(let event) = protocolArmy {
            XCTAssertEqual(event.newHolderId, "player-1")
            XCTAssertEqual(event.previousHolderId, "player-0")
            XCTAssertEqual(event.knightCount, 3)
        } else {
            XCTFail("Expected largestArmyAwarded event")
        }
    }
}

// MARK: - JSON Encoding Tests

final class JSONEncodingTests: XCTestCase {
    
    func testClientEnvelopeEncoding() throws {
        let message = ClientMessage.ping
        let envelope = ClientEnvelope(
            requestId: "req-123",
            lastSeenEventIndex: 5,
            message: message
        )
        
        let json = try CatanJSON.encodeToString(envelope)
        XCTAssertTrue(json.contains("request_id"))
        XCTAssertTrue(json.contains("protocol_version"))
        XCTAssertTrue(json.contains("ping"))
        
        // Decode back
        let decoded = try CatanJSON.decode(ClientEnvelope.self, from: json)
        XCTAssertEqual(decoded.requestId, "req-123")
        XCTAssertEqual(decoded.lastSeenEventIndex, 5)
        if case .ping = decoded.message {
            // Success
        } else {
            XCTFail("Expected ping message")
        }
    }
    
    func testServerEnvelopeEncoding() throws {
        let message = ServerMessage.pong
        let envelope = ServerEnvelope(
            correlationId: "req-123",
            message: message
        )
        
        let json = try CatanJSON.encodeToString(envelope)
        XCTAssertTrue(json.contains("correlation_id"))
        XCTAssertTrue(json.contains("pong"))
        
        // Decode back
        let decoded = try CatanJSON.decode(ServerEnvelope.self, from: json)
        XCTAssertEqual(decoded.correlationId, "req-123")
        if case .pong = decoded.message {
            // Success
        } else {
            XCTFail("Expected pong message")
        }
    }
    
    func testProtocolErrorEncoding() throws {
        let error = ProtocolError(code: .unsupportedVersion, message: "Version not supported")
        let message = ServerMessage.protocolError(error)
        let envelope = ServerEnvelope(message: message)
        
        let json = try CatanJSON.encodeToString(envelope)
        // Verify it can be decoded back
        let decoded = try CatanJSON.decode(ServerEnvelope.self, from: json)
        if case .protocolError(let decodedError) = decoded.message {
            XCTAssertEqual(decodedError.code, .unsupportedVersion)
            XCTAssertEqual(decodedError.message, "Version not supported")
        } else {
            XCTFail("Expected protocolError message")
        }
    }
    
    func testAuthenticateRequestEncoding() throws {
        let request = AuthenticateRequest(identifier: "testuser", sessionToken: nil)
        let message = ClientMessage.authenticate(request)
        let envelope = ClientEnvelope(requestId: "req-1", message: message)
        
        let json = try CatanJSON.encodeToString(envelope)
        XCTAssertTrue(json.contains("authenticate"))
        XCTAssertTrue(json.contains("testuser"))
        
        let decoded = try CatanJSON.decode(ClientEnvelope.self, from: json)
        if case .authenticate(let req) = decoded.message {
            XCTAssertEqual(req.identifier, "testuser")
        } else {
            XCTFail("Expected authenticate message")
        }
    }
    
    func testLobbyMessageEncoding() throws {
        let request = CreateLobbyRequest(
            lobbyName: "Test Game",
            playerMode: .threeToFour,
            useBeginnerLayout: true
        )
        let message = ClientMessage.createLobby(request)
        let envelope = ClientEnvelope(requestId: "req-2", message: message)
        
        let json = try CatanJSON.encodeToString(envelope)
        XCTAssertTrue(json.contains("create_lobby"))
        XCTAssertTrue(json.contains("Test Game"))
    }
    
    func testGameActionEncoding() throws {
        // Roll dice
        let rollEnvelope = ClientEnvelope(requestId: "req-3", message: .rollDice)
        let rollJson = try CatanJSON.encodeToString(rollEnvelope)
        XCTAssertTrue(rollJson.contains("roll_dice"))
        
        // Build settlement
        let buildRequest = BuildSettlementIntent(nodeId: 15, isFree: false)
        let buildEnvelope = ClientEnvelope(requestId: "req-4", message: .buildSettlement(buildRequest))
        let buildJson = try CatanJSON.encodeToString(buildEnvelope)
        XCTAssertTrue(buildJson.contains("build_settlement"))
        XCTAssertTrue(buildJson.contains("15"))
    }
}

// MARK: - Token Tests

final class TokenTests: XCTestCase {
    
    func testTokenVerification() {
        // Malformed tokens should fail
        XCTAssertFalse(AuthService.verifyToken("malformed"))
        XCTAssertFalse(AuthService.verifyToken("no.proper.signature.format"))
        XCTAssertFalse(AuthService.verifyToken(""))
    }
}

// MARK: - Model Tests (No Database Required)

final class ModelTests: XCTestCase {
    
    func testLobbyPlayerInfo() {
        let player = LobbyPlayerInfo(
            userId: "user-123",
            displayName: "Test Player",
            color: .red,
            isReady: true,
            isHost: false
        )
        
        XCTAssertEqual(player.userId, "user-123")
        XCTAssertEqual(player.displayName, "Test Player")
        XCTAssertEqual(player.color, .red)
        XCTAssertTrue(player.isReady)
        XCTAssertFalse(player.isHost)
    }
    
    func testGamePlayerInfo() {
        let player = GamePlayerInfo(
            playerId: "player-0",
            userId: "user-123",
            displayName: "Test Player",
            color: .blue,
            turnOrder: 2
        )
        
        XCTAssertEqual(player.playerId, "player-0")
        XCTAssertEqual(player.userId, "user-123")
        XCTAssertEqual(player.color, .blue)
        XCTAssertEqual(player.turnOrder, 2)
    }
    
    func testLobbyPlayerInfoCodable() throws {
        let player = LobbyPlayerInfo(
            userId: "user-456",
            displayName: "Codable Test",
            color: .orange,
            isReady: false,
            isHost: true
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(player)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LobbyPlayerInfo.self, from: data)
        
        XCTAssertEqual(decoded.userId, player.userId)
        XCTAssertEqual(decoded.displayName, player.displayName)
        XCTAssertEqual(decoded.color, player.color)
        XCTAssertEqual(decoded.isReady, player.isReady)
        XCTAssertEqual(decoded.isHost, player.isHost)
    }
    
    func testGamePlayerInfoCodable() throws {
        let player = GamePlayerInfo(
            playerId: "player-1",
            userId: "user-789",
            displayName: "Codable Player",
            color: .white,
            turnOrder: 0
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(player)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GamePlayerInfo.self, from: data)
        
        XCTAssertEqual(decoded.playerId, player.playerId)
        XCTAssertEqual(decoded.userId, player.userId)
        XCTAssertEqual(decoded.color, player.color)
        XCTAssertEqual(decoded.turnOrder, player.turnOrder)
    }
}

// MARK: - ActionResult Tests

final class ActionResultTests: XCTestCase {
    
    func testActionResultSuccess() {
        let events: [DomainEvent] = [
            .diceRolled(playerId: "player-0", die1: 3, die2: 4)
        ]
        let result = ActionResult.success(events)
        
        if case .success(let returnedEvents) = result {
            XCTAssertEqual(returnedEvents.count, 1)
        } else {
            XCTFail("Expected success result")
        }
    }
    
    func testActionResultRejected() {
        let violations = [
            RuleViolation(code: .notYourTurn, message: "It's not your turn")
        ]
        let result = ActionResult.rejected(violations)
        
        if case .rejected(let returnedViolations) = result {
            XCTAssertEqual(returnedViolations.count, 1)
            XCTAssertEqual(returnedViolations[0].code, .notYourTurn)
        } else {
            XCTFail("Expected rejected result")
        }
    }
    
    func testActionResultError() {
        let result = ActionResult.error("Something went wrong")
        
        if case .error(let message) = result {
            XCTAssertEqual(message, "Something went wrong")
        } else {
            XCTFail("Expected error result")
        }
    }
}

// MARK: - Route Registration Tests (requires running Vapor)

final class RouteTests: XCTestCase {
    
    var app: Application!
    
    override func setUp() async throws {
        try await super.setUp()
        app = try await Application.make(.testing)
        try Routes.register(app)
    }
    
    override func tearDown() async throws {
        try await app.asyncShutdown()
        app = nil
        try await super.tearDown()
    }
    
    func testHealthEndpoint() async throws {
        try await app.test(.GET, "health", afterResponse: { response async throws in
            XCTAssertEqual(response.status, .ok)
            let json = try response.content.decode([String: String].self)
            XCTAssertEqual(json["status"], "ok")
        })
    }
    
    func testVersionEndpoint() async throws {
        try await app.test(.GET, "api/version", afterResponse: { response async throws in
            XCTAssertEqual(response.status, .ok)
            let json = try response.content.decode([String: String].self)
            XCTAssertEqual(json["version"], ProtocolVersion.current.stringValue)
            XCTAssertEqual(json["minSupported"], ProtocolVersion.minSupported.stringValue)
        })
    }
}
