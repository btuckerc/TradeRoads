// MARK: - Bank and Supply

import Foundation
import CatanProtocol

/// The bank holds resource cards and development cards.
public struct Bank: Sendable, Hashable, Codable {
    /// Resource cards available in the bank.
    public var resources: ResourceBundle
    
    /// Development cards remaining in the deck (top of deck is first).
    public var developmentCards: [DevelopmentCardType]
    
    public init(resources: ResourceBundle, developmentCards: [DevelopmentCardType]) {
        self.resources = resources
        self.developmentCards = developmentCards
    }
    
    /// Create a bank with standard CATAN setup.
    public static func standard() -> Bank {
        // 19 of each resource
        let resources = ResourceBundle(brick: 19, lumber: 19, ore: 19, grain: 19, wool: 19)
        
        // Development card distribution (25 total):
        // 14 Knight, 5 Victory Point, 2 Road Building, 2 Year of Plenty, 2 Monopoly
        var cards: [DevelopmentCardType] = []
        cards.append(contentsOf: Array(repeating: .knight, count: 14))
        cards.append(contentsOf: Array(repeating: .victoryPoint, count: 5))
        cards.append(contentsOf: Array(repeating: .roadBuilding, count: 2))
        cards.append(contentsOf: Array(repeating: .yearOfPlenty, count: 2))
        cards.append(contentsOf: Array(repeating: .monopoly, count: 2))
        
        return Bank(resources: resources, developmentCards: cards)
    }
    
    /// Shuffle the development card deck.
    public mutating func shuffleDeck<R: RandomNumberGenerator>(using rng: inout R) {
        developmentCards.shuffle(using: &rng)
    }
    
    /// Draw a development card from the deck.
    public mutating func drawDevelopmentCard() -> DevelopmentCardType? {
        guard !developmentCards.isEmpty else { return nil }
        return developmentCards.removeFirst()
    }
    
    /// Check if bank has enough of a resource.
    public func has(_ type: ResourceType, amount: Int) -> Bool {
        resources[type] >= amount
    }
    
    /// Check if bank has enough resources.
    public func has(_ bundle: ResourceBundle) -> Bool {
        resources.contains(bundle)
    }
    
    /// Take resources from bank (returns nil if insufficient).
    public func taking(_ bundle: ResourceBundle) -> Bank? {
        guard has(bundle) else { return nil }
        var copy = self
        copy.resources = resources - bundle
        return copy
    }
    
    /// Return resources to bank.
    public func returning(_ bundle: ResourceBundle) -> Bank {
        var copy = self
        copy.resources = resources + bundle
        return copy
    }
}

