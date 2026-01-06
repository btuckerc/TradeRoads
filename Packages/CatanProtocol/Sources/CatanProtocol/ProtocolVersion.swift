// MARK: - Protocol Version

import Foundation

/// Represents the wire protocol version for client-server communication.
/// The server will reject messages outside the supported range.
public struct ProtocolVersion: Sendable, Hashable, Codable, Comparable {
    public let major: Int
    public let minor: Int
    
    public init(major: Int, minor: Int) {
        self.major = major
        self.minor = minor
    }
    
    /// The current protocol version that new clients/servers should use.
    public static let current = ProtocolVersion(major: 1, minor: 0)
    
    /// The minimum protocol version the server will accept.
    /// Clients below this version must upgrade.
    public static let minSupported = ProtocolVersion(major: 1, minor: 0)
    
    /// Check if this version is supported by the server.
    public var isSupported: Bool {
        self >= Self.minSupported && self <= Self.current
    }
    
    public static func < (lhs: ProtocolVersion, rhs: ProtocolVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        return lhs.minor < rhs.minor
    }
    
    public var stringValue: String {
        "\(major).\(minor)"
    }
}

extension ProtocolVersion: CustomStringConvertible {
    public var description: String {
        stringValue
    }
}

