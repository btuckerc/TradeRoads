import Foundation
import GameCore
import SwiftUI

/// Application state representing different screens.
enum AppScreen: Equatable {
    case login
    case lobby
    case game
}

/// Resume choice when user has both active lobby and game.
enum ResumeChoice {
    case lobby
    case game
    case fresh  // Leave lobby and start fresh
}

/// Manages the game state for the iOS client.
@MainActor
@Observable
final class GameStateManager {
    // MARK: - Navigation
    
    var currentScreen: AppScreen = .login
    
    // MARK: - User Info
    
    var userId: String?
    var displayName: String?
    var isAuthenticated: Bool { userId != nil }
    
    // MARK: - Lobby State
    
    var lobbyState: LobbyState?
    var isInLobby: Bool { lobbyState != nil }
    
    // MARK: - Game State
    
    var gameId: String?
    var gameState: GameState?
    var boardLayout: BoardLayout?
    var players: [GamePlayer] = []
    var localPlayerId: String?
    var isInGame: Bool { gameState != nil }
    
    // MARK: - Error Handling
    
    var errorMessage: String?
    var showError: Bool = false
    
    // MARK: - Resume State
    
    /// Pending session state for resume prompt.
    var pendingSessionState: SessionState?
    var showResumePrompt: Bool = false
    
    // MARK: - Event Queue (for animations)
    
    var pendingAnimations: [GameDomainEvent] = []
    var isAnimating: Bool = false
    
    // MARK: - Board Interaction State
    
    /// Currently selected node ID (for building settlements/cities).
    var selectedNodeId: Int?
    /// Currently selected edge ID (for building roads).
    var selectedEdgeId: Int?
    /// What the player is trying to build.
    var buildingMode: BuildingMode = .none
    
    enum BuildingMode: Equatable {
        case none
        case settlement
        case road
        case city
        case setupSettlement  // Free settlement during setup
        case setupRoad        // Free road during setup
    }
    
    // MARK: - Auth
    
    func setAuthenticated(userId: String, displayName: String) {
        self.userId = userId
        self.displayName = displayName
        currentScreen = .lobby
    }
    
    func logout() {
        userId = nil
        displayName = nil
        lobbyState = nil
        gameState = nil
        boardLayout = nil
        players = []
        localPlayerId = nil
        gameId = nil
        currentScreen = .login
    }
    
    // MARK: - Lobby
    
    func setLobbyState(_ state: LobbyState) {
        lobbyState = state
        currentScreen = .lobby
    }
    
    func clearLobby() {
        lobbyState = nil
    }
    
    // MARK: - Session State / Resume
    
    func handleSessionState(_ state: SessionState) {
        // Check if there's anything to resume
        if state.hasActiveSession {
            // If only one exists, auto-resume
            if state.activeLobby != nil && state.activeGame == nil {
                // Only lobby exists - auto-resume
                setLobbyState(state.activeLobby!)
            } else if state.activeGame != nil && state.activeLobby == nil {
                // Only game exists - store state for reconnect (client needs to call reconnect)
                pendingSessionState = state
                showResumePrompt = true
            } else {
                // Both exist - show prompt
                pendingSessionState = state
                showResumePrompt = true
            }
        }
        // If neither exists, do nothing - user is on lobby screen with fresh state
    }
    
    func resumeChoice(_ choice: ResumeChoice) {
        guard let state = pendingSessionState else { return }
        
        switch choice {
        case .lobby:
            if let lobby = state.activeLobby {
                setLobbyState(lobby)
            }
        case .game:
            // Store game info for reconnect - will be handled by caller
            if let game = state.activeGame {
                pendingGameReconnect = game
            }
        case .fresh:
            // User wants to leave lobby and start fresh - will be handled by caller
            break
        }
        
        pendingSessionState = nil
        showResumePrompt = false
    }
    
    /// Game info pending reconnection.
    var pendingGameReconnect: ActiveGameSummary?
    
    func clearPendingReconnect() {
        pendingGameReconnect = nil
    }
    
    // MARK: - Game
    
    /// Reconnect to an ongoing game.
    func reconnectToGame(event: GameReconnectedEvent) {
        gameId = event.gameId
        boardLayout = event.boardLayout
        players = event.playerOrder
        
        // Find local player
        localPlayerId = event.playerOrder.first { $0.userId == userId }?.playerId
        
        // Initialize game state with current turn info
        initializeReconnectedGameState(from: event)
        
        // Apply any pending events
        applyEvents(event.events)
        
        // Transition to game screen
        currentScreen = .game
    }
    
    private func initializeReconnectedGameState(from event: GameReconnectedEvent) {
        let config = GameConfig(
            gameId: event.gameId,
            playerMode: event.playerOrder.count > 4 ? .fiveToSix : .threeToFour
        )
        
        let playerInfos = event.playerOrder.map { p in
            (userId: p.userId, displayName: p.displayName, color: p.color)
        }
        
        var rng = SeededRNG(seed: UInt64.random(in: 0..<UInt64.max))
        var state = GameState.new(config: config, playerInfos: playerInfos, rng: &rng)
        
        // Set current turn state from reconnect data
        state.turn.activePlayerId = event.currentTurn.activePlayerId
        state.turn.turnNumber = event.currentTurn.turnNumber
        state.turn.setupRound = event.currentTurn.setupRound
        state.turn.setupNeedsRoad = event.currentTurn.setupNeedsRoad
        
        // Set phase from string
        switch event.currentTurn.phase {
        case "setup": state.turn.phase = .setup
        case "preRoll": state.turn.phase = .preRoll
        case "main": state.turn.phase = .main
        case "movingRobber": state.turn.phase = .movingRobber
        case "stealing": state.turn.phase = .stealing
        case "discarding": state.turn.phase = .discarding
        case "ended": state.turn.phase = .ended
        default: state.turn.phase = .setup
        }
        
        // Restore buildings state
        for (nodeId, playerId) in event.buildings.settlements {
            state.buildings = state.buildings.placingSettlement(at: nodeId, playerId: playerId)
            state = state.updatingPlayer(id: playerId) { $0.adding(settlement: nodeId) }
        }
        for (nodeId, playerId) in event.buildings.cities {
            state.buildings = state.buildings.upgradingToCity(at: nodeId)
            state = state.updatingPlayer(id: playerId) { $0.upgradingToCity(at: nodeId) }
        }
        for (edgeId, playerId) in event.buildings.roads {
            state.buildings = state.buildings.placingRoad(at: edgeId, playerId: playerId)
            state = state.updatingPlayer(id: playerId) { $0.adding(road: edgeId) }
        }
        
        gameState = state
    }
    
    func startGame(event: GameStartedEvent) {
        gameId = event.gameId
        boardLayout = event.boardLayout
        players = event.playerOrder
        
        // Find local player
        localPlayerId = event.playerOrder.first { $0.userId == userId }?.playerId
        
        // Initialize game state
        initializeGameState(from: event)
        
        currentScreen = .game
    }
    
    private func initializeGameState(from event: GameStartedEvent) {
        // Create initial game state from the started event
        // This will be populated as events arrive
        let config = GameConfig(
            gameId: event.gameId,
            playerMode: event.playerOrder.count > 4 ? .fiveToSix : .threeToFour
        )
        
        let playerInfos = event.playerOrder.map { p in
            (userId: p.userId, displayName: p.displayName, color: p.color)
        }
        
        // Use the board seed from the server (we'll rebuild from events anyway)
        var rng = SeededRNG(seed: UInt64.random(in: 0..<UInt64.max))
        gameState = GameState.new(config: config, playerInfos: playerInfos, rng: &rng)
    }
    
    func applyEvents(_ events: [GameDomainEvent]) {
        for event in events {
            applyEvent(event)
        }
    }
    
    func applyEvent(_ event: GameDomainEvent) {
        // Queue for animation
        pendingAnimations.append(event)
        
        // Apply to local state (convert protocol event to domain event and apply)
        // Note: In a full implementation, we'd convert GameDomainEvent to DomainEvent
        // For now, we'll handle the key events directly
        applyProtocolEventToState(event)
    }
    
    private func applyProtocolEventToState(_ event: GameDomainEvent) {
        guard var state = gameState else { return }
        
        switch event {
        case .diceRolled(let e):
            state.turn.lastRoll = DiceRoll(die1: e.die1, die2: e.die2)
            state.turn.phase = .main
            
        case .turnStarted(let e):
            state.turn.activePlayerId = e.playerId
            state.turn.turnNumber = e.turnNumber
            state.turn.phase = .preRoll
            state.turn.lastRoll = nil
            
        case .turnEnded:
            state.turn.lastRoll = nil
            state.turn.phase = .preRoll
            
        case .roadBuilt(let e):
            state.buildings = state.buildings.placingRoad(at: e.edgeId, playerId: e.playerId)
            state = state.updatingPlayer(id: e.playerId) { $0.adding(road: e.edgeId) }
            if !e.wasFree {
                state = state.updatingPlayer(id: e.playerId) {
                    $0.removing(resources: e.resourcesSpent)
                }
            }
            
        case .settlementBuilt(let e):
            state.buildings = state.buildings.placingSettlement(at: e.nodeId, playerId: e.playerId)
            state = state.updatingPlayer(id: e.playerId) { $0.adding(settlement: e.nodeId) }
            if !e.wasFree {
                state = state.updatingPlayer(id: e.playerId) {
                    $0.removing(resources: e.resourcesSpent)
                }
            }
            
        case .cityBuilt(let e):
            state.buildings = state.buildings.upgradingToCity(at: e.nodeId)
            state = state.updatingPlayer(id: e.playerId) { $0.upgradingToCity(at: e.nodeId) }
            state = state.updatingPlayer(id: e.playerId) {
                $0.removing(resources: e.resourcesSpent)
            }
            
        case .resourcesProduced(let e):
            for prod in e.production {
                state = state.updatingPlayer(id: prod.playerId) {
                    $0.adding(resources: prod.resources)
                }
            }
            
        case .robberMoved(let e):
            state.robberHexId = e.toHexId
            
        case .resourceStolen(let e):
            let stolen = ResourceBundle.single(e.resourceType, count: 1)
            state = state.updatingPlayer(id: e.victimId) {
                $0.removing(resources: stolen)
            }
            state = state.updatingPlayer(id: e.thiefId) {
                $0.adding(resources: stolen)
            }
            
        case .playerWon(let e):
            state.winnerId = e.playerId
            
        case .longestRoadAwarded(let e):
            state.awards.longestRoadHolder = e.newHolderId
            state.awards.longestRoadLength = e.roadLength
            
        case .largestArmyAwarded(let e):
            state.awards.largestArmyHolder = e.newHolderId
            state.awards.largestArmySize = e.knightCount
            
        case .setupPiecePlaced(let e):
            if e.pieceType == .settlement {
                state.buildings = state.buildings.placingSettlement(at: e.locationId, playerId: e.playerId)
                state = state.updatingPlayer(id: e.playerId) { $0.adding(settlement: e.locationId) }
                state.turn.setupNeedsRoad = true
            } else if e.pieceType == .road {
                state.buildings = state.buildings.placingRoad(at: e.locationId, playerId: e.playerId)
                state = state.updatingPlayer(id: e.playerId) { $0.adding(road: e.locationId) }
                state.turn.setupNeedsRoad = false
            }
            
        case .setupTurnAdvanced(let e):
            state.turn.activePlayerId = e.nextPlayerId
            state.turn.setupRound = e.setupRound
            state.turn.setupPlayerIndex = e.setupPlayerIndex
            state.turn.setupForward = e.setupForward
            state.turn.setupNeedsRoad = false
            
        case .setupPhaseEnded:
            state.turn.phase = .preRoll
            state.turn.turnNumber = 1
            
        case .mustDiscard(let e):
            state.turn.phase = .discarding
            state.turn.playersToDiscard = Set(e.playerDiscardRequirements.map { $0.playerId })
            
        default:
            break
        }
        
        gameState = state
    }
    
    func loadSnapshot(_ snapshot: GameSnapshot) {
        // In a full implementation, we'd decode the full state
        // For now we'll handle this when the server sends state
    }
    
    func endGame(event: GameEndedEvent) {
        if let state = gameState {
            var newState = state
            newState.winnerId = event.winnerId
            gameState = newState
        }
    }
    
    // MARK: - Errors
    
    func setError(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    func clearError() {
        errorMessage = nil
        showError = false
    }
    
    // MARK: - Computed Properties
    
    var localPlayer: Player? {
        guard let playerId = localPlayerId else { return nil }
        return gameState?.player(id: playerId)
    }
    
    var activePlayer: Player? {
        gameState?.activePlayer
    }
    
    var isLocalPlayerTurn: Bool {
        localPlayerId == gameState?.turn.activePlayerId
    }
    
    var currentPhase: GamePhase? {
        gameState?.turn.phase
    }
    
    var diceRoll: (Int, Int)? {
        guard let roll = gameState?.turn.lastRoll else { return nil }
        return (roll.die1, roll.die2)
    }
    
    var diceTotal: Int? {
        guard let roll = diceRoll else { return nil }
        return roll.0 + roll.1
    }
    
    // MARK: - Setup Phase Helpers
    
    /// Whether we're in setup phase.
    var isSetupPhase: Bool {
        currentPhase == .setup
    }
    
    /// What piece the local player needs to place during setup.
    var setupPieceNeeded: BuildingMode {
        guard isSetupPhase, isLocalPlayerTurn else { return .none }
        guard let state = gameState else { return .none }
        
        // If setupNeedsRoad is true, we just placed a settlement and need a road
        if state.turn.setupNeedsRoad {
            return .setupRoad
        } else {
            return .setupSettlement
        }
    }
    
    /// Clear selection state.
    func clearSelection() {
        selectedNodeId = nil
        selectedEdgeId = nil
        buildingMode = .none
    }
    
    /// Select a node for building.
    func selectNode(_ nodeId: Int) {
        selectedNodeId = nodeId
        selectedEdgeId = nil
    }
    
    /// Select an edge for building.
    func selectEdge(_ edgeId: Int) {
        selectedEdgeId = edgeId
        selectedNodeId = nil
    }
}

// MARK: - ResourceBundle Extension

extension ResourceBundle {
    static func single(_ resource: ResourceType, count: Int) -> ResourceBundle {
        switch resource {
        case .brick: return ResourceBundle(brick: count, lumber: 0, ore: 0, grain: 0, wool: 0)
        case .lumber: return ResourceBundle(brick: 0, lumber: count, ore: 0, grain: 0, wool: 0)
        case .ore: return ResourceBundle(brick: 0, lumber: 0, ore: count, grain: 0, wool: 0)
        case .grain: return ResourceBundle(brick: 0, lumber: 0, ore: 0, grain: count, wool: 0)
        case .wool: return ResourceBundle(brick: 0, lumber: 0, ore: 0, grain: 0, wool: count)
        }
    }
}
