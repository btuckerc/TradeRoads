# Trade Roads Architecture

## Overview

Trade Roads is a Catan-inspired digital board game built with a modern, event-sourced architecture. The system consists of four main components:

1. **GameCore** - Pure game logic (rules, state machine)
2. **CatanProtocol** - Wire protocol definitions and JSON utilities
3. **Server** - Vapor-based authoritative game server
4. **iOS App** - SwiftUI/SpriteKit client

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         iOS Client                               │
│  ┌─────────────┐  ┌─────────────┐  ┌───────────────────────┐   │
│  │   SwiftUI   │  │  SpriteKit  │  │   WebSocketClient     │   │
│  │   Views     │  │   Board     │  │   (CatanProtocol)     │   │
│  └──────┬──────┘  └──────┬──────┘  └───────────┬───────────┘   │
│         │                │                      │               │
│         └────────────────┴──────────────────────┘               │
│                          │                                       │
│                 GameStateManager                                 │
│                    (GameCore)                                    │
└────────────────────────────┬────────────────────────────────────┘
                             │ WebSocket (CatanProtocol)
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Vapor Server                               │
│  ┌─────────────────┐  ┌─────────────────┐  ┌────────────────┐  │
│  │ WebSocketHandler│  │   LobbyManager  │  │  GameManager   │  │
│  └────────┬────────┘  └────────┬────────┘  └───────┬────────┘  │
│           │                    │                    │           │
│           └────────────────────┴────────────────────┘           │
│                          │                                       │
│                    GameEngine                                    │
│                 (GameCore per game)                              │
│                          │                                       │
│                   ┌──────┴──────┐                               │
│                   │   Fluent    │                               │
│                   │  (Postgres) │                               │
│                   └─────────────┘                               │
└─────────────────────────────────────────────────────────────────┘
```

## Event Sourcing Model

Trade Roads uses event sourcing, where the game state is derived from a sequence of immutable events:

### Core Concepts

- **GameState** - The complete, immutable state at any point in time
- **GameAction** - A player's intent (what they want to do)
- **DomainEvent** - A fact about what happened (immutable record)
- **Validator** - Checks if an action is legal given current state
- **Reducer** - Applies an action to produce new state and events

### Flow

```
1. Client sends intent (GameAction) to server
2. Server validates action against current state
3. If valid, server reduces action → (newState, events)
4. Server persists events to database
5. Server broadcasts events to all clients
6. Clients apply events to their local state
```

### Benefits

- **Deterministic**: Same events always produce same state
- **Auditable**: Complete history of every game
- **Replayable**: Can reconstruct state from events
- **Reconnectable**: Clients can catch up after disconnect

## Module Responsibilities

### GameCore

The pure game engine, with zero dependencies on networking, UI, or timers.

- `GameState` - Complete game state (board, players, turn info)
- `GameAction` - All possible player intents
- `DomainEvent` - All significant state changes
- `Validator` - Rule enforcement
- `Reducer` - State transitions
- `BoardGenerator` - Standard and 5-6 player boards
- `LongestRoad` - Graph algorithm for longest road

### CatanProtocol

Wire contract between client and server.

- `ClientMessage` / `ServerMessage` - All message types
- `ClientEnvelope` / `ServerEnvelope` - Message wrappers with metadata
- `ProtocolVersion` - Versioning for compatibility
- `CatanJSON` - Canonical JSON encoder/decoder

### Server (Vapor)

Authoritative game server.

- `WebSocketHandler` - Connection management, message routing
- `LobbyManager` - Pre-game matchmaking
- `GameManager` - Active game registry
- `GameEngine` - Per-game actor with state and persistence
- `AuthService` - Session token management
- Fluent models: `User`, `Session`, `Lobby`, `Game`, `GameEvent`, `GameSnapshot`

### iOS App

SwiftUI and SpriteKit client.

- `WebSocketClient` - Server communication
- `GameStateManager` - Local state management
- `LobbyView` - Pre-game UI
- `GameView` - In-game UI
- `BoardScene` - SpriteKit hex board rendering

## Data Flow

### Game Action Flow

```
Player Tap → Interaction Engine → GameAction → WebSocket → Server
     ↓                                              ↓
Animation ←─── Event ←─── WebSocket ←─── Reduce(State, Action)
                                              ↓
                                        Persist Events
```

### Reconnection Flow

```
Client Connect → Authenticate → Reconnect(gameId, lastSeenEventIndex)
                                              ↓
                                    Server looks up game
                                              ↓
            ┌─────────────────────────────────┴───────────────────────┐
            ↓                                                         ↓
    Events available                                          Too many missed
            ↓                                                         ↓
    Send missing events                                    Load snapshot + events
            ↓                                                         ↓
    Client applies to local state                     Client rebuilds from snapshot
```

## Security Model

- **Dev Auth**: Simple identifier-based auth for development
- **Session Tokens**: HMAC-signed tokens with expiration
- **Player Identity**: Server enforces that clients can only act as themselves
- **State Authority**: Server is the single source of truth
- **RNG**: Server-side random number generation for dice and cards

## Database Schema

```sql
users           -- Player accounts
sessions        -- Auth sessions
lobbies         -- Pre-game waiting rooms
games           -- Active/completed games
game_events     -- Event log (append-only)
game_snapshots  -- Periodic state snapshots for fast reconnection
```

## Scalability Considerations

- **Actor per Game**: Games are isolated, can scale horizontally
- **Snapshot Cadence**: Configurable to balance storage vs reconnect speed
- **Event Compression**: Events are stored as JSON, could compress
- **Database**: PostgreSQL handles concurrent access

## Future Extensions

- **Spectator Mode**: Read-only event streams
- **Game Replay**: Playback recorded games
- **Custom Scenarios**: Different board layouts
- **Real Auth**: OAuth, email verification
- **Matchmaking**: ELO ratings, random matching

