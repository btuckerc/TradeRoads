import Vapor
import Fluent
import FluentPostgresDriver
import GameCore

@main
struct TradeRoadsServer {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        
        let app = try await Application.make(env)
        defer { Task { try await app.asyncShutdown() } }
        
        try await configure(app)
        try await app.execute()
    }
    
    /// Configure the application.
    static func configure(_ app: Application) async throws {
        // Configure database
        let databaseURL = Environment.get("DATABASE_URL") ?? "postgres://localhost/traderoads"
        try app.databases.use(.postgres(url: databaseURL), as: .psql)
        
        // Run migrations
        app.migrations.add(CreateUsers())
        app.migrations.add(CreateSessions())
        app.migrations.add(CreateLobbies())
        app.migrations.add(CreateGames())
        app.migrations.add(CreateGameEvents())
        app.migrations.add(CreateGameSnapshots())
        
        try await app.autoMigrate()
        
        // Register routes
        try Routes.register(app)
        
        app.logger.info("TradeRoads Server starting on \(app.http.server.configuration.hostname):\(app.http.server.configuration.port)")
    }
}
