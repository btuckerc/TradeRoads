// MARK: - Player Model

import Foundation
import CatanProtocol

/// A player's complete state in the game.
public struct Player: Sendable, Hashable, Codable {
    public let id: String
    public let userId: String
    public let displayName: String
    public let color: PlayerColor
    public let turnOrder: Int
    
    // Resource hand
    public var resources: ResourceBundle
    
    // Development cards
    public var developmentCards: [DevelopmentCard]
    
    // Buildings placed
    public var settlements: Set<Int>  // Node IDs
    public var cities: Set<Int>       // Node IDs
    public var roads: Set<Int>        // Edge IDs
    
    // Tracking
    public var knightsPlayed: Int
    public var developmentCardBoughtThisTurn: Bool
    public var developmentCardPlayedThisTurn: Bool
    public var longestRoadLength: Int
    
    // 5-6 player extension
    public var isPairedPlayer1: Bool
    public var isPairedPlayer2: Bool
    
    public init(
        id: String,
        userId: String,
        displayName: String,
        color: PlayerColor,
        turnOrder: Int,
        resources: ResourceBundle = .zero,
        developmentCards: [DevelopmentCard] = [],
        settlements: Set<Int> = [],
        cities: Set<Int> = [],
        roads: Set<Int> = [],
        knightsPlayed: Int = 0,
        developmentCardBoughtThisTurn: Bool = false,
        developmentCardPlayedThisTurn: Bool = false,
        longestRoadLength: Int = 0,
        isPairedPlayer1: Bool = false,
        isPairedPlayer2: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.displayName = displayName
        self.color = color
        self.turnOrder = turnOrder
        self.resources = resources
        self.developmentCards = developmentCards
        self.settlements = settlements
        self.cities = cities
        self.roads = roads
        self.knightsPlayed = knightsPlayed
        self.developmentCardBoughtThisTurn = developmentCardBoughtThisTurn
        self.developmentCardPlayedThisTurn = developmentCardPlayedThisTurn
        self.longestRoadLength = longestRoadLength
        self.isPairedPlayer1 = isPairedPlayer1
        self.isPairedPlayer2 = isPairedPlayer2
    }
    
    // MARK: - Computed Properties
    
    /// Total resource cards in hand.
    public var totalResources: Int {
        resources.total
    }
    
    /// Total development cards in hand (including unplayable).
    public var totalDevelopmentCards: Int {
        developmentCards.count
    }
    
    /// Development cards that can be played this turn.
    public var playableDevelopmentCards: [DevelopmentCard] {
        developmentCards.filter { $0.canPlay && !$0.boughtThisTurn }
    }
    
    /// Number of unplayed victory point cards.
    public var victoryPointCards: Int {
        developmentCards.filter { $0.type == .victoryPoint && !$0.isPlayed }.count
    }
    
    /// Remaining settlements in supply.
    public var remainingSettlements: Int {
        GameConstants.maxSettlements - settlements.count
    }
    
    /// Remaining cities in supply.
    public var remainingCities: Int {
        GameConstants.maxCities - cities.count
    }
    
    /// Remaining roads in supply.
    public var remainingRoads: Int {
        GameConstants.maxRoads - roads.count
    }
    
    /// Check if player can afford a cost.
    public func canAfford(_ cost: ResourceBundle) -> Bool {
        resources.contains(cost)
    }
    
    // MARK: - Mutations (return new Player)
    
    /// Add resources to hand.
    public func adding(resources newResources: ResourceBundle) -> Player {
        var copy = self
        copy.resources = resources + newResources
        return copy
    }
    
    /// Remove resources from hand.
    public func removing(resources toRemove: ResourceBundle) -> Player {
        var copy = self
        copy.resources = resources - toRemove
        return copy
    }
    
    /// Add a development card.
    public func adding(developmentCard card: DevelopmentCard) -> Player {
        var copy = self
        copy.developmentCards.append(card)
        return copy
    }
    
    /// Mark a development card as played.
    public func markingCardPlayed(cardId: String) -> Player {
        var copy = self
        if let idx = copy.developmentCards.firstIndex(where: { $0.id == cardId }) {
            copy.developmentCards[idx] = copy.developmentCards[idx].played()
        }
        return copy
    }
    
    /// Add a settlement.
    public func adding(settlement nodeId: Int) -> Player {
        var copy = self
        copy.settlements.insert(nodeId)
        return copy
    }
    
    /// Upgrade settlement to city.
    public func upgradingToCity(at nodeId: Int) -> Player {
        var copy = self
        copy.settlements.remove(nodeId)
        copy.cities.insert(nodeId)
        return copy
    }
    
    /// Add a road.
    public func adding(road edgeId: Int) -> Player {
        var copy = self
        copy.roads.insert(edgeId)
        return copy
    }
    
    /// Increment knights played.
    public func incrementingKnights() -> Player {
        var copy = self
        copy.knightsPlayed += 1
        return copy
    }
    
    /// Reset turn-specific flags.
    public func resettingTurnFlags() -> Player {
        var copy = self
        copy.developmentCardBoughtThisTurn = false
        copy.developmentCardPlayedThisTurn = false
        // Mark cards bought last turn as playable
        copy.developmentCards = copy.developmentCards.map { $0.markNotBoughtThisTurn() }
        return copy
    }
    
    /// Update longest road length.
    public func withLongestRoadLength(_ length: Int) -> Player {
        var copy = self
        copy.longestRoadLength = length
        return copy
    }
}

/// A development card in a player's hand.
public struct DevelopmentCard: Sendable, Hashable, Codable {
    public let id: String
    public let type: DevelopmentCardType
    public var isPlayed: Bool
    public var boughtThisTurn: Bool
    
    public init(id: String, type: DevelopmentCardType, isPlayed: Bool = false, boughtThisTurn: Bool = true) {
        self.id = id
        self.type = type
        self.isPlayed = isPlayed
        self.boughtThisTurn = boughtThisTurn
    }
    
    /// Whether this card can be played.
    public var canPlay: Bool {
        !isPlayed && type != .victoryPoint
    }
    
    /// Return a copy marked as played.
    public func played() -> DevelopmentCard {
        DevelopmentCard(id: id, type: type, isPlayed: true, boughtThisTurn: boughtThisTurn)
    }
    
    /// Return a copy no longer marked as bought this turn.
    public func markNotBoughtThisTurn() -> DevelopmentCard {
        DevelopmentCard(id: id, type: type, isPlayed: isPlayed, boughtThisTurn: false)
    }
}

/// Game constants for piece limits.
public enum GameConstants {
    public static let maxSettlements = 5
    public static let maxCities = 4
    public static let maxRoads = 15
    
    public static let victoryPointsToWin = 10
    public static let minLongestRoad = 5
    public static let minLargestArmy = 3
    
    public static let discardThreshold = 7
}

