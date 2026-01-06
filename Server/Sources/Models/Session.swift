import Fluent
import Vapor
import Foundation

/// Session model for auth tokens.
final class Session: Model, Content, @unchecked Sendable {
    static let schema = "sessions"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "token")
    var token: String
    
    @Field(key: "created_at")
    var createdAt: Date
    
    @Field(key: "expires_at")
    var expiresAt: Date
    
    @Field(key: "is_revoked")
    var isRevoked: Bool
    
    init() {}
    
    init(id: UUID? = nil, userId: UUID, token: String, expiresAt: Date) {
        self.id = id
        self.$user.id = userId
        self.token = token
        self.createdAt = Date()
        self.expiresAt = expiresAt
        self.isRevoked = false
    }
    
    var isValid: Bool {
        !isRevoked && expiresAt > Date()
    }
}

/// Migration to create sessions table.
struct CreateSessions: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("sessions")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id"))
            .field("token", .string, .required)
            .field("created_at", .datetime, .required)
            .field("expires_at", .datetime, .required)
            .field("is_revoked", .bool, .required)
            .unique(on: "token")
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("sessions").delete()
    }
}

