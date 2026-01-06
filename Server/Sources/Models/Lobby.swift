import Fluent
import Vapor
import CatanProtocol

/// Lobby model for matchmaking.
final class Lobby: Model, Content, @unchecked Sendable {
    static let schema = "lobbies"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "code")
    var code: String
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "host_user_id")
    var hostUserId: UUID
    
    @Field(key: "player_mode")
    var playerMode: String  // "3-4" or "5-6"
    
    @Field(key: "use_beginner_layout")
    var useBeginnerLayout: Bool
    
    @Field(key: "players_json")
    var playersJson: String  // JSON array of LobbyPlayerInfo
    
    @Field(key: "status")
    var status: String  // "waiting", "started", "closed"
    
    @Field(key: "game_id")
    var gameId: UUID?
    
    @Field(key: "created_at")
    var createdAt: Date
    
    init() {}
    
    init(
        id: UUID? = nil,
        code: String,
        name: String,
        hostUserId: UUID,
        playerMode: PlayerMode,
        useBeginnerLayout: Bool
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.hostUserId = hostUserId
        self.playerMode = playerMode.rawValue
        self.useBeginnerLayout = useBeginnerLayout
        self.playersJson = "[]"
        self.status = "waiting"
        self.gameId = nil
        self.createdAt = Date()
    }
    
    var playerModeEnum: PlayerMode {
        PlayerMode(rawValue: playerMode) ?? .threeToFour
    }
    
    var players: [LobbyPlayerInfo] {
        get {
            guard let data = playersJson.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([LobbyPlayerInfo].self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                playersJson = json
            }
        }
    }
}

/// Player info stored in lobby JSON.
struct LobbyPlayerInfo: Codable, Sendable {
    var userId: String
    var displayName: String
    var color: PlayerColor?
    var isReady: Bool
    var isHost: Bool
}

/// Migration to create lobbies table.
struct CreateLobbies: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("lobbies")
            .id()
            .field("code", .string, .required)
            .field("name", .string, .required)
            .field("host_user_id", .uuid, .required)
            .field("player_mode", .string, .required)
            .field("use_beginner_layout", .bool, .required)
            .field("players_json", .string, .required)
            .field("status", .string, .required)
            .field("game_id", .uuid)
            .field("created_at", .datetime, .required)
            .unique(on: "code")
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("lobbies").delete()
    }
}

