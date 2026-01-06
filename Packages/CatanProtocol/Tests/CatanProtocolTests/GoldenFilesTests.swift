import XCTest
@testable import CatanProtocol

/// Tests that verify golden file fixtures can be decoded and re-encoded stably.
/// This catches accidental breaking changes to the wire format.
final class GoldenFilesTests: XCTestCase {
    
    // MARK: - Client Envelope Golden Files
    
    func testClientAuthenticateGoldenFile() throws {
        let envelope = try loadGoldenClientEnvelope("client_authenticate")
        
        // Verify structure
        XCTAssertEqual(envelope.protocolVersion, ProtocolVersion(major: 1, minor: 0))
        XCTAssertEqual(envelope.requestId, "req-auth-001")
        XCTAssertNil(envelope.lastSeenEventIndex)
        
        // Verify message content
        if case .authenticate(let request) = envelope.message {
            XCTAssertEqual(request.identifier, "testuser@example.com")
            XCTAssertEqual(request.oneTimeCode, "123456")
            XCTAssertNil(request.sessionToken)
        } else {
            XCTFail("Expected authenticate message")
        }
        
        // Verify round-trip stability
        try assertGoldenStability("client_authenticate", envelope)
    }
    
    func testClientBuildRoadGoldenFile() throws {
        let envelope = try loadGoldenClientEnvelope("client_build_road")
        
        XCTAssertEqual(envelope.protocolVersion, ProtocolVersion(major: 1, minor: 0))
        XCTAssertEqual(envelope.requestId, "req-build-001")
        XCTAssertEqual(envelope.lastSeenEventIndex, 42)
        
        if case .buildRoad(let intent) = envelope.message {
            XCTAssertEqual(intent.edgeId, 15)
            XCTAssertFalse(intent.isFree)
        } else {
            XCTFail("Expected buildRoad message")
        }
        
        try assertGoldenStability("client_build_road", envelope)
    }
    
    func testClientProposeTradeGoldenFile() throws {
        let envelope = try loadGoldenClientEnvelope("client_propose_trade")
        
        XCTAssertEqual(envelope.lastSeenEventIndex, 50)
        
        if case .proposeTrade(let intent) = envelope.message {
            XCTAssertEqual(intent.tradeId, "trade-abc-123")
            XCTAssertEqual(intent.offering.brick, 2)
            XCTAssertEqual(intent.offering.lumber, 1)
            XCTAssertEqual(intent.requesting.ore, 1)
            XCTAssertEqual(intent.requesting.wool, 1)
            XCTAssertEqual(intent.targetPlayerIds, ["player-2", "player-3"])
        } else {
            XCTFail("Expected proposeTrade message")
        }
        
        try assertGoldenStability("client_propose_trade", envelope)
    }
    
    // MARK: - Server Envelope Golden Files
    
    func testServerProtocolErrorGoldenFile() throws {
        let envelope = try loadGoldenServerEnvelope("server_protocol_error")
        
        XCTAssertEqual(envelope.protocolVersion, ProtocolVersion(major: 1, minor: 0))
        XCTAssertEqual(envelope.correlationId, "req-old-001")
        
        if case .protocolError(let error) = envelope.message {
            XCTAssertEqual(error.code, .unsupportedVersion)
            XCTAssertTrue(error.message.contains("0.5"))
        } else {
            XCTFail("Expected protocolError message")
        }
        
        try assertServerGoldenStability("server_protocol_error", envelope)
    }
    
    func testServerLobbyStateGoldenFile() throws {
        let envelope = try loadGoldenServerEnvelope("server_lobby_state")
        
        XCTAssertEqual(envelope.correlationId, "req-join-001")
        
        if case .lobbyJoined(let lobby) = envelope.message {
            XCTAssertEqual(lobby.lobbyId, "lobby-456")
            XCTAssertEqual(lobby.lobbyCode, "WXYZ")
            XCTAssertEqual(lobby.lobbyName, "Friday Night Catan")
            XCTAssertEqual(lobby.hostId, "user-host-123")
            XCTAssertEqual(lobby.playerMode, .threeToFour)
            XCTAssertFalse(lobby.useBeginnerLayout)
            XCTAssertEqual(lobby.players.count, 2)
            XCTAssertEqual(lobby.availableColors, [.white, .orange])
            
            let host = lobby.players.first { $0.isHost }
            XCTAssertNotNil(host)
            XCTAssertEqual(host?.color, .red)
            XCTAssertTrue(host?.isReady ?? false)
        } else {
            XCTFail("Expected lobbyJoined message")
        }
        
        try assertServerGoldenStability("server_lobby_state", envelope)
    }
    
    func testServerGameEventsGoldenFile() throws {
        let envelope = try loadGoldenServerEnvelope("server_game_events")
        
        XCTAssertEqual(envelope.correlationId, "req-roll-001")
        
        if case .gameEvents(let batch) = envelope.message {
            XCTAssertEqual(batch.gameId, "game-xyz-789")
            XCTAssertEqual(batch.startIndex, 2)
            XCTAssertEqual(batch.endIndex, 3)
            XCTAssertEqual(batch.events.count, 2)
            
            // Check first event: dice rolled
            if case .diceRolled(let rolled) = batch.events[0] {
                XCTAssertEqual(rolled.playerId, "player-1")
                XCTAssertEqual(rolled.die1, 3)
                XCTAssertEqual(rolled.die2, 5)
                XCTAssertEqual(rolled.total, 8)
            } else {
                XCTFail("Expected diceRolled event")
            }
            
            // Check second event: resources produced
            if case .resourcesProduced(let produced) = batch.events[1] {
                XCTAssertEqual(produced.diceTotal, 8)
                XCTAssertEqual(produced.production.count, 2)
                
                let p1Production = produced.production.first { $0.playerId == "player-1" }
                XCTAssertNotNil(p1Production)
                XCTAssertEqual(p1Production?.resources.brick, 2)
                XCTAssertEqual(p1Production?.sources.first?.buildingType, .city)
            } else {
                XCTFail("Expected resourcesProduced event")
            }
        } else {
            XCTFail("Expected gameEvents message")
        }
        
        try assertServerGoldenStability("server_game_events", envelope)
    }
    
    // MARK: - All Golden Files Decode Test
    
    func testAllGoldenFilesCanDecode() throws {
        let clientFiles = ["client_authenticate", "client_build_road", "client_propose_trade"]
        let serverFiles = ["server_protocol_error", "server_lobby_state", "server_game_events"]
        
        for file in clientFiles {
            XCTAssertNoThrow(try loadGoldenClientEnvelope(file), "Failed to decode \(file)")
        }
        
        for file in serverFiles {
            XCTAssertNoThrow(try loadGoldenServerEnvelope(file), "Failed to decode \(file)")
        }
    }
    
    // MARK: - Helpers
    
    private func loadGoldenClientEnvelope(_ name: String) throws -> ClientEnvelope {
        let data = try loadGoldenFileData(name)
        return try CatanJSON.decode(ClientEnvelope.self, from: data)
    }
    
    private func loadGoldenServerEnvelope(_ name: String) throws -> ServerEnvelope {
        let data = try loadGoldenFileData(name)
        return try CatanJSON.decode(ServerEnvelope.self, from: data)
    }
    
    private func loadGoldenFileData(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "GoldenFiles") else {
            throw GoldenFileError.fileNotFound(name)
        }
        return try Data(contentsOf: url)
    }
    
    private func assertGoldenStability(_ name: String, _ envelope: ClientEnvelope, file: StaticString = #file, line: UInt = #line) throws {
        // Re-encode and compare
        let reencoded = try CatanJSON.encode(envelope)
        let original = try loadGoldenFileData(name)
        
        // Parse both as JSON for comparison (ignoring whitespace differences)
        let originalJSON = try JSONSerialization.jsonObject(with: original) as? NSDictionary
        let reencodedJSON = try JSONSerialization.jsonObject(with: reencoded) as? NSDictionary
        
        XCTAssertEqual(originalJSON, reencodedJSON, "Golden file \(name) round-trip mismatch", file: file, line: line)
    }
    
    private func assertServerGoldenStability(_ name: String, _ envelope: ServerEnvelope, file: StaticString = #file, line: UInt = #line) throws {
        let reencoded = try CatanJSON.encode(envelope)
        let original = try loadGoldenFileData(name)
        
        let originalJSON = try JSONSerialization.jsonObject(with: original) as? NSDictionary
        let reencodedJSON = try JSONSerialization.jsonObject(with: reencoded) as? NSDictionary
        
        XCTAssertEqual(originalJSON, reencodedJSON, "Golden file \(name) round-trip mismatch", file: file, line: line)
    }
    
    private enum GoldenFileError: Error {
        case fileNotFound(String)
    }
}

