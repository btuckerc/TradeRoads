import Fluent
import Vapor
import CatanProtocol
import GameCore

/// Game model for persistence.
final class Game: Model, Content, @unchecked Sendable {
    static let schema = "games"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "player_mode")
    var playerMode: String
    
    @Field(key: "use_beginner_layout")
    var useBeginnerLayout: Bool
    
    @Field(key: "board_seed")
    var boardSeed: Int64
    
    @Field(key: "players_json")
    var playersJson: String
    
    @Field(key: "status")
    var status: String  // "active", "completed", "abandoned"
    
    @Field(key: "winner_user_id")
    var winnerUserId: UUID?
    
    @Field(key: "event_count")
    var eventCount: Int
    
    @Field(key: "created_at")
    var createdAt: Date
    
    @Field(key: "updated_at")
    var updatedAt: Date
    
    init() {}
    
    init(
        id: UUID? = nil,
        playerMode: PlayerMode,
        useBeginnerLayout: Bool,
        boardSeed: Int64,
        players: [GamePlayerInfo]
    ) {
        self.id = id
        self.playerMode = playerMode.rawValue
        self.useBeginnerLayout = useBeginnerLayout
        self.boardSeed = boardSeed
        self.playersJson = Self.encodePlayersJson(players)
        self.status = "active"
        self.winnerUserId = nil
        self.eventCount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var playerModeEnum: PlayerMode {
        PlayerMode(rawValue: playerMode) ?? .threeToFour
    }
    
    var players: [GamePlayerInfo] {
        get {
            guard let data = playersJson.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([GamePlayerInfo].self, from: data)) ?? []
        }
        set {
            playersJson = Self.encodePlayersJson(newValue)
        }
    }
    
    static func encodePlayersJson(_ players: [GamePlayerInfo]) -> String {
        if let data = try? JSONEncoder().encode(players),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "[]"
    }
}

/// Player info stored in game JSON.
struct GamePlayerInfo: Codable, Sendable {
    var playerId: String
    var userId: String
    var displayName: String
    var color: PlayerColor
    var turnOrder: Int
}

/// Migration to create games table.
struct CreateGames: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("games")
            .id()
            .field("player_mode", .string, .required)
            .field("use_beginner_layout", .bool, .required)
            .field("board_seed", .int64, .required)
            .field("players_json", .string, .required)
            .field("status", .string, .required)
            .field("winner_user_id", .uuid)
            .field("event_count", .int, .required)
            .field("created_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("games").delete()
    }
}

