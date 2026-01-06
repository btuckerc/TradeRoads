// MARK: - Board Generation

import Foundation
import CatanProtocol

/// Generates game boards for different configurations.
public enum BoardGenerator {
    
    // MARK: - Standard 3-4 Player Board
    
    /// Generate the standard 3-4 player board.
    /// - Parameters:
    ///   - beginner: Use the beginner fixed layout (true) or random (false).
    ///   - rng: Random number generator for shuffling.
    public static func generateStandard<R: RandomNumberGenerator>(
        beginner: Bool,
        rng: inout R
    ) -> Board {
        let hexCoords = standardHexCoords
        let terrains = beginner ? beginnerTerrains : randomTerrains(rng: &rng)
        let tokens = beginner ? beginnerTokens : randomTokens(terrains: terrains, rng: &rng)
        
        return buildBoard(hexCoords: hexCoords, terrains: terrains, tokens: tokens, harbors: standardHarbors)
    }
    
    /// Generate the 5-6 player extended board.
    public static func generateExtended<R: RandomNumberGenerator>(
        beginner: Bool,
        rng: inout R
    ) -> Board {
        let hexCoords = extendedHexCoords
        let terrains = beginner ? extendedBeginnerTerrains : extendedRandomTerrains(rng: &rng)
        let tokens = beginner ? extendedBeginnerTokens : randomTokens(terrains: terrains, rng: &rng)
        
        return buildBoard(hexCoords: hexCoords, terrains: terrains, tokens: tokens, harbors: extendedHarbors)
    }
    
    // MARK: - Hex Coordinates
    
    /// Standard 3-4 player hex coordinates (19 hexes in a spiral).
    private static let standardHexCoords: [AxialCoord] = [
        // Center
        AxialCoord(q: 0, r: 0),
        // Ring 1 (6 hexes)
        AxialCoord(q: 1, r: -1), AxialCoord(q: 1, r: 0), AxialCoord(q: 0, r: 1),
        AxialCoord(q: -1, r: 1), AxialCoord(q: -1, r: 0), AxialCoord(q: 0, r: -1),
        // Ring 2 (12 hexes)
        AxialCoord(q: 2, r: -2), AxialCoord(q: 2, r: -1), AxialCoord(q: 2, r: 0),
        AxialCoord(q: 1, r: 1), AxialCoord(q: 0, r: 2), AxialCoord(q: -1, r: 2),
        AxialCoord(q: -2, r: 2), AxialCoord(q: -2, r: 1), AxialCoord(q: -2, r: 0),
        AxialCoord(q: -1, r: -1), AxialCoord(q: 0, r: -2), AxialCoord(q: 1, r: -2),
    ]
    
    /// Extended 5-6 player hex coordinates (30 hexes).
    private static let extendedHexCoords: [AxialCoord] = {
        var coords = standardHexCoords
        // Add outer ring for 5-6 player
        let outerRing: [AxialCoord] = [
            AxialCoord(q: 3, r: -3), AxialCoord(q: 3, r: -2), AxialCoord(q: 3, r: -1),
            AxialCoord(q: 3, r: 0), AxialCoord(q: 2, r: 1), AxialCoord(q: 1, r: 2),
            AxialCoord(q: 0, r: 3), AxialCoord(q: -1, r: 3), AxialCoord(q: -2, r: 3),
            AxialCoord(q: -3, r: 3), AxialCoord(q: -3, r: 2),
        ]
        coords.append(contentsOf: outerRing)
        return coords
    }()
    
    // MARK: - Beginner Layouts
    
    /// Beginner terrain layout (spiral from center).
    private static let beginnerTerrains: [TerrainType] = [
        .desert,    // Center
        .fields, .pasture, .forest, .hills, .mountains, .pasture,  // Ring 1
        .fields, .forest, .pasture, .hills, .mountains, .forest,   // Ring 2 first half
        .hills, .fields, .pasture, .mountains, .forest, .fields    // Ring 2 second half
    ]
    
    /// Beginner token layout (placed on non-desert hexes).
    private static let beginnerTokens: [Int?] = [
        nil,        // Desert
        9, 12, 6, 4, 10, 3,   // Ring 1
        8, 11, 5, 8, 10, 9,   // Ring 2 first half
        5, 4, 6, 3, 11, 2     // Ring 2 second half
    ]
    
    /// Extended beginner terrains.
    private static let extendedBeginnerTerrains: [TerrainType] = {
        var terrains = beginnerTerrains
        // Add more terrain for outer ring
        terrains.append(contentsOf: [
            .fields, .mountains, .pasture, .forest, .hills,
            .pasture, .mountains, .forest, .hills, .fields, .desert
        ])
        return terrains
    }()
    
    /// Extended beginner tokens.
    private static let extendedBeginnerTokens: [Int?] = {
        var tokens = beginnerTokens
        tokens.append(contentsOf: [2, 5, 4, 6, 3, 9, 8, 11, 10, 12, nil])
        return tokens
    }()
    
    // MARK: - Random Layouts
    
    /// Generate random terrains.
    private static func randomTerrains<R: RandomNumberGenerator>(rng: inout R) -> [TerrainType] {
        var terrains: [TerrainType] = []
        // Standard distribution: 4 forest, 4 pasture, 4 fields, 3 hills, 3 mountains, 1 desert
        terrains.append(contentsOf: Array(repeating: TerrainType.forest, count: 4))
        terrains.append(contentsOf: Array(repeating: TerrainType.pasture, count: 4))
        terrains.append(contentsOf: Array(repeating: TerrainType.fields, count: 4))
        terrains.append(contentsOf: Array(repeating: TerrainType.hills, count: 3))
        terrains.append(contentsOf: Array(repeating: TerrainType.mountains, count: 3))
        terrains.append(.desert)
        terrains.shuffle(using: &rng)
        return terrains
    }
    
    /// Generate random terrains for 5-6.
    private static func extendedRandomTerrains<R: RandomNumberGenerator>(rng: inout R) -> [TerrainType] {
        var terrains: [TerrainType] = []
        // Extended distribution: 6 forest, 6 pasture, 6 fields, 5 hills, 5 mountains, 2 desert
        terrains.append(contentsOf: Array(repeating: TerrainType.forest, count: 6))
        terrains.append(contentsOf: Array(repeating: TerrainType.pasture, count: 6))
        terrains.append(contentsOf: Array(repeating: TerrainType.fields, count: 6))
        terrains.append(contentsOf: Array(repeating: TerrainType.hills, count: 5))
        terrains.append(contentsOf: Array(repeating: TerrainType.mountains, count: 5))
        terrains.append(contentsOf: Array(repeating: TerrainType.desert, count: 2))
        terrains.shuffle(using: &rng)
        return terrains
    }
    
    /// Generate tokens avoiding 6/8 adjacency rule.
    private static func randomTokens<R: RandomNumberGenerator>(
        terrains: [TerrainType],
        rng: inout R
    ) -> [Int?] {
        // Standard token set (excluding 7)
        var tokenPool = [2, 3, 3, 4, 4, 5, 5, 6, 6, 8, 8, 9, 9, 10, 10, 11, 11, 12]
        tokenPool.shuffle(using: &rng)
        
        var tokens: [Int?] = Array(repeating: nil, count: terrains.count)
        var tokenIndex = 0
        
        for (i, terrain) in terrains.enumerated() {
            if terrain == .desert {
                tokens[i] = nil
            } else if tokenIndex < tokenPool.count {
                tokens[i] = tokenPool[tokenIndex]
                tokenIndex += 1
            }
        }
        
        return tokens
    }
    
    // MARK: - Harbors
    
    /// Standard harbor configuration.
    private static let standardHarbors: [(HarborType, [AxialCoord])] = [
        (.generic, [AxialCoord(q: 2, r: -2)]),
        (.specific(.wool), [AxialCoord(q: 2, r: 0)]),
        (.generic, [AxialCoord(q: 0, r: 2)]),
        (.specific(.brick), [AxialCoord(q: -2, r: 2)]),
        (.specific(.lumber), [AxialCoord(q: -2, r: 0)]),
        (.generic, [AxialCoord(q: 0, r: -2)]),
        (.specific(.ore), [AxialCoord(q: 1, r: -2)]),
        (.specific(.grain), [AxialCoord(q: -1, r: 2)]),
        (.generic, [AxialCoord(q: 2, r: -1)]),
    ]
    
    /// Extended harbor configuration.
    private static let extendedHarbors: [(HarborType, [AxialCoord])] = {
        var harbors = standardHarbors
        harbors.append(contentsOf: [
            (.generic, [AxialCoord(q: 3, r: -2)]),
            (.specific(.wool), [AxialCoord(q: 3, r: 0)]),
        ])
        return harbors
    }()
    
    // MARK: - Board Construction
    
    private static func buildBoard(
        hexCoords: [AxialCoord],
        terrains: [TerrainType],
        tokens: [Int?],
        harbors: [(HarborType, [AxialCoord])]
    ) -> Board {
        // Create hexes
        var hexes: [Hex] = []
        for (i, coord) in hexCoords.enumerated() {
            let hex = Hex(
                id: i,
                coord: coord,
                terrain: terrains[i],
                numberToken: tokens[i]
            )
            hexes.append(hex)
        }
        
        // Build lookup for hex by coord
        let hexByCoord = Dictionary(uniqueKeysWithValues: hexes.map { ($0.coord, $0) })
        
        // Generate nodes (vertices)
        var nodesByCanonical: [VertexCoord: Node] = [:]
        var nodeId = 0
        
        for hex in hexes {
            for dir in 0..<6 {
                let vertexCoord = VertexCoord(hex: hex.coord, direction: dir).canonical
                if nodesByCanonical[vertexCoord] == nil {
                    // Find all hexes adjacent to this vertex
                    var adjacentHexIds: [Int] = []
                    for checkHex in hexes {
                        for checkDir in 0..<6 {
                            let checkVertex = VertexCoord(hex: checkHex.coord, direction: checkDir).canonical
                            if checkVertex == vertexCoord {
                                adjacentHexIds.append(checkHex.id)
                                break
                            }
                        }
                    }
                    
                    let node = Node(
                        id: nodeId,
                        coord: vertexCoord,
                        adjacentHexIds: adjacentHexIds
                    )
                    nodesByCanonical[vertexCoord] = node
                    nodeId += 1
                }
            }
        }
        
        // Generate edges
        var edgesByCanonical: [EdgeCoord: Edge] = [:]
        var edgeId = 0
        
        for hex in hexes {
            for dir in 0..<6 {
                let edgeCoord = EdgeCoord(hex: hex.coord, direction: dir).canonical
                if edgesByCanonical[edgeCoord] == nil {
                    let vertices = edgeCoord.vertices
                    guard let node1 = nodesByCanonical[vertices.0],
                          let node2 = nodesByCanonical[vertices.1] else {
                        continue
                    }
                    
                    // Find adjacent hexes
                    var adjacentHexIds: [Int] = []
                    if let h = hexByCoord[edgeCoord.hex] {
                        adjacentHexIds.append(h.id)
                    }
                    let neighborCoord = edgeCoord.hex.neighbor(edgeCoord.direction)
                    if let h = hexByCoord[neighborCoord] {
                        adjacentHexIds.append(h.id)
                    }
                    
                    let edge = Edge(
                        id: edgeId,
                        coord: edgeCoord,
                        nodeIds: (node1.id, node2.id),
                        adjacentHexIds: adjacentHexIds
                    )
                    edgesByCanonical[edgeCoord] = edge
                    edgeId += 1
                }
            }
        }
        
        // Update nodes with edge and neighbor info
        var nodes = Array(nodesByCanonical.values)
        let edges = Array(edgesByCanonical.values)
        
        for i in 0..<nodes.count {
            var adjacentEdgeIds: [Int] = []
            var adjacentNodeIds: [Int] = []
            
            for edge in edges {
                if edge.nodeIds.0 == nodes[i].id || edge.nodeIds.1 == nodes[i].id {
                    adjacentEdgeIds.append(edge.id)
                    let otherNodeId = edge.nodeIds.0 == nodes[i].id ? edge.nodeIds.1 : edge.nodeIds.0
                    if !adjacentNodeIds.contains(otherNodeId) {
                        adjacentNodeIds.append(otherNodeId)
                    }
                }
            }
            
            nodes[i] = Node(
                id: nodes[i].id,
                coord: nodes[i].coord,
                adjacentHexIds: nodes[i].adjacentHexIds,
                adjacentEdgeIds: adjacentEdgeIds,
                adjacentNodeIds: adjacentNodeIds
            )
        }
        
        // Create harbors
        var harborConfigs: [HarborConfig] = []
        for (i, (harborType, _)) in harbors.enumerated() {
            // For simplicity, assign harbors to first 2 nodes at each harbor location
            // In a real implementation, you'd compute which nodes are coastal
            let harborNodeIds = Array(nodes.prefix(2).map { $0.id })
            harborConfigs.append(HarborConfig(id: i, type: harborType, nodeIds: harborNodeIds))
        }
        
        return Board(
            hexes: hexes,
            nodes: nodes.sorted { $0.id < $1.id },
            edges: edges.sorted { $0.id < $1.id },
            harbors: harborConfigs
        )
    }
}

// MARK: - Game State Factory

extension GameState {
    /// Create a new game with the given configuration and players.
    public static func new<R: RandomNumberGenerator>(
        config: GameConfig,
        playerInfos: [(userId: String, displayName: String, color: PlayerColor)],
        rng: inout R
    ) -> GameState {
        // Generate board
        let board: Board
        switch config.playerMode {
        case .threeToFour:
            board = BoardGenerator.generateStandard(beginner: config.useBeginnerLayout, rng: &rng)
        case .fiveToSix:
            board = BoardGenerator.generateExtended(beginner: config.useBeginnerLayout, rng: &rng)
        }
        
        // Create players
        var players: [Player] = []
        for (i, info) in playerInfos.enumerated() {
            let player = Player(
                id: "player-\(i)",
                userId: info.userId,
                displayName: info.displayName,
                color: info.color,
                turnOrder: i
            )
            players.append(player)
        }
        
        // Create bank
        var bank = Bank.standard()
        bank.shuffleDeck(using: &rng)
        
        // Find robber starting position
        let robberHexId = board.desertHex?.id ?? 0
        
        // Create turn state
        let turn = TurnState(
            phase: .setup,
            activePlayerId: players.first?.id ?? "",
            turnNumber: 0
        )
        
        return GameState(
            config: config,
            board: board,
            players: players,
            bank: bank,
            robberHexId: robberHexId,
            turn: turn
        )
    }
}

