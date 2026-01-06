// MARK: - Shared JSON Encoder/Decoder Configuration

import Foundation

/// Centralized JSON encoding/decoding configuration.
/// Both iOS client and Vapor server must use these exact settings
/// to ensure wire compatibility.
public enum CatanJSON {
    /// The shared JSON encoder with canonical settings.
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
    
    /// The shared JSON decoder with canonical settings.
    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
    
    /// Encode a value to JSON Data.
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }
    
    /// Decode a value from JSON Data.
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }
    
    /// Encode a value to a JSON string.
    public static func encodeToString<T: Encodable>(_ value: T) throws -> String {
        let data = try encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(value, .init(
                codingPath: [],
                debugDescription: "Failed to convert encoded data to UTF-8 string"
            ))
        }
        return string
    }
    
    /// Decode a value from a JSON string.
    public static func decode<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
        guard let data = string.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [],
                debugDescription: "Failed to convert string to UTF-8 data"
            ))
        }
        return try decode(type, from: data)
    }
}

