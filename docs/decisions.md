# Trade Roads Design Decisions

This document records key architectural and implementation decisions.

## Authentication

### Decision: Dev Auth with HMAC Tokens

**Choice**: Simple identifier-based authentication with HMAC-SHA256 signed session tokens.

**Rationale**:
- Fast to implement for development
- No external dependencies (OAuth providers)
- Demonstrates the auth flow without complexity
- Easy to upgrade later

**Token Format**:
```
base64(random_bytes).base64(hmac_signature)
```

**Session Duration**: 7 days

**Future Consideration**: Production should use OAuth (Apple Sign-In, Google) with proper email verification.

---

## JSON Encoding

### Decision: Snake Case with ISO8601 Dates

**Choice**: 
- Keys: `snake_case`
- Dates: ISO8601 format
- Sorted keys for output stability

**Rationale**:
- Snake case is more readable in JSON
- ISO8601 is universally parseable
- Sorted keys make golden file tests stable
- Matches common API conventions

**Implementation**:
```swift
public enum CatanJSON {
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
}
```

---

## Snapshot Cadence

### Decision: Snapshot Every 50 Events

**Choice**: Create a `GameSnapshot` every 50 domain events.

**Rationale**:
- Balances storage cost vs reconnection speed
- 50 events ≈ 5-10 turns
- Reconnection loads at most 49 events
- Typical game has 200-400 events total

**Trade-offs**:
- Lower cadence = more events to replay on reconnect
- Higher cadence = more storage, more writes

**Configurable**: The `snapshotInterval` constant in `GameEngine` can be adjusted.

---

## RNG Strategy

### Decision: Server-Authoritative with SeededRNG

**Choice**: 
- All RNG happens server-side
- `SeededRNG` for deterministic testing
- `SystemRNG` for production

**Rationale**:
- Prevents cheating (can't predict dice)
- Enables deterministic replay in tests
- Allows game replay/verification

**Implementation**:
```swift
public struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    
    public init(seed: UInt64) {
        self.state = seed
    }
    
    public mutating func next() -> UInt64 {
        // xorshift64* algorithm
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 0x2545F4914F6CDD1D
    }
}
```

---

## Actor Model for Game State

### Decision: One Actor per Game

**Choice**: Each game is managed by a `GameEngine` actor.

**Rationale**:
- Swift actors provide safe concurrency
- Serialized access prevents race conditions
- Natural fit for event-sourced state
- Can scale horizontally (games are independent)

**Structure**:
```swift
actor GameEngine {
    private var state: GameState
    
    func processAction(_ action: GameAction) async -> ActionResult {
        // Serialized by actor
    }
}
```

---

## Event Storage

### Decision: JSON in TEXT Column

**Choice**: Store domain events as JSON strings in a TEXT column.

**Rationale**:
- Simple to implement
- Human-readable for debugging
- No schema migrations for event format changes
- PostgreSQL handles TEXT efficiently

**Trade-offs**:
- Larger storage than binary
- Slower queries on event content (but rarely needed)

**Schema**:
```sql
CREATE TABLE game_events (
    id UUID PRIMARY KEY,
    game_id UUID REFERENCES games(id),
    event_index INT NOT NULL,
    event_type VARCHAR NOT NULL,
    event_json TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL,
    UNIQUE(game_id, event_index)
);
```

---

## Protocol Versioning

### Decision: Semantic Versioning with Range Support

**Choice**: 
- Version format: `major.minor`
- Client sends version in every message
- Server supports a range of versions

**Rationale**:
- Major version = breaking changes
- Minor version = backward-compatible additions
- Range support allows gradual client upgrades

**Implementation**:
```swift
public struct ProtocolVersion {
    public static let current = ProtocolVersion(major: 1, minor: 0)
    public static let minSupported = ProtocolVersion(major: 1, minor: 0)
    
    public var isSupported: Bool {
        self >= .minSupported && self.major <= Self.current.major
    }
}
```

---

## UI Framework

### Decision: SwiftUI + SpriteKit

**Choice**: 
- SwiftUI for UI/HUD
- SpriteKit for board rendering

**Rationale**:
- SwiftUI: Modern, declarative, easy state binding
- SpriteKit: Efficient 2D rendering, good for hexes
- Hybrid approach uses each framework's strengths

**Alternative Considered**: Metal for board (rejected: overkill for 2D hexes)

---

## Lobby vs Game Separation

### Decision: Explicit Lobby Phase

**Choice**: Separate lobby management from game management.

**Rationale**:
- Clear state machine: lobby → game → ended
- Lobby has different rules (join/leave freely)
- Reduces complexity in game code
- Natural UI separation

**Flow**:
```
1. Create/Join Lobby
2. Select Color + Ready Up
3. Host Starts Game (all ready)
4. Game Engine Takes Over
5. Game End → Back to Lobby
```

---

## Reconnection Strategy

### Decision: Event Replay from Last Seen Index

**Choice**: 
- Client tracks `lastSeenEventIndex`
- Server sends missing events on reconnect
- Falls back to snapshot + events if gap is large

**Rationale**:
- Simple to implement
- Clients stay in sync
- Graceful handling of disconnects
- No duplicate event processing

**Implementation**:
- Client sends `lastSeenEventIndex` in every message
- On reconnect, server returns events with index > lastSeen
- If gap > snapshotInterval, send latest snapshot + subsequent events

---

## Color Selection

### Decision: First-Come-First-Served in Lobby

**Choice**: Players select colors in the lobby, each color can only be taken once.

**Rationale**:
- Clear ownership before game starts
- Prevents conflicts during game
- Simple UI: show taken vs available

**Colors**:
- Base game: Red, Blue, Orange, White
- 5-6 player: adds Green, Brown

