// MARK: - Game Board

import Foundation
import CatanProtocol

/// A hex tile on the board.
public struct Hex: Sendable, Hashable, Codable {
    public let id: Int
    public let coord: AxialCoord
    public let terrain: TerrainType
    public let numberToken: Int?
    
    public init(id: Int, coord: AxialCoord, terrain: TerrainType, numberToken: Int?) {
        self.id = id
        self.coord = coord
        self.terrain = terrain
        self.numberToken = numberToken
    }
    
    /// The resource this hex produces (nil for desert).
    public var producedResource: ResourceType? {
        terrain.producedResource
    }
}

/// A node (vertex/intersection) on the board where settlements/cities can be built.
public struct Node: Sendable, Hashable, Codable {
    public let id: Int
    public let coord: VertexCoord
    /// IDs of hexes adjacent to this node.
    public let adjacentHexIds: [Int]
    /// IDs of edges adjacent to this node.
    public var adjacentEdgeIds: [Int]
    /// IDs of nodes adjacent to this node.
    public var adjacentNodeIds: [Int]
    
    public init(id: Int, coord: VertexCoord, adjacentHexIds: [Int], adjacentEdgeIds: [Int] = [], adjacentNodeIds: [Int] = []) {
        self.id = id
        self.coord = coord
        self.adjacentHexIds = adjacentHexIds
        self.adjacentEdgeIds = adjacentEdgeIds
        self.adjacentNodeIds = adjacentNodeIds
    }
}

/// An edge on the board where roads can be built.
public struct Edge: Sendable, Hashable, Codable {
    public let id: Int
    public let coord: EdgeCoord
    /// IDs of the two nodes at the endpoints.
    public let nodeIds: (Int, Int)
    /// IDs of hexes adjacent to this edge.
    public let adjacentHexIds: [Int]
    
    public init(id: Int, coord: EdgeCoord, nodeIds: (Int, Int), adjacentHexIds: [Int]) {
        self.id = id
        self.coord = coord
        self.nodeIds = nodeIds
        self.adjacentHexIds = adjacentHexIds
    }
    
    // Custom Codable for tuple
    private enum CodingKeys: String, CodingKey {
        case id, coord, nodeId1, nodeId2, adjacentHexIds
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        coord = try container.decode(EdgeCoord.self, forKey: .coord)
        let nodeId1 = try container.decode(Int.self, forKey: .nodeId1)
        let nodeId2 = try container.decode(Int.self, forKey: .nodeId2)
        nodeIds = (nodeId1, nodeId2)
        adjacentHexIds = try container.decode([Int].self, forKey: .adjacentHexIds)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(coord, forKey: .coord)
        try container.encode(nodeIds.0, forKey: .nodeId1)
        try container.encode(nodeIds.1, forKey: .nodeId2)
        try container.encode(adjacentHexIds, forKey: .adjacentHexIds)
    }
    
    public static func == (lhs: Edge, rhs: Edge) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// A harbor (port) on the board.
public struct HarborConfig: Sendable, Hashable, Codable {
    public let id: Int
    public let type: HarborType
    /// Node IDs that have access to this harbor.
    public let nodeIds: [Int]
    
    public init(id: Int, type: HarborType, nodeIds: [Int]) {
        self.id = id
        self.type = type
        self.nodeIds = nodeIds
    }
}

/// The complete board layout.
public struct Board: Sendable, Codable {
    public let hexes: [Hex]
    public let nodes: [Node]
    public let edges: [Edge]
    public let harbors: [HarborConfig]
    
    /// Lookup tables for fast access
    private let hexById: [Int: Hex]
    private let nodeById: [Int: Node]
    private let edgeById: [Int: Edge]
    private let hexByCoord: [AxialCoord: Hex]
    private let nodeByCoord: [VertexCoord: Node]
    private let edgeByCoord: [EdgeCoord: Edge]
    private let nodesByHexId: [Int: [Int]]
    private let edgesByNodeId: [Int: [Int]]
    
    public init(hexes: [Hex], nodes: [Node], edges: [Edge], harbors: [HarborConfig]) {
        self.hexes = hexes
        self.nodes = nodes
        self.edges = edges
        self.harbors = harbors
        
        // Build lookup tables
        self.hexById = Dictionary(uniqueKeysWithValues: hexes.map { ($0.id, $0) })
        self.nodeById = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        self.edgeById = Dictionary(uniqueKeysWithValues: edges.map { ($0.id, $0) })
        self.hexByCoord = Dictionary(uniqueKeysWithValues: hexes.map { ($0.coord, $0) })
        self.nodeByCoord = Dictionary(uniqueKeysWithValues: nodes.map { ($0.coord.canonical, $0) })
        self.edgeByCoord = Dictionary(uniqueKeysWithValues: edges.map { ($0.coord.canonical, $0) })
        
        // Build hex -> nodes lookup
        var nodesByHex: [Int: [Int]] = [:]
        for node in nodes {
            for hexId in node.adjacentHexIds {
                nodesByHex[hexId, default: []].append(node.id)
            }
        }
        self.nodesByHexId = nodesByHex
        
        // Build node -> edges lookup
        var edgesByNode: [Int: [Int]] = [:]
        for edge in edges {
            edgesByNode[edge.nodeIds.0, default: []].append(edge.id)
            edgesByNode[edge.nodeIds.1, default: []].append(edge.id)
        }
        self.edgesByNodeId = edgesByNode
    }
    
    // Custom Codable to handle computed properties
    private enum CodingKeys: String, CodingKey {
        case hexes, nodes, edges, harbors
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let hexes = try container.decode([Hex].self, forKey: .hexes)
        let nodes = try container.decode([Node].self, forKey: .nodes)
        let edges = try container.decode([Edge].self, forKey: .edges)
        let harbors = try container.decode([HarborConfig].self, forKey: .harbors)
        self.init(hexes: hexes, nodes: nodes, edges: edges, harbors: harbors)
    }
    
    // MARK: - Lookup Methods
    
    public func hex(id: Int) -> Hex? {
        hexById[id]
    }
    
    public func hex(at coord: AxialCoord) -> Hex? {
        hexByCoord[coord]
    }
    
    public func node(id: Int) -> Node? {
        nodeById[id]
    }
    
    public func node(at coord: VertexCoord) -> Node? {
        nodeByCoord[coord.canonical]
    }
    
    public func edge(id: Int) -> Edge? {
        edgeById[id]
    }
    
    public func edge(at coord: EdgeCoord) -> Edge? {
        edgeByCoord[coord.canonical]
    }
    
    /// Get all nodes adjacent to a hex.
    public func nodes(adjacentToHex hexId: Int) -> [Node] {
        nodesByHexId[hexId]?.compactMap { nodeById[$0] } ?? []
    }
    
    /// Get all edges adjacent to a node.
    public func edges(adjacentToNode nodeId: Int) -> [Edge] {
        edgesByNodeId[nodeId]?.compactMap { edgeById[$0] } ?? []
    }
    
    /// Get all nodes adjacent to a node.
    public func adjacentNodes(to nodeId: Int) -> [Node] {
        guard let node = nodeById[nodeId] else { return [] }
        return node.adjacentNodeIds.compactMap { nodeById[$0] }
    }
    
    /// Get hexes that produce for a given dice roll.
    public func hexes(forRoll roll: Int) -> [Hex] {
        hexes.filter { $0.numberToken == roll }
    }
    
    /// Get the harbor accessible from a node, if any.
    public func harbor(forNode nodeId: Int) -> HarborConfig? {
        harbors.first { $0.nodeIds.contains(nodeId) }
    }
    
    /// Find the desert hex.
    public var desertHex: Hex? {
        hexes.first { $0.terrain == .desert }
    }
}

