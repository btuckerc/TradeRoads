// MARK: - Special Awards (Longest Road, Largest Army)

import Foundation

/// Tracks the special award cards.
public struct Awards: Sendable, Hashable, Codable {
    /// Player ID who currently holds Longest Road (nil if unclaimed).
    public var longestRoadHolder: String?
    /// The current longest road length.
    public var longestRoadLength: Int
    
    /// Player ID who currently holds Largest Army (nil if unclaimed).
    public var largestArmyHolder: String?
    /// The current largest army size.
    public var largestArmySize: Int
    
    public init(
        longestRoadHolder: String? = nil,
        longestRoadLength: Int = 0,
        largestArmyHolder: String? = nil,
        largestArmySize: Int = 0
    ) {
        self.longestRoadHolder = longestRoadHolder
        self.longestRoadLength = longestRoadLength
        self.largestArmyHolder = largestArmyHolder
        self.largestArmySize = largestArmySize
    }
    
    /// Check and update Longest Road award.
    /// Returns the new awards state and whether the holder changed.
    public func checkLongestRoad(
        playerId: String,
        roadLength: Int
    ) -> (Awards, changed: Bool, previousHolder: String?) {
        var copy = self
        var changed = false
        let previousHolder = longestRoadHolder
        
        // Must have at least 5 roads to claim
        guard roadLength >= GameConstants.minLongestRoad else {
            return (self, changed: false, previousHolder: nil)
        }
        
        // If no current holder, claim it
        if longestRoadHolder == nil {
            copy.longestRoadHolder = playerId
            copy.longestRoadLength = roadLength
            changed = true
        }
        // If this player already holds it, just update length
        else if longestRoadHolder == playerId {
            copy.longestRoadLength = max(longestRoadLength, roadLength)
        }
        // If someone else holds it, must beat them
        else if roadLength > longestRoadLength {
            copy.longestRoadHolder = playerId
            copy.longestRoadLength = roadLength
            changed = true
        }
        
        return (copy, changed: changed, previousHolder: changed ? previousHolder : nil)
    }
    
    /// Handle when a player's road is broken (by another player's settlement).
    /// If the holder's road drops below another player's, the award transfers.
    public func recheckLongestRoad(
        playerRoadLengths: [String: Int]
    ) -> (Awards, changed: Bool, previousHolder: String?, newHolder: String?) {
        var copy = self
        
        // Find the player(s) with the longest road >= 5
        let qualifying = playerRoadLengths.filter { $0.value >= GameConstants.minLongestRoad }
        guard !qualifying.isEmpty else {
            // No one qualifies anymore
            if longestRoadHolder != nil {
                let prev = longestRoadHolder
                copy.longestRoadHolder = nil
                copy.longestRoadLength = 0
                return (copy, changed: true, previousHolder: prev, newHolder: nil)
            }
            return (self, changed: false, previousHolder: nil, newHolder: nil)
        }
        
        let maxLength = qualifying.values.max()!
        let leaders = qualifying.filter { $0.value == maxLength }
        
        // If current holder is still a leader, they keep it
        if let holder = longestRoadHolder, leaders[holder] != nil {
            copy.longestRoadLength = maxLength
            return (copy, changed: false, previousHolder: nil, newHolder: nil)
        }
        
        // If there's a tie, no one gets it (award is unclaimed until broken)
        if leaders.count > 1 {
            let prev = longestRoadHolder
            copy.longestRoadHolder = nil
            copy.longestRoadLength = maxLength
            return (copy, changed: prev != nil, previousHolder: prev, newHolder: nil)
        }
        
        // Single new leader
        let newHolder = leaders.keys.first!
        let prev = longestRoadHolder
        copy.longestRoadHolder = newHolder
        copy.longestRoadLength = maxLength
        return (copy, changed: true, previousHolder: prev, newHolder: newHolder)
    }
    
    /// Check and update Largest Army award.
    public func checkLargestArmy(
        playerId: String,
        knightsPlayed: Int
    ) -> (Awards, changed: Bool, previousHolder: String?) {
        var copy = self
        var changed = false
        let previousHolder = largestArmyHolder
        
        // Must have at least 3 knights to claim
        guard knightsPlayed >= GameConstants.minLargestArmy else {
            return (self, changed: false, previousHolder: nil)
        }
        
        // If no current holder, claim it
        if largestArmyHolder == nil {
            copy.largestArmyHolder = playerId
            copy.largestArmySize = knightsPlayed
            changed = true
        }
        // If this player already holds it, just update size
        else if largestArmyHolder == playerId {
            copy.largestArmySize = knightsPlayed
        }
        // If someone else holds it, must beat them
        else if knightsPlayed > largestArmySize {
            copy.largestArmyHolder = playerId
            copy.largestArmySize = knightsPlayed
            changed = true
        }
        
        return (copy, changed: changed, previousHolder: changed ? previousHolder : nil)
    }
}

