import Vapor
import Fluent
import CatanProtocol
import Foundation
import Crypto

/// Service for authentication operations.
enum AuthService {
    /// Session duration (7 days).
    static let sessionDuration: TimeInterval = 7 * 24 * 60 * 60
    
    /// Secret key for HMAC signing (should come from environment in production).
    private static var secretKey: SymmetricKey {
        let keyString = Environment.get("AUTH_SECRET") ?? "dev-secret-key-change-in-production"
        return SymmetricKey(data: keyString.data(using: .utf8)!)
    }
    
    /// Create a new session for a user.
    static func createSession(for user: User, on db: Database) async throws -> Session {
        let tokenData = generateSecureToken()
        let token = signToken(tokenData)
        
        let session = Session(
            userId: user.id!,
            token: token,
            expiresAt: Date().addingTimeInterval(sessionDuration)
        )
        try await session.save(on: db)
        
        return session
    }
    
    /// Validate a session token and return the user.
    static func validateSession(token: String, on db: Database) async throws -> User? {
        guard let session = try await Session.query(on: db)
            .filter(\.$token == token)
            .with(\.$user)
            .first(),
              session.isValid else {
            return nil
        }
        
        return session.user
    }
    
    /// Generate a secure random token.
    private static func generateSecureToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
    }
    
    /// Sign a token with HMAC.
    private static func signToken(_ tokenData: String) -> String {
        let signature = HMAC<SHA256>.authenticationCode(
            for: Data(tokenData.utf8),
            using: secretKey
        )
        let signatureBase64 = Data(signature).base64EncodedString()
        return "\(tokenData).\(signatureBase64)"
    }
    
    /// Verify a signed token.
    static func verifyToken(_ token: String) -> Bool {
        let parts = token.split(separator: ".")
        guard parts.count == 2 else { return false }
        
        let tokenData = String(parts[0])
        let providedSignature = String(parts[1])
        
        let expectedSignature = HMAC<SHA256>.authenticationCode(
            for: Data(tokenData.utf8),
            using: secretKey
        )
        let expectedSignatureBase64 = Data(expectedSignature).base64EncodedString()
        
        return providedSignature == expectedSignatureBase64
    }
}

