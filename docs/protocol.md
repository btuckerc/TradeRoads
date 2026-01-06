# Trade Roads Protocol Specification

## Overview

The Trade Roads protocol defines communication between clients and the server over WebSocket. All messages are JSON-encoded using snake_case key naming and ISO8601 dates.

## Protocol Version

```json
{
  "major": 1,
  "minor": 0
}
```

- **Current Version**: 1.0
- **Minimum Supported**: 1.0
- Clients must send their protocol version in every message
- Server rejects unsupported versions with `protocol_error`

## Message Envelopes

### Client → Server

```json
{
  "protocol_version": { "major": 1, "minor": 0 },
  "request_id": "req-123",
  "last_seen_event_index": 42,
  "sent_at": "2024-01-01T12:00:00Z",
  "message": { ... }
}
```

- `request_id`: Unique ID for request/response correlation
- `last_seen_event_index`: Last event the client has processed (for reconnection)

### Server → Client

```json
{
  "protocol_version": { "major": 1, "minor": 0 },
  "correlation_id": "req-123",
  "sent_at": "2024-01-01T12:00:00Z",
  "message": { ... }
}
```

- `correlation_id`: Echoes the `request_id` from the request (if applicable)

## Message Catalog

### Authentication

#### authenticate (Client → Server)
```json
{
  "authenticate": {
    "identifier": "username",
    "session_token": null
  }
}
```

#### authenticated (Server → Client)
```json
{
  "authenticated": {
    "user_id": "uuid",
    "session_token": "token.signature",
    "display_name": "username"
  }
}
```

#### authentication_failed (Server → Client)
```json
{
  "authentication_failed": {
    "reason": "session_expired"
  }
}
```

### Lobby Management

#### create_lobby (Client → Server)
```json
{
  "create_lobby": {
    "lobby_name": "My Game",
    "player_mode": "three_to_four",
    "use_beginner_layout": true
  }
}
```

#### lobby_created (Server → Client)
```json
{
  "lobby_created": {
    "lobby_id": "uuid",
    "lobby_code": "ABCD",
    "lobby": { ... }
  }
}
```

#### join_lobby (Client → Server)
```json
{
  "join_lobby": {
    "lobby_code": "ABCD"
  }
}
```

#### select_color (Client → Server)
```json
{
  "select_color": {
    "color": "red"
  }
}
```

#### set_ready (Client → Server)
```json
{
  "set_ready": {
    "ready": true
  }
}
```

#### start_game (Client → Server)
```json
"start_game"
```

### Game Actions

#### roll_dice (Client → Server)
```json
"roll_dice"
```

#### build_road (Client → Server)
```json
{
  "build_road": {
    "edge_id": 42,
    "is_free": false
  }
}
```

#### build_settlement (Client → Server)
```json
{
  "build_settlement": {
    "node_id": 15,
    "is_free": false
  }
}
```

#### build_city (Client → Server)
```json
{
  "build_city": {
    "node_id": 15
  }
}
```

#### buy_development_card (Client → Server)
```json
"buy_development_card"
```

#### end_turn (Client → Server)
```json
"end_turn"
```

### Game Events (Server → Client)

#### game_started
```json
{
  "game_started": {
    "game_id": "uuid",
    "player_order": [...],
    "board_layout": {...},
    "initial_event_index": 0
  }
}
```

#### game_events
```json
{
  "game_events": {
    "game_id": "uuid",
    "events": [...],
    "start_index": 1,
    "end_index": 5
  }
}
```

#### Event Types

- `dice_rolled` - Dice roll result
- `resources_produced` - Resources distributed from roll
- `turn_started` - New turn began
- `turn_ended` - Turn completed
- `road_built` - Road placed
- `settlement_built` - Settlement placed
- `city_built` - City upgraded
- `development_card_bought` - Dev card purchased
- `knight_played` - Knight card used
- `robber_moved` - Robber relocated
- `resource_stolen` - Resource taken by robber
- `longest_road_awarded` - Award changed hands
- `largest_army_awarded` - Award changed hands
- `player_won` - Game ended with winner

### Error Handling

#### protocol_error (Server → Client)
```json
{
  "protocol_error": {
    "code": "unsupported_version",
    "message": "Protocol version 0.1 not supported"
  }
}
```

Error codes:
- `unsupported_version` - Protocol version not supported
- `malformed_message` - Could not parse message
- `unauthorized` - Not authenticated
- `internal_error` - Server error

#### intent_rejected (Server → Client)
```json
{
  "intent_rejected": {
    "request_id": "req-123",
    "violations": [
      {
        "code": "not_your_turn",
        "message": "It is not your turn"
      }
    ]
  }
}
```

### Reconnection

#### reconnect (Client → Server)
```json
{
  "reconnect": {
    "game_id": "uuid",
    "last_seen_event_index": 42
  }
}
```

Server responds with either:
- `game_events` with missing events
- `game_snapshot` + `game_events` if too many missed

## Data Types

### PlayerMode
- `"three_to_four"` - Standard 3-4 player
- `"five_to_six"` - Extended 5-6 player

### PlayerColor
- `"red"`, `"blue"`, `"orange"`, `"white"`, `"green"`, `"brown"`

### ResourceType
- `"brick"`, `"lumber"`, `"ore"`, `"grain"`, `"wool"`

### TerrainType
- `"hills"`, `"forest"`, `"mountains"`, `"fields"`, `"pasture"`, `"desert"`

### HarborType
- `"generic"` - 3:1 trade
- `"brick"`, `"lumber"`, `"ore"`, `"grain"`, `"wool"` - 2:1 specific

### DevelopmentCardType
- `"knight"`, `"road_building"`, `"year_of_plenty"`, `"monopoly"`, `"victory_point"`

## JSON Encoding Rules

- Keys: snake_case
- Dates: ISO8601 format
- Enums: snake_case string values
- Optionals: Omitted when null
- Arrays: Empty arrays included

Example encoder configuration:
```swift
let encoder = JSONEncoder()
encoder.keyEncodingStrategy = .convertToSnakeCase
encoder.dateEncodingStrategy = .iso8601
encoder.outputFormatting = [.sortedKeys]
```

