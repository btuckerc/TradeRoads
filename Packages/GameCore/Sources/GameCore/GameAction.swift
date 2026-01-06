// MARK: - Game Actions (Player Intents)

import Foundation
import CatanProtocol

/// Actions that players can take in the game.
/// These are "intents" - they must be validated before being applied.
public enum GameAction: Sendable, Hashable, Codable {
    // MARK: - Setup Phase
    
    /// Place a settlement during setup.
    case setupPlaceSettlement(playerId: String, nodeId: Int)
    
    /// Place a road during setup.
    case setupPlaceRoad(playerId: String, edgeId: Int)
    
    // MARK: - Dice
    
    /// Roll the dice at the start of a turn.
    case rollDice(playerId: String)
    
    // MARK: - Robber (on 7)
    
    /// Discard resources when over 7 cards on a 7 roll.
    case discardResources(playerId: String, resources: ResourceBundle)
    
    /// Move the robber to a new hex.
    case moveRobber(playerId: String, hexId: Int)
    
    /// Steal a resource from an adjacent player.
    case stealResource(playerId: String, victimId: String)
    
    /// Skip stealing (when no valid targets).
    case skipSteal(playerId: String)
    
    // MARK: - Building
    
    /// Build a road.
    case buildRoad(playerId: String, edgeId: Int)
    
    /// Build a settlement.
    case buildSettlement(playerId: String, nodeId: Int)
    
    /// Build a city (upgrade settlement).
    case buildCity(playerId: String, nodeId: Int)
    
    // MARK: - Development Cards
    
    /// Buy a development card.
    case buyDevelopmentCard(playerId: String)
    
    /// Play a Knight card.
    case playKnight(playerId: String, cardId: String, moveRobberTo: Int, stealFrom: String?)
    
    /// Play Road Building card.
    case playRoadBuilding(playerId: String, cardId: String)
    
    /// Place a road from Road Building card.
    case placeRoadBuildingRoad(playerId: String, edgeId: Int)
    
    /// Play Year of Plenty card.
    case playYearOfPlenty(playerId: String, cardId: String, resource1: ResourceType, resource2: ResourceType)
    
    /// Play Monopoly card.
    case playMonopoly(playerId: String, cardId: String, resource: ResourceType)
    
    // MARK: - Trading
    
    /// Propose a domestic trade.
    case proposeTrade(playerId: String, tradeId: String, offering: ResourceBundle, requesting: ResourceBundle, targetPlayerIds: [String]?)
    
    /// Accept a trade proposal.
    case acceptTrade(playerId: String, tradeId: String)
    
    /// Reject a trade proposal.
    case rejectTrade(playerId: String, tradeId: String)
    
    /// Cancel own trade proposal.
    case cancelTrade(playerId: String, tradeId: String)
    
    /// Execute a trade with a player who accepted.
    case executeTrade(playerId: String, tradeId: String, withPlayerId: String)
    
    /// Execute a maritime (port) trade.
    case maritimeTrade(playerId: String, giving: ResourceType, givingAmount: Int, receiving: ResourceType)
    
    // MARK: - Turn Control
    
    /// End the current turn.
    case endTurn(playerId: String)
    
    // MARK: - 5-6 Player Extension
    
    /// Pass the paired player marker.
    case passPairedMarker(playerId: String)
    
    /// Supply trade (player 2 in paired turn).
    case supplyTrade(playerId: String, giving: ResourceType, receiving: ResourceType)
    
    /// Extract the player ID from any action.
    public var playerId: String {
        switch self {
        case .setupPlaceSettlement(let id, _),
             .setupPlaceRoad(let id, _),
             .rollDice(let id),
             .discardResources(let id, _),
             .moveRobber(let id, _),
             .stealResource(let id, _),
             .skipSteal(let id),
             .buildRoad(let id, _),
             .buildSettlement(let id, _),
             .buildCity(let id, _),
             .buyDevelopmentCard(let id),
             .playKnight(let id, _, _, _),
             .playRoadBuilding(let id, _),
             .placeRoadBuildingRoad(let id, _),
             .playYearOfPlenty(let id, _, _, _),
             .playMonopoly(let id, _, _),
             .proposeTrade(let id, _, _, _, _),
             .acceptTrade(let id, _),
             .rejectTrade(let id, _),
             .cancelTrade(let id, _),
             .executeTrade(let id, _, _),
             .maritimeTrade(let id, _, _, _),
             .endTurn(let id),
             .passPairedMarker(let id),
             .supplyTrade(let id, _, _):
            return id
        }
    }
}

