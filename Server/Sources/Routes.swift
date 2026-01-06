import Vapor
import GameCore

/// Route registration for the server.
enum Routes {
    /// Register application routes.
    static func register(_ app: Application) throws {
        // Health check
        app.get("health") { _ in
            ["status": "ok"]
        }
        
        // API version
        app.get("api", "version") { _ in
            [
                "version": ProtocolVersion.current.stringValue,
                "minSupported": ProtocolVersion.minSupported.stringValue
            ]
        }
        
        // WebSocket endpoint
        app.webSocket("ws") { req, ws async in
            await WebSocketHandler.shared.handleConnection(req: req, ws: ws, app: req.application)
        }
        
        // REST endpoints for auth (alternative to WS auth)
        let authController = AuthController()
        try app.register(collection: authController)
    }
}
