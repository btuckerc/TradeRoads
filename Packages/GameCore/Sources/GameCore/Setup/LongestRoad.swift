// MARK: - Longest Road Calculation

import Foundation

/// Calculates the longest continuous road for a player.
public enum LongestRoadCalculator {
    
    /// Calculate the longest road length for a player.
    /// Handles branching roads and blocking by opponent settlements.
    public static func calculate(
        playerId: String,
        state: GameState
    ) -> Int {
        let board = state.board
        let buildings = state.buildings
        
        // Get all road edges for this player
        let playerRoads = buildings.roadEdges(for: playerId)
        guard !playerRoads.isEmpty else { return 0 }
        
        // Build adjacency graph of roads
        // Key: edge ID, Value: set of connected edge IDs (not blocked by opponent buildings)
        var roadGraph: [Int: Set<Int>] = [:]
        
        for edgeId in playerRoads {
            roadGraph[edgeId] = []
            
            guard let edge = board.edge(id: edgeId) else { continue }
            
            // Check both endpoints
            for nodeId in [edge.nodeIds.0, edge.nodeIds.1] {
                // Check if this node is blocked by an opponent's building
                if let building = buildings.building(at: nodeId), building.playerId != playerId {
                    continue  // Road is blocked at this node
                }
                
                // Find other roads connected at this node
                for otherEdge in board.edges(adjacentToNode: nodeId) {
                    if otherEdge.id != edgeId && playerRoads.contains(otherEdge.id) {
                        roadGraph[edgeId]?.insert(otherEdge.id)
                    }
                }
            }
        }
        
        // DFS from each road to find the longest path
        var longestPath = 0
        
        for startEdge in playerRoads {
            let pathLength = findLongestPath(from: startEdge, graph: roadGraph)
            longestPath = max(longestPath, pathLength)
        }
        
        return longestPath
    }
    
    /// Find the longest path starting from a given edge using DFS.
    private static func findLongestPath(
        from startEdge: Int,
        graph: [Int: Set<Int>]
    ) -> Int {
        var visited: Set<Int> = []
        return dfs(edge: startEdge, graph: graph, visited: &visited)
    }
    
    /// DFS to find longest path.
    private static func dfs(
        edge: Int,
        graph: [Int: Set<Int>],
        visited: inout Set<Int>
    ) -> Int {
        visited.insert(edge)
        
        var maxLength = 1  // Count this edge
        
        if let neighbors = graph[edge] {
            for neighbor in neighbors {
                if !visited.contains(neighbor) {
                    let length = 1 + dfs(edge: neighbor, graph: graph, visited: &visited)
                    maxLength = max(maxLength, length)
                }
            }
        }
        
        visited.remove(edge)
        return maxLength
    }
    
    /// Recalculate longest road for all players and update awards.
    public static func recalculateAll(state: GameState) -> (GameState, [DomainEvent]) {
        var newState = state
        var events: [DomainEvent] = []
        
        // Calculate for all players
        var playerRoadLengths: [String: Int] = [:]
        for player in state.players {
            let length = calculate(playerId: player.id, state: state)
            playerRoadLengths[player.id] = length
            newState = newState.updatingPlayer(id: player.id) { $0.withLongestRoadLength(length) }
        }
        
        // Check for award change
        let (updatedAwards, changed, previousHolder, newHolder) = state.awards.recheckLongestRoad(
            playerRoadLengths: playerRoadLengths
        )
        
        if changed {
            newState.awards = updatedAwards
            events.append(.longestRoadAwarded(
                newHolderId: newHolder,
                previousHolderId: previousHolder,
                roadLength: updatedAwards.longestRoadLength
            ))
        }
        
        return (newState, events)
    }
}

