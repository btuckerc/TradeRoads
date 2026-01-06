// MARK: - Board Coordinate System

import Foundation

/// Axial coordinate for hexagonal grid.
/// Uses the "pointy-top" orientation with q (column) and r (row).
public struct AxialCoord: Sendable, Hashable, Codable {
    public let q: Int
    public let r: Int
    
    public init(q: Int, r: Int) {
        self.q = q
        self.r = r
    }
    
    /// The six neighbor directions in axial coordinates.
    public static let directions: [AxialCoord] = [
        AxialCoord(q: 1, r: 0),   // E
        AxialCoord(q: 1, r: -1),  // NE
        AxialCoord(q: 0, r: -1),  // NW
        AxialCoord(q: -1, r: 0),  // W
        AxialCoord(q: -1, r: 1),  // SW
        AxialCoord(q: 0, r: 1),   // SE
    ]
    
    /// Get neighbor in the given direction (0-5).
    public func neighbor(_ direction: Int) -> AxialCoord {
        let dir = Self.directions[direction % 6]
        return AxialCoord(q: q + dir.q, r: r + dir.r)
    }
    
    /// Get all six neighbors.
    public var neighbors: [AxialCoord] {
        Self.directions.map { AxialCoord(q: q + $0.q, r: r + $0.r) }
    }
    
    public static func + (lhs: AxialCoord, rhs: AxialCoord) -> AxialCoord {
        AxialCoord(q: lhs.q + rhs.q, r: lhs.r + rhs.r)
    }
}

/// Cube coordinate for hexagonal grid (useful for distance calculations).
public struct CubeCoord: Sendable, Hashable {
    public let x: Int
    public let y: Int
    public let z: Int
    
    public init(x: Int, y: Int, z: Int) {
        assert(x + y + z == 0, "Cube coordinates must sum to 0")
        self.x = x
        self.y = y
        self.z = z
    }
    
    public init(axial: AxialCoord) {
        self.x = axial.q
        self.z = axial.r
        self.y = -axial.q - axial.r
    }
    
    public var axial: AxialCoord {
        AxialCoord(q: x, r: z)
    }
    
    /// Manhattan distance between two cube coordinates.
    public func distance(to other: CubeCoord) -> Int {
        (abs(x - other.x) + abs(y - other.y) + abs(z - other.z)) / 2
    }
}

/// Vertex position on the hex grid.
/// Each hex has 6 vertices, identified by direction (0-5).
public struct VertexCoord: Sendable, Hashable, Codable {
    /// The hex this vertex is relative to.
    public let hex: AxialCoord
    /// Direction of vertex (0=N, 1=NE, 2=SE, 3=S, 4=SW, 5=NW for pointy-top).
    /// We use 0=top-right, 1=right, etc.
    public let direction: Int
    
    public init(hex: AxialCoord, direction: Int) {
        self.hex = hex
        self.direction = direction % 6
    }
    
    /// Normalize to canonical form (each vertex is shared by 3 hexes).
    public var canonical: VertexCoord {
        // Use the vertex with smallest hex coordinate and direction 0 or 1
        // This ensures consistent identity for shared vertices
        switch direction {
        case 0, 1:
            return self
        case 2:
            // Same as hex's SE neighbor, direction 0
            return VertexCoord(hex: hex.neighbor(5), direction: 0)
        case 3:
            // Same as hex's S neighbor, direction 1
            return VertexCoord(hex: hex.neighbor(4), direction: 1)
        case 4:
            // Same as hex's SW neighbor, direction: 0
            return VertexCoord(hex: hex.neighbor(4), direction: 0)
        case 5:
            // Same as hex's NW neighbor, direction 1
            return VertexCoord(hex: hex.neighbor(2), direction: 1)
        default:
            return self
        }
    }
}

/// Edge position on the hex grid.
/// Each hex has 6 edges, identified by direction (0-5).
public struct EdgeCoord: Sendable, Hashable, Codable {
    /// The hex this edge is relative to.
    public let hex: AxialCoord
    /// Direction of edge (0=E, 1=SE, 2=SW, 3=W, 4=NW, 5=NE for pointy-top).
    public let direction: Int
    
    public init(hex: AxialCoord, direction: Int) {
        self.hex = hex
        self.direction = direction % 6
    }
    
    /// Normalize to canonical form (each edge is shared by 2 hexes).
    public var canonical: EdgeCoord {
        // Use the edge with smaller direction (0, 1, or 2)
        switch direction {
        case 0, 1, 2:
            return self
        case 3:
            // Same as western neighbor's edge 0
            return EdgeCoord(hex: hex.neighbor(3), direction: 0)
        case 4:
            // Same as SW neighbor's edge 1
            return EdgeCoord(hex: hex.neighbor(4), direction: 1)
        case 5:
            // Same as NW neighbor's edge 2
            return EdgeCoord(hex: hex.neighbor(2), direction: 2)
        default:
            return self
        }
    }
    
    /// Get the two vertices at the endpoints of this edge.
    public var vertices: (VertexCoord, VertexCoord) {
        let canon = canonical
        switch canon.direction {
        case 0: // E edge connects NE and SE vertices
            return (
                VertexCoord(hex: canon.hex, direction: 0).canonical,
                VertexCoord(hex: canon.hex, direction: 1).canonical
            )
        case 1: // SE edge connects SE and S vertices
            return (
                VertexCoord(hex: canon.hex, direction: 1).canonical,
                VertexCoord(hex: canon.hex, direction: 2).canonical
            )
        case 2: // SW edge connects S and SW vertices
            return (
                VertexCoord(hex: canon.hex, direction: 2).canonical,
                VertexCoord(hex: canon.hex, direction: 3).canonical
            )
        default:
            fatalError("Canonical edge should have direction 0, 1, or 2")
        }
    }
}

