// MARK: - GameCore Module

/// GameCore is a pure, deterministic game engine implementing CATAN rules.
///
/// # Architecture
///
/// The engine follows an event-sourcing pattern:
/// - `GameState` is immutable and represents the complete game state at a point in time
/// - `GameAction` represents player intents (what they want to do)
/// - `Validator.validate(_:state:)` checks if an action is legal
/// - `Reducer.reduce(_:action:rng:)` applies an action and returns new state + events
/// - `DomainEvent` represents facts about what happened
/// - `GameState.apply(_:)` reconstructs state from events
///
/// # Usage
///
/// ```swift
/// var state = GameState.new(config: config, rng: &rng)
/// let action = GameAction.rollDice(playerId: "p1")
///
/// let violations = Validator.validate(action, state: state)
/// guard violations.isEmpty else { /* handle error */ }
///
/// let (newState, events) = Reducer.reduce(state, action: action, rng: &rng)
/// // broadcast events to clients
/// state = newState
/// ```
///
/// # Determinism
///
/// GameCore is fully deterministic when given the same RNG seed. This enables:
/// - Replay from event logs
/// - Deterministic tests
/// - State verification between client and server

@_exported import CatanProtocol
@_exported import Foundation
