// MARK: - CatanProtocol Module

/// CatanProtocol provides the wire protocol types for client-server communication
/// in the TradeRoads game. Both the iOS client and Vapor server import this package
/// to ensure type-safe, version-compatible message exchange.
///
/// # Architecture
///
/// All messages are wrapped in envelopes:
/// - `ClientEnvelope` wraps `ClientMessage` for client-to-server communication
/// - `ServerEnvelope` wraps `ServerMessage` for server-to-client communication
///
/// # Versioning
///
/// The protocol uses semantic versioning via `ProtocolVersion`. The server will
/// reject messages with versions outside the `[minSupported, current]` range.
///
/// # JSON Encoding
///
/// Use `CatanJSON.encoder` and `CatanJSON.decoder` for all serialization to ensure
/// consistent date and key formatting between client and server.
///
/// # Example Usage
///
/// ```swift
/// // Client sending a message
/// let message = ClientMessage.rollDice
/// let envelope = ClientEnvelope(
///     requestId: UUID().uuidString,
///     message: message
/// )
/// let data = try CatanJSON.encode(envelope)
///
/// // Server decoding a message
/// let envelope = try CatanJSON.decode(ClientEnvelope.self, from: data)
/// guard envelope.protocolVersion.isSupported else {
///     // Send protocol error response
/// }
/// ```

@_exported import Foundation
