// MARK: - Building Placement State

import Foundation
import CatanProtocol

/// Tracks what's built where on the board.
public struct BuildingState: Sendable, Hashable, Codable {
    /// Node ID -> player ID who has a settlement there.
    public var settlements: [Int: String]
    
    /// Node ID -> player ID who has a city there.
    public var cities: [Int: String]
    
    /// Edge ID -> player ID who has a road there.
    public var roads: [Int: String]
    
    public init(
        settlements: [Int: String] = [:],
        cities: [Int: String] = [:],
        roads: [Int: String] = [:]
    ) {
        self.settlements = settlements
        self.cities = cities
        self.roads = roads
    }
    
    // MARK: - Queries
    
    /// Get the building at a node.
    public func building(at nodeId: Int) -> (type: BuildingType, playerId: String)? {
        if let playerId = cities[nodeId] {
            return (.city, playerId)
        }
        if let playerId = settlements[nodeId] {
            return (.settlement, playerId)
        }
        return nil
    }
    
    /// Check if a node is occupied.
    public func isOccupied(nodeId: Int) -> Bool {
        settlements[nodeId] != nil || cities[nodeId] != nil
    }
    
    /// Check if an edge has a road.
    public func hasRoad(edgeId: Int) -> Bool {
        roads[edgeId] != nil
    }
    
    /// Get the player who owns a road.
    public func roadOwner(edgeId: Int) -> String? {
        roads[edgeId]
    }
    
    /// Get all nodes with buildings for a player.
    public func buildingNodes(for playerId: String) -> [Int] {
        let settlementNodes = settlements.filter { $0.value == playerId }.map { $0.key }
        let cityNodes = cities.filter { $0.value == playerId }.map { $0.key }
        return settlementNodes + cityNodes
    }
    
    /// Get all edges with roads for a player.
    public func roadEdges(for playerId: String) -> [Int] {
        roads.filter { $0.value == playerId }.map { $0.key }
    }
    
    // MARK: - Mutations (return new state)
    
    /// Place a settlement.
    public func placingSettlement(at nodeId: Int, playerId: String) -> BuildingState {
        var copy = self
        copy.settlements[nodeId] = playerId
        return copy
    }
    
    /// Upgrade settlement to city.
    public func upgradingToCity(at nodeId: Int) -> BuildingState {
        guard let playerId = settlements[nodeId] else { return self }
        var copy = self
        copy.settlements.removeValue(forKey: nodeId)
        copy.cities[nodeId] = playerId
        return copy
    }
    
    /// Place a road.
    public func placingRoad(at edgeId: Int, playerId: String) -> BuildingState {
        var copy = self
        copy.roads[edgeId] = playerId
        return copy
    }
}

