import Vapor
import Fluent
import CatanProtocol
import Foundation

/// REST controller for authentication.
struct AuthController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("api", "auth")
        auth.post("register", use: register)
        auth.post("login", use: login)
        auth.post("refresh", use: refresh)
    }
    
    /// Register a new user (dev auth).
    func register(req: Request) async throws -> AuthResponse {
        let input = try req.content.decode(RegisterRequest.self)
        
        // Check if user exists
        if try await User.query(on: req.db)
            .filter(\.$identifier == input.identifier)
            .first() != nil {
            // User exists, return error
            throw Abort(.conflict, reason: "User already exists")
        }
        
        // Create user
        let user = User(
            identifier: input.identifier,
            displayName: input.displayName ?? input.identifier
        )
        try await user.save(on: req.db)
        
        // Create session
        let session = try await AuthService.createSession(for: user, on: req.db)
        
        return AuthResponse(
            userId: user.id!.uuidString,
            sessionToken: session.token,
            displayName: user.displayName,
            expiresAt: session.expiresAt
        )
    }
    
    /// Login with existing credentials (dev auth).
    func login(req: Request) async throws -> AuthResponse {
        let input = try req.content.decode(LoginRequest.self)
        
        // Find user
        guard let user = try await User.query(on: req.db)
            .filter(\.$identifier == input.identifier)
            .first() else {
            throw Abort(.unauthorized, reason: "Invalid credentials")
        }
        
        // Create new session
        let session = try await AuthService.createSession(for: user, on: req.db)
        
        return AuthResponse(
            userId: user.id!.uuidString,
            sessionToken: session.token,
            displayName: user.displayName,
            expiresAt: session.expiresAt
        )
    }
    
    /// Refresh an existing session.
    func refresh(req: Request) async throws -> AuthResponse {
        let input = try req.content.decode(RefreshRequest.self)
        
        // Find and validate session
        guard let session = try await Session.query(on: req.db)
            .filter(\.$token == input.sessionToken)
            .with(\.$user)
            .first(),
              session.isValid else {
            throw Abort(.unauthorized, reason: "Invalid or expired session")
        }
        
        // Revoke old session
        session.isRevoked = true
        try await session.save(on: req.db)
        
        // Create new session
        let newSession = try await AuthService.createSession(for: session.user, on: req.db)
        
        return AuthResponse(
            userId: session.user.id!.uuidString,
            sessionToken: newSession.token,
            displayName: session.user.displayName,
            expiresAt: newSession.expiresAt
        )
    }
}

// MARK: - Request/Response Types

struct RegisterRequest: Content {
    let identifier: String
    let displayName: String?
}

struct LoginRequest: Content {
    let identifier: String
}

struct RefreshRequest: Content {
    let sessionToken: String
}

struct AuthResponse: Content {
    let userId: String
    let sessionToken: String
    let displayName: String
    let expiresAt: Date
}

