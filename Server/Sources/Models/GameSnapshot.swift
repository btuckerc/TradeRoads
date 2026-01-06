import Fluent
import Vapor
import GameCore

/// Persisted game state snapshot for fast reconnection.
/// Named with "Model" suffix to avoid collision with CatanProtocol's GameSnapshot wire type.
final class GameSnapshotModel: Model, Content, @unchecked Sendable {
    static let schema = "game_snapshots"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "game_id")
    var game: Game
    
    @Field(key: "event_index")
    var eventIndex: Int
    
    @Field(key: "state_json")
    var stateJson: String
    
    @Field(key: "created_at")
    var createdAt: Date
    
    init() {}
    
    init(id: UUID? = nil, gameId: UUID, eventIndex: Int, state: GameState) throws {
        self.id = id
        self.$game.id = gameId
        self.eventIndex = eventIndex
        self.stateJson = try CatanJSON.encodeToString(state)
        self.createdAt = Date()
    }
    
    func decodeState() throws -> GameState {
        try CatanJSON.decode(GameState.self, from: stateJson)
    }
}

/// Migration to create game_snapshots table.
struct CreateGameSnapshots: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("game_snapshots")
            .id()
            .field("game_id", .uuid, .required, .references("games", "id"))
            .field("event_index", .int, .required)
            .field("state_json", .sql(.text), .required)
            .field("created_at", .datetime, .required)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("game_snapshots").delete()
    }
}
