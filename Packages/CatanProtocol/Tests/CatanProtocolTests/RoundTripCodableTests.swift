import XCTest
@testable import CatanProtocol

final class RoundTripCodableTests: XCTestCase {
    
    // MARK: - Protocol Version Tests
    
    func testProtocolVersionRoundTrip() throws {
        let version = ProtocolVersion(major: 1, minor: 2)
        let data = try CatanJSON.encode(version)
        let decoded = try CatanJSON.decode(ProtocolVersion.self, from: data)
        XCTAssertEqual(version, decoded)
    }
    
    func testProtocolVersionComparison() {
        XCTAssertTrue(ProtocolVersion(major: 1, minor: 0) < ProtocolVersion(major: 1, minor: 1))
        XCTAssertTrue(ProtocolVersion(major: 1, minor: 5) < ProtocolVersion(major: 2, minor: 0))
        XCTAssertFalse(ProtocolVersion(major: 2, minor: 0) < ProtocolVersion(major: 1, minor: 9))
    }
    
    func testProtocolVersionSupported() {
        XCTAssertTrue(ProtocolVersion.current.isSupported)
        XCTAssertTrue(ProtocolVersion.minSupported.isSupported)
        XCTAssertFalse(ProtocolVersion(major: 0, minor: 1).isSupported)
        XCTAssertFalse(ProtocolVersion(major: 99, minor: 0).isSupported)
    }
    
    // MARK: - Client Envelope Tests
    
    func testClientEnvelopeRoundTrip() throws {
        let envelope = ClientEnvelope(
            protocolVersion: .current,
            requestId: "test-123",
            lastSeenEventIndex: 42,
            sentAt: Date(timeIntervalSince1970: 1704067200),
            message: .rollDice
        )
        let data = try CatanJSON.encode(envelope)
        let decoded = try CatanJSON.decode(ClientEnvelope.self, from: data)
        XCTAssertEqual(envelope, decoded)
    }
    
    func testClientEnvelopeWithNilLastSeenEventIndex() throws {
        let envelope = ClientEnvelope(
            requestId: "test-456",
            lastSeenEventIndex: nil,
            message: .ping
        )
        let data = try CatanJSON.encode(envelope)
        let decoded = try CatanJSON.decode(ClientEnvelope.self, from: data)
        XCTAssertNil(decoded.lastSeenEventIndex)
    }
    
    // MARK: - Server Envelope Tests
    
    func testServerEnvelopeRoundTrip() throws {
        let envelope = ServerEnvelope(
            protocolVersion: .current,
            correlationId: "req-789",
            sentAt: Date(timeIntervalSince1970: 1704067200),
            message: .pong
        )
        let data = try CatanJSON.encode(envelope)
        let decoded = try CatanJSON.decode(ServerEnvelope.self, from: data)
        XCTAssertEqual(envelope, decoded)
    }
    
    // MARK: - Client Message Round Trips
    
    func testAuthenticateRoundTrip() throws {
        let message = ClientMessage.authenticate(AuthenticateRequest(
            identifier: "test@example.com",
            sessionToken: "token123",
            oneTimeCode: nil
        ))
        try assertRoundTrip(message)
    }
    
    func testCreateLobbyRoundTrip() throws {
        let message = ClientMessage.createLobby(CreateLobbyRequest(
            lobbyName: "Test Game",
            playerMode: .threeToFour,
            useBeginnerLayout: true
        ))
        try assertRoundTrip(message)
    }
    
    func testJoinLobbyRoundTrip() throws {
        let message = ClientMessage.joinLobby(JoinLobbyRequest(lobbyCode: "ABC123"))
        try assertRoundTrip(message)
    }
    
    func testSelectColorRoundTrip() throws {
        for color in PlayerColor.allCases {
            let message = ClientMessage.selectColor(SelectColorRequest(color: color))
            try assertRoundTrip(message)
        }
    }
    
    func testSetReadyRoundTrip() throws {
        try assertRoundTrip(ClientMessage.setReady(SetReadyRequest(ready: true)))
        try assertRoundTrip(ClientMessage.setReady(SetReadyRequest(ready: false)))
    }
    
    func testDiscardResourcesRoundTrip() throws {
        let message = ClientMessage.discardResources(DiscardResourcesIntent(
            resources: ResourceBundle(brick: 2, lumber: 1, ore: 0, grain: 1, wool: 0)
        ))
        try assertRoundTrip(message)
    }
    
    func testMoveRobberRoundTrip() throws {
        let message = ClientMessage.moveRobber(MoveRobberIntent(hexId: 7))
        try assertRoundTrip(message)
    }
    
    func testStealResourceRoundTrip() throws {
        let message = ClientMessage.stealResource(StealResourceIntent(targetPlayerId: "player-2"))
        try assertRoundTrip(message)
    }
    
    func testBuildRoadRoundTrip() throws {
        let message = ClientMessage.buildRoad(BuildRoadIntent(edgeId: 15, isFree: false))
        try assertRoundTrip(message)
    }
    
    func testBuildSettlementRoundTrip() throws {
        let message = ClientMessage.buildSettlement(BuildSettlementIntent(nodeId: 22, isFree: true))
        try assertRoundTrip(message)
    }
    
    func testBuildCityRoundTrip() throws {
        let message = ClientMessage.buildCity(BuildCityIntent(nodeId: 22))
        try assertRoundTrip(message)
    }
    
    func testPlayKnightRoundTrip() throws {
        let message = ClientMessage.playKnight(PlayKnightIntent(moveRobberTo: 5, stealFrom: "player-3"))
        try assertRoundTrip(message)
    }
    
    func testPlayRoadBuildingRoundTrip() throws {
        let message = ClientMessage.playRoadBuilding(PlayRoadBuildingIntent(firstEdgeId: 10, secondEdgeId: 11))
        try assertRoundTrip(message)
    }
    
    func testPlayYearOfPlentyRoundTrip() throws {
        let message = ClientMessage.playYearOfPlenty(PlayYearOfPlentyIntent(firstResource: .ore, secondResource: .grain))
        try assertRoundTrip(message)
    }
    
    func testPlayMonopolyRoundTrip() throws {
        let message = ClientMessage.playMonopoly(PlayMonopolyIntent(resourceType: .wool))
        try assertRoundTrip(message)
    }
    
    func testProposeTradeRoundTrip() throws {
        let message = ClientMessage.proposeTrade(ProposeTradeIntent(
            tradeId: "trade-123",
            offering: ResourceBundle(brick: 2),
            requesting: ResourceBundle(ore: 1),
            targetPlayerIds: ["player-2", "player-3"]
        ))
        try assertRoundTrip(message)
    }
    
    func testAcceptTradeRoundTrip() throws {
        let message = ClientMessage.acceptTrade(AcceptTradeIntent(tradeId: "trade-123"))
        try assertRoundTrip(message)
    }
    
    func testMaritimeTradeRoundTrip() throws {
        let message = ClientMessage.maritimeTrade(MaritimeTradeIntent(
            giving: .wool,
            givingAmount: 4,
            receiving: .brick
        ))
        try assertRoundTrip(message)
    }
    
    func testReconnectRoundTrip() throws {
        let message = ClientMessage.reconnect(ReconnectRequest(gameId: "game-456", lastSeenEventIndex: 100))
        try assertRoundTrip(message)
    }
    
    func testSimpleClientMessagesRoundTrip() throws {
        try assertRoundTrip(ClientMessage.leaveLobby)
        try assertRoundTrip(ClientMessage.startGame)
        try assertRoundTrip(ClientMessage.rollDice)
        try assertRoundTrip(ClientMessage.buyDevelopmentCard)
        try assertRoundTrip(ClientMessage.endTurn)
        try assertRoundTrip(ClientMessage.passPairedMarker)
        try assertRoundTrip(ClientMessage.ping)
    }
    
    // MARK: - Server Message Round Trips
    
    func testProtocolErrorRoundTrip() throws {
        let message = ServerMessage.protocolError(ProtocolError(
            code: .unsupportedVersion,
            message: "Protocol version 0.5 is not supported. Minimum: 1.0"
        ))
        try assertServerRoundTrip(message)
    }
    
    func testAuthenticatedRoundTrip() throws {
        let message = ServerMessage.authenticated(AuthenticatedResponse(
            userId: "user-123",
            sessionToken: "session-abc",
            displayName: "Player One"
        ))
        try assertServerRoundTrip(message)
    }
    
    func testAuthenticationFailedRoundTrip() throws {
        for reason in [AuthFailureReason.invalidCredentials, .sessionExpired, .accountDisabled, .invalidOneTimeCode] {
            let message = ServerMessage.authenticationFailed(AuthenticationFailedResponse(reason: reason))
            try assertServerRoundTrip(message)
        }
    }
    
    func testLobbyCreatedRoundTrip() throws {
        let message = ServerMessage.lobbyCreated(LobbyCreatedResponse(
            lobbyId: "lobby-123",
            lobbyCode: "ABCD",
            lobby: makeSampleLobbyState()
        ))
        try assertServerRoundTrip(message)
    }
    
    func testLobbyJoinedRoundTrip() throws {
        let message = ServerMessage.lobbyJoined(makeSampleLobbyState())
        try assertServerRoundTrip(message)
    }
    
    func testLobbyErrorRoundTrip() throws {
        for code in [LobbyErrorCode.notFound, .full, .alreadyInLobby, .colorTaken, .notHost, .notEnoughPlayers, .gameAlreadyStarted] {
            let message = ServerMessage.lobbyError(LobbyError(code: code, message: "Error: \(code.rawValue)"))
            try assertServerRoundTrip(message)
        }
    }
    
    func testGameStartedRoundTrip() throws {
        let message = ServerMessage.gameStarted(GameStartedEvent(
            gameId: "game-123",
            playerOrder: [
                GamePlayer(playerId: "p1", userId: "u1", displayName: "Player 1", color: .red, turnOrder: 0),
                GamePlayer(playerId: "p2", userId: "u2", displayName: "Player 2", color: .blue, turnOrder: 1)
            ],
            boardLayout: makeSampleBoardLayout(),
            initialEventIndex: 0
        ))
        try assertServerRoundTrip(message)
    }
    
    func testGameEventsBatchRoundTrip() throws {
        let events: [GameDomainEvent] = [
            .turnStarted(TurnStartedEvent(playerId: "p1", turnNumber: 1)),
            .diceRolled(DiceRolledEvent(playerId: "p1", die1: 3, die2: 4)),
            .resourcesProduced(ResourcesProducedEvent(diceTotal: 7, production: []))
        ]
        let message = ServerMessage.gameEvents(GameEventsBatch(
            gameId: "game-123",
            events: events,
            startIndex: 0,
            endIndex: 2
        ))
        try assertServerRoundTrip(message)
    }
    
    func testIntentRejectedRoundTrip() throws {
        let message = ServerMessage.intentRejected(IntentRejectedResponse(
            requestId: "req-123",
            violations: [
                RuleViolation(code: .notYourTurn, message: "It is not your turn"),
                RuleViolation(code: .insufficientResources, message: "You need 1 more brick")
            ]
        ))
        try assertServerRoundTrip(message)
    }
    
    func testGameEndedRoundTrip() throws {
        let message = ServerMessage.gameEnded(GameEndedEvent(
            gameId: "game-123",
            winnerId: "p1",
            reason: .victoryPointsReached,
            finalStandings: [
                FinalStanding(playerId: "p1", rank: 1, victoryPoints: 10),
                FinalStanding(playerId: "p2", rank: 2, victoryPoints: 8)
            ]
        ))
        try assertServerRoundTrip(message)
    }
    
    // MARK: - Domain Event Round Trips
    
    func testSetupEventsRoundTrip() throws {
        try assertEventRoundTrip(.setupPhaseStarted(SetupPhaseStartedEvent(firstPlayerId: "p1")))
        try assertEventRoundTrip(.setupPiecePlaced(SetupPiecePlacedEvent(
            playerId: "p1", pieceType: .settlement, locationId: 5, round: 1
        )))
        try assertEventRoundTrip(.setupPhaseEnded)
    }
    
    func testTurnEventsRoundTrip() throws {
        try assertEventRoundTrip(.turnStarted(TurnStartedEvent(playerId: "p1", turnNumber: 5)))
        try assertEventRoundTrip(.diceRolled(DiceRolledEvent(playerId: "p1", die1: 2, die2: 6)))
        try assertEventRoundTrip(.turnEnded(TurnEndedEvent(playerId: "p1", turnNumber: 5)))
    }
    
    func testResourceProductionEventRoundTrip() throws {
        let production = [
            PlayerProduction(
                playerId: "p1",
                resources: ResourceBundle(brick: 2, lumber: 1),
                sources: [
                    ProductionSource(hexId: 3, nodeId: 10, buildingType: .city, resource: .brick, amount: 2),
                    ProductionSource(hexId: 5, nodeId: 12, buildingType: .settlement, resource: .lumber, amount: 1)
                ]
            )
        ]
        try assertEventRoundTrip(.resourcesProduced(ResourcesProducedEvent(diceTotal: 8, production: production)))
    }
    
    func testNoResourcesProducedEventRoundTrip() throws {
        try assertEventRoundTrip(.noResourcesProduced(NoResourcesProducedEvent(
            diceTotal: 7, reason: .rolledSeven
        )))
        try assertEventRoundTrip(.noResourcesProduced(NoResourcesProducedEvent(
            diceTotal: 11, reason: .noMatchingBuildings
        )))
    }
    
    func testRobberEventsRoundTrip() throws {
        try assertEventRoundTrip(.mustDiscard(MustDiscardEvent(playerDiscardRequirements: [
            PlayerDiscardRequirement(playerId: "p1", currentCount: 10, mustDiscard: 5),
            PlayerDiscardRequirement(playerId: "p3", currentCount: 8, mustDiscard: 4)
        ])))
        try assertEventRoundTrip(.playerDiscarded(PlayerDiscardedEvent(
            playerId: "p1", discarded: ResourceBundle(brick: 2, wool: 3)
        )))
        try assertEventRoundTrip(.robberMoved(RobberMovedEvent(
            playerId: "p1", fromHexId: 0, toHexId: 5, eligibleVictims: ["p2", "p3"]
        )))
        try assertEventRoundTrip(.resourceStolen(ResourceStolenEvent(
            thiefId: "p1", victimId: "p2", resourceType: .ore
        )))
    }
    
    func testBuildingEventsRoundTrip() throws {
        try assertEventRoundTrip(.roadBuilt(RoadBuiltEvent(
            playerId: "p1", edgeId: 15, wasFree: false, resourcesSpent: .roadCost
        )))
        try assertEventRoundTrip(.settlementBuilt(SettlementBuiltEvent(
            playerId: "p1", nodeId: 22, wasFree: true, resourcesSpent: .zero
        )))
        try assertEventRoundTrip(.cityBuilt(CityBuiltEvent(
            playerId: "p1", nodeId: 22, resourcesSpent: .cityCost
        )))
    }
    
    func testDevCardEventsRoundTrip() throws {
        for cardType in DevelopmentCardType.allCases {
            try assertEventRoundTrip(.developmentCardBought(DevelopmentCardBoughtEvent(
                playerId: "p1", cardType: cardType, resourcesSpent: .developmentCardCost
            )))
        }
        try assertEventRoundTrip(.knightPlayed(KnightPlayedEvent(
            playerId: "p1", robberFromHexId: 0, robberToHexId: 5, knightsPlayed: 3
        )))
        try assertEventRoundTrip(.roadBuildingPlayed(RoadBuildingPlayedEvent(
            playerId: "p1", firstEdgeId: 10, secondEdgeId: 11
        )))
        try assertEventRoundTrip(.yearOfPlentyPlayed(YearOfPlentyPlayedEvent(
            playerId: "p1", firstResource: .ore, secondResource: .grain
        )))
        try assertEventRoundTrip(.monopolyPlayed(MonopolyPlayedEvent(
            playerId: "p1", resourceType: .brick,
            stolenAmounts: [
                PlayerResourceStolen(playerId: "p2", amount: 3),
                PlayerResourceStolen(playerId: "p3", amount: 1)
            ],
            totalStolen: 4
        )))
        try assertEventRoundTrip(.victoryPointRevealed(VictoryPointRevealedEvent(
            playerId: "p1", cardCount: 2
        )))
    }
    
    func testTradeEventsRoundTrip() throws {
        try assertEventRoundTrip(.tradeProposed(TradeProposedEvent(
            tradeId: "t1", proposerId: "p1",
            offering: ResourceBundle(brick: 2),
            requesting: ResourceBundle(ore: 1),
            targetPlayerIds: nil
        )))
        try assertEventRoundTrip(.tradeAccepted(TradeAcceptedEvent(tradeId: "t1", accepterId: "p2")))
        try assertEventRoundTrip(.tradeRejected(TradeRejectedEvent(tradeId: "t1", rejecterId: "p3")))
        try assertEventRoundTrip(.tradeCancelled(TradeCancelledEvent(tradeId: "t1", reason: .turnEnded)))
        try assertEventRoundTrip(.tradeExecuted(TradeExecutedEvent(
            tradeId: "t1", proposerId: "p1", accepterId: "p2",
            proposerGave: ResourceBundle(brick: 2),
            accepterGave: ResourceBundle(ore: 1)
        )))
        try assertEventRoundTrip(.maritimeTradeExecuted(MaritimeTradeExecutedEvent(
            playerId: "p1", gave: .wool, gaveAmount: 4, received: .brick, harborType: nil
        )))
        try assertEventRoundTrip(.maritimeTradeExecuted(MaritimeTradeExecutedEvent(
            playerId: "p1", gave: .wool, gaveAmount: 2, received: .brick, harborType: .specific(.wool)
        )))
    }
    
    func testAwardEventsRoundTrip() throws {
        try assertEventRoundTrip(.longestRoadAwarded(LongestRoadAwardedEvent(
            newHolderId: "p1", previousHolderId: nil, roadLength: 5
        )))
        try assertEventRoundTrip(.largestArmyAwarded(LargestArmyAwardedEvent(
            newHolderId: "p2", previousHolderId: "p1", knightCount: 4
        )))
    }
    
    func testVictoryEventRoundTrip() throws {
        try assertEventRoundTrip(.playerWon(PlayerWonEvent(
            playerId: "p1", victoryPoints: 10,
            breakdown: VictoryPointBreakdown(
                settlements: 2, cities: 3, longestRoad: 2, largestArmy: 0, victoryPointCards: 0
            )
        )))
    }
    
    func testPairedPlayerEventsRoundTrip() throws {
        try assertEventRoundTrip(.pairedTurnStarted(PairedTurnStartedEvent(
            player1Id: "p1", player2Id: "p4", turnNumber: 3
        )))
        try assertEventRoundTrip(.pairedMarkerPassed(PairedMarkerPassedEvent(
            fromPlayerId: "p1", toPlayerId: "p4"
        )))
        try assertEventRoundTrip(.supplyTradeExecuted(SupplyTradeExecutedEvent(
            playerId: "p4", gave: .brick, received: .ore
        )))
    }
    
    // MARK: - Resource Bundle Tests
    
    func testResourceBundleRoundTrip() throws {
        let bundle = ResourceBundle(brick: 5, lumber: 3, ore: 2, grain: 4, wool: 1)
        let data = try CatanJSON.encode(bundle)
        let decoded = try CatanJSON.decode(ResourceBundle.self, from: data)
        XCTAssertEqual(bundle, decoded)
    }
    
    func testResourceBundleArithmetic() {
        let a = ResourceBundle(brick: 3, lumber: 2, ore: 1)
        let b = ResourceBundle(brick: 1, lumber: 1, ore: 2, grain: 1)
        
        let sum = a + b
        XCTAssertEqual(sum.brick, 4)
        XCTAssertEqual(sum.lumber, 3)
        XCTAssertEqual(sum.ore, 3)
        XCTAssertEqual(sum.grain, 1)
        XCTAssertEqual(sum.wool, 0)
        
        let diff = a - b
        XCTAssertEqual(diff.brick, 2)
        XCTAssertEqual(diff.lumber, 1)
        XCTAssertEqual(diff.ore, 0) // Clamped to 0
        XCTAssertEqual(diff.grain, 0) // Clamped to 0
    }
    
    func testResourceBundleContains() {
        let hand = ResourceBundle(brick: 3, lumber: 2, ore: 1, grain: 1, wool: 1)
        
        XCTAssertTrue(hand.contains(.roadCost))
        XCTAssertTrue(hand.contains(.settlementCost))
        XCTAssertFalse(hand.contains(.cityCost)) // Need 3 ore
        XCTAssertTrue(hand.contains(.developmentCardCost))
    }
    
    func testResourceBundleSubscript() {
        var bundle = ResourceBundle()
        XCTAssertEqual(bundle[.brick], 0)
        
        bundle[.brick] = 5
        XCTAssertEqual(bundle[.brick], 5)
        
        bundle[.brick] = -3 // Should clamp to 0
        XCTAssertEqual(bundle[.brick], 0)
    }
    
    // MARK: - Harbor Type Tests
    
    func testHarborTypeRoundTrip() throws {
        let genericHarbor = Harbor(harborId: 1, type: .generic, nodeIds: [1, 2])
        let data1 = try CatanJSON.encode(genericHarbor)
        let decoded1 = try CatanJSON.decode(Harbor.self, from: data1)
        XCTAssertEqual(genericHarbor, decoded1)
        
        let specificHarbor = Harbor(harborId: 2, type: .specific(.brick), nodeIds: [3, 4])
        let data2 = try CatanJSON.encode(specificHarbor)
        let decoded2 = try CatanJSON.decode(Harbor.self, from: data2)
        XCTAssertEqual(specificHarbor, decoded2)
    }
    
    // MARK: - Edge Position Tests
    
    func testEdgePositionRoundTrip() throws {
        let edge = EdgePosition(edgeId: 5, nodeIds: (10, 11), adjacentHexIds: [1, 2])
        let data = try CatanJSON.encode(edge)
        let decoded = try CatanJSON.decode(EdgePosition.self, from: data)
        XCTAssertEqual(edge, decoded)
    }
    
    // MARK: - Helpers
    
    private func assertRoundTrip(_ message: ClientMessage, file: StaticString = #file, line: UInt = #line) throws {
        let data = try CatanJSON.encode(message)
        let decoded = try CatanJSON.decode(ClientMessage.self, from: data)
        XCTAssertEqual(message, decoded, file: file, line: line)
    }
    
    private func assertServerRoundTrip(_ message: ServerMessage, file: StaticString = #file, line: UInt = #line) throws {
        let data = try CatanJSON.encode(message)
        let decoded = try CatanJSON.decode(ServerMessage.self, from: data)
        XCTAssertEqual(message, decoded, file: file, line: line)
    }
    
    private func assertEventRoundTrip(_ event: GameDomainEvent, file: StaticString = #file, line: UInt = #line) throws {
        let data = try CatanJSON.encode(event)
        let decoded = try CatanJSON.decode(GameDomainEvent.self, from: data)
        XCTAssertEqual(event, decoded, file: file, line: line)
    }
    
    private func makeSampleLobbyState() -> LobbyState {
        LobbyState(
            lobbyId: "lobby-123",
            lobbyCode: "ABCD",
            lobbyName: "Test Game",
            hostId: "user-1",
            playerMode: .threeToFour,
            useBeginnerLayout: false,
            players: [
                LobbyPlayer(userId: "user-1", displayName: "Host", color: .red, isReady: true, isHost: true),
                LobbyPlayer(userId: "user-2", displayName: "Player 2", color: .blue, isReady: false, isHost: false)
            ],
            availableColors: [.white, .orange]
        )
    }
    
    private func makeSampleBoardLayout() -> BoardLayout {
        BoardLayout(
            hexes: [
                HexTile(hexId: 0, terrain: .desert, numberToken: nil, center: HexCoordinate(q: 0, r: 0)),
                HexTile(hexId: 1, terrain: .hills, numberToken: 8, center: HexCoordinate(q: 1, r: 0)),
                HexTile(hexId: 2, terrain: .forest, numberToken: 5, center: HexCoordinate(q: -1, r: 1))
            ],
            nodes: [
                NodePosition(nodeId: 0, adjacentHexIds: [0, 1], adjacentEdgeIds: [0, 1], adjacentNodeIds: [1, 2])
            ],
            edges: [
                EdgePosition(edgeId: 0, nodeIds: (0, 1), adjacentHexIds: [0, 1])
            ],
            harbors: [
                Harbor(harborId: 0, type: .generic, nodeIds: [10, 11])
            ],
            robberHexId: 0
        )
    }
}

