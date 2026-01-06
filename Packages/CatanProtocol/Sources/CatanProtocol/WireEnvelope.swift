// MARK: - Wire Envelope

import Foundation

/// Envelope for all client-to-server messages.
/// Every message from the client is wrapped in this structure.
public struct ClientEnvelope: Sendable, Codable, Hashable {
    /// The protocol version the client is using.
    public let protocolVersion: ProtocolVersion
    
    /// Unique identifier for this request (for correlation).
    public let requestId: String
    
    /// The last event index the client has seen (for reconnection/sync).
    public let lastSeenEventIndex: Int?
    
    /// When the message was sent (client clock).
    public let sentAt: Date
    
    /// The actual message payload.
    public let message: ClientMessage
    
    public init(
        protocolVersion: ProtocolVersion = .current,
        requestId: String,
        lastSeenEventIndex: Int? = nil,
        sentAt: Date = Date(),
        message: ClientMessage
    ) {
        self.protocolVersion = protocolVersion
        self.requestId = requestId
        self.lastSeenEventIndex = lastSeenEventIndex
        self.sentAt = sentAt
        self.message = message
    }
}

/// Envelope for all server-to-client messages.
/// Every message from the server is wrapped in this structure.
public struct ServerEnvelope: Sendable, Codable, Hashable {
    /// The protocol version the server is using.
    public let protocolVersion: ProtocolVersion
    
    /// Correlation ID matching a client request (if applicable).
    public let correlationId: String?
    
    /// When the message was sent (server clock).
    public let sentAt: Date
    
    /// The actual message payload.
    public let message: ServerMessage
    
    public init(
        protocolVersion: ProtocolVersion = .current,
        correlationId: String? = nil,
        sentAt: Date = Date(),
        message: ServerMessage
    ) {
        self.protocolVersion = protocolVersion
        self.correlationId = correlationId
        self.sentAt = sentAt
        self.message = message
    }
}

