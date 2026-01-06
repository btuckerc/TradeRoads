# Trade Roads Testing Guide

## Test Structure

The project has tests at multiple levels:

```
trade-roads/
├── Packages/
│   ├── GameCore/Tests/
│   │   └── GameCoreTests/
│   │       ├── BoardGeneratorTests.swift
│   │       ├── ModelTests.swift
│   │       ├── ReducerTests.swift
│   │       ├── ValidatorTests.swift
│   │       └── InvariantTests.swift
│   └── CatanProtocol/Tests/
│       └── CatanProtocolTests/
│           ├── RoundTripCodableTests.swift
│           └── GoldenFilesTests.swift
├── Server/Tests/
│   └── ServerTests.swift
└── Apps/iOS/TradeRoads/
    ├── TradeRoadsTests/
    └── TradeRoadsUITests/
```

## Running Tests

### All Tests

```bash
./scripts/test.sh
```

### By Package

```bash
# GameCore (78 tests)
cd Packages/GameCore && swift test

# CatanProtocol (60 tests)
cd Packages/CatanProtocol && swift test

# Server (26 tests)
cd Server && swift test
```

### iOS Tests

```bash
cd Apps/iOS/TradeRoads
xcodebuild test \
  -scheme TradeRoads \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -resultBundlePath TestResults
```

## Test Categories

### GameCore Tests

#### Model Tests
- Resource bundle operations
- Player state mutations
- Board coordinate systems

#### Validator Tests
- Setup phase rules
- Building placement rules
- Trading rules
- Development card rules

#### Reducer Tests
- Action → Event transformations
- State transitions
- RNG behavior with seeded generators

#### Board Generator Tests
- Standard board layout
- 5-6 player extended board
- Hex/node/edge adjacency

#### Invariant Tests
- Deterministic replay
- State consistency
- Event application

### CatanProtocol Tests

#### Round-Trip Codable Tests
- All message types encode/decode correctly
- Snake case key conversion
- Date formatting

#### Golden File Tests
- Protocol stability
- Backward compatibility
- Message format verification

Golden files in `Tests/CatanProtocolTests/GoldenFiles/`:
- `client_authenticate.json`
- `client_build_road.json`
- `client_propose_trade.json`
- `server_game_events.json`
- `server_lobby_state.json`
- `server_protocol_error.json`

### Server Tests

#### Protocol Tests
- Version support checking
- Version comparison

#### Event Conversion Tests
- DomainEvent → GameDomainEvent mapping
- All event types covered

#### JSON Encoding Tests
- Envelope structure
- Message encoding
- Error encoding

#### Token Tests
- Token verification
- Malformed token rejection

#### Model Tests
- LobbyPlayerInfo codable
- GamePlayerInfo codable

#### Route Tests
- Health endpoint
- Version endpoint

## Writing New Tests

### GameCore Test Pattern

```swift
func testSomeRule() {
    // Setup: Create a specific game state
    var rng = SeededRNG(seed: 12345)
    let config = GameConfig(gameId: "test", playerMode: .threeToFour)
    let state = GameState.new(config: config, playerInfos: [...], rng: &rng)
    
    // Create an action
    let action = GameAction.buildRoad(playerId: "player-0", edgeId: 42)
    
    // Validate
    let violations = Validator.validate(action, state: state)
    
    // Assert
    XCTAssertFalse(violations.isValid)
    XCTAssertTrue(violations.contains { $0.code == .insufficientResources })
}
```

### Server Test Pattern

```swift
func testSomeEndpoint() async throws {
    try await app.test(.GET, "api/endpoint", afterResponse: { response async throws in
        XCTAssertEqual(response.status, .ok)
        let result = try response.content.decode(ExpectedType.self)
        XCTAssertEqual(result.field, expectedValue)
    })
}
```

### Golden File Test Pattern

```swift
func testGoldenFile() throws {
    // Load golden file
    let goldenURL = Bundle.module.url(forResource: "message_name", withExtension: "json")!
    let goldenData = try Data(contentsOf: goldenURL)
    let goldenJSON = String(data: goldenData, encoding: .utf8)!
    
    // Create and encode message
    let message = SomeMessage(...)
    let encoded = try CatanJSON.encodeToString(message)
    
    // Compare
    XCTAssertEqual(encoded, goldenJSON)
    
    // Decode and verify
    let decoded = try CatanJSON.decode(SomeMessage.self, from: goldenJSON)
    XCTAssertEqual(decoded, message)
}
```

## Deterministic Testing

For tests involving RNG:

```swift
// Use SeededRNG for reproducibility
var rng = SeededRNG(seed: 12345)

// Same seed = same results
let state1 = GameState.new(config: config, playerInfos: infos, rng: &rng)

var rng2 = SeededRNG(seed: 12345)
let state2 = GameState.new(config: config, playerInfos: infos, rng: &rng2)

XCTAssertEqual(state1, state2)
```

## Coverage

To generate coverage reports:

```bash
cd Packages/GameCore
swift test --enable-code-coverage

# View coverage
xcrun llvm-cov report \
  .build/debug/GameCorePackageTests.xctest/Contents/MacOS/GameCorePackageTests \
  -instr-profile .build/debug/codecov/default.profdata
```

## Continuous Integration

The test suite is designed to run without external dependencies where possible:

- GameCore: Pure Swift, no external deps
- CatanProtocol: Pure Swift, no external deps
- Server: Uses XCTVapor, no database required for most tests
- iOS: Requires simulator

## Debugging Tests

```bash
# Verbose output
swift test --verbose

# Filter specific test
swift test --filter ReducerTests.testRollDice

# Run with sanitizers
swift test -Xswiftc -sanitize=address
```

