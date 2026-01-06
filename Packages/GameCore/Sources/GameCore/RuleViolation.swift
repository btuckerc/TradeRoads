// MARK: - Rule Violations

import Foundation
import CatanProtocol

/// Represents a rule violation that prevents an action from being executed.
public struct Violation: Sendable, Hashable, Codable, Error {
    public let code: RuleViolationCode
    public let message: String
    
    public init(code: RuleViolationCode, message: String) {
        self.code = code
        self.message = message
    }
    
    // MARK: - Factory Methods
    
    public static func notYourTurn() -> Violation {
        Violation(code: .notYourTurn, message: "It is not your turn")
    }
    
    public static func mustRollFirst() -> Violation {
        Violation(code: .mustRollFirst, message: "You must roll the dice first")
    }
    
    public static func alreadyRolled() -> Violation {
        Violation(code: .alreadyRolled, message: "You have already rolled this turn")
    }
    
    public static func mustMoveRobber() -> Violation {
        Violation(code: .mustMoveRobber, message: "You must move the robber first")
    }
    
    public static func mustDiscardFirst() -> Violation {
        Violation(code: .mustDiscardFirst, message: "You must discard resources first")
    }
    
    public static func mustStealFirst() -> Violation {
        Violation(code: .mustStealFirst, message: "You must steal a resource first")
    }
    
    public static func insufficientResources(need: String) -> Violation {
        Violation(code: .insufficientResources, message: "Insufficient resources: need \(need)")
    }
    
    public static func noSupplyRemaining(piece: String) -> Violation {
        Violation(code: .noSupplyRemaining, message: "No \(piece) remaining in your supply")
    }
    
    public static func invalidLocation() -> Violation {
        Violation(code: .invalidLocation, message: "Invalid location")
    }
    
    public static func violatesDistanceRule() -> Violation {
        Violation(code: .violatesDistanceRule, message: "Too close to another settlement (must be 2+ edges away)")
    }
    
    public static func noAdjacentRoad() -> Violation {
        Violation(code: .noAdjacentRoad, message: "Must build adjacent to your road network")
    }
    
    public static func noSettlementToUpgrade() -> Violation {
        Violation(code: .noSettlementToUpgrade, message: "You don't have a settlement at this location")
    }
    
    public static func locationOccupied() -> Violation {
        Violation(code: .locationOccupied, message: "This location is already occupied")
    }
    
    public static func cannotTradeWithSelf() -> Violation {
        Violation(code: .cannotTradeWithSelf, message: "Cannot trade with yourself")
    }
    
    public static func inactivePlayerCannotTrade() -> Violation {
        Violation(code: .inactivePlayerCannotTrade, message: "Only the active player can propose trades")
    }
    
    public static func invalidTradeRatio() -> Violation {
        Violation(code: .invalidTradeRatio, message: "Invalid trade ratio for maritime trade")
    }
    
    public static func noSuchTradeProposal() -> Violation {
        Violation(code: .noSuchTradeProposal, message: "Trade proposal not found")
    }
    
    public static func tradeAlreadyAccepted() -> Violation {
        Violation(code: .tradeAlreadyAccepted, message: "You have already responded to this trade")
    }
    
    public static func notTargetOfTrade() -> Violation {
        Violation(code: .notTargetOfTrade, message: "You are not a target of this trade")
    }
    
    public static func noDevCardToPlay() -> Violation {
        Violation(code: .noDevCardToPlay, message: "You don't have that development card")
    }
    
    public static func cannotPlayCardBoughtThisTurn() -> Violation {
        Violation(code: .cannotPlayCardBoughtThisTurn, message: "Cannot play a card bought this turn")
    }
    
    public static func alreadyPlayedDevCard() -> Violation {
        Violation(code: .alreadyPlayedDevCard, message: "You can only play one development card per turn")
    }
    
    public static func invalidDevCardType() -> Violation {
        Violation(code: .invalidDevCardType, message: "Cannot play this type of development card")
    }
    
    public static func mustMoveRobberToNewHex() -> Violation {
        Violation(code: .mustMoveRobberToNewHex, message: "Must move robber to a different hex")
    }
    
    public static func noEligibleVictim() -> Violation {
        Violation(code: .noEligibleVictim, message: "No eligible player to steal from")
    }
    
    public static func victimHasNoResources() -> Violation {
        Violation(code: .victimHasNoResources, message: "That player has no resources to steal")
    }
    
    public static func gameNotStarted() -> Violation {
        Violation(code: .gameNotStarted, message: "Game has not started")
    }
    
    public static func gameAlreadyEnded() -> Violation {
        Violation(code: .gameAlreadyEnded, message: "Game has already ended")
    }
    
    public static func invalidAction(_ message: String) -> Violation {
        Violation(code: .invalidAction, message: message)
    }
    
    public static func wrongPhase(expected: String, actual: String) -> Violation {
        Violation(code: .invalidAction, message: "Wrong phase: expected \(expected), but in \(actual)")
    }
    
    public static func wrongDiscardAmount(required: Int, provided: Int) -> Violation {
        Violation(code: .invalidAction, message: "Must discard exactly \(required) cards, but provided \(provided)")
    }
}

/// Result of validation - either empty (valid) or a list of violations.
public typealias ValidationResult = [Violation]

extension ValidationResult {
    /// Check if the action is valid (no violations).
    public var isValid: Bool {
        isEmpty
    }
}

