import Fluent
import Vapor
import GameCore

/// Persisted game event for event sourcing.
final class GameEventModel: Model, Content, @unchecked Sendable {
    static let schema = "game_events"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "game_id")
    var game: Game
    
    @Field(key: "event_index")
    var eventIndex: Int
    
    @Field(key: "event_type")
    var eventType: String
    
    @Field(key: "event_json")
    var eventJson: String
    
    @Field(key: "created_at")
    var createdAt: Date
    
    init() {}
    
    init(id: UUID? = nil, gameId: UUID, eventIndex: Int, event: DomainEvent) throws {
        self.id = id
        self.$game.id = gameId
        self.eventIndex = eventIndex
        self.eventType = String(describing: type(of: event))
        self.eventJson = try CatanJSON.encodeToString(event)
        self.createdAt = Date()
    }
    
    func decodeEvent() throws -> DomainEvent {
        try CatanJSON.decode(DomainEvent.self, from: eventJson)
    }
}

/// Migration to create game_events table.
struct CreateGameEvents: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("game_events")
            .id()
            .field("game_id", .uuid, .required, .references("games", "id"))
            .field("event_index", .int, .required)
            .field("event_type", .string, .required)
            .field("event_json", .sql(.text), .required)
            .field("created_at", .datetime, .required)
            .unique(on: "game_id", "event_index")
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("game_events").delete()
    }
}
