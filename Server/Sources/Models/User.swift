import Fluent
import Vapor

/// User model for persistence.
final class User: Model, Content, @unchecked Sendable {
    static let schema = "users"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "identifier")
    var identifier: String
    
    @Field(key: "display_name")
    var displayName: String
    
    @Field(key: "created_at")
    var createdAt: Date
    
    @Field(key: "updated_at")
    var updatedAt: Date
    
    init() {}
    
    init(id: UUID? = nil, identifier: String, displayName: String) {
        self.id = id
        self.identifier = identifier
        self.displayName = displayName
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

/// Migration to create users table.
struct CreateUsers: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .id()
            .field("identifier", .string, .required)
            .field("display_name", .string, .required)
            .field("created_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "identifier")
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("users").delete()
    }
}

